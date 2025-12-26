# Fire-Flow: Windmill + Rust

Contract-driven AI code generation with self-healing loops.

## Architecture

```
windmill/
├── scripts/
│   ├── generate.rs      # AI generates code from contract
│   ├── execute.rs       # Run generated code with input
│   ├── validate.rs      # Validate output against DataContract
│   └── collect_feedback.rs  # Build feedback for retry
├── flows/
│   └── contract_loop.yaml   # Self-healing orchestration flow
└── README.md
```

## Setup Windmill

### Option 1: Windmill Cloud (Fastest)

1. Sign up at [windmill.dev](https://www.windmill.dev/)
2. Create a workspace
3. Deploy scripts via CLI (see below)

### Option 2: Self-Hosted

```bash
# Install Windmill CLI
curl -fsSL https://raw.githubusercontent.com/windmill-labs/windmill/main/install.sh | bash

# Or via cargo
cargo install windmill-cli

# Start local instance (requires Docker for Postgres)
windmill up

# Or connect to existing Postgres
export DATABASE_URL=postgres://user:pass@localhost/windmill
windmill server
```

### Option 3: Binary (No Docker)

```bash
# Download binary
curl -LO https://github.com/windmill-labs/windmill/releases/latest/download/windmill-linux-amd64
chmod +x windmill-linux-amd64

# Run with external Postgres
DATABASE_URL=postgres://localhost/windmill ./windmill-linux-amd64
```

## Deploy Scripts

```bash
# Install CLI
pip install wmill

# Login
wmill workspace add fire-flow https://app.windmill.dev/
wmill workspace switch fire-flow

# Push scripts
wmill push --path scripts/generate.rs
wmill push --path scripts/execute.rs
wmill push --path scripts/validate.rs
wmill push --path scripts/collect_feedback.rs

# Push flow
wmill push --path flows/contract_loop.yaml
```

## Usage

### Via CLI

```bash
wmill flow run f/fire-flow/flows/contract_loop \
  --data '{
    "contract_path": "/path/to/contract.yaml",
    "task": "Generate a function that echoes input",
    "language": "rust",
    "max_attempts": 5
  }'
```

### Via API

```bash
curl -X POST "https://app.windmill.dev/api/w/fire-flow/jobs/run/f/fire-flow/flows/contract_loop" \
  -H "Authorization: Bearer $WINDMILL_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "contract_path": "/path/to/contract.yaml",
    "task": "Generate a REST API handler",
    "language": "rust"
  }'
```

### Via Rust SDK

```rust
use windmill_client::Client;

let client = Client::new("https://app.windmill.dev", "your-token");
let result = client.run_flow("f/fire-flow/flows/contract_loop", json!({
    "contract_path": "contracts/api.yaml",
    "task": "Generate REST endpoint",
    "language": "rust",
})).await?;
```

## Supported Languages

| Language | Extension | Runtime |
|----------|-----------|---------|
| Rust | `.rs` | rustc/cargo |
| Python | `.py` | python3 |
| TypeScript | `.ts` | deno |
| Go | `.go` | go run |

## Flow Logic

```
┌─────────────┐
│    INIT     │ Create workspace, trace_id
└──────┬──────┘
       ▼
┌──────────────────────────────────────────┐
│           RETRY LOOP (max_attempts)       │
│  ┌─────────────┐                          │
│  │  GENERATE   │ AI creates code          │
│  └──────┬──────┘                          │
│         ▼                                 │
│  ┌─────────────┐                          │
│  │   EXECUTE   │ Run code with input      │
│  └──────┬──────┘                          │
│         ▼                                 │
│  ┌─────────────┐                          │
│  │  VALIDATE   │ Check against contract   │
│  └──────┬──────┘                          │
│         ▼                                 │
│  ┌─────────────┐  valid?  ┌───────────┐   │
│  │CHECK RESULT │─────────►│  SUCCESS  │───┼──► EXIT
│  └──────┬──────┘   yes    └───────────┘   │
│         │ no                              │
│         ▼                                 │
│  ┌─────────────┐                          │
│  │  FEEDBACK   │ Collect errors           │
│  └──────┬──────┘                          │
│         │                                 │
│         └──────────► next iteration       │
└──────────────────────────────────────────┘
       │ max attempts exceeded
       ▼
┌─────────────┐
│  ESCALATE   │ Human intervention needed
└─────────────┘
```

## Prerequisites

- `datacontract` CLI - for contract validation
- `opencode` or LLM API - for code generation
- Windmill instance - orchestration

## Migration from Nushell

| Old (Nushell) | New (Rust) |
|---------------|------------|
| `generate.nu` | `scripts/generate.rs` |
| `run-tool.nu` | `scripts/execute.rs` |
| `validate.nu` | `scripts/validate.rs` |
| Kestra YAML | `flows/contract_loop.yaml` |
