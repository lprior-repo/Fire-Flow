//! Kestra Client Library
//!
//! Following Wardley principles: commoditize common patterns
//! - Credential retrieval (commodity)
//! - HTTP client with auth (commodity)
//! - Log parsing/formatting (utility)
//! - Execution polling (custom)

use base64::{engine::general_purpose::STANDARD, Engine};
use serde::{Deserialize, Serialize};

// ============================================================================
// COMMODITY LAYER: Standard patterns that should be reused
// ============================================================================

/// Credential provider - commodity pattern for secure credential retrieval
pub mod credentials {
    use std::error::Error;

    pub trait CredentialProvider {
        fn get_credentials(&self) -> Result<(String, String), Box<dyn Error>>;
    }

    /// Pass-based credential provider (uses GPG password manager)
    pub struct PassProvider;

    impl CredentialProvider for PassProvider {
        fn get_credentials(&self) -> Result<(String, String), Box<dyn Error>> {
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
    }

    /// Environment variable credential provider (for CI/CD)
    pub struct EnvProvider {
        pub user_var: String,
        pub pass_var: String,
    }

    impl Default for EnvProvider {
        fn default() -> Self {
            Self {
                user_var: "KESTRA_USER".into(),
                pass_var: "KESTRA_PASS".into(),
            }
        }
    }

    impl CredentialProvider for EnvProvider {
        fn get_credentials(&self) -> Result<(String, String), Box<dyn Error>> {
            let username = std::env::var(&self.user_var)?;
            let password = std::env::var(&self.pass_var)?;
            Ok((username, password))
        }
    }

    /// Static credential provider (for testing)
    #[cfg(test)]
    pub struct StaticProvider {
        pub username: String,
        pub password: String,
    }

    #[cfg(test)]
    impl CredentialProvider for StaticProvider {
        fn get_credentials(&self) -> Result<(String, String), Box<dyn Error>> {
            Ok((self.username.clone(), self.password.clone()))
        }
    }
}

/// HTTP authentication - commodity pattern
pub mod auth {
    use super::*;

    pub fn basic_auth_header(username: &str, password: &str) -> String {
        let credentials = format!("{}:{}", username, password);
        let encoded = STANDARD.encode(credentials.as_bytes());
        format!("Basic {}", encoded)
    }

    #[cfg(test)]
    mod tests {
        use super::*;

        #[test]
        fn test_basic_auth_header() {
            let header = basic_auth_header("user", "pass");
            assert!(header.starts_with("Basic "));
            // user:pass base64 = dXNlcjpwYXNz
            assert_eq!(header, "Basic dXNlcjpwYXNz");
        }

        #[test]
        fn test_basic_auth_special_chars() {
            let header = basic_auth_header("user@example.com", "p@ss!word");
            assert!(header.starts_with("Basic "));
        }
    }
}

// ============================================================================
// UTILITY LAYER: Reusable but domain-specific
// ============================================================================

/// Log entry structure - matches Kestra's log format
#[derive(Debug, Clone, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct LogEntry {
    pub execution_id: Option<String>,
    pub namespace: Option<String>,
    pub flow_id: Option<String>,
    pub task_id: Option<String>,
    pub message: Option<String>,
    pub level: Option<String>,
    pub timestamp: Option<String>,
}

impl LogEntry {
    /// Format log entry for human consumption
    pub fn format_pretty(&self) -> String {
        let level = self.level.as_deref().unwrap_or("INFO");
        let task = self.task_id.as_deref().unwrap_or("-");
        let msg = self.message.as_deref().unwrap_or("");
        format!("{} | {} | {}", level, task, msg)
    }

    /// Format log entry as JSON
    pub fn format_json(&self) -> Result<String, serde_json::Error> {
        serde_json::to_string(self)
    }

