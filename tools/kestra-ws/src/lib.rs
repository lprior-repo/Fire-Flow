//! Kestra Client Library
//!
//! Following Wardley principles: commoditize common patterns
//! - Credential retrieval (commodity)
//! - HTTP client with auth (commodity)
//! - Log parsing/formatting (utility)
//! - Execution polling (custom)

use base64::{engine::general_purpose::STANDARD, Engine};
use serde::{Deserialize, Serialize};
use std::collections::HashSet;

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
}
