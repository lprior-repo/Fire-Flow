# bitter-truth

AI-operated, contract-driven orchestration.

```
Human Intent (English)
        ↓
   [OpenCode]     ← AI as Compiler
        ↓
Nushell Script    ← Machine Code for AI
        ↓
   [Kestra]       ← CPU (Scheduling)
        ↓
Structured Output
        ↓
 [DataContract]   ← Memory Protection (Validation)
```

## The 2 Laws

See [LAWS.md](bitter-truth/LAWS.md) for full doctrine.

| Law | Rule | Violation |
|-----|------|-----------|
| 1. No-Human Zone | AI writes all Nushell | Human cognitive overload |
| 2. Contract is Law | Draconian validation, self-heal | Hallucinated destruction |

## Why Nushell?

**AI Goal**: "Filter rows where CPU > 80%"

```bash
# Bash: Text parsing, AI gets wrong 20% of time
top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}'
```

```nu
# Nushell: Structured data, AI gets right 99% of time
sys | get cpu | where usage > 80
```

For an AI operator, structured data is the path of least resistance.

## Structure

```
bitter-truth/
├── LAWS.md                  # The doctrine
├── contracts/               # DataContract YAML (humans write this)
│   ├── common.yaml
│   └── tools/echo.yaml
├── tools/                   # Nushell scripts (AI writes this)
│   └── echo.nu
└── kestra/flows/
    └── contract-loop.yml    # The workflow
```

## The Workflow

```
Generate → Gate → Pass or Self-Heal → Escalate
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

## Requirements

- [Nushell](https://www.nushell.sh/)
- [Data Contract CLI](https://cli.datacontract.com/)
- [Kestra](https://kestra.io/)
- [OpenCode](https://opencode.ai/)
