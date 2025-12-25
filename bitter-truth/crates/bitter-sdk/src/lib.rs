//! bitter-sdk: Minimal SDK for bitter-truth tools
//!
//! Tools are pure functions: protobuf in (stdin) → protobuf out (stdout)
//! Logs go to stderr as JSON for observability.
//!
//! # Example
//! ```rust,ignore
//! use bitter_sdk::{read_input, write_output, log_info};
//! use bitter_sdk::proto::tools::{EchoInput, EchoOutput};
//!
//! fn main() -> anyhow::Result<()> {
//!     let input: EchoInput = read_input()?;
//!     log_info("processing", &[("message", &input.message)]);
//!
//!     let output = EchoOutput {
//!         echo: input.message.clone(),
//!         reversed: input.message.chars().rev().collect(),
//!         length: input.message.len() as i32,
//!         was_dry_run: input.context.map(|c| c.dry_run).unwrap_or(false),
//!     };
//!
//!     write_output(&output)?;
//!     Ok(())
//! }
//! ```

use std::io::{Read, Write};
use std::time::Instant;

use prost::Message;

// Re-export proto types
// Structure: bitter contains tools as submodule so super::ExecutionContext works
pub mod proto {
    pub mod bitter {
        include!("gen/bitter.rs");

        pub mod tools {
            include!("gen/bitter.tools.rs");
        }
    }
}

pub use proto::bitter::{ExecutionContext, StructuredError, ToolResponse};

/// Read protobuf input from stdin
pub fn read_input<T: Message + Default>() -> anyhow::Result<T> {
    let mut buf = Vec::new();
    std::io::stdin().read_to_end(&mut buf)?;
    T::decode(&buf[..]).map_err(Into::into)
}

/// Write protobuf output to stdout
pub fn write_output<T: Message>(msg: &T) -> anyhow::Result<()> {
    let buf = msg.encode_to_vec();
    std::io::stdout().write_all(&buf)?;
    std::io::stdout().flush()?;
    Ok(())
}

/// Log a JSON message to stderr (for observability)
pub fn log_info(msg: &str, fields: &[(&str, &str)]) {
    let mut obj = serde_json::json!({
        "level": "info",
        "msg": msg,
        "ts": chrono_lite_now(),
    });
    for (k, v) in fields {
        obj[*k] = serde_json::Value::String(v.to_string());
    }
    eprintln!("{}", obj);
}

/// Log an error to stderr
pub fn log_error(msg: &str, err: &str) {
    eprintln!(
        r#"{{"level":"error","msg":"{}","error":"{}","ts":"{}"}}"#,
        msg.replace('"', r#"\""#),
        err.replace('"', r#"\""#),
        chrono_lite_now()
    );
}

/// Simple timestamp (no chrono dependency)
fn chrono_lite_now() -> String {
    // Use std::time for a simple unix timestamp
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs().to_string())
        .unwrap_or_else(|_| "0".to_string())
}

/// Timer for measuring execution duration
pub struct Timer {
    start: Instant,
}

impl Timer {
    pub fn start() -> Self {
        Self { start: Instant::now() }
    }

    pub fn elapsed_ms(&self) -> i64 {
        self.start.elapsed().as_millis() as i64
    }
}

/// Wrap tool execution with standard error handling and timing
pub fn run_tool<I, O, F>(f: F) -> anyhow::Result<()>
where
    I: Message + Default,
    O: Message,
    F: FnOnce(I) -> anyhow::Result<O>,
{
    let timer = Timer::start();

    let input: I = match read_input() {
        Ok(i) => i,
        Err(e) => {
            log_error("failed to read input", &e.to_string());
            // Write error response
            let resp = ToolResponse {
                success: false,
                error: e.to_string(),
                ..Default::default()
            };
            write_output(&resp)?;
            return Err(e);
        }
    };

    match f(input) {
        Ok(output) => {
            let data = output.encode_to_vec();
            let resp = ToolResponse {
                success: true,
                data,
                duration_ms: timer.elapsed_ms(),
                ..Default::default()
            };
            write_output(&resp)?;
            log_info("tool completed", &[("duration_ms", &timer.elapsed_ms().to_string())]);
            Ok(())
        }
        Err(e) => {
            log_error("tool failed", &e.to_string());
            let resp = ToolResponse {
                success: false,
                error: e.to_string(),
                duration_ms: timer.elapsed_ms(),
                ..Default::default()
            };
            write_output(&resp)?;
            Err(e)
        }
    }
}
