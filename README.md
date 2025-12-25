# bitter-truth

AI-operated, contract-driven orchestration.

```
Human Intent
     ↓
 [Contract]     ← Law 3: We set the standard
     ↓
 [Kestra]       ← Law 4: Orchestrator runs everything
     ↓
 [OpenCode]     ← Law 1: AI writes all Nushell
     ↓
 [Nushell]      ← Structured execution
     ↓
 [Validate]     ← Law 2: Contract is the law
     ↓
   Done
```

## The 4 Laws

| Law | Rule |
|-----|------|
| 1 | AI writes all Nushell |
| 2 | Contract validates all output |
| 3 | Human sets standard, AI hits it |
| 4 | Orchestrator runs everything |

See [LAWS.md](bitter-truth/LAWS.md) for full doctrine.

## Why Nushell?

```bash
# Bash: AI gets wrong 20% of time
top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}'
```

```nu
# Nushell: AI gets right 99% of time
sys | get cpu | where usage > 80
```

Structured data is the path of least resistance for AI.

## Structure

```
bitter-truth/
├── LAWS.md              # The 4 Laws
├── contracts/           # Humans write (Law 3)
├── tools/               # AI writes (Law 1)
└── kestra/flows/        # Runs everything (Law 4)
```

## Quick Start

```bash
# Install
uv tool install datacontract-cli
pacman -S nushell

# Validate contract (Law 2)
datacontract lint bitter-truth/contracts/tools/echo.yaml

# Run tool
echo '{"message": "hello"}' | nu bitter-truth/tools/echo.nu
```
