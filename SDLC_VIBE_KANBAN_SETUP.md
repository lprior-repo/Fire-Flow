# Fire-Flow SDLC + Vibe Kanban Setup Guide

## Executive Summary

This document consolidates Software Development Lifecycle (SDLC) best practices implemented in the Fire-Flow project, integrated with Vibe Kanban task management for optimal AI-assisted development workflow.

---

## Part 1: SDLC Skills & Best Practices Added to Fire-Flow

### 1.1 Test-Driven Development (TDD)

**Implementation:** Red-Green-Refactor Cycle

```go
// RED: Write failing test first
func TestMounter_Mount_CreatesDirectories(t *testing.T) {
    m := NewFakeMounter()
    config := MountConfig{
        Source: "/src",
        Target: "/mnt",
        WorkDir: "/work",
    }
    mount, err := m.Mount(config)
    assert.NoError(t, err)
    assert.NotNil(t, mount)
}

// GREEN: Implement minimal code to pass
func (f *FakeMounter) Mount(config MountConfig) (*Mount, error) {
    return &Mount{...}, nil
}

// REFACTOR: Improve without breaking tests
func (f *FakeMounter) Mount(config MountConfig) (*Mount, error) {
    return &Mount{
        Source:  config.Source,
        Target:  config.Target,
        WorkDir: config.WorkDir,
    }, nil
}
```

**Benefits:**
- ✅ Confidence in code changes
- ✅ Living documentation via tests
- ✅ Faster debugging cycles
- ✅ Reduced regression bugs

**Fire-Flow Usage:**
- Unit tests in `internal/overlay/*_test.go`
- Integration tests for OverlayFS mounts
- Concurrent scenario testing

---

### 1.2 Git-Native Issue Tracking (Beads/bd CLI)

**Why Beads Over Traditional Trackers:**

| Aspect | Beads | Jira/Trello | GitHub Issues |
|--------|-------|-------------|---------------|
| **Source** | Git commits | External API | GitHub API |
| **Ownership** | Local control | Cloud vendor | GitHub |
| **Sync** | Automatic with git | Manual | Depends on CI |
| **Availability** | Works offline | Requires internet | Requires internet |
| **Cost** | Free (git) | Paid (at scale) | Free/Paid tiers |

**Fire-Flow Beads Structure:**
```
Fire-Flow-11f          (Epic: TCR Enforcer CLI + Kestra)
├── Fire-Flow-11f.1   (Feature: CLI State & Config)
│   ├── Fire-Flow-11f.1.1  (Task: Design state struct)
│   ├── Fire-Flow-11f.1.2  (Task: Implement init command)
│   ├── Fire-Flow-11f.1.3  (Task: YAML config loader)
│   └── Fire-Flow-11f.1.4  (Task: Status command)
├── Fire-Flow-11f.2   (Feature: TDD Gate CLI)
├── Fire-Flow-11f.3   (Feature: Test Execution)
└── ... [43 total tasks]
```

**Best Practices Implemented:**
- ✅ Hierarchical issue structure (Epic → Feature → Task)
- ✅ Consistent ID naming (Fire-Flow-XXXX)
- ✅ Priority levels (P0-P4)
- ✅ Type classification (task, feature, bug, docs)
- ✅ Automatic git integration (bd sync)

---

### 1.3 Multi-Dimensional Task Organization (Tagging System)

**Tag Categories:**

| Category | Examples | Purpose |
|----------|----------|---------|
| **Type** | task, feature, bug, docs, testing, enhancement | Classify work nature |
| **Epic** | tcr-enforcer-epic, overlayfs-epic | Large initiative grouping |
| **Component** | cli, overlay, tdd-gate, orchestration, integration | Technical area |
| **Status** | backlog, testing, done | Workflow state |
| **Priority** | P0 (critical) → P4 (backlog) | Urgency & importance |
| **Lifecycle** | refactor, testing, documentation | Phase of work |

