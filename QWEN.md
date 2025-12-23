# Fire-Flow Project Guide: TDD, Go, Beads & Agent Instructions

**Last Updated**: 2025-12-23
**Priority**: 🔴 Bd (Beads) CLI is #1 - Master this first
**Project**: Fire-Flow (TCR Enforcement via OverlayFS)
**Language**: Go 1.25+
**Methodology**: Test-Driven Development (TDD) + Idiomatic Go
**Issue Tracking**: Beads (bd CLI tool) - MANDATORY

---

## 🚀 PRIORITY #1: BEADS (BD CLI TOOL) - MASTER THIS FIRST

### What is Beads?
**Beads** is a git-native, AI-friendly issue tracking system that lives in your `.beads/` directory. It's the authoritative source of work and dependencies for this project.

### Quick Start (5 minutes)
```bash
# 1. Onboard to Beads (MANDATORY first step)
bd onboard

# 2. View available work (do this BEFORE coding)
bd ready

# 3. Pick an issue
bd show <issue-id>

# 4. Start work (claims the issue to you)
bd update <issue-id> --status in_progress

# 5. Complete work (close when done)
bd close <issue-id>

# 6. Sync with git
bd sync
```

### Essential Bd Commands (Reference)

| Command | Purpose | Example |
|---------|---------|---------|
| `bd onboard` | Initialize Beads in project | `bd onboard` |
| `bd ready` | Show available work | `bd ready` |
| `bd show <id>` | View issue details | `bd show mp-123` |
| `bd create <title>` | Create new issue | `bd create "Implement mount()"` |
| `bd update <id> --status <status>` | Change issue status | `bd update mp-123 --status in_progress` |
| `bd close <id>` | Mark issue complete | `bd close mp-123` |
| `bd list` | List all issues | `bd list` |
| `bd list --status in_progress` | View your current work | `bd list --status in_progress` |
| `bd sync` | Sync issues with git | `bd sync` |
| `bd dependencies <id>` | Show dependencies | `bd dependencies mp-123` |
| `bd assign <id> --to lewis` | Assign issue | `bd assign mp-123 --to lewis` |

### Bd Workflow Checklist (Before Every Work Session)
- [ ] Run `bd ready` - See what needs doing
- [ ] Read issue details with `bd show <id>` - Understand requirements
- [ ] Run `bd update <id> --status in_progress` - Claim the work
- [ ] Check dependencies: `bd dependencies <id>` - Know what blocks you
- [ ] Start coding (with TDD!)
- [ ] When done, run `bd close <id>` and `bd sync`

### Understanding Bd Status Flow
```
Available (unassigned)
    ↓
in_progress (you claim it with bd update)
    ↓
in_review (optional, if peer review needed)
    ↓
closed (done)
```

### Bd + Git Integration
```bash
# Issues are stored in .beads/issues.jsonl (git-tracked)
# When you close an issue:
bd close mp-123
bd sync              # Updates .beads/issues.jsonl

# This should trigger:
git status           # Shows modified .beads/issues.jsonl
git add .beads/
git commit -m "Close: mp-123 - Implement mount()"
git push
```

---

## 📊 PROJECT STRUCTURE

### Directory Layout
```
/home/lewis/src/Fire-Flow/
├── cmd/                          # Command-line entry points
│   └── fire-flow/
│       ├── main.go              # CLI dispatcher
│       └── commands/            # Command implementations
│
├── internal/                    # Private packages
│   ├── overlay/                # OverlayFS implementation (PHASE 1)
│   │   ├── types.go            # Core types (MountConfig, Mounter)
│   │   ├── kernel.go           # Real KernelMounter
│   │   ├── fake.go             # FakeMounter for tests
│   │   ├── errors.go           # Error types
│   │   ├── overlay.go          # High-level orchestration
│   │   ├── *_test.go           # Unit tests
│   │   └── integration_test.go  # Real mount tests
│   │
│   ├── config/                 # Configuration management
│   │   ├── config.go           # Config loading/parsing
│   │   └── config_test.go
│   │
│   ├── state/                  # State persistence
│   │   ├── state.go            # State struct + JSON I/O
│   │   └── state_test.go
│   │
│   └── watch/                  # Watch workflow (PHASE 2)
│       └── watcher.go
│
├── .beads/                      # Beads issue tracking
│   └── issues.jsonl            # Issues file (git-tracked)
│
├── .opencode/tcr/              # Fire-Flow config
│   ├── config.yml              # User configuration
│   └── state.json              # Runtime state
│
├── go.mod                       # Go module definition
├── go.sum                       # Dependency hashes
│
├── QWEN.md                      # This file (Agent instructions)
├── NEXT_STAGES_FROM_MEM0.md    # Implementation spec (reference)
├── README.md                    # User documentation
├── Taskfile.yml                 # Task automation (Taskmaster)
│
└── tests/                       # Test fixtures
    └── fixtures/               # Sample data, config files
```

