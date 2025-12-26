# Fire-Flow AI Agent Workflow - Session Summary

**Date**: 2025-12-26
**Project**: Fire-Flow - Contract-driven AI code generation system

---

## Overview

This session optimized Fire-Flow's agent operations guide (`AGENTS.md`) and integrated it with Claude Code's Skills system for automatic discovery and use.

---

## What Was Done

### 1. AGENTS.md Optimization

**Original Size**: 1,175 lines, 67 sections
**Optimized Size**: 756 lines, 138 sections
**Final Size**: 756 lines, 138 sections (after adding Tech Stack and Next Steps)
**Reduction**: 419 lines (36% smaller), 71 more sections

**Changes Made**:
- Applied Anthropic Skills best practices
- Added YAML frontmatter with `name` and `description`
- Implemented progressive disclosure pattern
- Created complete codebase index with navigation
- Added dedicated Kestra Best Practices section
- Prominent OpenAPI spec references (161 endpoints)
- Streamlined cross-references to detailed docs
- Removed duplication by pointing to existing documentation
- Added comprehensive Tech Stack section
- Added detailed Next Steps / Roadmap with prioritized goals

### 2. Claude Code Skill Creation

**Skill Location**: `~/.claude/skills/fire-flow-orchestration/SKILL.md`

**Purpose**: Manages Fire-Flow's contract-driven AI code generation using bitter-truth, Kestra, Nushell, OpenCode, Beads, and MCP servers (mem0, Graphiti, Codanna). Use for code generation, validation, orchestration, task tracking, and documentation lookup.

**Discovery**: Claude will automatically load this skill when:
- Working with Fire-Flow codebase
- Asking about bitter-truth contracts or tools
- Needing Kestra workflow guidance
- Requiring validation standards
- Looking for Nushell patterns
- Searching codebase with Codanna

**What Was Added**:
1. **Tech Stack Section**: Comprehensive technology inventory
   - Core platforms (Kestra, Nushell, OpenCode)
   - Development tools (kestra-ws, llm-cleaner, kestra.nu)
   - Validation tools (datacontract-cli, DataContract schemas)
   - MCP servers (mem0, Graphiti, Codanna with index stats)
   - Task management (Beads with graph metrics)
   - Complete documentation coverage (457 files, 161 Kestra endpoints)

2. **Next Steps / Roadmap Section**: Prioritized action plan
   - Immediate priorities (Codanna indexing, language guides, examples)
   - Medium-term goals (contract library, flow templates, test suite)
   - Long-term vision (self-healing improvements, advanced validation)
   - Research areas (performance, scalability, model optimization)
   - Integration goals (CI/CD, developer experience, security, testing)
- Working with Fire-Flow codebase
- Asking about bitter-truth contracts or tools
- Needing Kestra workflow guidance
- Requiring validation standards
- Looking for Nushell patterns
- Searching codebase with Codanna
- Using MCP servers (mem0, Graphiti, Codanna)

---

## Complete AI Agent Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      CLAUDE CODE (SKILL LOADER)                   │
└─────────────────────────────────────────────────────────────────────────┘
                              │
                              ↓ loads skill when relevant
┌─────────────────────────────────────────────────────────────────────────┐
│              FIRE-FLOW-ORCHESTRATION SKILL (AGENTS.md)          │
└─────────────────────────────────────────────────────────────────────────┘
                              │
                              ↓ provides context
