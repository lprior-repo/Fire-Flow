# Implementation Plan: TCR Enforcer for OpenCode

## Document Info

| Field | Value |
|-------|-------|
| Version | 0.1.0 |
| Status | Draft |
| Author | Lewis |
| Created | 2025-12-12 |

---

## Overview

Phased delivery approach prioritizing core functionality first.

```
Phase 0: Setup (0.5 day)
    │
    ▼
Phase 1: Core Plugin (1-2 days)
    │
    ▼
Phase 2: Test Reporter (1 day)
    │
    ▼
Phase 3: Polish & Testing (1 day)
    │
    ▼
Phase 4: Documentation (0.5 day)
    │
    ▼
v1.0 Release
```

---

## Phase 0: Project Setup

**Duration**: 0.5 day

### Tasks

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| 0.1 | Initialize repository | Git repo with README |
| 0.2 | Setup TypeScript/Bun | `bun init`, tsconfig |
| 0.3 | Install dependencies | @opencode-ai/plugin, yaml |
| 0.4 | Create directory structure | See structure below |
| 0.5 | Setup test framework | Vitest configured |

### Directory Structure

```
tcr-enforcer/
├── src/
│   ├── index.ts              # Plugin entry point
│   ├── types.ts              # Type definitions
│   ├── state-manager.ts      # State persistence
│   ├── tdd-gate.ts           # TDD enforcement
│   ├── tcr-loop.ts           # Test && commit || revert
│   ├── git-ops.ts            # Git operations
│   ├── utils.ts              # Helper functions
│   └── messages.ts           # User-facing messages
├── reporters/
│   └── vitest/
│       └── index.ts          # Vitest reporter
├── test/
│   ├── state-manager.test.ts
│   ├── tdd-gate.test.ts
│   ├── tcr-loop.test.ts
│   └── integration.test.ts
├── docs/                     # Planning docs
├── examples/
│   └── config.yml            # Example configuration
├── package.json
├── tsconfig.json
├── vitest.config.ts
└── README.md
```

### Deliverables
- [ ] Repository initialized
- [ ] Build tooling configured
- [ ] Test framework running
- [ ] Directory structure created

---

## Phase 1: Core Plugin

**Duration**: 1-2 days

### 1.1 Types & Constants (2 hours)

```typescript
// src/types.ts
// Define all interfaces from technical spec:
// - TCRConfig
// - TCRMode
// - TestResults
// - TCRStats
// - RuntimeState
```

**Tests**:
- Type exports compile correctly
- Default values match spec

### 1.2 State Manager (4 hours)

```typescript
// src/state-manager.ts
// Implement StateManager class:
// - init()
// - loadConfig() / getConfig()
// - loadTestResults() / refreshTestResults()
// - loadStats() / saveStats()
// - recordCommit() / recordRevert()
// - isEnabled() / setEnabled()
// - getMode() / setMode()
```

**Tests**:
- Creates data directory if missing
- Loads config with defaults
- Persists stats correctly
- Handles missing/corrupt files

### 1.3 Utility Functions (2 hours)

```typescript
// src/utils.ts
// - isProtectedPath(path, patterns)
// - isTestFile(path, patterns)
// - truncateOutput(text, limit)
```

**Tests**:
- Test file detection for all patterns
- Protected path detection
- Output truncation

### 1.4 Git Operations (2 hours)

```typescript
// src/git-ops.ts
// - runTests($, command, directory)
// - gitCommit($, message)
// - gitRevert($)
// - hasUncommittedChanges($)
```

**Tests**:
- Mock shell execution
- Handle command failures
- Verify git commands

### 1.5 TDD Gate (3 hours)

```typescript
// src/tdd-gate.ts
// - createTDDGate(state, directory)
// Returns hook function that:
// - Blocks protected paths
// - Allows when disabled
// - Allows test files
// - Checks for failing tests
// - Blocks implementation without tests
```

**Tests**:
- Blocks impl without failing test
- Allows impl with failing test
- Always allows test files
- Blocks protected paths
- Respects mode setting

### 1.6 TCR Loop (3 hours)

```typescript
// src/tcr-loop.ts
// - createTCRLoop(state, directory, $)
// Returns hook function that:
// - Runs tests after write/edit
// - Commits on pass
// - Reverts on fail
// - Handles relaxed mode
// - Tracks statistics
```

**Tests**:
- Commits on passing tests
- Reverts on failing tests
- Skips revert in relaxed mode
- Updates stats correctly
- Debounces rapid edits

### 1.7 Plugin Entry Point (2 hours)

```typescript
// src/index.ts
// - Export TCREnforcer plugin
// - Wire up state manager
// - Register hooks
// - Handle bash tool protection
```

