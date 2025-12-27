//! Update state for next iteration
//!
//! Stores feedback and attempt number for retry loop.
//!
//! ```cargo
//! [dependencies]
//! anyhow = "1.0"
//! serde = { version = "1.0", features = ["derive"] }
//! ```

use anyhow::Result;
use serde::{Deserialize, Serialize};

#[derive(Deserialize)]
pub struct UpdateStateInput {
    pub feedback: String,
    pub iter_value: u32,
}

#[derive(Serialize)]
pub struct UpdateStateOutput {
    pub updated: bool,
    pub feedback: String,
    pub attempt: u32,
}

pub fn main(input: UpdateStateInput) -> Result<UpdateStateOutput> {
    Ok(UpdateStateOutput {
        updated: true,
        feedback: input.feedback,
        attempt: input.iter_value,
    })
}