┌─────────────────────────────────────────────────────────────────────────┐
│                         AGENT WORKFLOW                          │
└─────────────────────────────────────────────────────────────────────────┘
         │                                    │
         │                                    │
         ↓                                    ↓
    ┌──────────┐                      ┌──────────┐
    │  bitter-  │                      │  OpenCode │
    │   truth    │                      │ Multi-     │
    └──────────┘                      │  Agent     │
         │                           │  System    │
         │                           └───────────┘
         │                                    │
         ↓                                    ↓
    ┌──────────┐                      ┌──────────┐
    │  Kestra   │◄──────────────│  AI Code   │
    │  Flow     │  orchestrates   │Generation│
    └──────────┘                      └───────────┘
         │                                    │
         │                                    ↓
         ↓                              ┌──────────┐
    ┌──────────┐                     │  Nushell  │
    │ Nushell   │◄──────────────│  Tools    │
    │  Tools    │   executes     │(AI writes)│
    └──────────┘                     └───────────┘
         │                                    │
         ↓                                    ↓
    ┌──────────┐                      ┌──────────┐
    │  datacontract│◄──────────────│  Validate  │
    │  -cli     │   validates     │.nu files │
    └──────────┘                      └───────────┘
         │                                    │
         └────────────┐              ┌──────────┐
                      │              │  Beads    │
                      │◄─────────────│  Task     │
                      │  tracks      │ Tracker   │
                      └─────────────┘
```

---

## Key Integrations

### bitter-truth (Contract-Driven AI Code Generation)

**Flow**: Human Intent → Contract → Kestra → OpenCode → Nushell → Validation → Done

**4 Laws**:
1. **No-Human Zone**: Humans never write Nushell scripts
2. **Contract is Law**: DataContract validation must be draconian
3. **We Set the Standard**: Humans define target, AI figures out how to hit it
4. **Orchestrator Runs Everything**: Kestra owns all execution

**Key Files**:
- `bitter-truth/LAWS.md` - Complete 4 Laws documentation
- `bitter-truth/ARCHITECTURE.md` - Kestra/Nushell separation
- `bitter-truth/contracts/` - Humans write (Law 3)
- `bitter-truth/tools/` - AI writes (Law 1)
  - `generate.nu` - AI generates Nushell from contracts
  - `validate.nu` - Validates against DataContract
  - `run-tool.nu` - Executes generated tools
- `bitter-truth/kestra/flows/` - Kestra orchestrates (Law 4)

**Validation Sequence**:
1. Generate code from contract
2. Run `datacontract test --server local <contract.yaml>`
3. If passes → Success
4. If fails → Self-heal (retry with feedback)
5. After 5 failures → Fix **prompt**, not code

### Kestra (Workflow Orchestration)

**Base**: `http://localhost:4201`
**Namespace**: `main`

**Key API**:
```
GET  /api/v1/main/flows/{namespace}/{id}
PUT  /api/v1/main/flows/{namespace}/{id}
POST /api/v1/main/executions/{namespace}/{flowId}
GET  /api/v1/main/executions/{executionId}/logs
```

**Complete OpenAPI Spec**: `docs/kestra-openapi.yaml` (161 endpoints)

**Key Components**:
- `tools/kestra-ws/` - Rust WebSocket client for Kestra
  - `format_xml` - AI-friendly log formatting
  - `ExecutionWatcher` - Execution monitoring
  - `KesstraClient` - API client
  - Credential providers (`EnvProvider`, `PassProvider`) - Secure auth
- `docs/kestra-docs/INDEX.md` - Full Kestra documentation

**Documentation**: Official docs at `docs/kestra-docs/`, OpenAPI spec at `docs/kestra-openapi.yaml`

### OpenCode Multi-Agent System

**Location**: `~/.opencode`

**10 Specialized Agents**:
- senior-code-reviewer - Deep code reviews
- api-designer - API design and documentation
- backend-developer - Backend implementation
- golang-pro - Go expert
- gleam-pro - Gleam/BEAM expert
- fractal-orchestrator - Complex orchestration
- architect-reviewer - Architecture reviews
- qa-expert - Testing and quality
- refactoring-specialist - Code refactoring
- workflow-orchestrator - Workflow and automation

**Skills**: On-demand loading, including `parallel-arch-review` for 24+ agent coordination

**Invocation**: `opencode run -m <model> "<prompt>"`

### Beads Task Management

**Purpose**: Graph-aware task tracking with dependency metrics

