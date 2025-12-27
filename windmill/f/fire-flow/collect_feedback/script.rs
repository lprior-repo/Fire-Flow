//! Collect Feedback - Build feedback for AI self-healing retry
//!
//! Windmill Rust script that collects errors and builds feedback for retry.
//!
//! ```cargo
//! [dependencies]
//! anyhow = "1.0"
//! serde = { version = "1.0", features = ["derive"] }
//! serde_json = "1.0"
//! tokio = { version = "1", features = ["fs"] }
//! ```

use anyhow::Result;
use serde::{Deserialize, Serialize};

#[derive(Deserialize)]
pub struct FeedbackInput {
    /// Path to output file
    pub output_path: String,
    /// Path to logs file
    pub logs_path: String,
    /// Validation errors (contract or gate1 check)
    pub validation_errors: Vec<String>,
    /// Gate 1 errors (syntax, lint, type)
    #[serde(default)]
    pub gate1_errors: Vec<String>,
    /// Current attempt (e.g., "2/5")
    pub attempt: String,
    /// Max attempts
    pub max_attempts: u32,
}

#[derive(Serialize)]
pub struct FeedbackOutput {
    pub feedback: String,
    pub should_retry: bool,
    pub attempt_number: u32,
}

pub async fn main(input: FeedbackInput) -> Result<FeedbackOutput> {
    eprintln!("[feedback] Collecting feedback for attempt {}", input.attempt);

    // Parse attempt number
    let attempt_num: u32 = input.attempt
        .split('/')
        .next()
        .and_then(|s| s.parse().ok())
        .unwrap_or(1);

    let should_retry = attempt_num < input.max_attempts;

    // Read output if exists
    let output_content = tokio::fs::read_to_string(&input.output_path)
        .await
        .unwrap_or_else(|_| "<no output>".to_string());

    // Read logs if exists
    let logs_content = tokio::fs::read_to_string(&input.logs_path)
        .await
        .unwrap_or_else(|_| "<no logs>".to_string());

    // Check if this was a gate1 failure
    let has_gate1_errors = !input.gate1_errors.is_empty();

    // Build structured feedback
    let feedback = if has_gate1_errors {
        format!(
            r#"ATTEMPT {attempt}/{max} FAILED - GATE 1 (SYNTAX/LINT/TYPE) ERRORS.

GATE 1 ERRORS (fix these first):
{gate1_errors}

The code failed basic validation checks (syntax, linting, or type checking).
FIX THE CODE BEFORE IT CAN BE EXECUTED.
- Fix all syntax errors
- Resolve linting warnings
- Correct type mismatches"#,
            attempt = attempt_num,
            max = input.max_attempts,
            gate1_errors = input.gate1_errors.join("\n"),
        )
    } else {
        format!(
            r#"ATTEMPT {attempt}/{max} FAILED.

CONTRACT VALIDATION ERRORS:
{errors}

OUTPUT PRODUCED:
{output}

EXECUTION LOGS:
{logs}

FIX THE CODE TO SATISFY THE CONTRACT.
- Check the error messages carefully
- Ensure output matches the expected schema
- Handle edge cases properly"#,
            attempt = attempt_num,
            max = input.max_attempts,
            errors = if input.validation_errors.is_empty() {
                "No specific errors captured".to_string()
            } else {
                input.validation_errors.join("\n")
            },
            output = if output_content.len() > 2000 {
                format!("{}...[truncated]", &output_content[..2000])
            } else {
                output_content
            },
            logs = if logs_content.len() > 1000 {
                format!("{}...[truncated]", &logs_content[..1000])
            } else {
                logs_content
            },
        )
    };

    eprintln!("[feedback] Built {} char feedback, should_retry={}", feedback.len(), should_retry);

    Ok(FeedbackOutput {
        feedback,
        should_retry,
        attempt_number: attempt_num,
    })
}
