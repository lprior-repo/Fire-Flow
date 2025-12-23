# Fire-Flow: Next Development Stages (Consolidated from mem0)

**Last Updated**: 2025-12-22
**Status**: Ready for Phase 1 Implementation
**Current Model**: Haiku (claude-haiku-4-5-20251001)

---

## Executive Summary

Fire-Flow is transitioning from a reactive TCR enforcement tool (blocking code commits after green tests) to a **proactive OverlayFS-based architecture** that makes untested code physically impossible to persist.

**Key Insight**: By intercepting all file writes at the filesystem level via overlay mounts, untested code evaporates automatically. Tests pass → changes commit to real filesystem. Tests fail → changes disappear. No bypass vectors.

---

## Project Identity

| Property | Value |
|----------|-------|
| **Project Name** | Fire-Flow |
| **Purpose** | TCR (Test-Commit-Revert) Enforcement for Test-Driven Development |
| **Language** | Go 1.25 |
| **Location** | `/home/lewis/src/Fire-Flow/` |
| **Architecture Target** | Overlay-first, OverlayFS-based, Linux-first |
| **User** | lewis |
| **Key Tools** | Golang, OverlayFS (Linux), tmpfs, syscalls |

---

## Current State

### What Exists
- **Entry Point**: `cmd/fire-flow/main.go` (533 lines)
- **State Management**: `internal/state/state.go` (89 lines) - Tracking RED/GREEN/RevertStreak
- **Configuration**: `internal/config/config.go` (94 lines) - YAML-based config
- **Current Commands**: init, status, tdd-gate, run-tests, commit, revert
- **Storage**: `.opencode/tcr/state.json` and `.opencode/tcr/config.yml`
- **Integration**: Kestra workflows, OpenCode agent support, Beads issue tracking

### Current Command Architecture
- **Command Pattern**: Uses Execute() methods dispatched in main.go
- **Directory Structure**: Clean separation of `cmd/` (CLI) and `internal/` (business logic)
- **Testing Pattern**: Table-driven tests with testify assertions
- **Helper Functions**: GetTCRPath(), GetConfigPath(), GetStatePath()

---

## Architectural Transformation

### OLD APPROACH (Being Replaced)
```
Developer writes code (RED) → Tests fail (GREEN) → Commits manually
Problem: Tool VERIFIES compliance after the fact, developers can bypass
```

### NEW APPROACH (Overlay-First)
```
Developer mounts overlay → Writes code to overlay upper layer → Runs tests
- Tests PASS → Overlay commits to real filesystem ✓
- Tests FAIL → Overlay upper layer discarded, code vanishes ✗
Problem solved: No bypass possible (filesystem level enforcement)
```

---

## LOCKED-IN ARCHITECTURAL DECISIONS

### 1. Overlay-Only, Linux-First (No Backward Compatibility)
- **Completely replaces** old tdd-gate reactive workflow
- **Linux OverlayFS only** for Phases 1-3
- **Breaking change**: Users must migrate when init'ing
- **Permission requirement**: Requires sudo or CAP_SYS_ADMIN
- **macOS FUSE support**: Deferred to Phase 4

### 2. State Model Simplification
**Removed from old state**:
```go
Mode: "both"
RevertStreak: int
FailingTests: []string
LastCommitTime: time.Time
```

**New simplified state**:
```go
OverlayActive: bool
OverlayMountPath: string
OverlayUpperDir: string
OverlayWorkDir: string
OverlayMergedDir: string
OverlayMountedAt: time.Time
LastTestResult: bool
LastTestTime: time.Time
```

### 3. Configuration Strategy
**Keep**: TestCommand, TestTimeout
**Add**: OverlayWorkDir, WatchDebounce, WatchIgnore
**Remove**: Mode, ProtectedPaths, AutoCommitMsg

### 4. Storage Approach
- **Overlay directories**: `/tmp/fire-flow-overlay-<pid>` (tmpfs for speed)
- **State file**: Still `.opencode/tcr/state.json`
- **Config file**: Still `.opencode/tcr/config.yml`
- **Principle**: Zero project directory pollution from temp data

### 5. Complete Command Restructuring
**Removed entirely**: tdd-gate, run-tests, commit, revert

**New command set**:
```
fire-flow init                          # Initialize with new overlay format
fire-flow watch [--debounce 500ms]      # Primary workflow - watch & test loop
fire-flow gate [--stdin] [--stdout]     # CI/AI integration endpoint
fire-flow overlay mount                 # Manual overlay mount control
fire-flow overlay unmount
fire-flow overlay commit
fire-flow overlay discard
fire-flow overlay status
fire-flow status                        # Show current overlay state
```

