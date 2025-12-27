//! Generate Rust - Wrapper for bt-generate tool
//!
//! Calls the Rust-based code generation tool

use serde::{Deserialize, Serialize};
use std::process::Command;

#[derive(Deserialize)]
pub struct GenerateInput {
    pub contract_path: String,
    pub task: String,
    pub language: String,
    pub model: String,
    pub output_path: String,
    pub trace_id: String,
    pub dry_run: bool,
}

#[derive(Serialize)]
pub struct GenerateOutput {
    pub generated: bool,
    pub output_path: String,
    pub language: String,
    pub was_dry_run: bool,
}

pub fn main(input: GenerateInput) -> anyhow::Result<GenerateOutput> {
    // Build JSON input for bt-generate
    let json_input = serde_json::json!({
        "contract_path": input.contract_path,
        "task": input.task,
        "language": input.language,
        "model": input.model,
        "output_path": input.output_path,
        "context": {
            "trace_id": input.trace_id,
            "dry_run": input.dry_run
        }
    });

    // Call the Rust binary
    let output = Command::new("/home/lewis/src/Fire-Flow/bitter-truth-rs/target/release/generate")
        .arg(serde_json::to_string(&json_input)?)
        .output()?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(anyhow::anyhow!("Generation failed: {}", stderr));
    }

    let stdout = String::from_utf8(output.stdout)?;
    let response: serde_json::Value = serde_json::from_str(&stdout)?;

    if !response["success"].as_bool().unwrap_or(false) {
        return Err(anyhow::anyhow!("Generation failed: {}", response["error"]));
    }

    Ok(serde_json::from_value(response["data"].clone())?)
}