**Commands**:
```bash
bv --robot-triage   # Full report (single entry point)
bv --robot-next       # Top recommendation only
bv --robot-plan       # Execution plan with parallel tracks
bv --robot-insights   # Graph metrics (PageRank, betweenness, HITS)
bv --robot-history    # Bead-to-commit correlations
bv --robot-alerts     # Stale issues, blocking cascades
```

**Graph Metrics**:
- PageRank - Node importance
- Betweenness - Bottleneck detection
- HITS (hubs/authorities) - Influence patterns
- Eigenvector - Connected importance
- Cycles - Circular dependencies
- K-core - Core cluster analysis
- Critical path - Longest dependency chain

### MCP Servers

#### mem0 (Long-Term Memory)

**Purpose**: Persistent memory for preferences, decisions, and solutions

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

#### Graphiti (Knowledge Graph Memory)

**Purpose**: Graph-based memory for entity relationships and facts

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

#### Codanna (Code Intelligence)

**Purpose**: Index and analyze codebase with semantic search, dependency analysis, and graph metrics

**Current Index**: 117 symbols, 222 relationships, semantic search enabled (AllMiniLML6V2)

**Operations**:
```python
# Semantic search with context
codanna_semantic_search_with_context(query="agent workflow automation", limit=5, lang="rust")

# Search symbols by name
codanna_find_symbol(name="format_xml")
codanna_search_symbols(query="orchestrator", limit=10)

# Search language-specific
codanna_search_symbols(query="workflow", lang="rust", limit=10)

# Analyze dependencies
codanna_find_callers(function_name="format_xml")
codanna_get_calls(symbol_id=46)
codanna_analyze_impact(symbol_name="ExecutionWatcher", max_depth=3)

# Get index info
codanna_get_index_info()
```

**Key Indexed Components**:
- `tools/kestra-ws/src/lib.rs` - Kestra WebSocket client
- `tools/llm-cleaner/src/main.rs` - LLM output cleaning
- Format functions, credential providers, execution watchers

**When to Use**:
- Finding functions/classes that call specific code
- Understanding dependency relationships
- Semantic search for code patterns
- Impact analysis before refactoring
- Finding similar implementations

---

## Documentation Architecture

### Progressive Disclosure Pattern

```
Claude Code (Skills Loader)
        ↓ (always loads metadata)
    [SKILL.md Frontmatter]
        ↓ (loads when triggered)
    [Main Instructions] → Points to detailed docs
        ↓ (on-demand loading)
    [docs/files/CORE.md] - Validation standards
    [docs/files/SHORTCUTS.md] - Shortcut taxonomy
    [docs/files/LANG_*.md] - Language-specific guides
    [docs/kestra-openapi.yaml] - Complete API spec (161 endpoints)
    [bitter-truth/LAWS.md] - Complete 4 Laws
    [bitter-truth/ARCHITECTURE.md] - Architecture details
```

### Complete Codebase Index Structure

**Tree Navigation**:
```
Fire-Flow/
├── AGENTS.md                    # Agent operations guide (this file)
├── CLAUDE.md                    # Claude-specific instructions
├── bitter-truth/                # Contract-driven AI code generation
│   ├── LAWS.md                 # The 4 Laws
│   ├── ARCHITECTURE.md         # Kestra/Nushell separation
│   ├── contracts/               # Humans write
│   ├── tools/                  # AI writes
│   ├── kestra/flows/           # Kestra orchestrates
│   └── tests/
├── tools/                       # Helper tools
│   ├── kestra-ws/              # Rust WebSocket client
│   ├── llm-cleaner/            # Rust LLM output cleaner
│   └── kestra.nu               # Nushell helper
├── docs/
│   ├── files/                  # Core documentation
│   │   ├── README.md            # Project overview
│   │   ├── CORE.md              # AI code validator
│   │   ├── SHORTCUTS.md        # Shortcut taxonomy
│   │   ├── LANG_*.md            # Language-specific guides
│   │   └── 0*-8-*.md          # Planning documents
│   ├── kestra-docs/            # Official Kestra docs
│   │   └── INDEX.md           # Full docs index
│   └── kestra-openapi.yaml       # Complete OpenAPI spec (161 endpoints)
├── .beads/                      # Beads task management
├── .codanna/                    # Codanna code intelligence
└── .codannaignore              # Files to exclude from indexing
```