---

## Development Phases (From Implementation Prompt)

### PHASE 1: CORE OVERLAY PRIMITIVES (Est. 3 weeks)
**Goal**: Build foundation - can mount/unmount/commit/discard overlays reliably

**Critical Success Criteria**:
- ✓ Can mount OverlayFS overlay over any directory
- ✓ Changes write to upper layer (tmpfs), not real filesystem
- ✓ Commit merges upper → lower (real filesystem)
- ✓ Discard removes upper layer (changes vanish)
- ✓ Unmount always succeeds, cleans up temp dirs
- ✓ Zero leaked mounts after repeated cycles
- ✓ Works with existing config.yml test commands

**Key Files to Create**:
1. `internal/overlay/types.go` - Core data structures & Mounter interface
2. `internal/overlay/kernel.go` - Linux syscall.Mount() implementation
3. `internal/overlay/fake.go` - Mock implementation for testing
4. `internal/overlay/overlay.go` - High-level orchestration

**Testing Strategy**:
- **Unit Tests**: Use FakeMounter (no permissions needed)
- **Integration Tests**: Marked with `//go:build linux && integration` tag
- **Target**: 50+ tests with 90%+ coverage
- **Pattern**: AAA (Arrange/Act/Assert) for all tests
- **No sudo required** for unit tests

### PHASE 2: WATCH WORKFLOW (Est. 2 weeks)
**Goal**: Implement `fire-flow watch` - primary development workflow

**Features**:
- File system watcher (debounced)
- Automatic test runner on file changes
- Real-time feedback loop
- Commit/discard decisions based on test results

### PHASE 3: CI/AI INTEGRATION (Est. 2 weeks)
**Goal**: Implement `fire-flow gate` - integration with CI/AI systems

**Features**:
- stdin/stdout protocol for CI pipelines
- Integration with OpenCode agent
- Kestra workflow integration

### PHASE 4: FUTURE ENHANCEMENTS
- macOS FUSE support
- Additional command enhancements
- Performance optimizations

---

## Testing Strategy & Requirements

### Unit Test Requirements
- **Target**: 50+ tests with 90%+ coverage
- **Pattern**: AAA (Arrange/Act/Assert)
- **Test doubles**: FakeMounter for all unit tests
- **No permissions**: Unit tests do NOT require sudo
- **Fast**: Tests run in milliseconds
- **Repeatable**: Can run 1000x and get same results

### Integration Test Requirements
- **Marking**: Use `//go:build linux && integration` tag
- **Permissions**: Step 1.10 only - real KernelMounter tests
- **Real mounts**: Only for final integration validation
- **Requires sudo**: For kernel mounter integration tests only

### Test Location Convention
- Unit tests: `internal/overlay/types_test.go`, `internal/overlay/kernel_test.go`
- Each step has **minimum 5 unit tests**
- Tests defined in implementation prompt for each micro-step

---

## Key Implementation Patterns (From Existing Codebase)

### Command Pattern
```go
type Command interface {
    Execute() error
}
```

### Error Handling
- Descriptive error messages for users
- Wrap errors with context
- Return early on validation failures

### Configuration
- YAML-based (`internal/config/`)
- Environment variable overrides supported
- Paths: `.opencode/tcr/config.yml`

### State Management
- JSON serialization (`internal/state/`)
- Paths: `.opencode/tcr/state.json`
- Version field for future migrations

### File Operations
- Helper functions: GetTCRPath(), GetConfigPath(), GetStatePath()
- Clean path handling with filepath package
- Permission management for temp directories

---

## Critical Implementation Notes

### OverlayFS Mechanics
1. **LowerDir**: Original project directory (read-only from overlay perspective)
2. **UpperDir**: Writable layer where changes go (tmpfs for speed)
3. **WorkDir**: OverlayFS metadata/temporary space
4. **MergedDir**: Union view developers see & interact with
5. **Whiteouts**: OverlayFS marks deletions as special char devices (rdev=0)

### Mount Lifecycle
```
Mount (create overlay)
  ↓
[Development: write to upper layer]
  ↓
Test Passes? ──YES→ Commit (merge upper→lower) → Unmount
             ──NO → Discard (remove upper) → Unmount
```

### Storage Strategy for Overlays
- **Location**: `/tmp/fire-flow-overlay-<pid>/`
- **Why tmpfs**: Speed (in-memory FS)
- **Cleanup**: On unmount or discard
- **No project pollution**: All temp data outside project dir

---

## Acceptance Criteria Patterns

