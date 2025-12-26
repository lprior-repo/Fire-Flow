# Architecture Decision Records: TCR Enforcer

## Document Info

| Field | Value |
|-------|-------|
| Version | 0.1.0 |
| Status | Draft |
| Author | Lewis |
| Created | 2025-12-12 |

---

## ADR-001: Use OpenCode Plugin Architecture (Not Custom Tool)

### Status
Accepted

### Context
OpenCode offers two extension mechanisms:
1. **Custom Tools**: Functions the LLM can invoke directly
2. **Plugins**: Event-driven hooks into the OpenCode lifecycle

We need to intercept file operations before and after they happen.

### Decision
Use the Plugin architecture.

### Rationale
- Plugins can hook `tool.execute.before` to BLOCK operations (tools cannot)
- Plugins can hook `tool.execute.after` to trigger side effects (git commit/revert)
- Plugins can self-register tools if needed (superset of tool functionality)
- Tools are passive (wait to be called); we need proactive interception

### Consequences
- More complex implementation than a simple tool
- Must understand OpenCode's event lifecycle
- Can fully control the development loop

---

## ADR-002: Store Test Results in JSON File (Not In-Memory)

### Status
Accepted

### Context
The TDD gate needs to know if failing tests exist. Options:
1. Run tests on every check (slow, ~seconds)
2. Cache in plugin memory (lost on restart)
3. Write to disk from test reporter, read in plugin

### Decision
Use disk-based JSON file at `.opencode/tcr/data/test.json`.

### Rationale
- Test reporter (vitest/jest) runs in separate process from plugin
- Disk is the simplest IPC mechanism
- Survives OpenCode restarts
- Human-readable for debugging
- Sub-millisecond read time for small JSON

### Consequences
- Need to implement test reporters for each framework
- File could be stale if tests not run recently
- Must handle missing/corrupt file gracefully

### Alternatives Considered
- **Unix socket**: Complex, overkill for this use case
- **SQLite**: Unnecessary for simple key-value data
- **Environment variables**: Can't persist structured data

---

## ADR-003: Use YAML for User Configuration

### Status
Accepted

### Context
Users need to configure test commands, patterns, etc. Options:
1. JSON (strict, no comments)
2. YAML (readable, supports comments)
3. TOML (less common in JS ecosystem)
4. TypeScript config (complex to load)

### Decision
Use YAML for `config.yml`.

### Rationale
- Human-readable and editable
- Supports comments (important for documenting options)
- Common in DevOps/platform tooling
- Simple to parse with `yaml` package
- Familiar to target audience (platform engineers)

### Consequences
- Additional dependency (`yaml` package)
- Must validate against schema
- Users must learn YAML syntax (minimal barrier)

---

## ADR-004: Block Implementation Files, Allow Test Files

### Status
Accepted

### Context
TDD requires writing tests first. How do we distinguish test files from implementation files?

### Decision
Use configurable regex patterns to identify test files. Default patterns:
- `\.test\.[jt]sx?$`
- `\.spec\.[jt]sx?$`
- `_test\.go$`
- `test_.*\.py$`
- `Test\.php$`
- `_test\.rs$`

### Rationale
- Covers major languages and conventions
- User can override for non-standard setups
- Simple regex matching is fast
- False positives (blocking a test file) are annoying but recoverable
- False negatives (allowing impl file) defeat the purpose

### Consequences
- May need to expand patterns for edge cases
- Users with unusual naming must configure manually
- Pattern matching adds small overhead per operation

---

## ADR-005: Auto-Commit with "WIP" Message

### Status
Accepted

### Context
TCR requires committing on green. What commit message to use?

Options:
1. Generic "WIP" for all commits
2. Timestamp-based messages
3. AI-generated messages
4. File-based messages ("Updated foo.ts")

### Decision
Use configurable message, default "WIP". Users squash before push.

### Rationale
- TCR creates many small commits (potentially hundreds)
- Individual messages don't matter—they'll be squashed
- "WIP" is universally understood
- AI-generated messages would be slow and wasteful
- Kent Beck's original TCR uses simple messages

### Consequences
- Git history looks messy until squashed
- Must provide squash helper or documentation
- `--no-verify` needed to skip pre-commit hooks

### Workflow
```
[development]
WIP → WIP → WIP → WIP → squash → "feat: add user auth"
```

---

## ADR-006: Hard Revert on Test Failure (Not Stash)

### Status
Accepted

