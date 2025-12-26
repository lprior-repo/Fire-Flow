//! Execute - Run generated code and capture output
//!
//! Windmill Rust script that executes generated code with input.
//!
//! ```cargo
//! [dependencies]
//! anyhow = "1.0"
//! serde = { version = "1.0", features = ["derive"] }
//! serde_json = "1.0"
//! tokio = { version = "1", features = ["process", "fs"] }
//! ```

use anyhow::{anyhow, Result};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::process::Stdio;
use tokio::io::AsyncWriteExt;
use tokio::process::Command;

#[derive(Deserialize)]
pub struct ExecuteInput {
    /// Path to generated code file
    pub code_path: String,
    /// Language of the code (rust, python, typescript, go)
    pub language: String,
    /// JSON input for the code
    #[serde(default = "default_input")]
    pub code_input: Value,
    /// Where to write output
    #[serde(default = "default_output_path")]
    pub output_path: String,
    /// Where to write logs
    #[serde(default = "default_logs_path")]
    pub logs_path: String,
    /// Timeout in seconds
    #[serde(default = "default_timeout")]
    pub timeout_seconds: u64,
    /// Trace ID for observability
    #[serde(default)]
    pub trace_id: String,
    /// Skip actual execution
    #[serde(default)]
    pub dry_run: bool,
}

fn default_input() -> Value { Value::Object(serde_json::Map::new()) }
fn default_output_path() -> String { "/tmp/output.json".to_string() }
fn default_logs_path() -> String { "/tmp/logs.json".to_string() }
fn default_timeout() -> u64 { 60 }

#[derive(Serialize)]
pub struct ExecuteOutput {
    pub exit_code: i32,
    pub output_path: String,
    pub logs_path: String,
    pub was_dry_run: bool,
}

/// Get the command to run based on language
fn get_run_command(language: &str, code_path: &str) -> Result<(String, Vec<String>)> {
    match language {
        "rust" => {
            // For Rust, we need to compile first or use cargo-script
            // Using rustc for simplicity, or could use cargo
            Ok(("rustc".to_string(), vec![
                "--edition=2021".to_string(),
                "-o".to_string(),
                "/tmp/rust_binary".to_string(),
                code_path.to_string(),
            ]))
        }
        "python" => Ok(("python3".to_string(), vec![code_path.to_string()])),
        "typescript" => Ok(("deno".to_string(), vec!["run".to_string(), code_path.to_string()])),
        "go" => Ok(("go".to_string(), vec!["run".to_string(), code_path.to_string()])),
        "nushell" | "nu" => Ok(("nu".to_string(), vec![code_path.to_string()])),
        _ => Err(anyhow!("Unsupported language: {}", language)),
    }
}

pub async fn main(input: ExecuteInput) -> Result<ExecuteOutput> {
    eprintln!("[execute] Starting execution of {}", input.code_path);
    eprintln!("[execute] Language: {}", input.language);

    // Validate code exists
    if !tokio::fs::try_exists(&input.code_path).await.unwrap_or(false) {
        return Err(anyhow!("Code file not found: {}", input.code_path));
    }

    // Dry run mode
    if input.dry_run {
        eprintln!("[execute] Dry run mode - skipping execution");
        let output = serde_json::json!({ "dry_run": true });
        tokio::fs::write(&input.output_path, output.to_string()).await?;
        tokio::fs::write(&input.logs_path, "[]").await?;
        return Ok(ExecuteOutput {
            exit_code: 0,
            output_path: input.output_path,
            logs_path: input.logs_path,
            was_dry_run: true,
        });
    }

    let input_json = serde_json::to_string(&input.code_input)?;
    eprintln!("[execute] Input: {} bytes", input_json.len());

    // Get run command
    let (cmd, args) = get_run_command(&input.language, &input.code_path)?;
    eprintln!("[execute] Command: {} {:?}", cmd, args);

    // For Rust, compile first
    if input.language == "rust" {
        eprintln!("[execute] Compiling Rust code...");
        let compile = Command::new(&cmd)
            .args(&args)
            .output()
            .await?;

        if !compile.status.success() {
            let stderr = String::from_utf8_lossy(&compile.stderr);
            eprintln!("[execute] Compilation failed: {}", stderr);
            tokio::fs::write(&input.logs_path, &stderr.as_bytes()).await?;
            tokio::fs::write(&input.output_path, r#"{"error": "compilation failed"}"#).await?;
            return Ok(ExecuteOutput {
                exit_code: compile.status.code().unwrap_or(1),
                output_path: input.output_path,
                logs_path: input.logs_path,
                was_dry_run: false,
            });
        }

        // Now run the compiled binary
        let mut child = Command::new("timeout")
            .args([
                "--foreground",
                &format!("{}s", input.timeout_seconds),
                "/tmp/rust_binary",
            ])
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()?;

        if let Some(mut stdin) = child.stdin.take() {
            stdin.write_all(input_json.as_bytes()).await?;
        }

        let result = child.wait_with_output().await?;
        let exit_code = result.status.code().unwrap_or(1);

        tokio::fs::write(&input.output_path, &result.stdout).await?;
        tokio::fs::write(&input.logs_path, &result.stderr).await?;

        eprintln!("[execute] Completed with exit code {}", exit_code);
        return Ok(ExecuteOutput {
            exit_code,
            output_path: input.output_path,
            logs_path: input.logs_path,
            was_dry_run: false,
        });
    }

    // For interpreted languages, run directly with timeout
    let mut child = Command::new("timeout")
        .args([
            "--foreground",
            &format!("{}s", input.timeout_seconds),
        ])
        .arg(&cmd)
        .args(&args)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()?;

    if let Some(mut stdin) = child.stdin.take() {
        stdin.write_all(input_json.as_bytes()).await?;
    }

    let result = child.wait_with_output().await?;
    let exit_code = result.status.code().unwrap_or(1);

    // Save outputs
    tokio::fs::write(&input.output_path, &result.stdout).await?;
    tokio::fs::write(&input.logs_path, &result.stderr).await?;

    eprintln!("[execute] Completed with exit code {}", exit_code);
    eprintln!("[execute] Output: {} bytes, Logs: {} bytes",
        result.stdout.len(), result.stderr.len());

    Ok(ExecuteOutput {
        exit_code,
        output_path: input.output_path,
        logs_path: input.logs_path,
        was_dry_run: false,
    })
}