### Key Directories Explained

**`cmd/fire-flow/`**: Entry point for the `fire-flow` CLI binary. Dispatches to subcommands.

**`internal/overlay/`**: The heart of Phase 1. All OverlayFS mounting/unmounting logic lives here.

**`.beads/issues.jsonl`**: The source of truth for work. Every line is a Beads issue in JSONL format. This is git-tracked.

**`.opencode/tcr/`**: Configuration and state live here, outside the project root. No project pollution.

---

## 🧪 TEST-DRIVEN DEVELOPMENT (TDD) IN GO

### Core Principle: Red → Green → Refactor

**You write the test FIRST, then the implementation.**

```
┌─────────────┐
│   WRITE     │
│   FAILING   │  Red: Test fails, code doesn't exist
│    TEST     │
└──────┬──────┘
       ↓
┌─────────────┐
│   WRITE     │
│   MINIMAL   │  Green: Minimal code to make test pass
│     CODE    │
└──────┬──────┘
       ↓
┌─────────────┐
│  REFACTOR   │  Refactor: Improve without changing behavior
│    CODE     │
└──────┬──────┘
       ↓
   [Repeat for next feature]
```

### TDD Example: Implementing Mount()

**Step 1: Write the failing test (RED)**
```go
// types_test.go
func TestMounter_Mount_CreatesDirectories(t *testing.T) {
    // Arrange
    m := NewFakeMounter()
    config := MountConfig{
        LowerDir:  "/tmp/lower",
        UpperDir:  "/tmp/upper",
        WorkDir:   "/tmp/work",
        MergedDir: "/tmp/merged",
    }

    // Act
    mount, err := m.Mount(config)

    // Assert
    assert.NoError(t, err)
    assert.NotNil(t, mount)
    assert.Equal(t, config, mount.Config)
}
```

**Step 2: Write minimal code to pass (GREEN)**
```go
// types.go
func (f *FakeMounter) Mount(config MountConfig) (*OverlayMount, error) {
    return &OverlayMount{
        Config:    config,
        MountedAt: time.Now(),
        PID:       os.Getpid(),
    }, nil
}
```

**Step 3: Refactor for quality (REFACTOR)**
```go
// Add error handling, validation, better structure
func (f *FakeMounter) Mount(config MountConfig) (*OverlayMount, error) {
    // Validate config
    if config.LowerDir == "" {
        return nil, fmt.Errorf("lowerdir required")
    }
    if _, exists := f.mounts[config.MergedDir]; exists {
        return nil, fmt.Errorf("already mounted at %s", config.MergedDir)
    }

    // Create mount
    mount := &OverlayMount{
        Config:    config,
        MountedAt: time.Now(),
        PID:       os.Getpid(),
    }

    f.mounts[config.MergedDir] = mount
    return mount, nil
}
```

### TDD Best Practices in Fire-Flow

**1. Test Structure: AAA (Arrange-Act-Assert)**
```go
func TestSomething(t *testing.T) {
    // Arrange: Set up test data
    m := NewFakeMounter()
    config := createTestConfig()

    // Act: Perform the operation
    result, err := m.Mount(config)

    // Assert: Verify the outcome
    assert.NoError(t, err)
    assert.NotNil(t, result)
}
```

