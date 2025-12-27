//! Validate - Test data against a DataContract
//!
//! Windmill Rust script that validates output against a DataContract schema.
//!
//! ```cargo
//! [dependencies]
//! anyhow = "1.0"
//! serde = { version = "1.0", features = ["derive"] }
//! serde_json = "1.0"
//! serde_yaml = "0.9"
//! ```

use anyhow::{anyhow, Result};
use serde::{Deserialize, Serialize};
use std::process::{Command, Stdio};

#[derive(Deserialize)]
pub struct ValidateInput {
    /// Path to DataContract YAML file
    pub contract_path: String,
    /// Path to output file to validate
    pub output_path: String,
    /// Server name in contract (default: "local")
    #[serde(default = "default_server")]
    pub server: String,
    /// Trace ID for observability
    #[serde(default)]
    pub trace_id: String,
    /// Skip actual validation
    #[serde(default)]
    pub dry_run: bool,
}

fn default_server() -> String { "local".to_string() }

#[derive(Serialize)]
pub struct ValidateOutput {
    pub valid: bool,
    pub errors: Vec<String>,
    pub was_dry_run: bool,
}

/// Extract the expected data path from contract's servers section
fn get_contract_data_path(contract_path: &str, server: &str) -> Result<String> {
    let content = std::fs::read_to_string(contract_path)?;
    let yaml: serde_yaml::Value = serde_yaml::from_str(&content)?;

    yaml.get("servers")
        .and_then(|s| s.get(server))
        .and_then(|s| s.get("path"))
        .and_then(|p| p.as_str())
        .map(String::from)
        .ok_or_else(|| anyhow!("Contract missing servers.{}.path", server))
}

pub fn main(input: ValidateInput) -> Result<ValidateOutput> {
    eprintln!("[validate] Starting validation");
    eprintln!("[validate] Contract: {}", input.contract_path);
    eprintln!("[validate] Output: {}", input.output_path);

    // Validate files exist
    if !std::path::Path::new(&input.contract_path).exists() {
        return Err(anyhow!("Contract not found: {}", input.contract_path));
    }

    // Dry run mode
    if input.dry_run {
        eprintln!("[validate] Dry run mode - skipping validation");
        return Ok(ValidateOutput {
            valid: true,
            errors: vec![],
            was_dry_run: true,
        });
    }

    if !std::path::Path::new(&input.output_path).exists() {
        return Err(anyhow!("Output file not found: {}", input.output_path));
    }

    // Get expected path from contract
    let contract_expected_path = get_contract_data_path(&input.contract_path, &input.server)?;
    eprintln!("[validate] Contract expects data at: {}", contract_expected_path);

    // Copy output to expected location if different
    if input.output_path != contract_expected_path {
        eprintln!("[validate] Copying {} -> {}", input.output_path, contract_expected_path);
        std::fs::copy(&input.output_path, &contract_expected_path)?;
    }

    // Run datacontract test
    eprintln!("[validate] Running datacontract test --server {}", input.server);
    let result = Command::new("datacontract")
        .args(["test", "--server", &input.server, &input.contract_path])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()?;

    let exit_code = result.status.code().unwrap_or(1);
    let stdout = String::from_utf8_lossy(&result.stdout);
    let stderr = String::from_utf8_lossy(&result.stderr);

    eprintln!("[validate] datacontract exit code: {}", exit_code);
    if !stdout.is_empty() {
        eprintln!("[validate] stdout: {}", stdout);
    }
    if !stderr.is_empty() {
        eprintln!("[validate] stderr: {}", stderr);
    }

    let is_valid = exit_code == 0;

    // Parse errors from output
    let errors: Vec<String> = if is_valid {
        vec![]
    } else {
        stdout
            .lines()
            .chain(stderr.lines())
            .filter(|line| !line.is_empty())
            .map(String::from)
            .collect()
    };

    eprintln!("[validate] Result: valid={}, errors={}", is_valid, errors.len());

    Ok(ValidateOutput {
        valid: is_valid,
        errors,
        was_dry_run: false,
    })
}
