---
name: fire-flow-orchestration
description: Manages Fire-Flow's contract-driven AI code generation using bitter-truth, Kestra, Nushell, OpenCode, Beads, and MCP servers (mem0, Graphiti, Codanna). Use for code generation, validation, orchestration, task tracking, and documentation lookup.
---

# Fire-Flow Agent Operations Guide

## Quick Navigation

- [Complete Codebase Index](#complete-codebase-index)
- [Core Systems](#core-systems)
- [bitter-truth 4 Laws](#bitter-truth-4-laws)
- [Tool Selection](#tool-selection)
- [Kestra Best Practices](#kestra-best-practices)
- [MCP Servers](#mcp-servers)
- [Codanna Usage](#codanna-usage)
- [Validation](#validation)
- [Quick Reference](#quick-reference)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## Complete Codebase Index

### Quick Navigation
```
Fire-Flow/
├── AGENTS.md                    # This file - Agent operations guide
├── CLAUDE.md                    # Claude-specific instructions
├── bitter-truth/                # Contract-driven AI code generation
├── tools/                       # Helper tools (kestra-ws, llm-cleaner)
├── docs/
│   ├── files/                  # Core documentation
│   └── kestra-docs/            # Official Kestra docs
└── .beads/                      # Beads task management
```

**Search Patterns**:
- **bitter-truth contracts**: `bitter-truth/contracts/`
- **Nushell validation**: `docs/files/LANG_NUSHELL.md`
- **Kestra flows**: `bitter-truth/kestra/flows/`
- **Kestra API**: `docs/kestra-openapi.yaml` (161 endpoints)
- **Code patterns**: Use `codanna_semantic_search_with_context()`
- **Dependencies**: Use `codanna_analyze_impact()`

### Detailed File Locations

**Documentation** (`docs/files/`):
- `README.md` - Project overview
- `CORE.md` - AI code validator prime directive
- `SHORTCUTS.md` - Shortcut taxonomy (S001-S030)
- `LANG_*.md` - Language-specific validation guides
  - `LANG_NUSHELL.md` - Nushell (NU001-NU010)
  - `LANG_KESTRA.md` - Kestra (KE001-KE010)
  - `LANG_RUST.md` - Rust
  - `LANG_GO.md` - Go
  - `LANG_GLEAM.md` - Gleam/BEAM
- `0*-8-*.md` - Project planning documents

**bitter-truth**:
- `LAWS.md` - The 4 Laws
- `ARCHITECTURE.md` - Kestra/Nushell separation
- `contracts/` - Humans write (Law 3)
- `tools/` - AI writes (Law 1)
  - `generate.nu` - AI code generation
  - `validate.nu` - Contract validation
  - `run-tool.nu` - Tool execution
- `kestra/flows/` - Kestra orchestrates (Law 4)

**Kestra**:
- `docs/kestra-docs/INDEX.md` - Full documentation
- `docs/kestra-openapi.yaml` - **Complete OpenAPI spec (161 endpoints)**

**Tools**:
- `tools/kestra-ws/` - Rust WebSocket client for Kestra
- `tools/llm-cleaner/` - Rust LLM output cleaner
- `tools/kestra.nu` - Nushell helper

**Codanna Index**: 117 symbols, 222 relationships, semantic search enabled
- Key indexed: `tools/kestra-ws/src/lib.rs`, `tools/llm-cleaner/src/main.rs`
- Search: `codanna_semantic_search_with_context()`, `codanna_search_symbols()`
- Analysis: `codanna_analyze_impact()`, `codanna_find_callers()`

## Core Systems

### bitter-truth
**Purpose**: Contract-driven AI code generation with draconian validation.

**Architecture**: Human → Contract → Kestra → OpenCode → Nushell → Validation

**Key Files**:
- Contracts: `bitter-truth/contracts/` - Humans write (Law 3)
- Tools: `bitter-truth/tools/` - AI writes (Law 1)
- Flows: `bitter-truth/kestra/flows/` - Kestra orchestrates (Law 4)
- Laws: `bitter-truth/LAWS.md`
- Architecture: `bitter-truth/ARCHITECTURE.md`

### Kestra
**Purpose**: Workflow orchestration - owns loops, retries, state, decisions.

**Base**: `http://localhost:4201` | **Namespace**: `main`

**Complete OpenAPI Spec**: `docs/kestra-openapi.yaml` (161 endpoints)

**Key API**:
```
GET  /api/v1/main/flows/{namespace}/{id}
PUT  /api/v1/main/flows/{namespace}/{id}
POST /api/v1/main/executions/{namespace}/{flowId}
GET  /api/v1/main/executions/{executionId}/logs
```

**Key Components**:
- `tools/kestra-ws/` - Rust client for log streaming and execution monitoring
- Format functions (`format_xml`) - AI-friendly log formatting
- Credential providers (`EnvProvider`, `PassProvider`) - Secure credential retrieval

**Documentation**:
- Official: `docs/kestra-docs/INDEX.md`
- OpenAPI spec: `docs/kestra-openapi.yaml` - Complete API reference

### OpenCode Multi-Agent System
**Location**: `~/.opencode`

**10 Agents**: senior-code-reviewer, api-designer, backend-developer, golang-pro, gleam-pro, fractal-orchestrator, architect-reviewer, qa-expert, refactoring-specialist, workflow-orchestrator

**Skills**: On-demand loading, including `parallel-arch-review` for 24+ agent coordination

### Beads Task Management
**Purpose**: Graph-aware task tracking with dependency metrics.

**Commands**: `bv --robot-triage` (single entry point)

## bitter-truth 4 Laws

### Law 1: No-Human Zone
**Rule**: Humans never write Nushell scripts. AI generates all `.nu` files.

### Law 2: Contract is Law
**Rule**: DataContract validation must be draconian. Only safeguard since AI writes all logic.

**Validation Flow**:
1. Generate code from contract
2. Run `datacontract test --server local <contract.yaml>`
3. If passes → Success
4. If fails → Self-heal (retry with feedback)
5. After 5 failures → Fix **prompt**, not code

### Law 3: We Set the Standard
**Rule**: Humans define target. AI figures out how to hit it.

**Pattern**:
```
Human: "I need X with Y constraints"
        ↓
   [Contract]  ← The standard
        ↓
   [AI Loop]   ← bitter-truth finds path
        ↓
   [Output]    ← Meets standard or fails
```

### Law 4: Orchestrator Runs Everything
**Rule**: Kestra owns execution. Nothing runs outside orchestration.

- No ad-hoc scripts in production
- Every execution is tracked, timed, retried
- Kestra is single source of truth

**Full Documentation**: `bitter-truth/LAWS.md`, `bitter-truth/ARCHITECTURE.md`

## Tool Selection

### When to Use bitter-truth
- Nushell tool generation from contracts
- Contract validation enforcement
- Self-healing workflows (up to 5 attempts)

**Pattern**: Contract → Kestra → AI → Nushell → Validation

### When to Use OpenCode
- Complex code generation requiring specialized knowledge
- Multi-language projects (Go, Rust, Gleam, Nushell)
- Architecture reviews and refactoring
- Testing strategies and QA planning

**Invocation**: `opencode run -m <model> "<prompt>"` | List models: `opencode models`

### When to Use Kestra
- Orchestrating multi-step workflows
- Managing retries and error handling
- Parallel task execution
- Scheduled or event-triggered workflows

### When to Use Nushell
- Structured data processing
- Business logic in tools

**Patterns**: See `docs/files/LANG_NUSHELL.md`

## Kestra Best Practices

### Workflow Design
- Use explicit namespaces (hierarchical by domain)
- Add descriptions in flow metadata
- Use descriptive IDs (`extract_orders`, not `task1`)
- Timeouts on long tasks - Prevent hanging
- Retry external calls (HTTP, DB, API) with exponential backoff
- Parallel independent tasks - Use `Parallel` for concurrent execution
- Handle errors properly - Add `errors` section

### Security
- Never hardcode secrets - Always use `secret('KEY_NAME')`
- Sensitive values not in `variables` block
- Least privilege - Use scoped secrets

### Configuration
- Environment variables via `vars:` - Reference as `{{ vars.name }}`
- Secrets via `secret()` - Never expose in logs
- Namespace files - Use `namespaceFiles.enabled: true`
- Container images - Specify `containerImage` for reproducibility

### Triggers
- Schedules need `timezone` - Always specify explicitly
- Flow triggers need `conditions` - Filter by namespace, status
- Avoid polling - Prefer triggers over scheduled polling

### Output Management
- Fetch outputs - Set `fetch: true` or `store: true`
- Reference outputs - Use `outputs.taskId.property`
- Input files - Use `inputFiles:` mapping
- Output files - Use `outputFiles:` for artifacts

## MCP Servers

### mem0 - Long-Term Memory
**Purpose**: Persistent memory for preferences, decisions, solutions.

**Operations**:
```python
mem0_add_memories(text="User prefers Gleam's pipe operator")
mem0_search_memory(query="Gleam preferences")
mem0_list_memories()
mem0_delete_memories(memory_ids=["id1"])
```

**When to Use**:
- Session start - Search for project context
- Learn user preferences - Save immediately
- Make architecture decisions - Save with rationale
- Solve bugs - Save problem → solution → prevention
- Task complete - Consolidate learnings

### Graphiti - Knowledge Graph Memory
**Purpose**: Graph-based memory for entity relationships and facts.

**Operations**:
```python
graphiti_add_memory(name="Architecture", episode_body='{"components": ["Kestra"]}', source="json")
graphiti_search_nodes(query="Kestra workflow", max_nodes=10)
graphiti_search_memory_facts(query="validation failures", max_facts=10)
graphiti_analyze_impact(symbol_name="format_xml", max_depth=3)
```

**When to Use**:
- Track relationships between components
- Understanding dependency graphs
- Analyzing impact of changes
- Finding related concepts

### Codanna - Code Intelligence
**Purpose**: Codebase search, dependency analysis, semantic code search.

**Current Index**: 117 symbols, 222 relationships, semantic search enabled (AllMiniLML6V2)

**Key Operations**:
```python
# Semantic search with context
codanna_semantic_search_with_context(query="Kestra workflow automation", limit=5, lang="rust")

# Search symbols by name
codanna_find_symbol(name="format_xml")
codanna_search_symbols(query="orchestrator", limit=10)

# Analyze dependencies
codanna_find_callers(function_name="format_xml")
codanna_get_calls(symbol_id=46)
codanna_analyze_impact(symbol_name="ExecutionWatcher", max_depth=3)

# Get index info
codanna_get_index_info()
```

**When to Use**:
- Finding functions/classes that call specific code
- Understanding dependency relationships
- Semantic search for code patterns
- Impact analysis before refactoring
- Finding similar implementations

**Key Indexed Components**:
- `tools/kestra-ws/` - Kestra WebSocket client
- `tools/llm-cleaner/` - LLM output cleaning
- Format functions, credential providers, execution watchers

## Codanna Usage

### Finding Code
```python
# Find exact symbol
codanna_find_symbol(name="format_xml")

# Search with fuzzy matching
codanna_search_symbols(query="orchestrator", limit=10)

# Search by intent
codanna_semantic_search_with_context(query="Kestra WebSocket client", limit=5)

# Search language-specific
codanna_search_symbols(query="workflow", lang="rust", limit=10)
```

### Analyzing Dependencies
```python
# What calls this function
codanna_find_callers(function_name="format_xml")
codanna_find_callers(symbol_id=46)

# What this function calls
codanna_get_calls(symbol_id=46)

# All relationships (calls, types, composition)
codanna_analyze_impact(symbol_name="format_xml", max_depth=3)
codanna_analyze_impact(symbol_id=46)
```

### Understanding Code Structure
```python
# Index info
codanna_get_index_info()
# Returns: symbols, relationships, kinds, semantic search status
```

## Validation

### Core Validator (`docs/files/CORE.md`)
**Prime Directive**: Trust nothing. Verify everything.

**Validation Sequence** (stop at any BLOCKING failure):
```
P1: Parse Request    → Extract requirements checklist
P2: Completeness     → [BLOCKING] No placeholders, stubs, truncation
P3: Requirements     → [BLOCKING] Code does what was asked
P4: Correctness      → Logic, edge cases, error handling
P5: Hallucinations   → [BLOCKING] APIs/methods actually exist
P6: Tests            → If present, verify they're meaningful
P7: Quality          → Non-blocking suggestions
```

**Verdicts**: PASS, NEEDS_WORK, REJECT

### Shortcut Taxonomy (`docs/files/SHORTCUTS.md`)

| ID Range | Category | Examples |
|----------|----------|----------|
| S001-S007 | Incompleteness | TODO, stubs, truncation |
| S008-S012 | Logic | Happy path only, edge cases ignored |
| S013-S016 | Hallucination | Fake APIs, wrong method names |
| S017-S020 | Requirement Drift | Wrong problem, scope reduction |
| S021-S025 | Pseudo-Tests | Tautologies, mock abuse |
| S026-S030 | Quality | God functions, leaks |

### Language-Specific Validation

**Nushell** (`docs/files/LANG_NUSHELL.md`): NU001-NU010
- Common shortcuts and hallucinations
- Validation checklist for structured data, interpolation, error handling

**Kestra** (`docs/files/LANG_KESTRA.md`): KE001-KE010
- Workflow anti-patterns and hallucinations
- Validation checklist for flows, tasks, triggers, templates

## Vibe Kanban & AI Workflow Management

### Vibe Kanban (Open-Source AI Workflow)

**URL**: https://www.vibekanban.com/
**GitHub**: https://github.com/BloopAI/vibe-kanban
**Purpose**: Visual task management that orchestrates AI coding agents in parallel

**Key Features**:
- **Visual Kanban Board** - Trello-like interface for managing AI agent tasks
- **Multi-Agent Support** - Orchestrate Claude Code, Cursor, Amp, and other AI agents simultaneously
- **Git Integration** - Create branches, PRs directly from the board
- **Local Execution** - Runs completely on your machine for security
- **Agent Coordination** - Distribute work across specialized agents (code, test, review)

**Best For**:
- Startups needing visual workflow
- Teams using multiple AI tools (Cursor + Claude Code)
- Projects requiring agent coordination
- Teams wanting self-hosted data control

### Modern AI Workflow Tools

| Tool | Type | Key Features | AI Support | Scaling | Self-Hosted |
|-------|------|--------------|------------|----------|--------------|
| **Vibe Kanban** | Kanban Board | Visual, git integration, agent orchestration | ✅ | ★★★ | ✅ |
| **Linear** | Issue Tracker | Speed, issue tracking, PRs | ⚠️ Limited | ★★★★ | ❌ |
| **ClickUp** | Project Management | AI assistant, timeline | ✅ Strong | ★★★ | ❌ |
| **BloopAI/vibe-kanban** | GitHub Integration | Open-source, agent APIs | ✅ | ★★ | ✅ |
| **Trello** | Kanban Board | Established, team features | ❌ None | ★★★ | ❌ |
| **Jira** | Enterprise PM | Enterprise features, integrations | ❌ None | ★★★★★ | ❌ |

### Fire-Flow Integration with Vibe Kanban

**Pattern 1: bitter-truth → Vibe Kanban → Cursor**
```
Contract Creation (bitter-truth)
    ↓ create card
Vibe Kanban Task
    ↓ assign to agent
Cursor Generates Code
    ↓ creates PR
    ↓ move to review
Code Review
    ↓ deploy
```

**Pattern 2: Multi-Agent Coordination**
```
Vibe Kanban Board
    ├─ Card 1: Backend (Cursor)
    ├─ Card 2: Frontend (Claude Code)
    ├─ Card 3: Tests (bitter-truth)
    └─ Card 4: Deployment (Kestra)
         ↓ (parallel execution)
All agents work simultaneously
         ↓ (merge PRs)
Deployment
```

### Scaling Strategies (10x Multiplier)

**Single Developer → Small Team (3-5x)**
- Vibe Kanban for visual task tracking
- Cursor + local LLM for AI generation
- Shared bitter-truth contract library
- Distributed agent execution

**Small Team → Medium Team (5-10x)**
- Vibe Kanban with agent routing rules
- Multiple specialized agents (backend, frontend, testing)
- Kestra cluster for parallel execution
- Automated quality gates

**Medium Team → Large Team (10-20x)**
- Vibe Kanban enterprise features
- Agent pool with load balancing
- Kestra multi-environment (dev/staging/prod)
- Codanna for semantic code search across teams
- Beads for cross-team dependency tracking

**Large Team → Enterprise (20-50x)**
- Custom Vibe Kanban instances with integrations
- Multi-agent coordination with specialized roles
- Kestra distributed execution
- Centralized mem0/Graphiti knowledge graph
- Automated documentation generation
- Real-time observability and alerting

### Workflow Tools Comparison

**Traditional Tools** (Trello, Jira):
- ✅ Established, enterprise-ready
- ✅ Team collaboration features
- ❌ No AI integration
- ❌ No agent orchestration
- ❌ Cloud-dependent (data control issues)

**AI-Native Tools** (Vibe Kanban, ClickUp):
- ✅ Native AI agent support
- ✅ Multi-agent coordination
- ✅ Git integration
- ✅ Self-hosted options
- ⚠️ Newer, smaller ecosystem

**Best Stack for 10x Scale**:
```
┌─────────────────────────────────────────────────────────────┐
│           FIRE-FLOW 10X SCALE ARCHITECTURE          │
└─────────────────────────────────────────────────────────────┘
                          │
                          ↓
    ┌─────────────────────────────────┐
    │  Vibe Kanban (Visual)      │
    │  - Task tracking           │
    │  - Agent coordination       │
    │  - Git integration         │
    └─────────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        │                     │
        ↓                     ↓
   ┌────────┐          ┌──────────┐
   │ Cursor  │          │ bitter-   │
   │ (Local  │          │ truth     │
   │  LLM)   │          │ + Kestra  │
   └─────────┘          └───────────┘
        │                     │
        └───────────┬─────────┘
                    ↓
            ┌─────────────────┐
            │  Multi-Agent    │
            │  Coordination  │
            │  (Codanna,    │
            │   mem0, etc.)  │
            └─────────────────┘
```

### Implementation Roadmap

**Phase 1: Single Developer** (Week 1-2)
- Local Cursor + Vibe Kanban setup
- bitter-truth contract templates
- Basic Kestra flows
- Beads for task tracking

**Phase 2: Small Team** (Month 1)
- Shared Vibe Kanban instance
- Team bitter-truth contract library
- Kestra cluster setup
- Codanna indexing team codebase

**Phase 3: Medium Team** (Month 2-3)
- Vibe Kanban agent routing rules
- Multi-agent coordination
- Distributed Kestra execution
- Automated quality gates

**Phase 4: Large Team** (Month 4-6)
- Enterprise Vibe Kanban features
- Load-balanced agent pool
- Multi-environment Kestra
- Centralized knowledge graph

**Phase 5: Enterprise** (Month 6-12)
- Custom integrations
- Advanced observability
- Documentation automation
- Performance optimization

## Quick Reference

### bitter-truth Commands
```bash
# Validate contract
datacontract lint bitter-truth/contracts/tools/echo.yaml

# Run tool
echo '{"message": "hello"}' | nu bitter-truth/tools/echo.nu

# Test contract locally
datacontract test --server local bitter-truth/contracts/tools/echo.yaml
```

### Kestra Commands
```bash
# Deploy flow
curl -X PUT --netrc -H "Content-Type: application/x-yaml" \
  --data-binary '@flow.yml' \
  'http://localhost:4201/api/v1/main/flows/bitter/contract-loop'

# Trigger execution
curl -X POST --netrc \
  -F contract="/path/to/contract.yaml" \
  -F task="Create echo tool" \
  'http://localhost:4201/api/v1/main/executions/bitter/contract-loop'

# Monitor with kestra-ws
kestra-ws poll --execution-id {id} --format json
kestra-ws watch --namespace bitter
```

### Nushell Patterns
```nu
# Read JSON from stdin
let input = open --raw /dev/stdin | from json

# Output JSON to stdout
{ success: true, data: $result } | to json | print

# Log JSON to stderr
{ level: "info", msg: "processing" } | to json -r | print -e

# Error handling with try/catch
let content = try { open $path } catch {
  error make { msg: $"Failed to open ($path)" }
}

# Optional access
open data.json | get config.setting? | default "fallback"

# Structured data (don't parse strings)
ls | where type == "file" | get name
```

### OpenCode Commands
```bash
opencode run -m <model> "<prompt>"
opencode models
opencode run --print-logs -m <model> "<prompt>"
```

### Beads Commands
```bash
bv --robot-triage   # Mega-command
bv --robot-next       # Top recommendation
bv --robot-plan       # Execution plan
bv --robot-insights   # Graph metrics
```

### MCP Server Usage
```python
# mem0
mem0_add_memories(text="User prefers Gleam")
mem0_search_memory(query="Gleam preferences")

# Graphiti
graphiti_add_memory(name="Decision", episode_body='{"decision": "Use Kestra"}', source="json")
graphiti_search_nodes(query="Kestra workflow", max_nodes=10)

# Codanna
codanna_search_symbols(query="workflow", limit=10)
codanna_find_callers(function_name="format_xml")
codanna_analyze_impact(symbol_name="ExecutionWatcher")
```

## Troubleshooting

### bitter-truth Issues

**Validation fails repeatedly**:
1. Check contract schema - does it match expected output?
2. Review errors in `datacontract test` output
3. Fix **prompt**, not code (Law 2)
4. After 5 failures, escalate to human

**Timeout during generation**:
1. Check `timeout_seconds` context parameter
2. Verify model is responding: `opencode models`

### Kestra Issues

**Flow won't deploy**:
1. Check YAML syntax
2. Verify `id` and `namespace` are unique
3. Check credentials in `~/.netrc`

**Execution stuck in RUNNING**:
1. Check execution logs
2. Verify timeout settings
3. Check for hanging processes

**Validation always fails**:
1. Check contract path in flow input
2. Verify data file exists at `servers.local.path`
3. Review `datacontract test` output
4. Check if dry-run is enabled

### Codanna Issues

**Search returns no results**:
1. Check index info: `codanna_get_index_info()`
2. Try different search terms
3. Check language filter

## Best Practices

### bitter-truth
1. Write clear contracts with specific inputs, outputs, validation rules
2. Use dry-run mode first: `dry_run: true`
3. Review self-healing feedback
4. Follow 4 Laws - never manually edit Nushell
5. Monitor executions with Kestra UI or `kestra-ws`

### Kestra
1. Use secrets - Never hardcode credentials, use `secret('KEY')`
2. Add timeouts - Prevent hanging with `timeout` on long tasks
3. Configure retries - Add `retry` for external calls
4. Use Parallel - Run independent tasks in parallel
5. Handle errors - Add `errors` section

### Nushell
1. Use structured data operations, not string parsing
2. Add type annotations to custom commands
3. Use `try`/`catch` around fallible operations
4. Use optional access `?` for potentially missing fields
5. Log structured JSON for debugging

### Agent Coordination
1. Use appropriate tools: bitter-truth for Nushell, OpenCode for complex tasks
2. Save to memory (mem0) for preferences and decisions
3. Search first (Codanna) to find existing code patterns
4. Track with Beads: `bv --robot-triage`
5. Validate output using CORE.md checklist
