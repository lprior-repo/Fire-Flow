//! Kestra WebSocket Log Streamer
//!
//! A CLI tool that streams logs from Kestra executions via WebSocket,
//! outputting structured JSON for easy AI consumption.
//!
//! # Usage
//! ```bash
//! # Stream logs from a specific execution
//! kestra-ws logs --execution-id <id>
//!
//! # Stream all logs from a namespace
//! kestra-ws logs --namespace bitter
//!
//! # Watch new executions and stream their logs
//! kestra-ws watch --namespace bitter
//! ```

use base64::{engine::general_purpose::STANDARD, Engine};
use clap::{Parser, Subcommand};
use colored::*;

/// Kestra WebSocket Log Streamer - AI-friendly log monitoring
#[derive(Parser)]
#[command(name = "kestra-ws")]
#[command(about = "Stream Kestra logs via WebSocket for AI consumption")]
struct Cli {
    /// Kestra base URL
    #[arg(long, default_value = "localhost:4200", env = "KESTRA_URL")]
    url: String,

    /// Use credentials from pass (kestra/username, kestra/password)
    #[arg(long, default_value = "true")]
    use_pass: bool,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Stream logs from Kestra
    Logs {
        /// Execution ID to watch
        #[arg(long)]
        execution_id: Option<String>,

        /// Namespace to filter
        #[arg(long)]
        namespace: Option<String>,

        /// Flow ID to filter
        #[arg(long)]
        flow: Option<String>,

        /// Output format: json, pretty, raw
        #[arg(long, default_value = "pretty")]
        format: String,

        /// Minimum log level: TRACE, DEBUG, INFO, WARN, ERROR
        #[arg(long, default_value = "INFO")]
        level: String,
    },

    /// Watch for new executions
    Watch {
        /// Namespace to watch
        #[arg(long)]
        namespace: String,

        /// Output format: json, pretty
        #[arg(long, default_value = "pretty")]
        format: String,
    },

    /// Poll execution status via REST (fallback)
    Poll {
        /// Execution ID
        #[arg(long)]
        execution_id: String,

        /// Poll interval in seconds
        #[arg(long, default_value = "2")]
        interval: u64,

        /// Output format: json, pretty
        #[arg(long, default_value = "json")]
        format: String,
    },
}

// Use types from lib for XML formatting support
use kestra_ws::{LogEntry, Execution};

fn get_credentials() -> Result<(String, String), Box<dyn std::error::Error>> {
    let user = std::process::Command::new("pass")
        .args(["kestra/username"])
        .output()?;
    let pass = std::process::Command::new("pass")
        .args(["kestra/password"])
        .output()?;

    let username = String::from_utf8(user.stdout)?.trim().to_string();
    let password = String::from_utf8(pass.stdout)?.trim().to_string();

    Ok((username, password))
}

fn basic_auth_header(username: &str, password: &str) -> String {
    let credentials = format!("{}:{}", username, password);
    let encoded = STANDARD.encode(credentials.as_bytes());
    format!("Basic {}", encoded)
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();

    let (username, password) = if cli.use_pass {
        get_credentials().map_err(|e| {
            eprintln!("{}: Failed to get credentials from pass: {}", "ERROR".red(), e);
            e
        })?
    } else {
        (
            std::env::var("KESTRA_USER").unwrap_or_default(),
            std::env::var("KESTRA_PASS").unwrap_or_default(),
        )
    };

    match cli.command {
        Commands::Logs {
            execution_id,
            namespace,
            flow,
            format,
            level,
        } => {
            stream_logs(
                &cli.url,
                &username,
                &password,
                execution_id.as_deref(),
                namespace.as_deref(),
                flow.as_deref(),
                &format,
                &level,
            )
            .await?;
        }
        Commands::Watch { namespace, format } => {
            watch_executions(&cli.url, &username, &password, &namespace, &format).await?;
        }
        Commands::Poll {
            execution_id,
            interval,
            format,
        } => {
            poll_execution(&cli.url, &username, &password, &execution_id, interval, &format)
                .await?;
        }
    }

    Ok(())
}

