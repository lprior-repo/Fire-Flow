use anyhow::{anyhow, Result};
use bt_core::{error_exit, log_stderr, success_exit, Context, LogEntry};
use serde::{Deserialize, Serialize};
use std::fs;
use std::io::Read;
use std::process::Command;
use std::time::SystemTime;

#[derive(Debug, Deserialize)]
struct GenerateInput {
    contract_path: String,
    task: String,
    language: String,
    #[serde(default)]
    context: Context,
    #[serde(default = "default_feedback")]
    feedback: String,
    #[serde(default = "default_attempt")]
    attempt: String,
    #[serde(default = "default_output_path")]
    output_path: String,
    #[serde(default = "default_model")]
    model: String,
    #[serde(default)]
    dry_run: bool,
}

fn default_feedback() -> String {
    "Initial generation".to_string()
}
fn default_attempt() -> String {
    "1/5".to_string()
}
fn default_output_path() -> String {
    format!("/tmp/generated_{}.rs", uuid::Uuid::new_v4())
}
fn default_model() -> String {
    "anthropic/claude-opus-4-5".to_string()
}

#[derive(Debug, Serialize)]
struct GenerateOutput {
    generated: bool,
    output_path: String,
    language: String,
    was_dry_run: bool,
}

#[tokio::main]
async fn main() {
    let start = SystemTime::now();
    let mut input_str = String::new();
    if std::io::stdin().read_to_string(&mut input_str).is_err() {
        eprintln!("Failed to read stdin");
        std::process::exit(1);
    }

    let input: GenerateInput = match serde_json::from_str(&input_str) {
        Ok(i) => i,
        Err(e) => {
            let log = LogEntry::error(format!("Invalid JSON input: {}", e), "unknown".to_string());
            log_stderr(&log);
            error_exit(format!("Invalid JSON: {}", e), "unknown".to_string(), start);
        }
    };

    let trace_id = input.context.trace_id.clone();
    let dry_run = input.dry_run || input.context.dry_run;

    // Validate required fields
    if input.contract_path.is_empty() {
        let log = LogEntry::error("contract_path is required", trace_id.clone());
        log_stderr(&log);
        error_exit("contract_path is required".to_string(), trace_id, start);
    }

    if input.task.is_empty() {
        let log = LogEntry::error("task is required", trace_id.clone());
        log_stderr(&log);
        error_exit("task is required".to_string(), trace_id, start);
    }

    // Check contract file exists
    if !std::path::Path::new(&input.contract_path).exists() {
        let log = LogEntry::error(
            format!("contract not found: {}", input.contract_path),
            trace_id.clone(),
        );
        log_stderr(&log);
        error_exit(
            format!("Contract not found: {}", input.contract_path),
            trace_id,
            start,
        );
    }

    let log = LogEntry::info("generating code from contract", trace_id.clone())
        .with_extra("contract", serde_json::Value::String(input.contract_path.clone()))
        .with_extra("task", serde_json::Value::String(input.task.clone()))
        .with_extra("language", serde_json::Value::String(input.language.clone()))
        .with_extra("attempt", serde_json::Value::String(input.attempt.clone()))
        .with_extra("dry_run", serde_json::Value::Bool(dry_run));
    log_stderr(&log);

    if dry_run {
        // Dry-run: create a stub file
        let stub = format!("// Dry-run stub for {}\nfn main() {{\n    println!(\"dry-run\");\n}}\n", input.language);
        if let Err(e) = fs::write(&input.output_path, &stub) {
            let log = LogEntry::error(format!("Failed to write stub: {}", e), trace_id.clone());
            log_stderr(&log);
            error_exit(
                format!("Failed to write stub: {}", e),
                trace_id,
                start,
            );
        }

        let output = GenerateOutput {
            generated: true,
            output_path: input.output_path.clone(),
            language: input.language.clone(),
            was_dry_run: true,
        };

        success_exit(output, trace_id.clone(), start);
    }

    // Real generation: call opencode
    match generate_code(&input, &trace_id.clone()) {
        Ok(code) => {
            if let Err(e) = fs::write(&input.output_path, &code) {
                let log = LogEntry::error(format!("Failed to write generated code: {}", e), trace_id.clone());
                log_stderr(&log);
                error_exit(
                    format!("Failed to write code: {}", e),
                    trace_id,
                    start,
                );
            }

            let log = LogEntry::info("code generation successful", trace_id.clone())
                .with_extra("output_path", serde_json::Value::String(input.output_path.clone()))
                .with_extra("code_length", serde_json::Value::Number(code.len().into()));
            log_stderr(&log);

            let output = GenerateOutput {
                generated: true,
                output_path: input.output_path.clone(),
                language: input.language.clone(),
                was_dry_run: false,
            };

            success_exit(output, trace_id, start);
        }
        Err(e) => {
            let log = LogEntry::error(format!("Code generation failed: {}", e), trace_id.clone());
            log_stderr(&log);
            error_exit(
                format!("Generation failed: {}", e),
                trace_id,
                start,
            );
        }
    }
}