**2. Table-Driven Tests for Multiple Cases**
```go
func TestMounter_Mount_ErrorCases(t *testing.T) {
    tests := []struct {
        name      string
        config    MountConfig
        wantErr   bool
        errMsg    string
    }{
        {
            name:    "missing_lowerdir",
            config:  MountConfig{UpperDir: "/tmp/upper"},
            wantErr: true,
            errMsg:  "lowerdir required",
        },
        {
            name:    "already_mounted",
            config:  MountConfig{MergedDir: "/tmp/merged"},
            wantErr: true,
            errMsg:  "already mounted",
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            m := NewFakeMounter()
            _, err := m.Mount(tt.config)

            if tt.wantErr {
                assert.Error(t, err)
                assert.Contains(t, err.Error(), tt.errMsg)
            } else {
                assert.NoError(t, err)
            }
        })
    }
}
```

**3. Use FakeMounter in Unit Tests (No Permissions)**
```go
// This runs fast, no permissions needed
func TestOverlay_Mount_Logic(t *testing.T) {
    m := NewFakeMounter()  // ← Fast, no syscalls
    // Test logic here
}
```

**4. Use KernelMounter Only in Integration Tests**
```go
//go:build linux && integration

func TestKernelMounter_RealMount(t *testing.T) {
    if os.Geteuid() != 0 {
        t.Skip("requires root")
    }
    k := NewKernelMounter()  // ← Real syscalls
    // Test real mount behavior
}
```

### Running Tests

```bash
# Run all tests
go test ./...

# Run specific package
go test ./internal/overlay/...

# Run with verbose output
go test -v ./internal/overlay/...

# Run with coverage
go test -cover ./internal/overlay/...

# Run only unit tests (exclude integration)
go test ./internal/overlay/... -tags=!integration

# Run only integration tests
go test ./internal/overlay/... -tags=integration

# Run with race detector
go test -race ./...

# Run specific test
go test -run TestMounter_Mount ./internal/overlay/...
```

### Test Coverage Goals
- **Target**: 90%+ code coverage
- **Minimum**: 50+ unit tests for Phase 1
- **Speed**: All unit tests complete in <1 second
- **Integration tests**: <5 seconds each

---

## 🎯 IDIOMATIC GO PATTERNS

### 1. Error Handling (Not Try-Catch)

**❌ Bad: Ignoring errors**
```go
err := doSomething()
// Oops, forgot to check err!
```

**✅ Good: Explicit error handling**
```go
err := doSomething()
if err != nil {
    return fmt.Errorf("failed to do something: %w", err)
}
```

**✅ Better: Context-aware errors**
```go
err := doSomething()
if err != nil {
    if err == syscall.EPERM {
        return fmt.Errorf("permission denied: requires sudo or CAP_SYS_ADMIN")
    }
    return fmt.Errorf("mount failed: %w", err)
}
```

### 2. Interfaces Define Behavior

Instead of classes with inheritance, Go uses small interfaces:

```go
// Small, focused interface
type Mounter interface {
    Mount(config MountConfig) (*OverlayMount, error)
    Unmount(mount *OverlayMount) error
    Commit(mount *OverlayMount) error
    Discard(mount *OverlayMount) error
}

// Multiple implementations without inheritance
type FakeMounter struct { /* ... */ }
type KernelMounter struct { /* ... */ }

// Both implement Mounter
func (f *FakeMounter) Mount(config MountConfig) (*OverlayMount, error) { /* ... */ }
func (k *KernelMounter) Mount(config MountConfig) (*OverlayMount, error) { /* ... */ }
```

### 3. Composition Over Inheritance

**❌ Bad: Deep inheritance hierarchies**
```
File → IO → Closeable → Resource
```

**✅ Good: Simple composition**
```go
type FileHandler struct {
    file *os.File
    // No inheritance, just composition
}

func (f *FileHandler) Close() error {
    return f.file.Close()
}
```

### 4. Named Return Values (Use Sparingly)