    /// Format log entry as XML for AI consumption
    /// Includes nested JSON parsing and semantic classification
    pub fn format_xml(&self) -> String {
        let level = self.level.as_deref().unwrap_or("INFO");
        let severity = classify_severity(level);
        let msg = self.message.as_deref().unwrap_or("");

        let mut xml = format!("<log severity=\"{}\">\n", severity);

        // Metadata section
        xml.push_str("  <meta>\n");
        if let Some(ref id) = self.execution_id {
            xml.push_str(&format!("    <execution_id>{}</execution_id>\n", escape_xml(id)));
        }
        if let Some(ref ns) = self.namespace {
            xml.push_str(&format!("    <namespace>{}</namespace>\n", escape_xml(ns)));
        }
        if let Some(ref flow) = self.flow_id {
            xml.push_str(&format!("    <flow_id>{}</flow_id>\n", escape_xml(flow)));
        }
        if let Some(ref task) = self.task_id {
            xml.push_str(&format!("    <task_id>{}</task_id>\n", escape_xml(task)));
        }
        if let Some(ref level) = self.level {
            xml.push_str(&format!("    <level>{}</level>\n", escape_xml(level)));
        }
        if let Some(ref ts) = self.timestamp {
            xml.push_str(&format!("    <timestamp>{}</timestamp>\n", escape_xml(ts)));
        }
        xml.push_str("  </meta>\n");

        // Try to parse message as JSON for structured data
        if let Some(parsed) = try_parse_structured_message(msg) {
            xml.push_str("  <structured_message>\n");
            xml.push_str(&parsed);
            xml.push_str("  </structured_message>\n");
        }

        // Always include raw message
        xml.push_str(&format!("  <message><![CDATA[{}]]></message>\n", msg));

        // Add action hints for errors
        if severity == "error" || severity == "fatal" {
            if let Some(hint) = extract_error_hint(msg) {
                xml.push_str(&format!("  <action_hint>{}</action_hint>\n", escape_xml(&hint)));
            }
        }

        xml.push_str("</log>");
        xml
    }
}

/// Classify log level into semantic severity
fn classify_severity(level: &str) -> &'static str {
    match level.to_uppercase().as_str() {
        "TRACE" => "trace",
        "DEBUG" => "debug",
        "INFO" => "info",
        "WARN" | "WARNING" => "warning",
        "ERROR" => "error",
        "FATAL" | "CRITICAL" => "fatal",
        _ => "info",
    }
}

/// Try to parse message as structured JSON and convert to XML
fn try_parse_structured_message(msg: &str) -> Option<String> {
    // Try parsing as JSON
    if let Ok(json) = serde_json::from_str::<serde_json::Value>(msg) {
        return Some(json_to_xml(&json, 2));
    }

    // Check if message contains embedded JSON (common in logs)
    if let Some(start) = msg.find('{') {
        if let Some(end) = msg.rfind('}') {
            if end > start {
                let json_part = &msg[start..=end];
                if let Ok(json) = serde_json::from_str::<serde_json::Value>(json_part) {
                    let prefix = msg[..start].trim();
                    let mut result = String::new();
                    if !prefix.is_empty() {
                        result.push_str(&format!("    <prefix>{}</prefix>\n", escape_xml(prefix)));
                    }
                    result.push_str(&json_to_xml(&json, 2));
                    return Some(result);
                }
            }
        }
    }

    None
}

/// Convert JSON value to XML string
fn json_to_xml(value: &serde_json::Value, indent: usize) -> String {
    let spaces = "  ".repeat(indent);
    match value {
        serde_json::Value::Object(map) => {
            let mut xml = String::new();
            for (key, val) in map {
                let safe_key = sanitize_xml_tag(key);
                match val {
                    serde_json::Value::Object(_) | serde_json::Value::Array(_) => {
                        xml.push_str(&format!("{}<{}>\n", spaces, safe_key));
                        xml.push_str(&json_to_xml(val, indent + 1));
                        xml.push_str(&format!("{}</{}>\n", spaces, safe_key));
                    }
                    _ => {
                        let text = json_value_to_string(val);
                        xml.push_str(&format!("{}<{}>{}</{}>\n", spaces, safe_key, escape_xml(&text), safe_key));
                    }
                }
            }
            xml
        }
        serde_json::Value::Array(arr) => {
            let mut xml = String::new();
            for (i, val) in arr.iter().enumerate() {
                xml.push_str(&format!("{}<item index=\"{}\">\n", spaces, i));
                xml.push_str(&json_to_xml(val, indent + 1));
                xml.push_str(&format!("{}</item>\n", spaces));
            }
            xml
        }
        _ => {
            let text = json_value_to_string(value);
            format!("{}<value>{}</value>\n", spaces, escape_xml(&text))
        }
    }
}

