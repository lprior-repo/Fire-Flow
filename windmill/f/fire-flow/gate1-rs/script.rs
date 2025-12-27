//! Gate1 Rust - Wrapper for bt-gate1 tool
//!
//! Validates generated code syntax and types

use serde::{Deserialize, Serialize};
use std::process::Command;

#[derive(Deserialize)]
pub struct Gate1Input {
    pub code_path: String,
    pub language: String,
    pub trace_id: String,
}

#[derive(Serialize)]
pub struct Gate1Output {
    pub passed: bool,
    pub syntax_ok: bool,
    pub lint_ok: bool,
    pub type_ok: bool,
    pub errors: Vec<String>,
}

pub fn main(input: Gate1Input) -> anyhow::Result<Gate1Output> {
    let json_input = serde_json::json!({
        "code_path": input.code_path,
        "language": input.language,
        "context": {
            "trace_id": input.trace_id,
            "dry_run": false
        }
    });

    let output = Command::new("/home/lewis/src/Fire-Flow/bitter-truth-rs/target/release/gate1")
        .arg(serde_json::to_string(&json_input)?)
        .output()?;

    let stdout = String::from_utf8(output.stdout)?;
    let response: serde_json::Value = serde_json::from_str(&stdout)?;

    if !response["success"].as_bool().unwrap_or(false) {
        return Err(anyhow::anyhow!("Gate1 failed: {}", response["error"]));
    }

    Ok(serde_json::from_value(response["data"].clone())?)
}
