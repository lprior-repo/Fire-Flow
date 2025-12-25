# bitter-truth

AI-operated, contract-driven orchestration.

```
┌────────────────────────────────────────────┐
│           HUMAN (Architect)                │
│                                            │
│  Writes: Contracts, Prompts                │
│  Never writes: Nushell                     │
└─────────────────────┬──────────────────────┘
                      │ Intent
                      ▼
┌────────────────────────────────────────────┐
│              DATA CONTRACT                 │
│            (Source of Truth)               │
│                                            │
│  The law. Draconian validation.            │
└─────────────────────┬──────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────┐
│            OPENCODE (Compiler)             │
│                                            │
│  Compiles intent → Nushell                 │
│  Self-heals on contract failure            │
└─────────────────────┬──────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────┐
│           KESTRA (Orchestrator)            │
│                                            │
│  Generate → Gate → Pass or Self-Heal       │
│  Escalate after N failures                 │
└─────────────────────┬──────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────┐
│           NUSHELL (Execution)              │
│                                            │
│  Structured data in/out                    │
│  AI-authored exclusively                   │
└────────────────────────────────────────────┘
```

## The 3 Laws

See [LAWS.md](bitter-truth/LAWS.md) for full doctrine.

| Law | Rule | Violation |
|-----|------|-----------|
| 1. No-Human Zone | AI writes all Nushell | Human cognitive overload |
| 2. Contract is Law | Draconian validation, self-heal | Hallucinated destruction |
| 3. Ejection Seat | Rosetta Stone for Python | Vendor lock-in |

## Why Nushell?

**AI Goal**: "Filter rows where CPU > 80%"

```bash
# Bash: Text parsing, AI gets wrong 20% of time
top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}'

# Nushell: Structured data, AI gets right 99% of time
sys | get cpu | where usage > 80
```

For an AI operator, structured data is the path of least resistance.

## Structure

```
bitter-truth/
├── LAWS.md                      # The doctrine
├── contracts/                   # DataContract YAML (humans write this)
│   ├── common.yaml
│   └── tools/echo.yaml
├── tools/                       # Nushell scripts (AI writes this)
│   └── echo.nu
├── prompts/
│   └── rosetta-stone.md         # Nushell → Python migration
└── kestra/flows/
    └── contract-loop.yml        # The workflow
```

## The Workflow

```yaml
loop:
  - generate     # AI compiles intent → Nushell
  - execute      # Run the script
  - gate         # Validate against contract
  - check        # Pass? Done : Self-heal
  - escalate     # After N failures → fix PROMPT not CODE
```

## Quick Start

```bash
# Install
uv tool install datacontract-cli
pacman -S nushell

# Validate contract
datacontract lint bitter-truth/contracts/tools/echo.yaml

# Run AI-generated tool
echo '{"message": "hello"}' | nu bitter-truth/tools/echo.nu
```

## Requirements

- [Nushell](https://www.nushell.sh/) - Structured shell
- [Data Contract CLI](https://cli.datacontract.com/) - Schema validation
- [Kestra](https://kestra.io/) - Orchestration
- [OpenCode](https://opencode.ai/) - AI compilation
