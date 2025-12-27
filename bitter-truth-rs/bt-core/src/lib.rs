// Bitter-Truth Core Library
// Shared types and utilities for all bitter-truth tools

use serde::{Deserialize, Serialize};
use std::time::SystemTime;

/// Common context for all tools
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Context {
    pub trace_id: String,
    pub dry_run: bool,
    pub timeout_seconds: Option<u64>,
}

impl Default for Context {
    fn default() -> Self {
        Self {
            trace_id: uuid::Uuid::new_v4().to_string()[..8].to_string(),
            dry_run: false,
            timeout_seconds: Some(300),
        }
    }
}

/// Standard tool response envelope
#[derive(Debug, Serialize, Deserialize)]
pub struct ToolResponse<T> {
    pub success: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub data: Option<T>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
    pub trace_id: String,
    pub duration_ms: f64,
}

/// Log entry for stderr output
#[derive(Debug, Serialize)]
pub struct LogEntry {
    pub level: String,
    pub msg: String,
    pub trace_id: String,
    #[serde(flatten)]
    pub extra: serde_json::Value,
}

impl LogEntry {
    pub fn info(msg: impl Into<String>, trace_id: String) -> Self {
        Self {
            level: "info".to_string(),
            msg: msg.into(),
            trace_id,
            extra: serde_json::json!({}),
        }
    }

    pub fn error(msg: impl Into<String>, trace_id: String) -> Self {
        Self {
            level: "error".to_string(),
            msg: msg.into(),
            trace_id,
            extra: serde_json::json!({}),
        }
    }

    pub fn debug(msg: impl Into<String>, trace_id: String) -> Self {
        Self {
            level: "debug".to_string(),
            msg: msg.into(),
            trace_id,
            extra: serde_json::json!({}),
        }
    }

    pub fn with_extra(mut self, key: &str, value: serde_json::Value) -> Self {
        self.extra.as_object_mut().unwrap().insert(key.to_string(), value);
        self
    }
}

pub fn log_stderr(entry: &LogEntry) {
    if let Ok(json) = serde_json::to_string(entry) {
        eprintln!("{}", json);
    }
}

pub fn elapsed_ms(start: SystemTime) -> f64 {
    SystemTime::now()
        .duration_since(start)
        .unwrap_or_default()
        .as_millis() as f64
}

/// Exit with success response
pub fn success_exit<T: Serialize>(data: T, trace_id: String, start: SystemTime) {
    let response = ToolResponse {
        success: true,
        data: Some(data),
        error: None,
        trace_id,
        duration_ms: elapsed_ms(start),
    };
    println!("{}", serde_json::to_string(&response).unwrap());
    std::process::exit(0);
}

/// Exit with error response
pub fn error_exit(error: String, trace_id: String, start: SystemTime) -> ! {
    let response: ToolResponse<()> = ToolResponse {
        success: false,
        data: None,
        error: Some(error),
        trace_id,
        duration_ms: elapsed_ms(start),
    };
    println!("{}", serde_json::to_string(&response).unwrap());
    std::process::exit(1);
}