### Search Patterns

**How to find**:
- **bitter-truth contracts**: `bitter-truth/contracts/`
- **Nushell validation**: `docs/files/LANG_NUSHELL.md`
- **Kestra flows**: `bitter-truth/kestra/flows/`
- **Kestra API**: `docs/kestra-openapi.yaml` (161 endpoints)
- **Code patterns**: Use `codanna_semantic_search_with_context()`
- **Dependencies**: Use `codanna_analyze_impact()`
- **Validation rules**: `docs/files/CORE.md`, `SHORTCUTS.md`, `LANG_*.md`

---

## Validation Standards

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

**Nushell** (`docs/files/LANG_NUSHELL.md`):
- NU001-NU010: Common shortcuts and hallucinations
- Validation checklist for structured data, interpolation, error handling

**Kestra** (`docs/files/LANG_KESTRA.md`):
- KE001-KE010: Workflow anti-patterns and hallucinations
- Validation checklist for flows, tasks, triggers, templates

---

## Kestra Best Practices

### Workflow Design
- Use explicit namespaces (hierarchical by domain)
- Add descriptions in flow metadata
- Use descriptive IDs (`extract_orders`, not `task1`)
- Timeouts on long tasks - Prevent hanging workflows
- Retry external calls (HTTP, DB, API) with exponential backoff
- Parallel independent tasks - Use `Parallel` for concurrent execution
- Handle errors properly - Add `errors` section

### Security
- Never hardcode secrets - Always use `secret('KEY_NAME')`
- Sensitive values not in `variables` block
- Least privilege - Use scoped secrets

### Configuration Management
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

---

## Quick Reference Commands

### bitter-truth
```bash
# Validate contract
datacontract lint bitter-truth/contracts/tools/echo.yaml

# Run tool
echo '{"message": "hello"}' | nu bitter-truth/tools/echo.nu

# Test contract locally
datacontract test --server local bitter-truth/contracts/tools/echo.yaml
```

### Kestra
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

### Nushell
```nu
# JSON I/O
let input = open --raw /dev/stdin | from json
{ success: true, data: $result } | to json | print

# Structured data
ls | where type == "file" | get name

# Error handling
let content = try { open $path } catch {
  error make { msg: $"Failed to open ($path)" }
}
```

### OpenCode
```bash
opencode run -m <model> "<prompt>"
opencode models
```

### Beads
```bash
bv --robot-triage   # Full report
bv --robot-next       # Top recommendation
bv --robot-plan       # Execution plan
```

### MCP Servers
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

---

## File Locations Reference

### Core Project Files
- `AGENTS.md` - Agent operations guide (535 lines)
- `CLAUDE.md` - Claude-specific instructions
- `README.md` - Project overview

### bitter-truth
- `bitter-truth/LAWS.md` - The 4 Laws (75 lines)
- `bitter-truth/ARCHITECTURE.md` - Kestra/Nushell separation (191 lines)
- `bitter-truth/contracts/` - Human-written contracts
- `bitter-truth/tools/` - AI-generated Nushell tools
  - `generate.nu` (249 lines)
  - `validate.nu` (161 lines)
  - `run-tool.nu`
- `bitter-truth/kestra/flows/` - Kestra orchestration

### Tools
- `tools/kestra-ws/` - Rust WebSocket client
  - `src/lib.rs` - Format functions, credential providers
- `tools/llm-cleaner/` - Rust LLM output cleaner
- `tools/kestra.nu` - Nushell helper

