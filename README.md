# bitter-truth

Contract-driven orchestration with Rust tools and Kestra.

```
┌─────────────────────────────────────────────────────────────┐
│                      OPENCODE                               │
│              (Text in, Text/JSON out)                       │
└─────────────────────────┬───────────────────────────────────┘
                          │ Text prompt + JSON response
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                       KESTRA                                │
│                                                             │
│   - Orchestrates everything                                 │
│   - Manages state (internal DB or filesystem)               │
│   - Handles async (tools are sync)                          │
│   - Retry, timeout, scheduling                              │
│   - Converts JSON ↔ Protobuf at boundaries                  │
└─────────────────────────┬───────────────────────────────────┘
                          │ Protobuf bytes (stdin)
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                     RUST TOOL                               │
│                                                             │
│   - Small (50-200 lines)                                    │
│   - Pure function (no side effects)                         │
│   - Protobuf in, Protobuf out                               │
│   - No network (Kestra does HTTP)                           │
│   - No filesystem (Kestra passes data)                      │
│   - Type safety = correctness                               │
└─────────────────────────────────────────────────────────────┘
```

## Philosophy

**AI is a worker, not a decision-maker.**

1. Define the contract (what success looks like)
2. AI generates code (the only non-deterministic step)
3. Deterministic validation gates
4. Loop with structured feedback until all gates pass

The orchestrator owns the process. AI figures out *how* to satisfy the contract.

## Project Structure

```
bitter-truth/
├── proto/                    # Protobuf contracts (source of truth)
│   └── bitter/
│       ├── common.proto      # ExecutionContext, ToolResponse
│       └── tools/
│           └── echo.proto    # EchoInput, EchoOutput
├── crates/
│   ├── bitter-sdk/           # SDK for building tools
│   └── tools/
│       └── echo/             # Example tool (374KB binary)
└── kestra/
    └── flows/
        ├── echo.yml                      # Basic tool invocation
        └── code-generation-with-gates.yml # Contract-driven AI loop
```

## Quick Start

```bash
# Build all tools
cd bitter-truth
cargo build --release

# Run echo tool
echo '...' | ./target/release/echo

# Binary size
ls -lh target/release/echo  # ~374KB
```

## Writing a Tool

Tools are pure functions: protobuf in → protobuf out.

```rust
use bitter_sdk::{log_info, run_tool};
use bitter_sdk::proto::bitter::tools::{EchoInput, EchoOutput};

fn main() -> anyhow::Result<()> {
    run_tool(|input: EchoInput| {
        log_info("processing", &[("msg", &input.message)]);

        Ok(EchoOutput {
            echo: input.message.clone(),
            reversed: input.message.chars().rev().collect(),
            length: input.message.len() as i32,
            was_dry_run: input.context.map(|c| c.dry_run).unwrap_or(false),
        })
    })
}
```

## Contract-Driven Pattern

Kestra workflow with quality gates:

```yaml
tasks:
  # AI generates (non-deterministic)
  - id: generate
    type: shell
    command: opencode -p "{{ contract }}"

  # Gate 1: Syntax (deterministic)
  - id: gate_syntax
    type: shell
    command: cargo check

  # Gate 2: Tests (deterministic)
  - id: gate_tests
    type: shell
    command: cargo test

  # Gate 3: Coverage threshold (deterministic)
  - id: gate_coverage
    type: shell
    command: |
      COVERAGE=$(cargo llvm-cov --json | jq '.data[0].totals.lines.percent')
      [ $COVERAGE -ge 80 ]

  # Loop back with feedback if gates fail
  - id: feedback_loop
    type: choice
    conditions:
      - "{{ all_gates_passed }}" → done
      - default → generate
```

## Why This Architecture?

| Aspect | Before (Go+JSON) | Now (Rust+Protobuf) |
|--------|------------------|---------------------|
| Binary size | 5-10MB | ~374KB |
| Startup | ~20ms | ~5ms |
| Schema | Runtime validation | Compile-time |
| Type safety | Good | Excellent |
| Cross-language | Manual | Generated from .proto |

## Requirements

- Rust 1.70+
- protoc (protobuf compiler)
- Kestra (for orchestration)

## License

MIT
