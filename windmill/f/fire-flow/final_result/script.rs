//! Final result after loop completes
//!
//! Determines success or escalation based on loop results.
//!
//! ```cargo
//! [dependencies]
//! anyhow = "1.0"
//! serde = { version = "1.0", features = ["derive"] }
//! serde_json = "1.0"
//! ```

use anyhow::Result;
use serde::Serialize;
use serde_json::Value;

#[derive(Serialize)]
pub struct FinalResultOutput {
    pub status: String,
    pub attempts: u32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub output_path: Option<String>,
    pub message: String,
}

pub fn main(loop_result: Vec<Value>, max_attempts: Option<u32>) -> Result<FinalResultOutput> {
    let max_attempts = max_attempts.unwrap_or(5);

    // Check if we succeeded
    if !loop_result.is_empty() {
        if let Some(last) = loop_result.last() {
            if let Some(check_valid) = last.get("check_valid") {
                if check_valid.get("status").and_then(|s| s.as_str()) == Some("success") {
                    let attempts = check_valid
                        .get("attempts")
                        .and_then(|a| a.as_u64())
                        .unwrap_or(0) as u32;
                    let output_path = check_valid
                        .get("output_path")
                        .and_then(|p| p.as_str())
                        .map(|s| s.to_string());

                    return Ok(FinalResultOutput {
                        status: "success".to_string(),
                        attempts,
                        output_path,
                        message: "Contract satisfied!".to_string(),
                    });
                }
            }
        }
    }

    // Escalation - max attempts exceeded
    Ok(FinalResultOutput {
        status: "escalated".to_string(),
        attempts: max_attempts,
        output_path: None,
        message: "AI failed to satisfy contract. FIX THE PROMPT OR CONTRACT, NOT THE CODE."
            .to_string(),
    })
}
