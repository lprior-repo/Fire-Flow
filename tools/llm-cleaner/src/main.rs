use anyhow::{Context, Result, bail};
use clap::Parser;
use regex::Regex;
use serde_json::Value;
use std::io::{self, Read};

/// Extract valid code or JSON from chatty LLM outputs
///
/// Handles common LLM patterns like:
/// - "Here is the code you requested:" followed by code
/// - Markdown code blocks (```json, ```nushell, etc.)
/// - Mixed conversation with embedded code
#[derive(Parser)]
#[command(author, version, about)]
struct Cli {
    /// Extract code from a specific language block (e.g., "nushell", "json", "python")
    #[arg(short, long)]
    lang: Option<String>,

    /// Format output as Kestra Metric/Output syntax ::{...}::
    #[arg(short, long)]
    kestra_log: bool,

    /// Validate extracted content as JSON
    #[arg(short, long)]
    validate_json: bool,

    /// Show what was extracted (for debugging)
    #[arg(short, long)]
    debug: bool,
}

fn main() -> Result<()> {
    let args = Cli::parse();

    // Read from stdin
    let mut buffer = String::new();
    io::stdin()
        .read_to_string(&mut buffer)
        .context("Failed to read from stdin")?;

    if args.debug {
        eprintln!("[llm-cleaner] Input length: {} bytes", buffer.len());
    }

    // Try to extract code based on language or any code block
    let extracted = if let Some(ref lang) = args.lang {
        extract_code_block(&buffer, Some(lang), args.debug)?
    } else if args.validate_json {
        extract_json(&buffer, args.debug)?
    } else {
        // Default: try to extract any code block
        extract_code_block(&buffer, None, args.debug)?
    };

    // Validate as JSON if requested
    if args.validate_json {
        let parsed: Value = serde_json::from_str(&extracted)
            .context("Extracted text was not valid JSON")?;

        if args.kestra_log {
            println!("::{}::", serde_json::to_string(&parsed)?);
        } else {
            println!("{}", serde_json::to_string_pretty(&parsed)?);
        }
    } else {
        // Output raw extracted content
        print!("{}", extracted);
    }

    Ok(())
}

/// Extract code from markdown code blocks
fn extract_code_block(input: &str, lang: Option<&str>, debug: bool) -> Result<String> {
    // Build regex pattern for code blocks
    let pattern = if let Some(l) = lang {
        // Specific language: ```lang ... ```
        format!(r"(?s)```{}\s*\n?(.*?)```", regex::escape(l))
    } else {
        // Any code block: ```[lang]? ... ```
        r"(?s)```(?:\w+)?\s*\n?(.*?)```".to_string()
    };

    let re = Regex::new(&pattern)?;

    if let Some(caps) = re.captures(input) {
        let content = caps.get(1).map(|m| m.as_str().trim()).unwrap_or("");
        if debug {
            eprintln!("[llm-cleaner] Extracted {} bytes from code block", content.len());
        }
        if content.is_empty() {
            bail!("Code block was empty");
        }
        return Ok(content.to_string());
    }

    // Fallback: check if input looks like raw code (starts with shebang, def, fn, etc.)
    let trimmed = input.trim();
    if looks_like_code(trimmed) {
        if debug {
            eprintln!("[llm-cleaner] Input appears to be raw code, using as-is");
        }
        return Ok(trimmed.to_string());
    }

    // Try to find code by looking for lines that start like code
    if let Some(code) = extract_code_from_mixed(input, debug) {
        return Ok(code);
    }

    // Last resort: look for code after common LLM prefixes
    let prefix_patterns = [
        r"(?s)(?:Here is|Here's|Below is|The following is)[^:]*:\s*\n+(.*)",
        r"(?s)(?:I've|I have) (?:created|written|generated)[^:]*:\s*\n+(.*)",
    ];

    for pattern in prefix_patterns {
        let re = Regex::new(pattern)?;
        if let Some(caps) = re.captures(input) {
            let content = caps.get(1).map(|m| m.as_str().trim()).unwrap_or("");
            if !content.is_empty() && looks_like_code(content) {
                if debug {
                    eprintln!("[llm-cleaner] Extracted code after LLM prefix");
                }
                return Ok(content.to_string());
            }
        }
    }

    bail!("No code block found in input. Input preview: {}...",
          &input.chars().take(100).collect::<String>())
}

/// Extract JSON from input (handles markdown blocks and raw JSON)
fn extract_json(input: &str, debug: bool) -> Result<String> {
    // Try markdown code block first
    let re = Regex::new(r"(?s)```(?:json)?\s*\n?(\{.*?\})\s*```")?;
    if let Some(caps) = re.captures(input) {
        let content = caps.get(1).map(|m| m.as_str()).unwrap_or("");
        if debug {
            eprintln!("[llm-cleaner] Extracted JSON from code block");
        }
        return Ok(content.to_string());
    }

    // Try raw JSON object
    let re = Regex::new(r"(?s)(\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\})")?;
    if let Some(caps) = re.captures(input) {
        let content = caps.get(1).map(|m| m.as_str()).unwrap_or("");
        if debug {
            eprintln!("[llm-cleaner] Extracted raw JSON object");
        }
        return Ok(content.to_string());
    }

    bail!("No JSON found in input")
}

/// Heuristic to detect if text looks like code
fn looks_like_code(text: &str) -> bool {
    let first_line = text.lines().next().unwrap_or("");
    let trimmed = first_line.trim();

    // Common code indicators
    trimmed.starts_with("#!/")
        || trimmed.starts_with("def ")
        || trimmed.starts_with("fn ")
        || trimmed.starts_with("func ")
        || trimmed.starts_with("function ")
        || trimmed.starts_with("let ")
        || trimmed.starts_with("const ")
        || trimmed.starts_with("import ")
        || trimmed.starts_with("use ")
        || trimmed.starts_with("from ")
        || trimmed.starts_with("{")
        || trimmed.starts_with("[")
        || trimmed.starts_with("//")
        || trimmed.starts_with("#!")
        || trimmed.starts_with("# ")
        // Nushell specific
        || trimmed.starts_with("def main")
        || trimmed.starts_with("export def")
        || trimmed.starts_with("module ")
}

/// Try to find code starting from a line that looks like code
fn extract_code_from_mixed(input: &str, debug: bool) -> Option<String> {
    let lines: Vec<&str> = input.lines().collect();

    // Find first line that looks like code
    for (i, line) in lines.iter().enumerate() {
        if looks_like_code(line) {
            if debug {
                eprintln!("[llm-cleaner] Found code starting at line {}", i + 1);
            }
            // Return everything from this line onward
            return Some(lines[i..].join("\n"));
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_nushell_block() {
        let input = r#"Here is the script:

```nushell
#!/usr/bin/env nu
def main [] {
    print "hello"
}
```

Hope this helps!"#;

        let result = extract_code_block(input, Some("nushell"), false).unwrap();
        assert!(result.contains("def main"));
        assert!(result.contains("print \"hello\""));
    }

    #[test]
    fn test_extract_json() {
        let input = r#"Here is the data:
```json
{"success": true, "data": {"value": 42}}
```
"#;
        let result = extract_json(input, false).unwrap();
        assert!(result.contains("success"));
    }

    #[test]
    fn test_raw_code() {
        let input = "#!/usr/bin/env nu\ndef main [] { print 'test' }";
        let result = extract_code_block(input, None, false).unwrap();
        assert!(result.contains("def main"));
    }
}
