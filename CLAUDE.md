# Fire-Flow Project Instructions

## ═══════════════════════════════════════════════════════════════════════════════
## 🔥 KESTRA API - HOW TO CALL IT (OSS Edition)
## ═══════════════════════════════════════════════════════════════════════════════

**BASE URL**: `http://localhost:4200`
**TENANT**: `main` (OSS always uses `main` as tenant)
**AUTH**: Basic Auth via `~/.netrc` or `-u user:pass`

Check docs and Mem0 and Beads for more info please



### 🎯 CORE ENDPOINTS

```bash
# List/Search Flows
GET  /api/v1/main/flows/search?namespace={namespace}
GET  /api/v1/main/flows/{namespace}/{id}

# Deploy Flow
PUT  /api/v1/main/flows/{namespace}/{id}
     Content-Type: application/x-yaml
     Body: <flow YAML>

# Trigger Execution
POST /api/v1/main/executions/{namespace}/{flowId}
     -F input1=value1 -F input2=value2

# Get Execution Status
GET  /api/v1/main/executions/{executionId}

# Get Execution Logs
GET  /api/v1/main/executions/{executionId}/logs
```

### 💡 EXAMPLES

```bash
# Setup auth (run once)
echo "machine localhost
  login $(pass kestra/username)
  password $(pass kestra/password)" > ~/.netrc
chmod 600 ~/.netrc

# Search flows in 'bitter' namespace
curl --netrc 'http://localhost:4200/api/v1/main/flows/search?namespace=bitter'

# Deploy a flow
curl -X PUT --netrc -H "Content-Type: application/x-yaml" \
  --data-binary '@flow.yml' \
  'http://localhost:4200/api/v1/main/flows/bitter/contract-loop'

# Trigger execution
curl -X POST --netrc \
  -F contract="/path/to/contract.yaml" \
  -F task="Create echo tool" \
  -F input_json="{}" \
  'http://localhost:4200/api/v1/main/executions/bitter/contract-loop'
```