```go
// ✅ Good: Clear what's returned
func Mount(config MountConfig) (mount *OverlayMount, err error) {
    // ... implementation
    return // Returns (mount, err) automatically
}

// ✅ Also good: Less magical
func Mount(config MountConfig) (*OverlayMount, error) {
    return &OverlayMount{...}, nil
}
```

### 5. Defer for Cleanup

```go
func copyFile(src, dst string) error {
    srcFile, err := os.Open(src)
    if err != nil {
        return fmt.Errorf("open source: %w", err)
    }
    defer srcFile.Close()  // ← Guaranteed to run

    dstFile, err := os.Create(dst)
    if err != nil {
        return fmt.Errorf("create destination: %w", err)
    }
    defer dstFile.Close()  // ← Even if Copy fails

    _, err = io.Copy(dstFile, srcFile)
    return err
}
```

### 6. Package Organization

```go
// All overlay code in one package
package overlay

// Public (exported): starts with uppercase
func NewFakeMounter() *FakeMounter { }
type Mounter interface { }

// Private (unexported): starts with lowercase
func isWhiteout(info os.FileInfo) bool { }
type fakeMount struct { }
```

### 7. Nil is a Valid Return

```go
// ✅ Good: Handle nil explicitly
func (f *FakeMounter) Unmount(mount *OverlayMount) error {
    if mount == nil {
        return nil  // Safe to call with nil
    }
    delete(f.mounts, mount.Config.MergedDir)
    return nil
}
```

### 8. Variadic Functions (When Appropriate)

```go
// Good for optional parameters
func NewConfig(required string, opts ...ConfigOption) *Config {
    c := &Config{Required: required}
    for _, opt := range opts {
        opt(c)
    }
    return c
}
```

### 9. Idiomatic Loops

```go
// ✅ Simple iteration
for i := 0; i < len(items); i++ { }

// ✅ Range over slice
for i, item := range items { }

// ✅ Range ignore index
for _, item := range items { }

// ✅ Walk directories
filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
    // Process each path
    return nil
})
```

### 10. Testing is First-Class

```go
// ✅ Tests are in same package
package overlay

// tests/files go in same dir
// types.go
// types_test.go  ← Same package, _test.go suffix
```

---

## 🔧 AGENT INSTRUCTIONS: HOW TO WORK ON FIRE-FLOW

### Phase 0: Session Startup (Do This First!)

**MANDATORY first steps:**

```bash
# 1. Verify you're in the right place
cd /home/lewis/src/Fire-Flow
pwd  # Should show /home/lewis/src/Fire-Flow

# 2. Check available work with Beads
bd ready

# 3. Pick an issue and claim it
bd show <issue-id>           # Read details
bd update <issue-id> --status in_progress  # Claim it

# 4. Search memory for context
# (Using mem0 MCP server)
# Query: "Fire-Flow TDD patterns" or "Phase 1 overlay implementation"
```

### Phase 1: Understanding the Task

For each issue in `bd ready`:

1. **Read the issue completely**: `bd show <issue-id>`
2. **Check dependencies**: `bd dependencies <issue-id>`
3. **Understand acceptance criteria**: Listed in the issue
4. **Check test requirements**: How many tests? What coverage?
5. **Review context**: Read NEXT_STAGES_FROM_MEM0.md for details

### Phase 2: TDD Implementation Cycle

For each feature or bug fix:

**STEP 1: Write Failing Test (RED)**
```bash
# Create test file (if new)
touch internal/overlay/feature_test.go

# Write test that describes desired behavior
# Run test to verify it fails
go test -run TestYourFeature ./internal/overlay/... -v
# Should see: FAIL
```

**STEP 2: Write Minimal Code (GREEN)**
```bash
# Add minimal implementation to make test pass
# Run test again
go test -run TestYourFeature ./internal/overlay/... -v
# Should see: PASS
```

**STEP 3: Refactor (REFACTOR)**
```bash
# Improve code quality, add error handling, etc.
# Run full test suite
go test ./internal/overlay/...
# Should see: all tests pass
```

**STEP 4: Verify Coverage**
```bash
go test -cover ./internal/overlay/...
# Target: 90%+ coverage
```

