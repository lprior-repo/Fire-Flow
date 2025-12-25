# bitter-truth

Contract-driven orchestration with Nushell and Data Contracts.

```
┌─────────────────────────────────────────────────────────────┐
│                      OPENCODE                               │
│              (Text in, Text/JSON out)                       │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                       KESTRA                                │
│                                                             │
│   - Orchestrates everything                                 │
│   - Validates against Data Contracts                        │
│   - Handles async, retry, scheduling                        │
│   - Quality gates with thresholds                           │
└─────────────────────────┬───────────────────────────────────┘
                          │ JSON (stdin)
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    NUSHELL TOOL                             │
│                                                             │
│   - Small scripts (50-100 lines)                            │
│   - Pure functions on structured data                       │
│   - JSON in, JSON out                                       │
│   - Native tables, records, pipelines                       │
│   - No compilation needed                                   │
└─────────────────────────────────────────────────────────────┘
```

## Philosophy

**Data Contract is God.**

1. Define the contract (YAML schema = source of truth)
2. AI generates code (the only non-deterministic step)
3. Validate against contract (deterministic)
4. Loop with feedback until contract satisfied

The orchestrator owns the process. AI figures out *how* to satisfy the contract.

## Project Structure

```
bitter-truth/
├── contracts/                    # Data Contract YAML (source of truth)
│   ├── common.yaml               # Shared types (ExecutionContext, ToolResponse)
│   └── tools/
│       └── echo.yaml             # Echo tool contract
├── tools/
│   └── echo.nu                   # Nushell tool (~50 lines)
└── kestra/
    └── flows/
        ├── echo.yml                      # Tool invocation
        └── code-generation-with-gates.yml # Contract-driven AI loop
```

## Quick Start

```bash
# Install dependencies
pacman -S nushell               # or: cargo install nu
pipx install datacontract-cli   # or: pip install datacontract-cli

# Run echo tool directly
echo '{"message": "hello"}' | nu bitter-truth/tools/echo.nu

# Validate contract
datacontract test bitter-truth/contracts/tools/echo.yaml
```

## Writing a Tool

Tools are Nushell scripts: JSON in → JSON out.

```nu
#!/usr/bin/env nu
# Contract: contracts/tools/echo.yaml

def main [] {
    let input = $in | from json
    let message = $input.message

    {
        success: true
        data: {
            echo: $message
            reversed: ($message | split chars | reverse | str join)
            length: ($message | str length)
        }
    } | to json
}
```

## Data Contracts

Contracts define the schema. Everything validates against them.

```yaml
dataContractSpecification: 0.9.3
id: echo-tool
info:
  title: Echo Tool Contract
  version: 1.0.0

models:
  EchoInput:
    type: object
    fields:
      - name: message
        type: string
        required: true
        minLength: 1

  EchoOutput:
    type: object
    fields:
      - name: echo
        type: string
        required: true
      - name: reversed
        type: string
        required: true
      - name: length
        type: integer
        required: true
```

## Contract-Driven Pattern

Kestra workflow with quality gates:

```yaml
tasks:
  # AI generates (non-deterministic)
  - id: generate
    command: opencode -p "{{ contract }}"

  # Gate 1: Contract validation (deterministic)
  - id: gate_contract
    command: datacontract test contracts/tool.yaml --data output.json

  # Gate 2: Tests (deterministic)
  - id: gate_tests
    command: nu test.nu

  # Loop back if gates fail
  - id: feedback_loop
    conditions:
      - "{{ all_gates_passed }}" → done
      - default → generate
```

## Why This Architecture?

| Aspect | Rust+Protobuf | Nushell+DataContract |
|--------|---------------|----------------------|
| Compilation | Required | None |
| Binary size | 374KB | 0 (script) |
| Schema format | .proto | YAML |
| Validation | Compile-time | Runtime (CLI) |
| Learning curve | Medium | Low |
| Iteration speed | Slow | Fast |
| Structured data | Manual | Native |

## Requirements

- [Nushell](https://www.nushell.sh/) 0.90+
- [Data Contract CLI](https://cli.datacontract.com/) 0.10+
- [Kestra](https://kestra.io/) (for orchestration)

## License

MIT
