//! Echo tool - bitter-truth proof of concept
//!
//! Reads EchoInput from stdin (protobuf)
//! Writes EchoOutput to stdout (protobuf)
//! Logs JSON to stderr

use bitter_sdk::{log_info, run_tool};
use bitter_sdk::proto::bitter::tools::{EchoInput, EchoOutput};

fn main() -> anyhow::Result<()> {
    run_tool(|input: EchoInput| {
        let dry_run = input.context.as_ref().map(|c| c.dry_run).unwrap_or(false);

        log_info("processing echo", &[
            ("message_len", &input.message.len().to_string()),
            ("dry_run", &dry_run.to_string()),
        ]);

        if dry_run {
            log_info("dry-run mode - skipping side effects", &[]);
        }

        Ok(EchoOutput {
            echo: input.message.clone(),
            reversed: input.message.chars().rev().collect(),
            length: input.message.len() as i32,
            was_dry_run: dry_run,
        })
    })
}
