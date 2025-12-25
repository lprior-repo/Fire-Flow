# bitter-truth

Contract-driven AI orchestration.

```
┌────────────────────────────────────────────┐
│              DATA CONTRACT                 │
│           (Source of Truth)                │
│                                            │
│  Defines what success looks like (YAML)    │
└─────────────────────┬──────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────┐
│                 KESTRA                     │
│              (Orchestrator)                │
│                                            │
│  Loop: Generate → Validate → Pass/Retry   │
└─────────────────────┬──────────────────────┘
                      │
        ┌─────────────┼─────────────┐
        ▼             ▼             ▼
   ┌─────────┐   ┌─────────┐   ┌─────────┐
   │ OpenCode│   │  Gate   │   │  Gate   │
   │   (AI)  │   │Contract │   │  Tests  │
   │         │   │         │   │         │
   │Generate │   │Validate │   │  Run    │
   └─────────┘   └─────────┘   └─────────┘
       ↑              │             │
       └──────────────┴─────────────┘
              Feedback Loop
```

## The Pattern

```yaml
loop:
  - generate    # AI produces output (non-deterministic)
  - gate        # Validate against contract (deterministic)
  - gate        # Run tests (deterministic)
  - check       # All passed? Done : Retry with feedback
```

**Contract is God. AI is a worker.**

## Structure

```
bitter-truth/
├── contracts/           # Data Contract YAML (source of truth)
│   ├── common.yaml      # Shared types
│   └── tools/
│       └── echo.yaml    # Example contract
├── tools/
│   └── echo.nu          # Nushell tool
└── kestra/flows/
    └── contract-loop.yml  # THE workflow
```

## Quick Start

```bash
# Install
uv tool install datacontract-cli
pacman -S nushell

# Validate contract
datacontract lint bitter-truth/contracts/tools/echo.yaml

# Run tool
echo '{"message": "hello"}' | nu bitter-truth/tools/echo.nu
```

## The Workflow

```yaml
# kestra/flows/contract-loop.yml
inputs:
  - contract: path/to/contract.yaml
  - task: "What the AI should generate"

tasks:
  - generate    # opencode -p "..."
  - gate        # datacontract test
  - gate        # nu test.nu
  - check       # pass or retry with feedback
```

## Requirements

- [Nushell](https://www.nushell.sh/)
- [Data Contract CLI](https://cli.datacontract.com/)
- [Kestra](https://kestra.io/)
- [OpenCode](https://opencode.ai/)