/// Convert JSON value to string representation
fn json_value_to_string(value: &serde_json::Value) -> String {
    match value {
        serde_json::Value::String(s) => s.clone(),
        serde_json::Value::Number(n) => n.to_string(),
        serde_json::Value::Bool(b) => b.to_string(),
        serde_json::Value::Null => "null".to_string(),
        _ => value.to_string(),
    }
}

/// Sanitize a string to be a valid XML tag name
fn sanitize_xml_tag(s: &str) -> String {
    let mut result = String::new();
    for (i, c) in s.chars().enumerate() {
        if i == 0 {
            if c.is_ascii_alphabetic() || c == '_' {
                result.push(c);
            } else {
                result.push('_');
                if c.is_ascii_alphanumeric() {
                    result.push(c);
                }
            }
        } else if c.is_ascii_alphanumeric() || c == '_' || c == '-' || c == '.' {
            result.push(c);
        } else {
            result.push('_');
        }
    }
    if result.is_empty() {
        result = "field".to_string();
    }
    result
}

/// Extract actionable hints from error messages
fn extract_error_hint(msg: &str) -> Option<String> {
    let msg_lower = msg.to_lowercase();

    // Exit code analysis
    if msg_lower.contains("exit code 137") || msg_lower.contains("exit 137") {
        return Some("Process killed (OOM or timeout). Check memory limits or increase timeout.".into());
    }
    if msg_lower.contains("exit code 1") || msg_lower.contains("exit 1") {
        return Some("Command failed. Check the command output for specific error details.".into());
    }

    // Common error patterns
    if msg_lower.contains("connection refused") {
        return Some("Service unreachable. Check if the target service is running.".into());
    }
    if msg_lower.contains("permission denied") {
        return Some("Permission issue. Check file/resource permissions.".into());
    }
    if msg_lower.contains("not found") || msg_lower.contains("no such file") {
        return Some("Resource not found. Verify paths and dependencies exist.".into());
    }
    if msg_lower.contains("timeout") {
        return Some("Operation timed out. Consider increasing timeout or optimizing the operation.".into());
    }
    if msg_lower.contains("opencode failed") {
        return Some("AI code generation failed. Check opencode logs and API connectivity.".into());
    }

    None
}

/// Escape XML special characters
pub fn escape_xml(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&apos;")
}

/// XML stream wrapper for complete output
pub struct XmlStream {
    execution_id: String,
    namespace: String,
    flow_id: String,
    start_time: String,
}

impl XmlStream {
    pub fn new(execution_id: &str, namespace: &str, flow_id: &str) -> Self {
        Self {
            execution_id: execution_id.to_string(),
            namespace: namespace.to_string(),
            flow_id: flow_id.to_string(),
            start_time: chrono::Utc::now().to_rfc3339(),
        }
    }

    /// Output stream header
    pub fn header(&self) -> String {
        format!(
            r#"<kestra_stream version="1.0">
  <stream_meta>
    <execution_id>{}</execution_id>
    <namespace>{}</namespace>
    <flow_id>{}</flow_id>
    <stream_started>{}</stream_started>
    <schema>kestra-ws-xml-v1</schema>
  </stream_meta>
  <logs>
"#,
            escape_xml(&self.execution_id),
            escape_xml(&self.namespace),
            escape_xml(&self.flow_id),
            escape_xml(&self.start_time)
        )
    }