### Context
When tests fail, TCR reverts. How?

Options:
1. `git reset --hard HEAD` (destructive)
2. `git stash` (preserves code)
3. `git checkout -- .` (unstaged only)
4. Copy to backup file before revert

### Decision
Use `git reset --hard HEAD` (true TCR).

### Rationale
- TCR's power comes from the "pain" of losing code
- Stashing defeats the purpose (agent would just unstash)
- Forces genuinely small steps
- Last committed state is always green
- "Relaxed" mode available for those who want softer enforcement

### Consequences
- Code is truly lost on revert
- Agent learns to take smaller steps
- May frustrate users initially
- Relaxed mode provides escape hatch

---

## ADR-007: Self-Protection via Path Blocking

### Status
Accepted

### Context
AI agents will try to disable the enforcer. How do we prevent this?

Options:
1. Block writes to protected paths in plugin
2. OS-level file permissions
3. Separate process with IPC
4. Accept that agents can disable (rely on prompting)

### Decision
Block writes and shell commands that target protected paths.

### Rationale
- Plugin runs before tool execution, can throw to block
- Covers both `write`/`edit` tools and `bash` tool
- No external dependencies
- OS permissions are fragile and OS-specific
- Cannot trust prompting alone

### Protected Paths
```
opencode.json
.opencode/plugin/
.opencode/tcr/
.git/
```

### Consequences
- Agent sees clear error message
- Determined user can still disable manually
- Must also block shell commands that touch these paths

---

## ADR-008: Provide "Relaxed" Mode

### Status
Accepted

### Context
Full TCR (with revert) may be too aggressive for some users/projects.

### Decision
Offer multiple modes:
- `both`: Full TDD + TCR (default)
- `tdd`: Only TDD gate, no auto-commit/revert
- `tcr`: Only TCR loop, no TDD gate
- `relaxed`: TCR without revert (just skip commit on red)
- `off`: Disabled

### Rationale
- Different projects have different needs
- Learning curve—start relaxed, move to strict
- Some legacy projects can't do TDD
- Some projects want TCR but not TDD

### Consequences
- More configuration complexity
- Must test all mode combinations
- Clear documentation needed

---

## ADR-009: Track Statistics for Feedback

### Status
Accepted

### Context
Users benefit from seeing their commit/revert ratio and patterns.

### Decision
Track and persist statistics:
- Total commits
- Total reverts
- Current revert streak
- Last revert reason
- Session start time

### Rationale
- Gamification encourages smaller steps
- Streak warnings help agents learn
- Data useful for process improvement
- Minimal storage overhead

### Consequences
- Must persist stats to disk
- Privacy consideration (local only)
- Could expose via tool for agent to query

---

## ADR-010: Debounce Test Execution

### Status
Accepted

### Context
Rapid consecutive edits could trigger many test runs.

### Decision
Debounce test execution with configurable delay (default 100ms).

### Rationale
- Agent might make several quick edits
- Running tests after each is wasteful
- 100ms groups rapid changes into single test run
- User can tune based on their workflow

### Consequences
- Slight delay before test feedback
- Must handle debounce cancellation properly
- Edge case: long-running test interrupted by new edit

---

## ADR-011: Use Bun Shell ($) for Commands

### Status
Accepted

### Context
Plugin needs to run git commands and test commands.

Options:
1. Bun's `$` shell API (provided in context)
2. Node's `child_process`
3. `execa` library

### Decision
Use Bun's `$` shell API provided in plugin context.

### Rationale
- Already available in plugin context (no dependency)
- Clean template literal syntax
- Proper escaping built-in
- Async/await friendly
- OpenCode runs on Bun

### Consequences
- Tied to Bun runtime
- Shell syntax may vary across OS (minimal concern)
- Must handle errors from shell commands

---

## ADR-012: Reporter Per Test Framework

### Status
Accepted

### Context
Different test frameworks have different reporter APIs.

Options:
1. Single reporter that parses stdout (fragile)
2. Per-framework reporters
3. TAP output standardization

### Decision
Implement separate reporters for each major framework.

### Rationale
- Native integration is most reliable
- TAP parsing is fragile and loses information
- Framework-specific reporters can capture more detail
- Users only install reporter for their framework

### Initial Support
1. Vitest (priority—modern, popular)
2. Jest (most common)
3. pytest (Python)
4. Go test
5. PHPUnit, Rust (future)

### Consequences
- More code to maintain
- Must track framework version changes
- Users must configure their test runner
