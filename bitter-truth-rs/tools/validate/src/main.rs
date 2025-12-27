use bt_core::{error_exit, log_stderr, success_exit, Context, LogEntry};
use serde::{Deserialize, Serialize};
use std::io::Read;
use std::time::SystemTime;

#[derive(Debug, Deserialize)]
struct ValidateInput {
    contract_path: String,
    output_path: String,
    #[serde(default)]
    context: Context,
}

#[derive(Debug, Serialize)]
struct ValidateOutput {
    valid: bool,
    errors: Vec<String>,
    was_dry_run: bool,
}

fn main() {
    let start = SystemTime::now();
    let mut input_str = String::new();
    if std::io::stdin().read_to_string(&mut input_str).is_err() {
        eprintln!("Failed to read stdin");
        std::process::exit(1);
    }

    let input: ValidateInput = match serde_json::from_str(&input_str) {
        Ok(i) => i,
        Err(e) => {
            let log = LogEntry::error(format!("Invalid JSON input: {}", e), "unknown".to_string());
            log_stderr(&log);
            error_exit(format!("Invalid JSON: {}", e), "unknown".to_string(), start);
        }
    };

    let trace_id = input.context.trace_id.clone();
    let dry_run = input.context.dry_run;

    if dry_run {
        let log = LogEntry::info("dry-run mode - skipping validation", trace_id.clone());
        log_stderr(&log);

        let output = ValidateOutput {
            valid: true,
            errors: vec![],
            was_dry_run: true,
        };

        success_exit(output, trace_id.clone(), start);
    }

    let log = LogEntry::info("validating output against contract", trace_id.clone())
        .with_extra("contract", serde_json::Value::String(input.contract_path.clone()))
        .with_extra("output", serde_json::Value::String(input.output_path.clone()));
    log_stderr(&log);

    // Basic validation: check files exist
    let contract_exists = std::path::Path::new(&input.contract_path).exists();
    let output_exists = std::path::Path::new(&input.output_path).exists();

    if !contract_exists {
        error_exit(
            format!("Contract not found: {}", input.contract_path),
            trace_id,
            start,
        );
    }

    if !output_exists {
        error_exit(
            format!("Output file not found: {}", input.output_path),
            trace_id,
            start,
        );
    }

    // For now, just verify files exist and are readable
    // Full datacontract-cli validation would go here
    let output = ValidateOutput {
        valid: true,
        errors: vec![],
        was_dry_run: false,
    };

    success_exit(output, trace_id, start);
}
