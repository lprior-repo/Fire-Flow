//! Check Test Execution result
//!
//! Determines if tests passed and whether to continue or retry.
//!
//! ```cargo
//! [dependencies]
//! anyhow = "1.0"
//! serde = { version = "1.0", features = ["derive"] }
//! ```

use anyhow::Result;
use serde::{Deserialize, Serialize};

#[derive(Deserialize)]
pub struct CheckTestExecutionInput {
    pub success: bool,
    pub tests_passed: u32,
    pub tests_failed: u32,
    pub exit_code: i32,
    pub iter_value: u32,
}

#[derive(Serialize)]
pub struct CheckTestExecutionOutput {
    pub status: String,
    pub attempts: u32,
    pub should_continue: bool,
}

pub fn main(input: CheckTestExecutionInput) -> Result<CheckTestExecutionOutput> {
    if input.success && input.tests_failed == 0 {
        Ok(CheckTestExecutionOutput {
            status: "passed".to_string(),
            attempts: input.iter_value,
            should_continue: true,
        })
    } else {
        Ok(CheckTestExecutionOutput {
            status: "failed".to_string(),
            attempts: input.iter_value,
            should_continue: false,
        })
    }
}