    /// Output stream footer with summary
    pub fn footer(&self, final_state: &str, task_summary: &str, error_count: usize, warning_count: usize) -> String {
        format!(
            r#"  </logs>
  <summary>
    <final_state>{}</final_state>
    <task_summary>{}</task_summary>
    <error_count>{}</error_count>
    <warning_count>{}</warning_count>
    <stream_ended>{}</stream_ended>
  </summary>
</kestra_stream>
"#,
            escape_xml(final_state),
            escape_xml(task_summary),
            error_count,
            warning_count,
            chrono::Utc::now().to_rfc3339()
        )
    }
}

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq)]
pub struct ExecutionState {
    pub current: String,
}

impl ExecutionState {
    pub fn is_terminal(&self) -> bool {
        matches!(
            self.current.as_str(),
            "SUCCESS" | "FAILED" | "KILLED" | "WARNING"
        )
    }

    pub fn is_success(&self) -> bool {
        self.current == "SUCCESS"
    }
}

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct TaskRun {
    pub id: String,
    pub task_id: String,
    pub state: ExecutionState,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Execution {
    pub id: String,
    pub namespace: String,
    pub flow_id: String,
    pub state: ExecutionState,
    pub task_run_list: Option<Vec<TaskRun>>,
}

impl Execution {
    /// Get summary of task states
    pub fn task_summary(&self) -> String {
        self.task_run_list
            .as_ref()
            .map(|tasks| {
                tasks
                    .iter()
                    .map(|t| format!("{}:{}", t.task_id, t.state.current))
                    .collect::<Vec<_>>()
                    .join(", ")
            })
            .unwrap_or_default()
    }

    /// Format execution status as XML for AI consumption
    pub fn format_xml(&self) -> String {
        let mut xml = String::from("<execution_status>\n");

        xml.push_str(&format!("  <id>{}</id>\n", escape_xml(&self.id)));
        xml.push_str(&format!("  <namespace>{}</namespace>\n", escape_xml(&self.namespace)));
        xml.push_str(&format!("  <flow_id>{}</flow_id>\n", escape_xml(&self.flow_id)));
        xml.push_str(&format!("  <state>{}</state>\n", escape_xml(&self.state.current)));

        if let Some(ref tasks) = self.task_run_list {
            xml.push_str("  <tasks>\n");
            for task in tasks {
                xml.push_str(&format!(
                    "    <task id=\"{}\" state=\"{}\"/>\n",
                    escape_xml(&task.task_id),
                    escape_xml(&task.state.current)
                ));
            }
            xml.push_str("  </tasks>\n");
        }

        xml.push_str("</execution_status>");
        xml
    }
}

// ============================================================================
// CUSTOM LAYER: Application-specific logic
// ============================================================================

/// Kestra client for API interactions
pub struct KesstraClient {
    pub base_url: String,
    pub auth_header: String,
    pub client: reqwest::Client,
}

impl KesstraClient {
    pub fn new(base_url: &str, username: &str, password: &str) -> Self {
        Self {
            base_url: base_url.to_string(),
            auth_header: auth::basic_auth_header(username, password),
            client: reqwest::Client::new(),
        }
    }

    pub async fn get_execution(
        &self,
        execution_id: &str,
    ) -> Result<Execution, Box<dyn std::error::Error>> {
        let url = format!("http://{}/api/v1/executions/{}", self.base_url, execution_id);

        let response = self
            .client
            .get(&url)
            .header("Authorization", &self.auth_header)
            .send()
            .await?;

        if !response.status().is_success() {
            return Err(format!("Failed to fetch execution: {}", response.status()).into());
        }

        Ok(response.json().await?)
    }

    pub async fn get_logs(
        &self,
        execution_id: &str,
    ) -> Result<Vec<LogEntry>, Box<dyn std::error::Error>> {
        let url = format!("http://{}/api/v1/logs/{}", self.base_url, execution_id);

        let response = self
            .client
            .get(&url)
            .header("Authorization", &self.auth_header)
            .send()
            .await?;

        if !response.status().is_success() {
            return Err(format!("Failed to fetch logs: {}", response.status()).into());
        }

        Ok(response.json().await?)
    }
}

/// Execution watcher - polls and yields new logs/status
pub struct ExecutionWatcher {
    client: KesstraClient,
    execution_id: String,
    seen_log_count: usize,
}

impl ExecutionWatcher {
    pub fn new(client: KesstraClient, execution_id: &str) -> Self {
        Self {
            client,
            execution_id: execution_id.to_string(),
            seen_log_count: 0,
        }
    }

    /// Poll for updates, returns (new_logs, execution_status, is_complete)
    pub async fn poll(
        &mut self,
    ) -> Result<(Vec<LogEntry>, Execution, bool), Box<dyn std::error::Error>> {
        let execution = self.client.get_execution(&self.execution_id).await?;
        let logs = self.client.get_logs(&self.execution_id).await?;

        let new_logs: Vec<LogEntry> = logs.into_iter().skip(self.seen_log_count).collect();
        self.seen_log_count += new_logs.len();

        let is_complete = execution.state.is_terminal();

        Ok((new_logs, execution, is_complete))
    }
}

// ============================================================================
// TESTS
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_log_entry_format_pretty() {
        let log = LogEntry {
            execution_id: Some("exec-123".into()),
            namespace: Some("bitter".into()),
            flow_id: Some("contract-loop".into()),
            task_id: Some("generate".into()),
            message: Some("Generating tool".into()),
            level: Some("INFO".into()),
            timestamp: Some("2024-12-25T00:00:00Z".into()),
        };

        let formatted = log.format_pretty();
        assert!(formatted.contains("INFO"));
        assert!(formatted.contains("generate"));
        assert!(formatted.contains("Generating tool"));
    }

    #[test]
    fn test_log_entry_format_json() {
        let log = LogEntry {
            execution_id: Some("exec-123".into()),
            namespace: None,
            flow_id: None,
            task_id: Some("test".into()),
            message: Some("Test message".into()),
            level: Some("DEBUG".into()),
            timestamp: None,
        };

        let json = log.format_json().unwrap();
        assert!(json.contains("exec-123"));
        assert!(json.contains("DEBUG"));
    }

    #[test]
    fn test_execution_state_terminal() {
        assert!(ExecutionState { current: "SUCCESS".into() }.is_terminal());
        assert!(ExecutionState { current: "FAILED".into() }.is_terminal());
        assert!(ExecutionState { current: "KILLED".into() }.is_terminal());
        assert!(!ExecutionState { current: "RUNNING".into() }.is_terminal());
        assert!(!ExecutionState { current: "CREATED".into() }.is_terminal());
    }

    #[test]
    fn test_execution_state_success() {
        assert!(ExecutionState { current: "SUCCESS".into() }.is_success());
        assert!(!ExecutionState { current: "FAILED".into() }.is_success());
        assert!(!ExecutionState { current: "RUNNING".into() }.is_success());
    }

    #[test]
    fn test_execution_task_summary() {
        let exec = Execution {
            id: "exec-1".into(),
            namespace: "test".into(),
            flow_id: "flow-1".into(),
            state: ExecutionState { current: "RUNNING".into() },
            task_run_list: Some(vec![
                TaskRun {
                    id: "run-1".into(),
                    task_id: "task-a".into(),
                    state: ExecutionState { current: "SUCCESS".into() },
                },
                TaskRun {
                    id: "run-2".into(),
                    task_id: "task-b".into(),
                    state: ExecutionState { current: "RUNNING".into() },
                },
            ]),
        };

        let summary = exec.task_summary();
        assert!(summary.contains("task-a:SUCCESS"));
        assert!(summary.contains("task-b:RUNNING"));
    }

    #[test]
    fn test_log_entry_deserialize() {
        let json = r#"{
            "executionId": "abc123",
            "namespace": "bitter",
            "flowId": "test-flow",
            "taskId": "generate",
            "message": "Test log message",
            "level": "INFO",
            "timestamp": "2024-12-25T12:00:00Z"
        }"#;

        let log: LogEntry = serde_json::from_str(json).unwrap();
        assert_eq!(log.execution_id, Some("abc123".into()));
        assert_eq!(log.level, Some("INFO".into()));
    }

    #[test]
    fn test_execution_deserialize() {
        let json = r#"{
            "id": "exec-abc",
            "namespace": "bitter",
            "flowId": "contract-loop",
            "state": { "current": "RUNNING" },
            "taskRunList": []
        }"#;

        let exec: Execution = serde_json::from_str(json).unwrap();
        assert_eq!(exec.id, "exec-abc");
        assert!(!exec.state.is_terminal());
    }

    #[test]
    fn test_log_entry_format_xml_basic() {
        let log = LogEntry {
            execution_id: Some("exec-123".into()),
            namespace: Some("bitter".into()),
            flow_id: Some("contract-loop".into()),
            task_id: Some("generate".into()),
            message: Some("Test message".into()),
            level: Some("INFO".into()),
            timestamp: Some("2024-12-25T00:00:00Z".into()),
        };

        let xml = log.format_xml();
        assert!(xml.contains("<log severity=\"info\">"));
        assert!(xml.contains("<execution_id>exec-123</execution_id>"));
        assert!(xml.contains("<task_id>generate</task_id>"));
        assert!(xml.contains("<![CDATA[Test message]]>"));
    }

    #[test]
    fn test_log_entry_format_xml_with_json_message() {
        let log = LogEntry {
            execution_id: Some("exec-123".into()),
            namespace: None,
            flow_id: None,
            task_id: Some("generate".into()),
            message: Some(r#"{"level":"info","msg":"generating tool","trace_id":"abc123"}"#.into()),
            level: Some("ERROR".into()),
            timestamp: None,
        };

        let xml = log.format_xml();
        assert!(xml.contains("<log severity=\"error\">"));
        assert!(xml.contains("<structured_message>"));
        assert!(xml.contains("<level>info</level>"));
        assert!(xml.contains("<msg>generating tool</msg>"));
        assert!(xml.contains("<trace_id>abc123</trace_id>"));
    }

    #[test]
    fn test_log_entry_format_xml_with_action_hint() {
        let log = LogEntry {
            execution_id: Some("exec-123".into()),
            namespace: None,
            flow_id: None,
            task_id: Some("generate".into()),
            message: Some("opencode failed with exit 137".into()),
            level: Some("ERROR".into()),
            timestamp: None,
        };

        let xml = log.format_xml();
        assert!(xml.contains("<action_hint>"));
        assert!(xml.contains("OOM or timeout"));
    }

    #[test]
    fn test_execution_format_xml() {
        let exec = Execution {
            id: "exec-abc".into(),
            namespace: "bitter".into(),
            flow_id: "contract-loop".into(),
            state: ExecutionState { current: "FAILED".into() },
            task_run_list: Some(vec![
                TaskRun {
                    id: "run-1".into(),
                    task_id: "generate".into(),
                    state: ExecutionState { current: "FAILED".into() },
                },
            ]),
        };

        let xml = exec.format_xml();
        assert!(xml.contains("<execution_status>"));
        assert!(xml.contains("<id>exec-abc</id>"));
        assert!(xml.contains("<state>FAILED</state>"));
        assert!(xml.contains("<task id=\"generate\" state=\"FAILED\"/>"));
    }

    #[test]
    fn test_escape_xml() {
        assert_eq!(escape_xml("<test>"), "&lt;test&gt;");
        assert_eq!(escape_xml("a & b"), "a &amp; b");
        assert_eq!(escape_xml("\"quoted\""), "&quot;quoted&quot;");
    }
}
