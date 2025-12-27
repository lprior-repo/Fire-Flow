//! Test Execution - Run tests on generated code
//!
//! Windmill Rust script that executes tests for generated code.
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
use std::process::Stdio;
use tokio::process::Command;

#[derive(Deserialize)]
pub struct TestExecutionInput {
    /// Path to generated code file or project root
    pub code_path: String,
    /// Language of the code (rust, python, typescript, go)
    pub language: String,
    /// Where to write test results
    #[serde(default = "default_output_path")]
    pub output_path: String,
    /// Where to write test logs
    #[serde(default = "default_logs_path")]
    pub logs_path: String,
    /// Timeout in seconds for test execution
    #[serde(default = "default_timeout")]
    pub timeout_seconds: u64,
    /// Trace ID for observability
    #[serde(default)]
    pub trace_id: String,
    /// Skip actual test execution
    #[serde(default)]
    pub dry_run: bool,
}

fn default_output_path() -> String { "/tmp/test_results.json".to_string() }
fn default_logs_path() -> String { "/tmp/test_logs.json".to_string() }
fn default_timeout() -> u64 { 120 }

#[derive(Serialize)]
pub struct TestExecutionOutput {
    pub success: bool,
    pub exit_code: i32,
    pub output_path: String,
    pub logs_path: String,
    pub was_dry_run: bool,
    pub tests_passed: u32,
    pub tests_failed: u32,
}

/// Get the test command based on language and code path
fn get_test_command(language: &str, code_path: &str) -> Result<(String, Vec<String>, Option<String>)> {
    match language {
        "rust" => {
            // For Rust, run cargo test in the parent directory or current directory
            let parent = std::path::Path::new(code_path).parent()
                .and_then(|p| p.to_str())
                .unwrap_or("/tmp");

            Ok(("cargo".to_string(),
                vec!["test".to_string(), "--".to_string(), "--nocapture".to_string()],
                Some(parent.to_string())))
        }
        "python" => {
            // For Python, use pytest
            Ok(("pytest".to_string(),
                vec!["-v".to_string(), code_path.to_string()],
                None))
        }
        "typescript" => {
            // For TypeScript, try jest first, then vitest
            // Run in the parent directory where package.json likely exists
            let parent = std::path::Path::new(code_path).parent()
                .and_then(|p| p.to_str())
                .unwrap_or("/tmp");

            Ok(("npx".to_string(),
                vec!["jest".to_string(), code_path.to_string()],
                Some(parent.to_string())))
        }
        "go" => {
            // For Go, use go test
            let parent = std::path::Path::new(code_path).parent()
                .and_then(|p| p.to_str())
                .unwrap_or("/tmp");

            Ok(("go".to_string(),
                vec!["test".to_string(), "-v".to_string(), "./...".to_string()],
                Some(parent.to_string())))
        }
        _ => Err(anyhow!("Unsupported language for testing: {}", language)),
    }
}

/// Parse test results to extract pass/fail counts
fn parse_test_results(output: &str, language: &str) -> (u32, u32) {
    let mut passed = 0;
    let mut failed = 0;

    match language {
        "rust" => {
            // Rust cargo test output shows "test result: ok. X passed; Y failed"
            if let Some(line) = output.lines().find(|l| l.contains("test result:")) {
                if line.contains("ok.") {
                    // Count from the passed field
                    if let Some(p) = line.split("passed").next() {
                        if let Some(num) = p.split_whitespace().last() {
                            if let Ok(n) = num.parse::<u32>() {
                                passed = n;
                            }
                        }
                    }
                } else if line.contains("FAILED") {
                    // Extract failure count
                    if let Some(f) = line.split("failed").next() {
                        if let Some(num) = f.split_whitespace().last() {
                            if let Ok(n) = num.parse::<u32>() {
                                failed = n;
                            }
                        }
                    }
                }
            }
        }
        "python" => {
            // pytest output shows "X passed" or "X failed"
            for line in output.lines() {
                if line.contains(" passed") {
                    if let Some(num_str) = line.split_whitespace().next() {
                        if let Ok(n) = num_str.parse::<u32>() {
                            passed = n;
                        }
                    }
                }
                if line.contains(" failed") {
                    if let Some(num_str) = line.split_whitespace().next() {
                        if let Ok(n) = num_str.parse::<u32>() {
                            failed = n;
                        }
                    }
                }
            }
        }
        "typescript" => {
            // Jest output shows "Tests: X passed, Y failed"
            for line in output.lines() {
                if line.contains("Tests:") {
                    // Parse "Tests: X passed, Y failed"
                    let parts: Vec<&str> = line.split(|c| c == ',' || c == ':').collect();
                    for (i, part) in parts.iter().enumerate() {
                        if part.contains("passed") && i > 0 {
                            if let Ok(n) = parts[i - 1].trim().parse::<u32>() {
                                passed = n;
                            }
                        }
                        if part.contains("failed") && i > 0 {
                            if let Ok(n) = parts[i - 1].trim().parse::<u32>() {
                                failed = n;
                            }
                        }
                    }
                }
            }
        }
        "go" => {
            // Go test output shows "ok\tmodule\t1.234s" or "FAIL\tmodule"
            let passed_tests = output.lines().filter(|l| l.starts_with("ok")).count();
            let failed_tests = output.lines().filter(|l| l.starts_with("FAIL")).count();
            passed = passed_tests as u32;
            failed = failed_tests as u32;
        }
        _ => {}
    }

    (passed, failed)
}

