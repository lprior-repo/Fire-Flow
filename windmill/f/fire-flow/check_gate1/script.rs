//! Check Gate 1 result
//!
//! Returns pass/fail status from gate1 validation.
//!
//! ```cargo
//! [dependencies]
//! anyhow = "1.0"
//! serde = { version = "1.0", features = ["derive"] }
//! ```

use anyhow::Result;
use serde::{Deserialize, Serialize};

#[derive(Deserialize)]
pub struct CheckGate1Input {
    pub passed: bool,
    #[serde(default)]
    pub errors: Vec<String>,
}

#[derive(Serialize)]
pub struct CheckGate1Output {
    pub status: String,
    pub errors: Vec<String>,
}

pub fn main(input: CheckGate1Input) -> Result<CheckGate1Output> {
    if input.passed {
        Ok(CheckGate1Output {
            status: "passed".to_string(),
            errors: vec![],
        })
    } else {
        Ok(CheckGate1Output {
            status: "failed".to_string(),
            errors: input.errors,
        })
    }
}
