//! Graphiti Integration Script (MCP-Enabled)
//!
//! Integrates with Graphiti MCP server for knowledge graph management
//!
//! ```cargo
//! [dependencies]
//! anyhow = "1.0"
//! serde = { version = "1.0", features = ["derive"] }
//! serde_json = "1.0"
//! ```
use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::process::{Command, Stdio};

#[derive(Deserialize)]
pub struct GraphitiInput {
    pub action: String,
    pub name: Option<String>,
    pub episode_body: Option<String>,
    pub query: Option<String>,
}

#[derive(Serialize)]
pub struct GraphitiOutput {
    pub success: bool,
    pub message: String,
    pub episode_id: Option<String>,
    pub results: Option<serde_json::Value>,
}

/// Call Graphiti MCP tool via wmill CLI wrapper
fn call_graphiti_mcp(input: &GraphitiInput) -> Result<serde_json::Value> {
    // Build the wmill MCP call command
    // This assumes wmill MCP server is available
    let args = match input.action.as_str() {
        "add" => {
            if let (Some(name), Some(body)) = (&input.name, &input.episode_body) {
                vec![
                    "mcp", "call",
                    "graphiti",
                    "add_memory",
                    "--json",
                    &format!(r#"{{"name": "{}", "episode_body": "{}"}}"#, name, body)
                ]
            } else {
                return Err(anyhow!("add action requires name and episode_body"));
            }
        },
        "search" => {
            if let Some(query) = &input.query {
                vec![
                    "mcp", "call",
                    "graphiti",
                    "search_nodes",
                    "--json",
                    &format!(r#"{{"query": "{}", "max_nodes": 10}}"#, query)
                ]
            } else {
                return Err(anyhow!("search action requires query"));
            }
        },
        "search_facts" => {
            if let Some(query) = &input.query {
                vec![
                    "mcp", "call",
                    "graphiti",
                    "search_memory_facts",
                    "--json",
                    &format!(r#"{{"query": "{}", "max_facts": 10}}"#, query)
                ]
            } else {
                return Err(anyhow!("search_facts action requires query"));
            }
        },
        "list_episodes" => {
            vec![
                "mcp", "call",
                "graphiti",
                "get_episodes",
                "--json",
                r#"{{"max_episodes": 10}}"#
            ]
        },
        _ => return Err(anyhow!("Unknown action: {}", input.action)),
    };

    eprintln!("[graphiti] Calling MCP: wmill {}", args.join(" "));

    // Execute via wmill MCP client
    let output = Command::new("wmill")
        .args(&args)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);

    if !output.status.success() {
        return Err(anyhow!("wmill MCP call failed: {}", stderr));
    }

    // Parse JSON response
    match serde_json::from_str(&stdout) {
        Ok(value) => Ok(value),
        Err(e) => Err(anyhow!("Failed to parse Graphiti response: {}", e)),
    }
}

pub fn main(input: GraphitiInput) -> Result<GraphitiOutput> {
    eprintln!("[graphiti] Action: {}", input.action);

    match input.action.as_str() {
        "add" => {
            if let (Some(name), Some(body)) = (&input.name, &input.episode_body) {
                let result = call_graphiti_mcp(&input)?;
                eprintln!("[graphiti] Added episode: {}", name);
                Ok(GraphitiOutput {
                    success: true,
                    message: "Episode added successfully".to_string(),
                    episode_id: result.get("episode_id").and_then(|v| v.as_str()).map(|s| s.to_string()),
                    results: Some(result),
                })
            } else {
                Ok(GraphitiOutput {
                    success: false,
                    message: "Name and episode_body required for add action".to_string(),
                    episode_id: None,
                    results: None,
                })
            }
        },
        "search" => {
            if let Some(query) = &input.query {
                let result = call_graphiti_mcp(&input)?;
                eprintln!("[graphiti] Found {} nodes", result.get("results").and_then(|r| r.as_array()).map(|a| a.len()).unwrap_or(0));
                Ok(GraphitiOutput {
                    success: true,
                    message: "Search completed".to_string(),
                    episode_id: None,
                    results: Some(result),
                })
            } else {
                Ok(GraphitiOutput {
                    success: false,
                    message: "Query required for search action".to_string(),
                    episode_id: None,
                    results: None,
                })
            }
        },
        "search_facts" => {
            if let Some(query) = &input.query {
                let result = call_graphiti_mcp(&input)?;
                eprintln!("[graphiti] Found {} facts", result.get("results").and_then(|r| r.as_array()).map(|a| a.len()).unwrap_or(0));
                Ok(GraphitiOutput {
                    success: true,
                    message: "Facts search completed".to_string(),
                    episode_id: None,
                    results: Some(result),
                })
            } else {
                Ok(GraphitiOutput {
                    success: false,
                    message: "Query required for search_facts action".to_string(),
                    episode_id: None,
                    results: None,
                    episode_id: None,
                    results: None,
                })
            }
        },
        "list_episodes" => {
            let result = call_graphiti_mcp(&input)?;
            eprintln!("[graphiti] Listed episodes");
            Ok(GraphitiOutput {
                success: true,
                message: "Episodes listed".to_string(),
                episode_id: None,
                results: Some(result),
            })
        },
        _ => Ok(GraphitiOutput {
            success: false,
            message: format!("Unknown action: {}", input.action),
            episode_id: None,
            results: None,
        }),
    }
}