pub async fn main(input: TestExecutionInput) -> Result<TestExecutionOutput> {
    eprintln!("[test_execution] Starting test execution for {}", input.code_path);
    eprintln!("[test_execution] Language: {}", input.language);

    // Dry run mode
    if input.dry_run {
        eprintln!("[test_execution] Dry run mode - skipping test execution");
        let results = serde_json::json!({
            "dry_run": true,
            "message": "Test execution skipped"
        });
        tokio::fs::write(&input.output_path, results.to_string()).await?;
        tokio::fs::write(&input.logs_path, "[]").await?;
        return Ok(TestExecutionOutput {
            success: true,
            exit_code: 0,
            output_path: input.output_path,
            logs_path: input.logs_path,
            was_dry_run: true,
            tests_passed: 0,
            tests_failed: 0,
        });
    }

    // Get test command
    let (cmd, args, work_dir) = get_test_command(&input.language, &input.code_path)?;
    eprintln!("[test_execution] Command: {} {:?}", cmd, args);

    // Build command
    let mut command = Command::new(&cmd);
    command.args(&args)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());

    // Set working directory if specified
    if let Some(dir) = work_dir {
        command.current_dir(&dir);
        eprintln!("[test_execution] Working directory: {}", dir);
    }

    // Execute with timeout
    let child = command.spawn()?;

    let result = tokio::time::timeout(
        std::time::Duration::from_secs(input.timeout_seconds),
        child.wait_with_output()
    ).await;

    let (exit_code, stdout, stderr) = match result {
        Ok(Ok(output)) => {
            (output.status.code().unwrap_or(1),
             String::from_utf8_lossy(&output.stdout).to_string(),
             String::from_utf8_lossy(&output.stderr).to_string())
        }
        Ok(Err(e)) => {
            eprintln!("[test_execution] Command execution failed: {}", e);
            let error_msg = format!("Test execution failed: {}", e);
            tokio::fs::write(&input.logs_path, &error_msg).await?;
            return Ok(TestExecutionOutput {
                success: false,
                exit_code: 1,
                output_path: input.output_path,
                logs_path: input.logs_path,
                was_dry_run: false,
                tests_passed: 0,
                tests_failed: 1,
            });
        }
        Err(_) => {
            eprintln!("[test_execution] Test execution timed out after {} seconds", input.timeout_seconds);
            let timeout_msg = format!("Test execution timed out after {} seconds", input.timeout_seconds);
            tokio::fs::write(&input.logs_path, &timeout_msg).await?;
            return Ok(TestExecutionOutput {
                success: false,
                exit_code: 124, // Standard timeout exit code
                output_path: input.output_path,
                logs_path: input.logs_path,
                was_dry_run: false,
                tests_passed: 0,
                tests_failed: 1,
            });
        }
    };

    // Parse test results
    let (tests_passed, tests_failed) = parse_test_results(&stdout, &input.language);
    let success = exit_code == 0 && tests_failed == 0;

    // Save results
    let results = serde_json::json!({
        "exit_code": exit_code,
        "success": success,
        "tests_passed": tests_passed,
        "tests_failed": tests_failed,
        "language": input.language,
    });

    tokio::fs::write(&input.output_path, results.to_string()).await?;
    let logs = format!("STDOUT:\n{}\n\nSTDERR:\n{}", stdout, stderr);
    tokio::fs::write(&input.logs_path, logs).await?;

    eprintln!("[test_execution] Tests completed: {} passed, {} failed", tests_passed, tests_failed);
    eprintln!("[test_execution] Exit code: {}", exit_code);

    Ok(TestExecutionOutput {
        success,
        exit_code,
        output_path: input.output_path,
        logs_path: input.logs_path,
        was_dry_run: false,
        tests_passed,
        tests_failed,
    })
}