**Example Task Fully Tagged:**
```
Fire-Flow-11f.7.3: "Test state persistence and concurrency"

Tags:
  • type:testing
  • component:tdd-gate
  • component:testing
  • epic:tcr-enforcer-epic
  • lifecycle:testing
  • status:testing
  • priority:P2
```

**Query Examples (Kanban filtering):**
- "Show all CLI tasks" → `component:cli`
- "What's ready for testing?" → `status:testing`
- "TCR Enforcer progress" → `epic:tcr-enforcer-epic`
- "Technical debt" → `lifecycle:refactor`

---

### 1.4 Component-Based Architecture

**Fire-Flow Components:**

```
Fire-Flow/
├── cmd/fire-flow/           (CLI entry point)
├── internal/overlay/        (Core OverlayFS logic)
│   ├── kernel.go           (Linux kernel mounts)
│   ├── fake.go             (Test doubles)
│   └── overlay.go          (High-level API)
├── .beads/                  (Issue tracking)
└── scripts/                 (Automation & sync)
```

**Separation of Concerns:**
- **CLI Layer** (cmd/): Handles user input, command routing
- **Domain Layer** (internal/overlay/): Business logic, mount operations
- **Test Doubles** (fake.go): Unit testing without system dependencies
- **Integration** (orchestration/): Kestra workflows, OpenCode hooks

---

### 1.5 Code Quality Standards (Martin Fowler Principles)

**Implemented Standards:**