fn generate_code(input: &GenerateInput, trace_id: &str) -> Result<String> {
    // Validate opencode is available
    let models_output = Command::new("opencode")
        .arg("models")
        .output()?;

    if !models_output.status.success() {
        return Err(anyhow!("Failed to list opencode models"));
    }

    let models_str = String::from_utf8(models_output.stdout)?;
    let available_models: Vec<&str> = models_str.lines().collect();

    // Check if model is available
    if !available_models.iter().any(|m| m.contains(&input.model)) {
        return Err(anyhow!(
            "Model '{}' not available. Available: {}",
            input.model,
            available_models.join(", ")
        ));
    }

    // Read contract
    let contract_content = fs::read_to_string(&input.contract_path)?;

    // Build prompt
    let prompt = build_prompt(input, &contract_content);

    let log = LogEntry::info("calling opencode", trace_id.to_string())
        .with_extra("model", serde_json::Value::String(input.model.clone()))
        .with_extra("prompt_length", serde_json::Value::Number(prompt.len().into()));
    log_stderr(&log);

    // Call opencode
    let output = Command::new("opencode")
        .arg("run")
        .arg("-m")
        .arg(&input.model)
        .arg(&prompt)
        .output()?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(anyhow!("opencode failed: {}", stderr));
    }

    let raw_output = String::from_utf8(output.stdout)?;

    if raw_output.trim().is_empty() {
        return Err(anyhow!("Empty response from opencode"));
    }

    // Extract code using llm-cleaner
    let code = extract_code(&raw_output, &input.language, trace_id)?;
    Ok(code)
}

fn extract_code(output: &str, language: &str, trace_id: &str) -> Result<String> {
    // Try to find llm-cleaner binary
    let llm_cleaner_paths = [
        "/home/lewis/src/Fire-Flow/tools/llm-cleaner/target/release/llm-cleaner",
        "./tools/llm-cleaner/target/release/llm-cleaner",
        "/usr/local/bin/llm-cleaner",
        "llm-cleaner",
    ];

    let llm_cleaner = llm_cleaner_paths
        .iter()
        .find(|p| std::path::Path::new(p).exists())
        .copied()
        .ok_or_else(|| anyhow!("llm-cleaner not found"))?;

    let log = LogEntry::info("extracting code with llm-cleaner", trace_id.to_string())
        .with_extra("cleaner_path", serde_json::Value::String(llm_cleaner.to_string()));
    log_stderr(&log);

    let output_result = Command::new(llm_cleaner)
        .arg("--lang")
        .arg(language)
        .arg("--debug")
        .output()?;

    if output_result.status.success() {
        let code = String::from_utf8(output_result.stdout)?;
        Ok(code)
    } else {
        // Fallback: use raw output
        let log = LogEntry::error("llm-cleaner failed, using raw output", trace_id.to_string());
        log_stderr(&log);
        Ok(output.to_string())
    }
}

fn build_prompt(input: &GenerateInput, contract: &str) -> String {
    format!(
        r#"You are a {} code generator. Output ONLY valid {} code, never explanations.

TASK: {}

CONTRACT (your output must produce data matching this schema):
{}

FEEDBACK FROM PREVIOUS ATTEMPT: {}
ATTEMPT: {}

REQUIREMENTS:
- Output must match the contract schema exactly
- Return success/error appropriately
- Output valid, runnable code

Generate the complete {} code for the task.
OUTPUT ONLY THE CODE:"#,
        input.language, input.language, input.task, contract, input.feedback, input.attempt, input.language
    )
}
