//! Initialize workspace for contract loop execution
//!
//! Creates a unique trace ID and work directory for this execution.
//!
//! ```cargo
//! [dependencies]
//! anyhow = "1.0"
//! serde = { version = "1.0", features = ["derive"] }
//! serde_json = "1.0"
//! uuid = { version = "1.0", features = ["v4"] }
//! tokio = { version = "1", features = ["fs"] }
//! ```

use anyhow::Result;
use serde::Serialize;

#[derive(Serialize)]
pub struct InitOutput {
    pub trace_id: String,
    pub work_dir: String,
    pub attempt: u32,
    pub feedback: String,
}

pub async fn main() -> Result<InitOutput> {
    let trace_id = uuid::Uuid::new_v4().to_string()[..8].to_string();
    let work_dir = format!("/tmp/fire-flow-{}", trace_id);

    tokio::fs::create_dir_all(&work_dir).await?;

    eprintln!("[init] Created workspace: {}", work_dir);

    Ok(InitOutput {
        trace_id,
        work_dir,
        attempt: 0,
        feedback: "Initial generation".to_string(),
    })
}