async fn stream_logs(
    base_url: &str,
    username: &str,
    password: &str,
    execution_id: Option<&str>,
    namespace: Option<&str>,
    flow: Option<&str>,
    format: &str,
    _level: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    // Build WebSocket URL for log streaming
    // Kestra uses SSE for logs, not WebSocket - fallback to polling
    eprintln!(
        "{}: Kestra uses SSE for logs. Using REST polling fallback...",
        "INFO".blue()
    );

    // Build query params
    let mut params = vec![];
    if let Some(ns) = namespace {
        params.push(format!("namespace={}", ns));
    }
    if let Some(f) = flow {
        params.push(format!("flowId={}", f));
    }
    if let Some(eid) = execution_id {
        params.push(format!("executionId={}", eid));
    }

    let query = if params.is_empty() {
        String::new()
    } else {
        format!("?{}", params.join("&"))
    };

    let logs_url = if let Some(eid) = execution_id {
        format!("http://{}/api/v1/logs/{}", base_url, eid)
    } else {
        format!("http://{}/api/v1/logs{}", base_url, query)
    };

    eprintln!("{}: Fetching logs from {}", "INFO".blue(), logs_url);

    let client = reqwest::Client::new();
    let auth = basic_auth_header(username, password);

    loop {
        let response = client
            .get(&logs_url)
            .header("Authorization", &auth)
            .send()
            .await?;

        if !response.status().is_success() {
            eprintln!(
                "{}: Failed to fetch logs: {}",
                "ERROR".red(),
                response.status()
            );
            tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;
            continue;
        }

        let logs: Vec<LogEntry> = response.json().await?;

        for log in logs {
            output_log(&log, format);
        }

        // Break if we're watching a specific execution
        if execution_id.is_some() {
            break;
        }

        tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;
    }

    Ok(())
}

async fn watch_executions(
    base_url: &str,
    username: &str,
    password: &str,
    namespace: &str,
    format: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    eprintln!(
        "{}: Watching executions in namespace '{}'",
        "INFO".blue(),
        namespace
    );

    let client = reqwest::Client::new();
    let auth = basic_auth_header(username, password);
    let mut seen_executions = std::collections::HashSet::new();

    loop {
        let url = format!(
            "http://{}/api/v1/executions?namespace={}",
            base_url, namespace
        );

        let response = client
            .get(&url)
            .header("Authorization", &auth)
            .send()
            .await?;

        if response.status().is_success() {
            let executions: serde_json::Value = response.json().await?;

            if let Some(results) = executions.get("results").and_then(|r| r.as_array()) {
                for exec in results {
                    if let Some(id) = exec.get("id").and_then(|i| i.as_str()) {
                        if !seen_executions.contains(id) {
                            seen_executions.insert(id.to_string());
                            output_execution(exec, format);
                        }
                    }
                }
            }
        }

        tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;
    }
}

async fn poll_execution(
    base_url: &str,
    username: &str,
    password: &str,
    execution_id: &str,
    interval: u64,
    format: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    eprintln!(
        "{}: Polling execution '{}' every {}s",
        "INFO".blue(),
        execution_id,
        interval
    );

    let client = reqwest::Client::new();
    let auth = basic_auth_header(username, password);
    let exec_url = format!("http://{}/api/v1/executions/{}", base_url, execution_id);
    let logs_url = format!("http://{}/api/v1/logs/{}", base_url, execution_id);

    let mut last_log_count = 0;
    let mut error_count = 0usize;
    let mut warning_count = 0usize;
    let mut xml_stream: Option<kestra_ws::XmlStream> = None;

    // For XML format, we need to get initial execution info for the header
    if format == "xml" {
        let exec_response = client
            .get(&exec_url)
            .header("Authorization", &auth)
            .send()
            .await?;

        if exec_response.status().is_success() {
            let execution: Execution = exec_response.json().await?;
            let stream = kestra_ws::XmlStream::new(&execution.id, &execution.namespace, &execution.flow_id);
            print!("{}", stream.header());
            xml_stream = Some(stream);
        }
    }

    loop {
        // Get execution status
        let exec_response = client
            .get(&exec_url)
            .header("Authorization", &auth)
            .send()
            .await?;

        if !exec_response.status().is_success() {
            eprintln!(
                "{}: Failed to fetch execution: {}",
                "ERROR".red(),
                exec_response.status()
            );
            tokio::time::sleep(tokio::time::Duration::from_secs(interval)).await;
            continue;
        }

        let execution: Execution = exec_response.json().await?;

        // Get new logs
        let logs_response = client
            .get(&logs_url)
            .header("Authorization", &auth)
            .send()
            .await?;

        if logs_response.status().is_success() {
            let logs: Vec<LogEntry> = logs_response.json().await?;

            // Only output new logs
            for log in logs.iter().skip(last_log_count) {
                // Track error/warning counts for summary
                if let Some(ref level) = log.level {
                    match level.to_uppercase().as_str() {
                        "ERROR" | "FATAL" | "CRITICAL" => error_count += 1,
                        "WARN" | "WARNING" => warning_count += 1,
                        _ => {}
                    }
                }
                output_log(log, format);
            }
            last_log_count = logs.len();
        }

        // Output execution summary (skip for XML - will be in footer)
        if format == "json" {
            let summary = serde_json::json!({
                "type": "execution_status",
                "id": execution.id,
                "state": execution.state.current,
                "tasks": execution.task_run_list.as_ref().map(|t| t.iter().map(|tr| {
                    serde_json::json!({
                        "id": tr.task_id,
                        "state": tr.state.current
                    })
                }).collect::<Vec<_>>())
            });
            println!("{}", serde_json::to_string(&summary)?);
        } else if format != "xml" {
            let state_color = match execution.state.current.as_str() {
                "SUCCESS" => "green",
                "FAILED" | "KILLED" => "red",
                "RUNNING" => "blue",
                _ => "yellow",
            };
            eprintln!(
                "{} | {} | {}",
                execution.id.dimmed(),
                execution.state.current.color(state_color),
                execution
                    .task_run_list
                    .as_ref()
                    .map(|t| t
                        .iter()
                        .map(|tr| format!("{}:{}", tr.task_id, tr.state.current))
                        .collect::<Vec<_>>()
                        .join(", "))
                    .unwrap_or_default()
            );
        }

        // Exit if execution completed
        match execution.state.current.as_str() {
            "SUCCESS" | "FAILED" | "KILLED" | "WARNING" => {
                // For XML, output the footer with summary
                if let Some(ref stream) = xml_stream {
                    let task_summary = execution
                        .task_run_list
                        .as_ref()
                        .map(|t| t
                            .iter()
                            .map(|tr| format!("{}:{}", tr.task_id, tr.state.current))
                            .collect::<Vec<_>>()
                            .join(", "))
                        .unwrap_or_default();
                    print!("{}", stream.footer(&execution.state.current, &task_summary, error_count, warning_count));
                }
                eprintln!("{}: Execution completed with state {}", "DONE".green(), execution.state.current);
                break;
            }
            _ => {}
        }

        tokio::time::sleep(tokio::time::Duration::from_secs(interval)).await;
    }

    Ok(())
}