✅ **Simplicity First**
- No premature optimization
- YAGNI (You Aren't Gonna Need It)
- Minimal abstractions

✅ **SOLID Principles**
- Single Responsibility (Mounter interface, separate handlers)
- Open/Closed (Extensible CLI commands)
- Dependency Injection (FakeMounter for tests)

✅ **Error Handling**
- Named return values for clarity
- Explicit error types
- Fail-fast with context

✅ **Testing Coverage**
- Unit tests for logic
- Integration tests for workflows
- Concurrent scenario testing

---

### 1.6 Iterative Development Workflow (Landing the Plane)

**Six-Step Session Completion Protocol:**

```bash
1. git status              # See all changes
2. git add -A             # Stage everything
3. bd sync                # Sync Beads issues
4. git commit -m "..."    # Commit with narrative
5. bd sync                # Final sync
6. git push               # Push to remote
```

**Purpose:** Ensure no work is lost, all tests pass, documentation updated, and changes backed up.

---

## Part 2: Vibe Kanban Setup & Integration

### 2.1 Installation & Launch

**Prerequisites:**
- Node.js (latest LTS)
- Authentication with Claude Code / OpenAI / other agents
- Git repositories initialized

**Launch:**
```bash
# Default (random port)
npx vibe-kanban

# Specific port
PORT=3000 npx vibe-kanban

# With remote SSH access
HOST=0.0.0.0 npx vibe-kanban
```

**Output:**
- Automatically opens in browser
- Shows recently active projects
- Displays task board for selected project

---

### 2.2 Configuration for Fire-Flow

**Environment Setup:**
```bash
# Port configuration
PORT=34107 npx vibe-kanban

# GitHub CLI (required for PR creation)
gh auth login
gh auth status

# Optional: Remote deployment
HOST=0.0.0.0 PORT=34107 npx vibe-kanban
```

**Initial Configuration:**
1. Add Fire-Flow repository (auto-detected or manual)
2. Set default coding agent (Claude Code recommended)
3. Configure editor integration (VSCode SSH or local)
4. Import tasks from Beads (via /tmp/beads-tasks-export.jsonl)

---

### 2.3 Vibe Kanban + Fire-Flow Integration

**Database Location:**
```
~/.local/share/vibe-kanban/db.sqlite
```

**Fire-Flow Project ID:**
```
522ec0f8-0cec-4533-8a2f-ac134da90b26
```

**Task Sync Workflow:**

```
Beads (bd list)
    ↓
JSONL Export
    ↓
Vibe Kanban DB Insert
    ↓
Web UI Display
    ↓
Agent Execution
    ↓
Git Worktree Isolation
```

---

### 2.4 Safe Agent Execution

**Vibe Kanban Safety Features:**

✅ **Git Worktree Isolation**
- Each task runs in isolated worktree
- Agents can't interfere with main branch
- Changes can be reviewed before merge

✅ **Autonomous Permissions**
- Agents run with `--yolo` flag by default
- No manual approval needed for each step
- Review outputs after completion

⚠️ **Risks to Manage:**
- Always review AI-generated code
- Maintain regular git backups
- Monitor resource usage
- Set task timeouts

**Recommended Safeguards:**
```yaml
# For Fire-Flow tasks:
max_iterations: 10        # Prevent infinite loops
timeout_minutes: 30       # Stop long-running tasks
require_tests: true       # Must pass tests
require_review: true      # Manual approval before merge
```

---

### 2.5 Workflow Integration with Beads

**Recommended Daily Workflow:**

```
Morning:
  1. bd list                              # See all open issues
  2. bd ready                             # Check work items
  3. npx vibe-kanban                      # Launch board
  4. Assign high-priority tasks to agents

During Day:
  5. Monitor Vibe Kanban task progress
  6. Review completed PRs
  7. bd sync                              # Keep Beads updated

End of Session:
  8. git status                           # Check uncommitted
  9. git add -A
  10. bd sync
  11. git commit
  12. bd sync
  13. git push                            # Landing the Plane
```

---

## Part 3: Best Practices Checklist

### 3.1 Task Creation (Beads)

- [ ] Create epic for large initiative (quarterly goal)
- [ ] Create feature for logical grouping (2-week work)
- [ ] Create tasks for individual units (1-2 day work)
- [ ] Add meaningful description with context
- [ ] Set priority (P0=urgent, P2=normal, P4=nice-to-have)
- [ ] Tag with type (task/feature/bug/docs)

### 3.2 Task Assignment (Vibe Kanban)

- [ ] Assign to appropriate agent (Claude Code preferred for Fire-Flow)
- [ ] Verify task has clear acceptance criteria
- [ ] Ensure task fits within agent capability
- [ ] Set reasonable timeout (30 min for CLI, 60 min for integration)
- [ ] Review task dependencies

### 3.3 Code Review Process

- [ ] Agent runs task in isolated git worktree
- [ ] Tests must pass before submission
- [ ] Code follows Fire-Flow conventions
- [ ] Changes documented in commit message
- [ ] No unintended side effects

### 3.4 Session Completion

- [ ] All changes committed with narrative message
- [ ] Tests passing locally and in CI
- [ ] Documentation updated (README, NEXT_STAGES)
- [ ] Beads issues synced and marked done
- [ ] Git push completes successfully

---

## Part 4: Fire-Flow Specific Recommendations

### 4.1 Component Development Order

**Phase 1: Overlay Foundations (Now)**
- [ ] KernelMounter Linux implementation
- [ ] FakeMounter test double
- [ ] Unit test coverage

**Phase 2: CLI Layer**
- [ ] init command (setup)
- [ ] tdd-gate command (test detection)
- [ ] run-tests command (execution)

**Phase 3: Orchestration**
- [ ] Kestra workflow creation
- [ ] OpenCode integration
- [ ] Webhook handlers

**Phase 4: Production Hardening**
- [ ] Performance testing
- [ ] Concurrent scenario testing
- [ ] Documentation

### 4.2 Tag-Based Project Planning

**See all TDD Gate work:**
```sql
SELECT * FROM tasks
WHERE tags LIKE '%component:tdd-gate%'
```

**See testing-phase items:**
```sql
SELECT * FROM tasks
WHERE tags LIKE '%status:testing%'
ORDER BY priority
```

**See architectural tasks needing design review:**
```sql
SELECT * FROM tasks
WHERE tags LIKE '%type:feature%'
  AND tags LIKE '%status:backlog%'
```

---

## Part 5: Troubleshooting

### Vibe Kanban Connection Issues

**Problem:** Cannot connect to Kanban at http://127.0.0.1:34107

**Solution:**
1. Verify process is running: `ps aux | grep vibe-kanban`
2. Check port: `lsof -i :34107`
3. Restart: Kill process and `PORT=34107 npx vibe-kanban`

### Task Import Failures

**Problem:** Tasks not appearing in Kanban

**Solution:**
1. Verify database exists: `ls ~/.local/share/vibe-kanban/db.sqlite`
2. Check project ID matches: `522ec0f8-0cec-4533-8a2f-ac134da90b26`
3. Re-run import script: `python3 scripts/insert-beads-to-kanban.py`

### Beads Sync Issues

**Problem:** bd sync fails with "Your index contains uncommitted changes"

**Solution:**
```bash
git add -A                          # Stage changes
git commit -m "Work in progress"   # Commit first
bd sync                            # Now sync works
```

---

## Part 6: Measuring Success

### Key Metrics

| Metric | Target | How to Measure |
|--------|--------|----------------|
| **Test Coverage** | >85% | `go test -cover ./...` |
| **Task Completion Rate** | >80% / sprint | bd list + Vibe stats |
| **Issue Resolution Time** | <3 days avg | Beads metadata |
| **Code Quality** | Martin Fowler standards | Code review checklist |
| **Deployment Success** | 100% with tests passing | CI/CD logs |

### Dashboard View (Vibe Kanban)

```
Fire-Flow Project Status:
├── Total Tasks: 43
├── Completed: 5 (11.6%)
├── In Progress: 3 (6.9%)
├── Testing: 8 (18.6%)
├── Backlog: 27 (62.8%)
└── By Component:
    ├── overlay: 8
    ├── tdd-gate: 6
    ├── cli: 10
    ├── orchestration: 5
    └── other: 14
```

---

## Part 7: Resources & References

### Official Documentation
- [Vibe Kanban Getting Started](https://www.vibekanban.com/docs/getting-started)
- [Vibe Kanban GitHub](https://github.com/BloopAI/vibe-kanban)
- [Fire-Flow Project Structure](./QWEN.md)
- [Implementation Stages](./NEXT_STAGES_FROM_MEM0.md)

### Development Standards
- **Testing:** [Go Testing Best Practices](https://golang.org/doc/effective_go#testing)
- **Code Quality:** Martin Fowler Code Quality Standards
- **Git Workflow:** [Git Branching Model](https://nvie.com/posts/a-successful-git-branching-model/)
- **TDD:** [Test-Driven Development by Example](https://www.obeythelaws.com/practices/test-driven-development)

### Commands Reference
```bash
# Beads CLI
bd list                 # Show all issues
bd ready                # Show ready items
bd sync                 # Sync with git
bd import               # Import JSONL

# Vibe Kanban
npx vibe-kanban         # Launch board
PORT=3000 npx vibe-kanban  # Custom port

# Fire-Flow Scripts
python3 scripts/insert-beads-to-kanban.py    # Import tasks
python3 scripts/add-tags-to-kanban.py        # Add tags
```

---

## Conclusion

Fire-Flow demonstrates enterprise-grade SDLC practices through:

1. **TDD-First Development** - Red-green-refactor for confidence
2. **Git-Native Tracking** - Beads for persistent issue management
3. **Intelligent Organization** - Multi-dimensional tagging system
4. **Component Architecture** - Clean separation of concerns
5. **Quality Standards** - Martin Fowler principles throughout
6. **Safe Automation** - Vibe Kanban with isolated task execution
7. **Iterative Workflow** - Landing the Plane protocol for consistency

This integrated approach enables rapid, reliable development with AI-assisted code generation while maintaining code quality and team accountability.

---

**Document Version:** 1.0
**Last Updated:** 2025-12-23
**Maintained By:** Fire-Flow Development Team
