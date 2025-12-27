# Fire-Flow Project Instructions

## RULE 1: NEVER PLAINTEXT CREDENTIALS

**CRITICAL**: Never echo, print, or display credentials in plaintext. Always use secure methods.

## Windmill Configuration

- **URL**: http://localhost:8000
- **CLI**: `wmill` - Windmill CLI for sync and deploy
- **Namespace**: `f/fire-flow`

## bitter-truth System

This is a contract-driven AI code generation system with self-healing:

### The 4 Laws

1. **No-Human Zone**: AI writes all code, humans write contracts
2. **Contract is Law**: Validation is draconian, self-heal on failure
3. **We Set the Standard**: Human defines target, AI hits it
4. **Orchestrator Runs Everything**: Windmill owns execution

### Flow Pattern

```
Generate -> Gate -> Pass or Self-Heal -> Escalate after N failures
```

### Key Components

- `bitter-truth/tools/generate.nu` - AI generates code from contract
- `bitter-truth/tools/run-tool.nu` - Execute generated tools
- `bitter-truth/tools/validate.nu` - Contract validation via datacontract-cli
- `bitter-truth/tools/gate1.nu` - Syntax/lint/type validation
- `bitter-truth/contracts/` - DataContract definitions
- `windmill/f/fire-flow/` - Windmill flows and scripts (Rust only)

### Prerequisites

- `nu` (Nushell) - script execution
- `opencode` - AI code generation
- `datacontract` - contract validation
- `wmill` - Windmill CLI
- Windmill (running on :8000) - orchestration

### Windmill Commands

```bash
# Sync local to remote
wmill sync push --yes

# Deploy a specific flow
wmill flow push ./f/fire-flow/contract_loop f/fire-flow/contract_loop

# Pull remote to local
wmill sync pull
```

## Using bv as an AI sidecar

bv is a graph-aware triage engine for Beads projects (.beads/beads.jsonl). Instead of parsing JSONL or hallucinating graph traversal, use robot flags for deterministic, dependency-aware outputs with precomputed metrics (PageRank, betweenness, critical path, cycles, HITS, eigenvector, k-core).

**Scope boundary:** bv handles *what to work on* (triage, priority, planning). For agent-to-agent coordination (messaging, work claiming, file reservations), use [MCP Agent Mail](https://github.com/Dicklesworthstone/mcp_agent_mail).

**CRITICAL: Use ONLY `--robot-*` flags. Bare `bv` launches an interactive TUI that blocks your session.**

### The Workflow: Start With Triage

**`bv --robot-triage` is your single entry point.** It returns everything you need in one call:
- `quick_ref`: at-a-glance counts + top 3 picks
- `recommendations`: ranked actionable items with scores, reasons, unblock info
- `quick_wins`: low-effort high-impact items
- `blockers_to_clear`: items that unblock the most downstream work
- `project_health`: status/type/priority distributions, graph metrics
- `commands`: copy-paste shell commands for next steps

```bash
bv --robot-triage        # THE MEGA-COMMAND: start here
bv --robot-next          # Minimal: just the single top pick + claim command
```

### Other Commands

**Planning:**
| Command | Returns |
|---------|---------|
| `--robot-plan` | Parallel execution tracks with `unblocks` lists |
| `--robot-priority` | Priority misalignment detection with confidence |

**Graph Analysis:**
| Command | Returns |
|---------|---------|
| `--robot-insights` | Full metrics: PageRank, betweenness, HITS, critical path, cycles |
| `--robot-label-health` | Per-label health: `health_level`, `velocity_score`, `staleness` |
| `--robot-label-flow` | Cross-label dependency: `flow_matrix`, `bottleneck_labels` |

**History & Change Tracking:**
| Command | Returns |
|---------|---------|
| `--robot-history` | Bead-to-commit correlations |
| `--robot-diff --diff-since <ref>` | Changes since ref |

### jq Quick Reference

```bash
bv --robot-triage | jq '.quick_ref'                        # At-a-glance summary
bv --robot-triage | jq '.recommendations[0]'               # Top recommendation
bv --robot-plan | jq '.plan.summary.highest_impact'        # Best unblock target
```

**Use bv instead of parsing beads.jsonl**—it computes PageRank, critical paths, cycles, and parallel tracks deterministically.
