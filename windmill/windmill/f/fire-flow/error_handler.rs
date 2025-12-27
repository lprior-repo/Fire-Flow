//! Error handler for contract loop failures
//!
//! Captures error context and logs for debugging/alerting.
//!
//! ```cargo
//! [dependencies]
//! anyhow = "1.0"
//! serde = { version = "1.0", features = ["derive"] }
//! serde_json = "1.0"
//! chrono = "0.4"
//! ```

use anyhow::Result;
use chrono::Utc;
use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Deserialize)]
pub struct ErrorHandlerInput {
    /// The error message from the failed step
    pub error: Option<Value>,
    /// The step that failed
    pub failed_step: Option<String>,
    /// Flow input for context
    pub flow_input: Option<Value>,
}

#[derive(Serialize)]
pub struct ErrorHandlerOutput {
    pub handled: bool,
    pub timestamp: String,
    pub error_summary: String,
    pub context: Value,
}

pub fn main(
    error: Option<Value>,
    failed_step: Option<String>,
    flow_input: Option<Value>,
) -> Result<ErrorHandlerOutput> {
    let timestamp = Utc::now().to_rfc3339();
    let step = failed_step.unwrap_or_else(|| "unknown".to_string());

    let error_summary = match &error {
        Some(e) => {
            if let Some(msg) = e.get("message").and_then(|m| m.as_str()) {
                msg.to_string()
            } else if let Some(s) = e.as_str() {
                s.to_string()
            } else {
                format!("{}", e)
            }
        }
        None => "Unknown error".to_string(),
    };

    // Log the error (Windmill captures stderr)
    eprintln!(
        "[error_handler] {} | Step: {} | Error: {}",
        timestamp, step, error_summary
    );

    // Build context for downstream alerting (Slack, Discord, etc.)
    let context = serde_json::json!({
        "failed_step": step,
        "error": error,
        "flow_input": flow_input,
        "timestamp": timestamp,
    });

    Ok(ErrorHandlerOutput {
        handled: true,
        timestamp,
        error_summary,
        context,
    })
}
