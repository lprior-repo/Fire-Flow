//! Gate 1: Syntax Check (Parse + Lint + Type)
//!
//! First gate in the 10-gate validation pipeline.
//! Validates code syntax, runs linters, and checks types.
//!
//! ```cargo
//! [dependencies]
//! anyhow = "1.0"
//! serde = { version = "1.0", features = ["derive"] }
//! serde_json = "1.0"
//! tokio = { version = "1", features = ["process", "io-util"] }
//! ```

use anyhow::{anyhow, Result};
use serde::{Deserialize, Serialize};
use std::process::Stdio;
use tokio::io::AsyncWriteExt;
use tokio::process::Command;

#[derive(Deserialize)]
pub struct Gate1Input {
    /// Path to the code file to validate
    pub code_path: String,
    /// Programming language (rust, python, typescript, go)
    pub language: String,
    /// Trace ID for observability
    #[serde(default)]
    pub trace_id: String,
    /// Skip actual validation
    #[serde(default)]
    pub dry_run: bool,
}

#[derive(Serialize)]
pub struct Gate1Output {
    /// Whether all checks passed
    pub passed: bool,
    /// Whether syntax check passed
    pub syntax_ok: bool,
    /// Whether lint check passed
    pub lint_ok: bool,
    /// Whether type check passed
    pub type_ok: bool,
    /// Error messages from failed checks
    pub errors: Vec<String>,
    /// Whether this was a dry run
    pub was_dry_run: bool,
}

/// Internal structure matching gate1.nu output
#[derive(Deserialize)]
struct Gate1NuResponse {
    success: bool,
    data: Option<Gate1NuData>,
    error: Option<String>,
    trace_id: Option<String>,
    duration_ms: Option<f64>,
}

#[derive(Deserialize)]
struct Gate1NuData {
    passed: bool,
    syntax_ok: bool,
    lint_ok: bool,
    type_ok: bool,
    errors: Vec<String>,
    was_dry_run: bool,
}

pub async fn main(input: Gate1Input) -> Result<Gate1Output> {
    eprintln!("[gate1] Starting Gate 1 validation");
    eprintln!("[gate1] Code path: {}", input.code_path);
    eprintln!("[gate1] Language: {}", input.language);

    // Build input for gate1.nu
    let nu_input = serde_json::json!({
        "code_path": input.code_path,
        "language": input.language,
        "context": {
            "trace_id": input.trace_id,
            "dry_run": input.dry_run
        }
    });

    // Find gate1.nu - check common locations
    let gate1_paths = [
        "/home/lewis/src/Fire-Flow/bitter-truth/tools/gate1.nu",
        "./bitter-truth/tools/gate1.nu",
        "/app/tools/gate1.nu",
    ];

    let gate1_path = gate1_paths
        .iter()
        .find(|p| std::path::Path::new(p).exists())
        .ok_or_else(|| anyhow!("gate1.nu not found in any known location"))?;

    eprintln!("[gate1] Using gate1.nu at: {}", gate1_path);

    // Run gate1.nu
    let mut child = Command::new("nu")
        .arg(gate1_path)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()?;

    // Write input to stdin
    if let Some(mut stdin) = child.stdin.take() {
        stdin.write_all(nu_input.to_string().as_bytes()).await?;
    }

    let output = child.wait_with_output().await?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);

    eprintln!("[gate1] gate1.nu stderr:\n{}", stderr);
    eprintln!("[gate1] gate1.nu stdout:\n{}", stdout);

    // Parse response
    let response: Gate1NuResponse = serde_json::from_str(&stdout)
        .map_err(|e| anyhow!("Failed to parse gate1.nu output: {} - stdout was: {}", e, stdout))?;

    if let Some(data) = response.data {
        Ok(Gate1Output {
            passed: data.passed,
            syntax_ok: data.syntax_ok,
            lint_ok: data.lint_ok,
            type_ok: data.type_ok,
            errors: data.errors,
            was_dry_run: data.was_dry_run,
        })
    } else {
        Err(anyhow!(
            "Gate 1 validation failed: {}",
            response.error.unwrap_or_else(|| "Unknown error".to_string())
        ))
    }
}