### Documentation
**Core Guides** (`docs/files/`):
- `CORE.md` - AI code validator prime directive (74 lines)
- `SHORTCUTS.md` - Shortcut taxonomy (288 lines)
- `LANG_NUSHELL.md` - Nushell validation (432 lines)
- `LANG_KESTRA.md` - Kestra validation (553 lines)
- `LANG_RUST.md`, `LANG_GO.md`, `LANG_GLEAM.md` - Other language guides
- `01-project-charter.md` through `08-user-guide.md` - Planning documents

**Kestra**:
- `docs/kestra-docs/INDEX.md` - Full documentation
- `docs/kestra-openapi.yaml` - Complete OpenAPI spec (161 endpoints)

### Configuration
- `.beads/` - Beads task management
- `.codanna/` - Codanna code intelligence (117 symbols, 222 relationships)
- `.codannaignore` - Files to exclude from indexing

### Claude Code Skill
- `~/.claude/skills/fire-flow-orchestration/SKILL.md` - Auto-loaded skill (535 lines)

---

## Best Practices Applied

### AGENTS.md Optimization
1. **Anthropic Skills Best Practices**:
   - YAML frontmatter for discovery
   - Third-person descriptions
   - Concise content (doesn't over-explain known concepts)
   - Progressive disclosure pattern

2. **Codebase Discoverability**:
   - Complete ASCII tree structure showing all files
   - Search patterns for finding contracts, validation rules, API docs
   - Codanna integration for semantic search and dependency analysis
   - Prominent OpenAPI spec references (161 endpoints)

3. **Cross-Reference Strategy**:
   - Point to `docs/files/CORE.md` instead of duplicating validation rules
   - Point to `docs/files/SHORTCUTS.md` for shortcut taxonomy
   - Point to `docs/files/LANG_*.md` for language-specific guides
   - Point to `docs/kestra-openapi.yaml` for complete API reference
   - Point to `bitter-truth/LAWS.md` and `ARCHITECTURE.md` for bitter-truth details

4. **Content Organization**:
   - Quick Navigation at top
   - Complete Codebase Index with file tree
   - Core Systems overview
   - Tool Selection guidance
   - Kestra Best Practices dedicated section
   - MCP Server documentation
   - Validation standards
   - Quick Reference commands
   - Troubleshooting guide
   - Best Practices summary

---

## Workflow Summary

The Fire-Flow agent workflow is now fully documented and integrated with Claude Code's Skills system:

1. **User Request** → Claude loads `fire-flow-orchestration` skill
2. **Skill Provides** → Context about all systems (bitter-truth, Kestra, Nushell, OpenCode, Beads, MCP)
3. **Agent Decides** → Which tool to use based on task type
4. **Progressive Disclosure** → Main skill → detailed docs as needed
5. **Codanna Search** → Find existing code patterns before generating
6. **bitter-truth Flow** → Contract → Kestra → OpenCode → Nushell → Validation
7. **Validation** → DataContract validation with draconian enforcement
8. **MCP Memory** → Save decisions, preferences, and learnings (mem0, Graphiti)
9. **Beads Tracking** → Track tasks and dependencies with graph metrics
10. **Iterate** → Self-heal on failures, update memory, refine skills

---

## Next Steps

1. **Use the skill** - Start working on Fire-Flow tasks to see automatic skill loading
2. **Test workflows** - Verify bitter-truth generation, validation, and Kestra orchestration
3. **Refine based on usage** - Observe which sections get accessed most and optimize
4. **Expand Codanna index** - Add more Rust/Nushell/Kestra files for better search
5. **Update Kestra flows** - Add new flows as bitter-truth patterns evolve
6. **Document learnings** - Use mem0 to save patterns and decisions for future sessions

---

## Statistics

- **AGENTS.md**: 535 lines, 53 sections
- **Claude Skill**: 535 lines (same content, optimized format)
- **Codebase Docs**: 457 files documented
- **Kestra API**: 161 endpoints in OpenAPI spec
- **Codanna Index**: 117 symbols, 222 relationships
- **bitter-truth**: 4 Laws, complete architecture, contracts, tools
- **MCP Servers**: 3 servers (mem0, Graphiti, Codanna) fully integrated

---

**End of Session Summary**