**Tests**:
- Plugin exports correctly
- Hooks registered properly
- Integration smoke test

### Deliverables
- [ ] All core modules implemented
- [ ] Unit tests passing
- [ ] Plugin loads in OpenCode

---

## Phase 2: Test Reporter

**Duration**: 1 day

### 2.1 Vitest Reporter (4 hours)

```typescript
// reporters/vitest/index.ts
// - TCRVitestReporter class
// - onInit(): Record start time
// - onFinished(): Collect results, write JSON
// - collectResults(): Recurse through tasks
```

**Tests**:
- Writes correct JSON format
- Handles nested suites
- Creates directory if missing

### 2.2 Reporter Package Setup (2 hours)

- Separate package.json for reporter
- Build configuration
- NPM publish preparation

### 2.3 Integration Test (2 hours)

- Create test project
- Install plugin + reporter
- Verify end-to-end flow

### Deliverables
- [ ] Vitest reporter working
- [ ] Reporter published (or ready to publish)
- [ ] End-to-end test passing

---

## Phase 3: Polish & Testing

**Duration**: 1 day

### 3.1 Error Messages (2 hours)

```typescript
// src/messages.ts
// - TDD_VIOLATION message
// - TCR_REVERTED message
// - PROTECTED_PATH message
// - REVERT_STREAK message
```

Review and improve all user-facing messages.

### 3.2 Edge Cases (3 hours)

Test and fix:
- Git not initialized
- Test command fails to run
- Config file syntax errors
- Empty test results
- Concurrent edits
- Very long test output

### 3.3 Integration Testing (3 hours)

Full scenario tests:
1. Fresh project setup
2. TDD workflow (test → impl → pass)
3. TCR revert scenario
4. Mode switching
5. Self-protection verification

### Deliverables
- [ ] All edge cases handled
- [ ] Error messages polished
- [ ] Integration tests passing

---

## Phase 4: Documentation

**Duration**: 0.5 day

### 4.1 User Guide (2 hours)

- Installation instructions
- Quick start
- Configuration reference
- Troubleshooting

### 4.2 README (1 hour)

- Project description
- Features list
- Installation
- Usage examples
- Contributing guide

### 4.3 Examples (1 hour)

- Example config.yml
- Example vitest.config.ts
- Example project structure

### Deliverables
- [ ] User guide complete
- [ ] README polished
- [ ] Examples provided

---

## Release Checklist

### Pre-Release

- [ ] All tests passing
- [ ] No TypeScript errors
- [ ] Documentation complete
- [ ] Examples working
- [ ] CHANGELOG written

### Release

- [ ] Version bump (1.0.0)
- [ ] Git tag created
- [ ] Package published (if applicable)
- [ ] Announcement written

### Post-Release

- [ ] Test installation from scratch
- [ ] Gather feedback
- [ ] Create issue templates
- [ ] Plan v1.1 features

---

## Task Tracking

### Sprint Board

| Status | Task | Assignee | Notes |
|--------|------|----------|-------|
| TODO | 0.1 Initialize repo | Lewis | |
| TODO | 0.2 Setup TypeScript | Lewis | |
| TODO | ... | | |

### Velocity

Target: 1 week to v1.0

| Day | Planned | Actual | Notes |
|-----|---------|--------|-------|
| 1 | Phase 0 + 1.1-1.3 | | |
| 2 | Phase 1.4-1.7 | | |
| 3 | Phase 2 | | |
| 4 | Phase 3 | | |
| 5 | Phase 4 + Release | | |

---

## Risk Mitigation

| Risk | Mitigation | Contingency |
|------|------------|-------------|
| OpenCode API changes | Pin version, test against specific release | Adapt quickly, maintain compatibility layer |
| Test reporter complexity | Start with Vitest only | Delay other frameworks to v1.1 |
| Edge cases emerge | Reserve time in Phase 3 | Push polish to v1.1 |
| Integration issues | Test early and often | Simplify scope |

---

## Dependencies

### Development

| Package | Version | Purpose |
|---------|---------|---------|
| @opencode-ai/plugin | latest | Plugin SDK |
| typescript | ^5.0 | Type checking |
| vitest | ^1.0 | Testing |
| yaml | ^2.0 | Config parsing |

### Runtime

| Dependency | Version | Notes |
|------------|---------|-------|
| Bun | >= 1.0 | Required by OpenCode |
| Git | >= 2.0 | For commit/revert |
| OpenCode | latest | Plugin host |

---

## Future Phases (Post v1.0)

### v1.1 Features
- Jest reporter
- pytest reporter
- Squash helper command
- Stats dashboard tool

### v1.2 Features
- Go test reporter
- LLM over-implementation detection
- Lint integration

### v2.0 Features
- MCP server
- Multi-project support
- Team analytics
