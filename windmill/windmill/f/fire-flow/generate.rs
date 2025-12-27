//! Generate - AI generates code from contract
//!
//! Windmill Rust script that calls an LLM to generate code matching a DataContract.
//!
//! ```cargo
//! [dependencies]
//! anyhow = "1.0"
//! serde = { version = "1.0", features = ["derive"] }
//! serde_json = "1.0"
//! ```

use anyhow::{anyhow, Result};
use serde::{Deserialize, Serialize};
use std::process::{Command, Stdio};
use std::io::Write;

#[derive(Deserialize)]
pub struct GenerateInput {
    /// Path to DataContract YAML file
    pub contract_path: String,
    /// Natural language task description
    pub task: String,
    /// Feedback from previous attempt (for self-healing)
    #[serde(default = "default_feedback")]
    pub feedback: String,
    /// Current attempt (e.g., "1/5")
    #[serde(default = "default_attempt")]
    pub attempt: String,
    /// Where to write the generated code
    #[serde(default = "default_output_path")]
    pub output_path: String,
    /// Target language (rust, python, typescript, go)
    #[serde(default = "default_language")]
    pub language: String,
    /// LLM model to use
    #[serde(default = "default_model")]
    pub model: String,
    /// Timeout in seconds
    #[serde(default = "default_timeout")]
    pub timeout_seconds: u64,
    /// Trace ID for observability
    #[serde(default)]
    pub trace_id: String,
    /// Skip actual generation (for testing)
    #[serde(default)]
    pub dry_run: bool,
}

fn default_feedback() -> String { "Initial generation".to_string() }
fn default_attempt() -> String { "1/5".to_string() }
fn default_output_path() -> String { "/tmp/generated_code".to_string() }
fn default_language() -> String { "rust".to_string() }
fn default_model() -> String { "anthropic/claude-sonnet-4-20250514".to_string() }
fn default_timeout() -> u64 { 300 }

#[derive(Serialize)]
pub struct GenerateOutput {
    pub generated: bool,
    pub output_path: String,
    pub language: String,
    pub was_dry_run: bool,
}

/// Build the prompt for code generation
fn build_prompt(input: &GenerateInput, contract_content: &str) -> String {
    let lang_example = match input.language.as_str() {
        "rust" => r#"```rust
use serde::{Deserialize, Serialize};

#[derive(Deserialize)]
struct Input { /* from contract */ }

#[derive(Serialize)]
struct Output { /* matches contract schema */ }

fn main(input: Input) -> anyhow::Result<Output> {
    // Implementation
    Ok(Output { /* ... */ })
}
```"#,
        "python" => r#"```python
from typing import TypedDict

class Input(TypedDict):
    # from contract
    pass

class Output(TypedDict):
    # matches contract schema
    pass

def main(input: Input) -> Output:
    # Implementation
    return {"success": True}
```"#,
        "typescript" => r#"```typescript
interface Input { /* from contract */ }
interface Output { /* matches contract schema */ }

export async function main(input: Input): Promise<Output> {
    // Implementation
    return { success: true };
}
```"#,
        _ => "Generate code matching the contract schema.",
    };

    format!(
        r#"You are a {lang} code generator. Output ONLY valid {lang} code, never explanations.

TASK: {task}

CONTRACT (your output must produce data matching this schema):
{contract}

FEEDBACK FROM PREVIOUS ATTEMPT: {feedback}
ATTEMPT: {attempt}

REQUIREMENTS:
- Read input as function parameter
- Output must match the contract schema exactly
- Return success/error appropriately

EXAMPLE FORMAT:
{example}

Generate the complete {lang} code for the task.
OUTPUT ONLY THE CODE:"#,
        lang = input.language,
        task = input.task,
        contract = contract_content,
        feedback = input.feedback,
        attempt = input.attempt,
        example = lang_example,
    )
}

/// Call the LLM to generate code (synchronous)
fn call_llm(prompt: &str, model: &str, timeout_secs: u64) -> Result<String> {
    let mut child = Command::new("timeout")
        .args([
            "--foreground",
            "--kill-after=5",
            &format!("{}s", timeout_secs),
            "opencode",
            "run",
            "-m",
            model,
        ])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()?;

    if let Some(mut stdin) = child.stdin.take() {
        stdin.write_all(prompt.as_bytes())?;
    }

    let output = child.wait_with_output()?;

    if output.status.code() == Some(124) {
        return Err(anyhow!("LLM generation timed out"));
    }

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(anyhow!("LLM failed: {}", stderr));
    }

    Ok(String::from_utf8_lossy(&output.stdout).to_string())
}

/// Extract code from LLM output (handles markdown code blocks)
fn extract_code(raw: &str, language: &str) -> String {
    // Look for code block
    let block_start = format!("```{}", language);
    if let Some(start) = raw.find(&block_start) {
        let code_start = start + block_start.len();
        if let Some(end) = raw[code_start..].find("```") {
            return raw[code_start..code_start + end].trim().to_string();
        }
    }
    // Fallback: try generic code block
    if let Some(start) = raw.find("```") {
        let code_start = raw[start + 3..].find('\n').map(|i| start + 4 + i).unwrap_or(start + 3);
        if let Some(end) = raw[code_start..].find("```") {
            return raw[code_start..code_start + end].trim().to_string();
        }
    }
    // No code block found, return as-is
    raw.trim().to_string()
}

pub fn main(input: GenerateInput) -> Result<GenerateOutput> {
    eprintln!("[generate] Starting generation for {}", input.task);
    eprintln!("[generate] Language: {}, Model: {}", input.language, input.model);

    // Validate contract exists
    if !std::path::Path::new(&input.contract_path).exists() {
        return Err(anyhow!("Contract not found: {}", input.contract_path));
    }

    // Dry run mode
    if input.dry_run {
        eprintln!("[generate] Dry run mode - writing stub");
        let stub = match input.language.as_str() {
            "rust" => "fn main() { println!(\"dry-run\"); }",
            "python" => "def main(): return {'dry_run': True}",
            "typescript" => "export function main() { return { dryRun: true }; }",
            _ => "// dry run stub",
        };
        std::fs::write(&input.output_path, stub)?;
        return Ok(GenerateOutput {
            generated: true,
            output_path: input.output_path,
            language: input.language,
            was_dry_run: true,
        });
    }

    // Read contract
    let contract_content = std::fs::read_to_string(&input.contract_path)?;
    eprintln!("[generate] Contract loaded ({} bytes)", contract_content.len());

    // Build prompt
    let prompt = build_prompt(&input, &contract_content);
    eprintln!("[generate] Prompt built ({} chars)", prompt.len());

    // Call LLM
    eprintln!("[generate] Calling {} with {}s timeout", input.model, input.timeout_seconds);
    let raw_output = call_llm(&prompt, &input.model, input.timeout_seconds)?;
    eprintln!("[generate] LLM returned {} chars", raw_output.len());

    // Extract code
    let code = extract_code(&raw_output, &input.language);
    eprintln!("[generate] Extracted {} chars of code", code.len());

    if code.is_empty() {
        return Err(anyhow!("No code extracted from LLM output"));
    }

    // Write to output path
    std::fs::write(&input.output_path, &code)?;
    eprintln!("[generate] Written to {}", input.output_path);

    Ok(GenerateOutput {
        generated: true,
        output_path: input.output_path,
        language: input.language,
        was_dry_run: false,
    })
}
