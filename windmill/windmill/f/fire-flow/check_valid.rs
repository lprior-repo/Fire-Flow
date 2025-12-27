//! Check validation result
//!
//! Determines if validation passed and whether to continue or stop.
//!
//! ```cargo
//! [dependencies]
//! anyhow = "1.0"
//! serde = { version = "1.0", features = ["derive"] }
//! ```

use anyhow::Result;
use serde::{Deserialize, Serialize};

#[derive(Deserialize)]
pub struct CheckValidInput {
    pub valid: bool,
    pub iter_value: u32,
    pub output_path: String,
}

#[derive(Serialize)]
pub struct CheckValidOutput {
    pub status: String,
    pub attempts: u32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub output_path: Option<String>,
}

pub fn main(input: CheckValidInput) -> Result<CheckValidOutput> {
    if input.valid {
        Ok(CheckValidOutput {
            status: "success".to_string(),
            attempts: input.iter_value,
            output_path: Some(input.output_path),
        })
    } else {
        Ok(CheckValidOutput {
            status: "retry_needed".to_string(),
            attempts: input.iter_value,
            output_path: None,
        })
    }
}