Each micro-step includes:
- ✓ Code compiles without errors
- ✓ All methods implemented per interface
- ✓ Unit tests pass (5+ tests minimum)
- ✓ Code follows existing patterns (error handling, naming)
- ✓ Acceptance criteria fully met
- ✓ No compiler warnings

---

## File Structure After Phase 1

```
internal/
├── overlay/
│   ├── types.go              # MountConfig, OverlayMount, Mounter interface
│   ├── types_test.go         # 5+ tests
│   ├── kernel.go             # KernelMounter (real Linux mounts)
│   ├── kernel_test.go        # 5+ tests (mostly unit, some integration)
│   ├── fake.go               # FakeMounter (for unit tests)
│   ├── fake_test.go          # 5+ tests
│   ├── overlay.go            # High-level orchestration
│   ├── overlay_test.go       # 5+ tests
│   ├── errors.go             # Custom error types
│   └── errors_test.go        # 3+ tests
├── config/
│   ├── config.go             # Updated with OverlayWorkDir
│   └── config_test.go
├── state/
│   ├── state.go              # Updated simplified state model
│   └── state_test.go
└── ...existing files...
```

---

## Memory Consolidation

### Key Facts Preserved from mem0
1. **Testing Uses FakeMounter**: Unit tests don't need permissions
2. **Integration Tests Marked**: `//go:build linux && integration`
3. **Each Step Reviewable**: <3 minutes per micro-step
4. **AAA Pattern**: Arrange/Act/Assert in all tests
5. **50+ Tests Target**: With 90%+ coverage goal
6. **No Sudo for Units**: Only integration tests need elevation

### Architecture Decisions Captured
1. **Overlay-first, Linux-first**: No cross-platform initially
2. **OverlayFS only**: Not FUSE or other mechanisms (yet)
3. **Filesystem-level enforcement**: Makes bypass impossible
4. **tmpfs for speed**: `/tmp/fire-flow-overlay-<pid>/`

### Testing Strategy Locked In
1. **Fast & repeatable**: Millisecond unit tests
2. **Fake + Real split**: FakeMounter for 95%, KernelMounter for edge cases
3. **Integration-only for real**: Only Step 1.10 uses real mounts
4. **No permission pollution**: Unit tests clean and isolated

---

## Next Steps (Immediately Available)

1. **Read the full prompt**: `/home/lewis/.claude/prompts/fire-flow-overlay-implementation-prompt.md`
2. **Verify Go setup**: `go version` (should be 1.25+)
3. **Start Phase 1, Step 1.1**: Create `internal/overlay/types.go`
   - Implement MountConfig struct
   - Implement OverlayMount struct
   - Define Mounter interface with 4 methods
   - Implement FakeMounter (basic versions)
4. **Write 5+ unit tests** for Step 1.1
5. **Run tests**: `go test ./internal/overlay/...`
6. **Verify**: No compiler errors, tests pass, covers types correctly

---

## Key Reminders

- **Breaking change**: This is not backward compatible
- **Requires permissions**: Users need sudo or CAP_SYS_ADMIN
- **Linux only**: Phases 1-3 (macOS deferred)
- **Use FakeMounter**: For 95% of tests (no permissions needed)
- **One step at a time**: Each is reviewable in <3 minutes
- **AAA tests**: Arrange/Act/Assert pattern
- **TDD approach**: Green state blocks code writes

---

## Configuration & Tools

### Development Environment
- **Go**: 1.25+
- **Platform**: Linux (kernel OverlayFS support required)
- **Test runner**: `go test ./...`
- **Linting**: Follow existing fire-flow patterns

### MCP Servers Available
- sequential-thinking: For complex reasoning
- serena: For architectural review
- beads: For issue tracking
- mem0: For memory persistence
- chrome-devtools: For debugging

### Available Skills
- bdd-beads-planner: For user stories
- gleam: (N/A for Go project)
- nushell: For scripting
- parallel-arch-review: For 5-lens design review
- frontend-design: (N/A for backend tool)

---

## Success Metrics

- ✓ Phase 1 complete: 50+ tests, 90%+ coverage
- ✓ All micro-steps reviewable in <3 minutes each
- ✓ Zero compiler warnings/errors
- ✓ No leaked mounts after 1000x mount/unmount cycles
- ✓ Unit tests run in <1 second total
- ✓ Integration tests (marked) run <5 seconds each
- ✓ Code follows existing fire-flow patterns

---

## Communication & Tracking

- **Memory System**: mem0 for persistent context
- **Issue Tracking**: Beads for multi-session work
- **Commit Format**: Include phase/step in message
- **Git Workflow**: Standard commit → test → push

---

*This document consolidates all architectural decisions, testing strategies, and implementation requirements from project memory for the next development phases.*