### 📚 Reference
- [Kestra OSS API Docs](https://kestra.io/docs/api-reference/open-source)
- [API Guide](https://kestra.io/docs/how-to-guides/api)

## ═══════════════════════════════════════════════════════════════════════════════

## RULE 1: NEVER PLAINTEXT CREDENTIALS

**CRITICAL**: Never echo, print, or display credentials in plaintext. Always use secure methods:

### Credential Access Patterns

```bash
# Kestra credentials are in pass
# Username: pass kestra/username
# Password: pass kestra/password

# ALWAYS use netrc or credential helpers - NEVER inline creds in commands
```

### Secure Kestra API Access

Create `~/.netrc` with proper permissions for Kestra access:
```
machine localhost
  login <email>
  password <password>
```

Or use a nushell helper that reads from pass:

```nu
# In ~/.config/nushell/scripts/kestra.nu
def kestra-api [endpoint: string, --method: string = "GET", --data: string = ""] {
    let user = (pass kestra/username | str trim)
    let pass = (pass kestra/password | str trim)
    let auth = [$user, $pass] | str join ":"
    let base64_auth = ($auth | encode base64)

    if $data == "" {
        http get -H ["Authorization" $"Basic ($base64_auth)"] $"http://localhost:4200($endpoint)"
    } else {
        http post -H ["Authorization" $"Basic ($base64_auth)" "Content-Type" "application/json"] $"http://localhost:4200($endpoint)" $data
    }
}
```

## Kestra Configuration

- **URL**: http://localhost:4200
- **Namespace**: `bitter`
- **Main Flow**: `contract-loop`
- **Credentials**: Stored in `pass` at:
  - `kestra/username` - email address
  - `kestra/password` - password

## bitter-truth System

This is a contract-driven AI code generation system with self-healing:

### The 4 Laws

1. **No-Human Zone**: AI writes all Nushell, humans write contracts
2. **Contract is Law**: Validation is draconian, self-heal on failure
3. **We Set the Standard**: Human defines target, AI hits it
4. **Orchestrator Runs Everything**: Kestra owns execution

### Flow Pattern

```
Generate -> Gate -> Pass or Self-Heal -> Escalate after N failures
```

### Key Components

- `bitter-truth/tools/generate.nu` - AI generates Nushell from contract
- `bitter-truth/tools/run-tool.nu` - Execute generated tools
- `bitter-truth/tools/validate.nu` - Contract validation via datacontract-cli
- `bitter-truth/tools/echo.nu` - Proof of concept echo tool
- `bitter-truth/contracts/` - DataContract definitions
- `bitter-truth/kestra/flows/` - Kestra orchestration flows

### Prerequisites

- `nu` (Nushell) - script execution
- `opencode` - AI code generation
- `datacontract` - contract validation
- Kestra (running on :4200) - orchestration

### Running the Flow

```bash
# Deploy flow
kestra-api "/api/v1/flows" --method PUT --data "$(cat bitter-truth/kestra/flows/contract-loop.yml)"

# Trigger execution
kestra-api "/api/v1/executions/bitter/contract-loop" --method POST --data '{
  "contract": "/path/to/contract.yaml",
  "task": "description of what to generate",
  "input_json": "{}",
  "max_attempts": 5,
  "tools_dir": "/path/to/bitter-truth/tools"
}'
```

## Monitoring

- Kestra UI: http://localhost:4200
- Execution logs visible in task outputs
- All tools log structured JSON to stderr
- Use `tools/kestra-ws` Rust CLI for AI-friendly log streaming

## Kestra API Reference

**OpenAPI Spec**: `docs/kestra-openapi.yaml` (161 endpoints)
**API Docs**: `docs/kestra-api.md` (progressive disclosure)

### Quick Reference

| Operation | Method | Endpoint |
|-----------|--------|----------|
| Trigger Flow | POST | `/api/v1/executions/{ns}/{flowId}` |
| Get Execution | GET | `/api/v1/executions/{execId}` |
| Get Logs | GET | `/api/v1/logs/{execId}` |
| Stream Logs (SSE) | GET | `/api/v1/logs/{execId}/follow` |
| Deploy Flow | PUT | `/api/v1/flows/{ns}/{id}` |
| Webhook Trigger | POST | `/api/v1/executions/webhook/{ns}/{flowId}/{key}` |

### Key Endpoints

- **Flows**: `/api/v1/{tenant}/flows` - CRUD, validate, graph, dependencies
- **Executions**: `/api/v1/{tenant}/executions` - trigger, pause, resume, kill, restart
- **Logs**: `/api/v1/{tenant}/logs` - search, download, follow (SSE)
- **Namespaces**: `/api/v1/{tenant}/namespaces` - files, KV store
- **Plugins**: `/api/v1/plugins` - schemas, icons, documentation

### Execution States

| State | Terminal | Description |
|-------|----------|-------------|
| CREATED | No | Just created |
| RUNNING | No | In progress |
| SUCCESS | Yes | Completed successfully |
| FAILED | Yes | One or more tasks failed |
| KILLED | Yes | Manually stopped |

## Using bv as an AI sidecar

bv is a graph-aware triage engine for Beads projects (.beads/beads.jsonl). Instead of parsing JSONL or hallucinating graph traversal, use robot flags for deterministic, dependency-aware outputs with precomputed metrics (PageRank, betweenness, critical path, cycles, HITS, eigenvector, k-core).

**Scope boundary:** bv handles *what to work on* (triage, priority, planning). For agent-to-agent coordination (messaging, work claiming, file reservations), use [MCP Agent Mail](https://github.com/Dicklesworthstone/mcp_agent_mail).

**⚠️ CRITICAL: Use ONLY `--robot-*` flags. Bare `bv` launches an interactive TUI that blocks your session.**

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
| `--robot-insights` | Full metrics: PageRank, betweenness, HITS (hubs/authorities), eigenvector, critical path, cycles, k-core, articulation points, slack |
| `--robot-label-health` | Per-label health: `health_level` (healthy\|warning\|critical), `velocity_score`, `staleness`, `blocked_count` |
| `--robot-label-flow` | Cross-label dependency: `flow_matrix`, `dependencies`, `bottleneck_labels` |
| `--robot-label-attention [--attention-limit=N]` | Attention-ranked labels by: (pagerank × staleness × block_impact) / velocity |

**History & Change Tracking:**
| Command | Returns |
|---------|---------|
| `--robot-history` | Bead-to-commit correlations: `stats`, `histories` (per-bead events/commits/milestones), `commit_index` |
| `--robot-diff --diff-since <ref>` | Changes since ref: new/closed/modified issues, cycles introduced/resolved |

**Other Commands:**
| Command | Returns |
|---------|---------|
| `--robot-burndown <sprint>` | Sprint burndown, scope changes, at-risk items |
| `--robot-forecast <id\|all>` | ETA predictions with dependency-aware scheduling |
| `--robot-alerts` | Stale issues, blocking cascades, priority mismatches |
| `--robot-suggest` | Hygiene: duplicates, missing deps, label suggestions, cycle breaks |
| `--robot-graph [--graph-format=json\|dot\|mermaid]` | Dependency graph export |
| `--export-graph <file.html>` | Self-contained interactive HTML visualization |

### Scoping & Filtering

```bash
bv --robot-plan --label backend              # Scope to label's subgraph
bv --robot-insights --as-of HEAD~30          # Historical point-in-time
bv --recipe actionable --robot-plan          # Pre-filter: ready to work (no blockers)
bv --recipe high-impact --robot-triage       # Pre-filter: top PageRank scores
bv --robot-triage --robot-triage-by-track    # Group by parallel work streams
bv --robot-triage --robot-triage-by-label    # Group by domain
```

### Understanding Robot Output

**All robot JSON includes:**
- `data_hash` — Fingerprint of source beads.jsonl (verify consistency across calls)
- `status` — Per-metric state: `computed|approx|timeout|skipped` + elapsed ms
- `as_of` / `as_of_commit` — Present when using `--as-of`; contains ref and resolved SHA

**Two-phase analysis:**
- **Phase 1 (instant):** degree, topo sort, density — always available immediately
- **Phase 2 (async, 500ms timeout):** PageRank, betweenness, HITS, eigenvector, cycles — check `status` flags

**For large graphs (>500 nodes):** Some metrics may be approximated or skipped. Always check `status`.

### jq Quick Reference

```bash
bv --robot-triage | jq '.quick_ref'                        # At-a-glance summary
bv --robot-triage | jq '.recommendations[0]'               # Top recommendation
bv --robot-plan | jq '.plan.summary.highest_impact'        # Best unblock target
bv --robot-insights | jq '.status'                         # Check metric readiness
bv --robot-insights | jq '.Cycles'                         # Circular deps (must fix!)
bv --robot-label-health | jq '.results.labels[] | select(.health_level == "critical")'
```

**Performance:** Phase 1 instant, Phase 2 async (500ms timeout). Prefer `--robot-plan` over `--robot-insights` when speed matters. Results cached by data hash.

**Use bv instead of parsing beads.jsonl**—it computes PageRank, critical paths, cycles, and parallel tracks deterministically.

---

## Development

- Edit flows in `bitter-truth/kestra/flows/`
- Redeploy with PUT to `/api/v1/flows/{namespace}/{id}`
- All shell tasks use `taskRunner.type: io.kestra.plugin.core.runner.Process` (no Docker)

## Tooling

### Nushell Helper (`tools/kestra.nu`)
```bash
nu tools/kestra.nu flow bitter contract-loop      # Get flow
nu tools/kestra.nu run bitter contract-loop '{}'  # Trigger
nu tools/kestra.nu status {exec-id}                       # Status
```

### Rust CLI (`tools/kestra-ws`)
```bash
kestra-ws poll --execution-id {id} --format json  # JSON output for AI
kestra-ws watch --namespace bitter                 # Watch executions
```

Build: `cargo build --release --manifest-path=tools/kestra-ws/Cargo.toml`