### Phase 3: Code Review Checklist

Before committing, verify:

- [ ] **Tests Pass**: `go test ./...` shows all green
- [ ] **Coverage High**: 90%+ for your code
- [ ] **No Warnings**: `go vet ./...` is clean
- [ ] **Follows Idiomatic Go**: Named returns, error handling, composition
- [ ] **Uses FakeMounter**: Unit tests don't need sudo
- [ ] **Integration Tests Marked**: `//go:build linux && integration`
- [ ] **Table-Driven**: Multiple test cases use table pattern
- [ ] **AAA Pattern**: Arrange/Act/Assert in tests
- [ ] **Error Messages**: Clear and helpful to users
- [ ] **Bd Issue Updated**: Status changed via `bd update`

### Phase 4: Using MCP Servers

**mem0 (Memory Persistence)**
```bash
# Search for context
# Before starting work: "Fire-Flow Phase 1 MountConfig implementation"
# After finishing: Save learnings
```

**sequential-thinking**
```bash
# For complex architectural decisions
# Helps reason through difficult problems
```

**Codanna (Code Analysis)**
```bash
# Pull up when you have finished code
# Ensures idiomatic Go and best practices
# Uses Martin Fowler code quality standards
```

### Phase 5: Landing the Plane - SESSION COMPLETION

**🚨 CRITICAL: Work is NOT complete until git push succeeds! 🚨**

**You MUST complete ALL steps below before stopping work:**

#### Step 1: Update Issue Status
```bash
# If work is done, close it
bd close <issue-id>

# If work is in progress, update status
bd update <issue-id> --status in_progress

# If you discovered new work, create issues
bd create "Bug: Mount fails with X error"
bd create "Feature: Add Y functionality"
```

#### Step 2: Run Quality Gates (If Code Changed)
```bash
# Tests MUST pass
go test ./...

# No compiler warnings
go vet ./...

# Coverage good
go test -cover ./...

# Build succeeds
go build -o fire-flow ./cmd/fire-flow/
```

#### Step 3: Sync Beads with Git
```bash
# This updates .beads/issues.jsonl
bd sync

# Verify changes
git status
# Should show: .beads/issues.jsonl modified
```

#### Step 4: MANDATORY Git Push
```bash
# Rebase to avoid conflicts
git pull --rebase

# Add your changes
git add .

# Commit with clear message
git commit -m "Phase 1: Implement MountConfig and Mounter interface

- Add MountConfig struct with 4 fields (LowerDir, UpperDir, WorkDir, MergedDir)
- Define Mounter interface (Mount, Unmount, Commit, Discard)
- Implement FakeMounter for unit testing
- Add 5+ unit tests with 90%+ coverage
- Update Beads issue mp-123

Tests: PASS (5 tests, 100% coverage)
"

# PUSH TO REMOTE (MANDATORY!)
git push

# VERIFY SUCCESS
git status
# Must show: "Your branch is up to date with origin/main"
```

**🚨 If push fails, FIX IT and retry until it succeeds! 🚨**

```bash
# Push failed? Handle the error:
# Conflicts: resolve manually, commit, push again
# Permission: check SSH keys
# Remote rejected: check branch protection rules

# DON'T just stop and say "ready when you are"
# YOU must push successfully
```

#### Step 5: Cleanup
```bash
# Clear any stashes
git stash list
git stash drop  # if applicable

# Prune remote branches
git remote prune origin

# Verify everything is clean
git status  # Should show working tree clean
```

#### Step 6: Verify and Hand Off
```bash
# Final check: Show what was done
git log -1 --stat  # Show last commit and files changed
git status         # Should be clean

# Update memory with session summary
# (mem0): "Completed Phase 1 Step 1.1 - Implemented types.go with MountConfig, OverlayMount, Mounter, FakeMounter"

# Hand off for next session
echo "Work completed and pushed successfully"
```

### 🚨 CRITICAL RULES (YOU MUST FOLLOW THESE)

1. **WORK IS NOT COMPLETE UNTIL GIT PUSH SUCCEEDS**
   - No exceptions
   - No "ready when you are"
   - Push must complete successfully

