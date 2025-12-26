# Architecture: TCR Enforcer for OpenCode

## Document Info

| Field | Value |
|-------|-------|
| Version | 0.1.0 |
| Status | Draft |
| Author | Lewis |
| Created | 2025-12-12 |

---

## 1. System Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              OPENCODE                                       │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         TCR ENFORCER PLUGIN                          │   │
│  │                                                                      │   │
│  │   ┌──────────────┐    ┌──────────────┐    ┌──────────────┐         │   │
│  │   │  TDD GATE    │    │  TCR LOOP    │    │   STATE      │         │   │
│  │   │              │    │              │    │   MANAGER    │         │   │
│  │   │ before hook  │    │ after hook   │    │              │         │   │
│  │   │ checks for   │    │ runs tests   │    │ reads/writes │         │   │
│  │   │ failing test │    │ commit/revert│    │ config/stats │         │   │
│  │   └──────┬───────┘    └──────┬───────┘    └──────┬───────┘         │   │
│  │          │                   │                   │                  │   │
│  └──────────┼───────────────────┼───────────────────┼──────────────────┘   │
│             │                   │                   │                       │
│             ▼                   ▼                   ▼                       │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                      .opencode/tcr/data/                             │  │
│  │   ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐    │  │
│  │   │ state.json │  │ test.json  │  │ stats.json │  │ config.yml │    │  │
│  │   │ on/off     │  │ results    │  │ metrics    │  │ settings   │    │  │
│  │   └────────────┘  └────────────┘  └────────────┘  └────────────┘    │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ writes test results
                                    │
                    ┌───────────────┴───────────────┐
                    │       TEST REPORTER           │
                    │   (vitest/jest/pytest/etc)    │
                    │                               │
                    │   Captures test output and    │
                    │   writes to test.json         │
                    └───────────────────────────────┘
```

---

## 2. Component Breakdown

### 2.1 TDD Gate (tool.execute.before)

**Responsibility**: Block implementation without failing tests

```
Input: Tool execution request (write/edit)
Output: Allow or throw Error (block)

Logic:
  1. Is this a protected path? → BLOCK
  2. Is enforcement disabled? → ALLOW
  3. Is this a test file? → ALLOW
  4. Are there failing tests? → ALLOW
  5. No failing tests? → BLOCK with message
```

**Key Decisions**:
- Runs synchronously before every write/edit
- Must be fast (< 50ms) since it blocks the operation
- Reads cached test results from disk (doesn't run tests)

### 2.2 TCR Loop (tool.execute.after)

**Responsibility**: Run tests and commit or revert

```
Input: Completed tool execution (write/edit)
Output: Side effects (commit or revert)

Logic:
  1. Is this a protected path? → SKIP
  2. Is enforcement disabled? → SKIP
  3. Is TCR mode off? → SKIP
  4. Run tests
  5. Tests pass? → git commit -am "WIP"
  6. Tests fail? → git reset --hard HEAD
  7. Update stats
```

**Key Decisions**:
- Runs asynchronously after write/edit completes
- Can be slow (test execution time)
- Performs actual git operations

### 2.3 State Manager

**Responsibility**: Persist and retrieve state between hook invocations

**Files Managed**:

| File | Purpose | Schema |
|------|---------|--------|
| `state.json` | Runtime state | `{ enabled, mode }` |
| `test.json` | Test results | `{ passed[], failed[], timestamp }` |
| `stats.json` | Metrics | `{ commits, reverts, streak }` |
| `config.yml` | User settings | See Configuration doc |

### 2.4 Test Reporter (Separate Package)

**Responsibility**: Capture test results and write to `test.json`

Lives in user's project, not in the plugin. Options:
- Vitest reporter
- Jest reporter
- Pytest plugin
- Go test wrapper
- Generic (parse TAP output)

---

## 3. Data Flow

### 3.1 Normal TDD Flow (Happy Path)

```
┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
│ Agent   │     │ Agent   │     │ Plugin  │     │ Tests   │     │ Plugin  │
│ writes  │────▶│ writes  │────▶│ allows  │────▶│ run,    │────▶│ commits │
│ test    │     │ impl    │     │ (has    │     │ pass    │     │         │
│         │     │         │     │ failing │     │         │     │         │
│         │     │         │     │ test)   │     │         │     │         │
└─────────┘     └─────────┘     └─────────┘     └─────────┘     └─────────┘
```

### 3.2 TDD Violation (No Test)

```
┌─────────┐     ┌─────────┐
│ Agent   │     │ Plugin  │
│ writes  │────▶│ BLOCKS  │
│ impl    │     │ "Write  │
│ (no     │     │ a test  │
│ test)   │     │ first"  │
└─────────┘     └─────────┘
```

### 3.3 TCR Revert (Test Fails)

```
┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
│ Agent   │     │ Agent   │     │ Plugin  │     │ Tests   │     │ Plugin  │
│ writes  │────▶│ writes  │────▶│ allows  │────▶│ run,    │────▶│ REVERTS │
│ test    │     │ impl    │     │         │     │ FAIL    │     │ "Code   │
│         │     │ (buggy) │     │         │     │         │     │ removed"│
└─────────┘     └─────────┘     └─────────┘     └─────────┘     └─────────┘
```

---

## 4. File System Layout

```
project-root/
├── .opencode/
│   ├── plugin/
│   │   └── tcr-enforcer.ts      # The plugin (or symlink to global)
│   └── tcr/
│       └── data/
│           ├── state.json       # { enabled: true, mode: "both" }
│           ├── test.json        # { passed: [...], failed: [...] }
│           ├── stats.json       # { commits: 42, reverts: 7 }
│           └── config.yml       # User configuration
│
├── src/                          # Implementation code
│   └── ...
├── test/                         # Test code
│   └── ...
├── vitest.config.ts             # With TCR reporter configured
└── package.json
```

For **global installation**:

```
~/.config/opencode/
├── plugin/
│   └── tcr-enforcer.ts          # Global plugin
└── tcr/
    └── data/
        └── config.yml           # Global defaults