fn output_log(log: &LogEntry, format: &str) {
    match format {
        "json" => {
            if let Ok(json) = serde_json::to_string(log) {
                println!("{}", json);
            }
        }
        "xml" => {
            println!("{}", log.format_xml());
        }
        "raw" => {
            if let Some(msg) = &log.message {
                println!("{}", msg);
            }
        }
        _ => {
            // Pretty format
            let level = log.level.as_deref().unwrap_or("INFO");
            let level_colored = match level {
                "ERROR" => level.red(),
                "WARN" | "WARNING" => level.yellow(),
                "DEBUG" | "TRACE" => level.dimmed(),
                _ => level.blue(),
            };

            let task = log.task_id.as_deref().unwrap_or("-");
            let msg = log.message.as_deref().unwrap_or("");

            println!(
                "{} | {} | {}",
                level_colored,
                task.cyan(),
                msg
            );
        }
    }
}

fn output_execution(exec: &serde_json::Value, format: &str) {
    match format {
        "json" => {
            if let Ok(json) = serde_json::to_string(exec) {
                println!("{}", json);
            }
        }
        "xml" => {
            let id = exec.get("id").and_then(|i| i.as_str()).unwrap_or("-");
            let ns = exec.get("namespace").and_then(|n| n.as_str()).unwrap_or("-");
            let flow = exec.get("flowId").and_then(|f| f.as_str()).unwrap_or("-");
            let state = exec
                .get("state")
                .and_then(|s| s.get("current"))
                .and_then(|c| c.as_str())
                .unwrap_or("-");

            println!(
                r#"<new_execution>
  <id>{}</id>
  <namespace>{}</namespace>
  <flow_id>{}</flow_id>
  <state>{}</state>
</new_execution>"#,
                kestra_ws::escape_xml(id),
                kestra_ws::escape_xml(ns),
                kestra_ws::escape_xml(flow),
                kestra_ws::escape_xml(state)
            );
        }
        _ => {
            let id = exec.get("id").and_then(|i| i.as_str()).unwrap_or("-");
            let flow = exec.get("flowId").and_then(|f| f.as_str()).unwrap_or("-");
            let state = exec
                .get("state")
                .and_then(|s| s.get("current"))
                .and_then(|c| c.as_str())
                .unwrap_or("-");

            println!(
                "{} | {} | {} | {}",
                "NEW".green(),
                id.cyan(),
                flow,
                state.yellow()
            );
        }
    }
}