2. **NEVER STOP BEFORE PUSHING**
   - Leaving work locally = lost work
   - Other sessions can't see it
   - Defeats purpose of git

3. **IF PUSH FAILS, FIX IT**
   - Handle conflicts manually
   - Check SSH keys
   - Resolve remote issues
   - RETRY UNTIL IT SUCCEEDS

4. **UPDATE BEADS BEFORE COMMITTING**
   - Close/update issues with `bd update`
   - Run `bd sync`
   - This updates `.beads/issues.jsonl`

5. **RUN QUALITY GATES**
   - All tests pass
   - No compiler warnings
   - Coverage 90%+

6. **CLEAR COMMIT MESSAGES**
   - Reference the Bd issue
   - Explain what and why
   - Format: "Phase X, Step Y: Description"

---

## 🔍 MARTIN FOWLER CODE QUALITY CHECKLIST

Apply these principles from Martin Fowler's refactoring patterns:

### Smell Detection
- [ ] **Long Method**: Any function >30 lines? Refactor.
- [ ] **Duplicate Code**: Same logic twice? Extract it.
- [ ] **Comments Necessary**: Code should explain itself.
- [ ] **Large Parameter List**: >3 params? Use a config struct.
- [ ] **Temporary Variables**: Reduce intermediate state.

### Refactoring Principles
- [ ] **Extract Function**: Pull out helper functions.
- [ ] **Replace Temp with Query**: Avoid temporary variables.
- [ ] **Inline Variable**: Remove unnecessary intermediate vars.
- [ ] **Rename for Clarity**: Names should be intent-revealing.

### Testing Quality (From TDD Guide)
- [ ] **AAA Pattern**: Arrange/Act/Assert
- [ ] **One Assert**: Try one assertion per test
- [ ] **Clear Names**: Test name describes what it tests
- [ ] **DAMP Over DRY**: Tests should be explicit
- [ ] **No Test Interdependence**: Each test stands alone

---

## 📚 REFERENCE DOCUMENTS

**Always available for context:**

1. **NEXT_STAGES_FROM_MEM0.md** - Complete Phase 1-4 implementation spec
   - 30+ sections with detailed code examples
   - Configuration templates
   - Error scenarios and recovery
   - Performance and security considerations

2. **QWEN.md** - This file (agent instructions)
   - TDD principles
   - Idiomatic Go patterns
   - Beads workflow
   - Session completion procedures

3. **README.md** - User-facing documentation

4. **Beads Issues** - Always check `bd ready` for latest work

---

## 💾 SESSION SUMMARY TEMPLATE

When ending a session, save this to mem0:

```
Fire-Flow Session [DATE]:

COMPLETED:
- [Issue ID]: [Description] ✓
- [Issue ID]: [Description] ✓

LEARNINGS:
- [What you learned about TDD/Go/Beads]

IN PROGRESS:
- [Issue ID]: [What remains]

BLOCKERS:
- [Any issues blocking progress]

NEXT STEPS:
- [What to work on next session]
```

---

## ❓ COMMON QUESTIONS

**Q: Do I need to write tests first?**
A: YES. Red-Green-Refactor means test first, always.

**Q: Can I use KernelMounter in unit tests?**
A: NO. Use FakeMounter in unit tests (no permissions needed). Only KernelMounter in integration tests marked with `//go:build linux && integration`.

**Q: What if I can't push due to conflicts?**
A: Resolve manually, then commit and push again. Don't give up.

**Q: Should I close the Bd issue before or after push?**
A: Before push. Use `bd close`, then `bd sync`, then `git push`.

**Q: What if a test needs special setup?**
A: Use table-driven tests. Set up everything in the test function.

**Q: How do I know if code is "idiomatic"?**
A: Small interfaces, explicit error handling, composition over inheritance, `defer` for cleanup.

---

*This guide is the north star for working on Fire-Flow. Read it before starting work. Follow it during development. Reference it when unsure.*

**Last truth: Work is NOT complete until `git push` succeeds and `git status` shows "up to date with origin".**