```

---

## 5. Security Model

### 5.1 Self-Protection

The plugin MUST protect itself from being disabled by the agent:

```typescript
const PROTECTED_PATHS = [
  'opencode.json',           // OpenCode config
  '.opencode/plugin',        // Plugin directory
  '.opencode/tcr',           // TCR data directory
  '.git',                    // Git internals
]

// In tool.execute.before:
if (isProtected(filePath)) {
  throw new Error("🚫 Cannot modify TCR/plugin configuration")
}
```

### 5.2 Shell Command Protection

Agent might try to bypass via bash tool:

```typescript
// Also hook bash tool
if (input.tool === "bash") {
  const cmd = output.args.command ?? ""
  if (PROTECTED_PATHS.some(p => cmd.includes(p))) {
    throw new Error("🚫 Cannot modify protected files via shell")
  }
}
```

### 5.3 File System Permissions (Optional Hardening)

```bash
# Make config read-only at OS level
chmod 444 .opencode/tcr/data/config.yml
chmod 444 .opencode/plugin/tcr-enforcer.ts
```

---

## 6. Integration Points

### 6.1 OpenCode Plugin API

```typescript
import type { Plugin } from "@opencode-ai/plugin"
import { tool } from "@opencode-ai/plugin"

export const TCREnforcer: Plugin = async ({ 
  directory,   // Project root
  $,           // Bun shell API
  client,      // OpenCode SDK client (for future use)
  project,     // Project info
  worktree     // Git worktree path
}) => {
  return {
    "tool.execute.before": async (input, output) => { ... },
    "tool.execute.after": async (input, output) => { ... },
    // Could also add custom tools:
    tool: {
      tcr_status: tool({ ... }),
      tcr_squash: tool({ ... })
    }
  }
}
```

### 6.2 Test Reporter Integration

Reporter writes to well-known location:

```typescript
// In vitest reporter
const OUTPUT_PATH = path.join(
  projectRoot, 
  '.opencode/tcr/data/test.json'
)

onFinished(files) {
  const results = { passed: [], failed: [], timestamp: Date.now() }
  // ... collect results
  fs.writeFileSync(OUTPUT_PATH, JSON.stringify(results))
}
```

### 6.3 Git Integration

```typescript
// Commit (on green)
await $`git add -A`
await $`git commit -m "WIP" --no-verify`

// Revert (on red)  
await $`git reset --hard HEAD`

// Check for uncommitted changes
const status = await $`git status --porcelain`.text()
const hasChanges = status.trim().length > 0
```

---

## 7. Performance Considerations

| Operation | Target Latency | Notes |
|-----------|----------------|-------|
| TDD gate check | < 50ms | Reads cached JSON, no I/O blocking |
| Test execution | Varies | User's test suite, can't control |
| Git commit | < 200ms | Local operation |
| Git revert | < 100ms | Local operation |

**Optimizations**:
- Cache test results in memory (refresh on file change)
- Debounce rapid consecutive edits
- Consider file watcher vs re-read on each hook

---

## 8. Error Handling

| Error | Handling |
|-------|----------|
| test.json missing | Assume no tests run yet, block impl |
| test.json parse error | Log warning, assume no tests |
| Git not initialized | Error with clear message |
| Git dirty state | Commit or stash before TCR |
| Test command fails to execute | Error with command output |
| Protected path write attempt | Block with clear message |

---

## 9. Future Architecture (v2+)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           TCR ENFORCER v2                                   │
│                                                                             │
│   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   │
│   │  TDD GATE   │   │  TCR LOOP   │   │   LINT      │   │   LLM       │   │
│   │             │   │             │   │   ENFORCER  │   │   VALIDATOR │   │
│   │             │   │             │   │             │   │             │   │
│   │ failing     │   │ test &&     │   │ sonar/      │   │ over-impl   │   │
│   │ test check  │   │ commit ||   │   │ eslint on   │   │ detection   │   │
│   │             │   │ revert      │   │ refactor    │   │             │   │
│   └─────────────┘   └─────────────┘   └─────────────┘   └─────────────┘   │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                         MCP SERVER                                  │   │
│   │   Expose TCR state/controls to other tools (Claude Code, etc)       │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```
