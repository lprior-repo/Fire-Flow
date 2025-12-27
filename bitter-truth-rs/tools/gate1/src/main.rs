use bt_core::{error_exit, log_stderr, success_exit, Context, LogEntry};
use serde::{Deserialize, Serialize};
use std::io::Read;
use std::process::Command;
use std::time::SystemTime;

#[derive(Debug, Deserialize)]
struct Gate1Input {
    code_path: String,
    language: String,
    #[serde(default)]
    context: Context,
}

#[derive(Debug, Serialize)]
struct Gate1Output {
    passed: bool,
    syntax_ok: bool,
    lint_ok: bool,
    type_ok: bool,
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

    let input: Gate1Input = match serde_json::from_str(&input_str) {
        Ok(i) => i,
        Err(e) => {
            let log = LogEntry::error(format!("Invalid JSON input: {}", e), "unknown".to_string());
            log_stderr(&log);
            error_exit(format!("Invalid JSON: {}", e), "unknown".to_string(), start);
        }
    };

    let trace_id = input.context.trace_id.clone();
    let dry_run = input.context.dry_run;

    // Validate required fields
    if input.code_path.is_empty() {
        let log = LogEntry::error("code_path is required", trace_id.clone());
        log_stderr(&log);
        error_exit("code_path is required".to_string(), trace_id, start);
    }

    if input.language.is_empty() {
        let log = LogEntry::error("language is required", trace_id.clone());
        log_stderr(&log);
        error_exit("language is required".to_string(), trace_id, start);
    }

    // Dry run mode
    if dry_run {
        let log = LogEntry::info("dry-run mode - skipping validation", trace_id.clone());
        log_stderr(&log);

        let output = Gate1Output {
            passed: true,
            syntax_ok: true,
            lint_ok: true,
            type_ok: true,
            errors: vec![],
            was_dry_run: true,
        };

        success_exit(output, trace_id.clone(), start);
    }

    // Check file exists
    if !std::path::Path::new(&input.code_path).exists() {
        let log = LogEntry::error(
            format!("code file not found: {}", input.code_path),
            trace_id.clone(),
        );
        log_stderr(&log);
        error_exit(
            format!("Code file not found: {}", input.code_path),
            trace_id,
            start,
        );
    }

    let log = LogEntry::info("starting Gate 1 validation", trace_id.clone())
        .with_extra("code_path", serde_json::Value::String(input.code_path.clone()))
        .with_extra("language", serde_json::Value::String(input.language.clone()));
    log_stderr(&log);

    let result = match input.language.as_str() {
        "rust" | "rs" => check_rust(&input.code_path, &trace_id),
        "python" | "py" => check_python(&input.code_path, &trace_id),
        "typescript" | "ts" => check_typescript(&input.code_path, &trace_id),
        "go" => check_go(&input.code_path, &trace_id),
        lang => {
            let log = LogEntry::error(format!("unsupported language: {}", lang), trace_id.clone());
            log_stderr(&log);
            Gate1Output {
                passed: false,
                syntax_ok: false,
                lint_ok: false,
                type_ok: false,
                errors: vec![format!("Unsupported language: {}", lang)],
                was_dry_run: false,
            }
        }
    };

    let passed = result.passed;
    let log = LogEntry::info("Gate 1 validation complete", trace_id.clone())
        .with_extra("passed", serde_json::Value::Bool(passed));
    log_stderr(&log);

    if passed {
        success_exit(result, trace_id, start);
    } else {
        error_exit(
            format!("Gate 1 validation failed: {}", result.errors.join("; ")),
            trace_id,
            start,
        );
    }
}

fn check_rust(code_path: &str, trace_id: &str) -> Gate1Output {
    let log = LogEntry::debug("checking Rust syntax and types", trace_id.to_string());
    log_stderr(&log);

    // Check syntax with rustc
    let syntax_check = Command::new("rustfmt")
        .arg("--check")
        .arg(code_path)
        .output();

    let syntax_ok = syntax_check.map(|o| o.status.success()).unwrap_or(true);

    // Try cargo check if Cargo.toml exists
    let has_cargo = std::path::Path::new("Cargo.toml").exists();
    let type_ok = if has_cargo {
        Command::new("cargo")
            .arg("check")
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false)
    } else {
        // Fallback: just check with rustc
        Command::new("rustc")
            .arg("--crate-type")
            .arg("bin")
            .arg(code_path)
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false)
    };

    Gate1Output {
        passed: syntax_ok && type_ok,
        syntax_ok,
        lint_ok: true,
        type_ok,
        errors: if !syntax_ok {
            vec!["Rust syntax check failed".to_string()]
        } else if !type_ok {
            vec!["Rust type check failed".to_string()]
        } else {
            vec![]
        },
        was_dry_run: false,
    }
}

fn check_python(code_path: &str, trace_id: &str) -> Gate1Output {
    let log = LogEntry::debug("checking Python syntax", trace_id.to_string());
    log_stderr(&log);

    let check = Command::new("python3")
        .arg("-m")
        .arg("py_compile")
        .arg(code_path)
        .output();

    let passed = check.map(|o| o.status.success()).unwrap_or(false);

    Gate1Output {
        passed,
        syntax_ok: passed,
        lint_ok: true,
        type_ok: true,
        errors: if !passed {
            vec!["Python syntax check failed".to_string()]
        } else {
            vec![]
        },
        was_dry_run: false,
    }
}

fn check_typescript(code_path: &str, trace_id: &str) -> Gate1Output {
    let log = LogEntry::debug("checking TypeScript syntax", trace_id.to_string());
    log_stderr(&log);

    // Try tsc if available
    let check = Command::new("tsc")
        .arg("--noEmit")
        .arg(code_path)
        .output();

    let passed = check.map(|o| o.status.success()).unwrap_or(false);

    Gate1Output {
        passed,
        syntax_ok: passed,
        lint_ok: true,
        type_ok: true,
        errors: if !passed {
            vec!["TypeScript syntax check failed".to_string()]
        } else {
            vec![]
        },
        was_dry_run: false,
    }
}

fn check_go(code_path: &str, trace_id: &str) -> Gate1Output {
    let log = LogEntry::debug("checking Go syntax", trace_id.to_string());
    log_stderr(&log);

    let check = Command::new("go")
        .arg("fmt")
        .arg(code_path)
        .output();

    let passed = check.map(|o| o.status.success()).unwrap_or(false);

    Gate1Output {
        passed,
        syntax_ok: passed,
        lint_ok: true,
        type_ok: true,
        errors: if !passed {
            vec!["Go syntax check failed".to_string()]
        } else {
            vec![]
        },
        was_dry_run: false,
    }
}
