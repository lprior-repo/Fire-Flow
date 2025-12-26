# User Guide: TCR Enforcer for OpenCode

## Document Info

| Field | Value |
|-------|-------|
| Version | 0.1.0 |
| Status | Draft |
| Author | Lewis |
| Created | 2025-12-12 |

---

## 1. What is TCR Enforcer?

TCR Enforcer is an OpenCode plugin that enforces disciplined development practices:

**TDD Gate**: You must write a failing test before writing implementation code.

**TCR Loop**: After every change, tests run automatically:
- ✅ Tests pass → Code is committed
- ❌ Tests fail → Code is reverted (deleted!)

This forces small, incremental steps and eliminates debugging spirals.

---

## 2. Quick Start

### 2.1 Installation

```bash
# Create plugin directory
mkdir -p .opencode/plugin

# Download plugin (or copy from source)
curl -o .opencode/plugin/tcr-enforcer.ts \
  https://raw.githubusercontent.com/your-org/tcr-enforcer/main/dist/tcr-enforcer.ts

# Create data directory
mkdir -p .opencode/tcr/data
```

### 2.2 Install Test Reporter

For Vitest:

```bash
npm install --save-dev tcr-vitest-reporter
```

Update `vitest.config.ts`:

```typescript
import { defineConfig } from 'vitest/config'
import { TCRVitestReporter } from 'tcr-vitest-reporter'

export default defineConfig({
  test: {
    reporters: ['default', new TCRVitestReporter()]
  }
})
```

### 2.3 Basic Configuration

Create `.opencode/tcr/data/config.yml`:

```yaml
enabled: true
mode: both
testCommand: npm test
```

### 2.4 Verify Setup

```bash
# Start OpenCode
opencode

# Try to write an implementation file
> Write a new function in src/math.ts

# Expected: "🚫 TDD VIOLATION: No failing tests found"
```

---

## 3. The TDD Cycle with TCR

### 3.1 The Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐     │
│  │  RED    │───▶│  GREEN  │───▶│REFACTOR │───▶│ REPEAT  │──┐  │
│  │         │    │         │    │         │    │         │  │  │
│  │ Write   │    │ Write   │    │ Clean   │    │ Next    │  │  │
│  │ failing │    │ minimal │    │ up code │    │ feature │  │  │
│  │ test    │    │ code to │    │ (keep   │    │         │  │  │
│  │         │    │ pass    │    │ green)  │    │         │  │  │
│  └─────────┘    └─────────┘    └─────────┘    └─────────┘  │  │
│       │              │              │                       │  │
│       │              │              │                       │  │
│       ▼              ▼              ▼                       │  │
│    ALLOWED        ALLOWED       ALLOWED                     │  │
│    (test file)   (has failing  (tests pass)                 │  │
│                    test)                                    │  │
│                      │                                      │  │
│                      ▼                                      │  │
│               ┌─────────────┐                               │  │
│               │ Tests pass? │                               │  │
│               └──────┬──────┘                               │  │
│                      │                                      │  │
│            ┌─────────┴─────────┐                            │  │
│            │                   │                            │  │
│           YES                  NO                           │  │
│            │                   │                            │  │
│            ▼                   ▼                            │  │
│      ┌──────────┐       ┌──────────┐                        │  │
│      │  COMMIT  │       │  REVERT  │                        │  │
│      │   WIP    │       │ (code    │                        │  │
│      │          │       │  lost!)  │                        │  │
│      └──────────┘       └──────────┘                        │  │
│                                                              │  │
└──────────────────────────────────────────────────────────────┘
```

### 3.2 Example Session

**Step 1: Try to write implementation (BLOCKED)**

```
You: Create an add function in src/math.ts

Claude: [tries to write file]

🚫 TDD VIOLATION: No failing tests found

You must write a failing test before implementing.
File: src/math.ts

TDD Cycle:
  1. Write a failing test (RED)
  2. Write minimal code to pass (GREEN)
  3. Refactor while green (REFACTOR)

Current state: No failing tests detected.
Write a test first!
```

**Step 2: Write a failing test (ALLOWED)**

```
You: Write a test for the add function first

Claude: [writes test/math.test.ts]

✅ File created: test/math.test.ts

🧪 TCR: Running tests...
❌ TCR (relaxed): Tests failed → NOT committing
   (This is expected - you wrote a failing test!)
```

**Step 3: Write implementation (ALLOWED, now passes)**

```
You: Now implement the add function

Claude: [writes src/math.ts]

✅ File created: src/math.ts

🧪 TCR: Running tests...
✅ TCR: Tests passed → Committed
```

**Step 4: Implement too much (REVERTED)**

```
You: Add subtract, multiply, and divide functions

Claude: [writes all three functions at once]

🧪 TCR: Running tests...
❌ TCR: Tests failed → REVERTED

The code you just wrote did not pass tests.
It has been removed (git reset --hard HEAD).

Take a smaller step that keeps tests passing.
```

---

## 4. Modes Explained

### 4.1 `both` (Default - Full Enforcement)

```yaml
mode: both
```

- ✅ TDD Gate: Blocks implementation without failing tests
- ✅ TCR Loop: Auto-commits on pass, auto-reverts on fail

**Best for**: Experienced TDD practitioners who want full discipline.

### 4.2 `relaxed` (Gentle TCR)

```yaml
mode: relaxed
```

- ❌ TDD Gate: Not enforced
- ✅ TCR Loop: Auto-commits on pass
- ❌ Revert: Does NOT auto-revert on fail

**Best for**: Learning TCR without the fear of losing code.

### 4.3 `tdd` (TDD Only)

```yaml
mode: tdd
```

- ✅ TDD Gate: Blocks implementation without failing tests
- ❌ TCR Loop: Not active (manual commits)

**Best for**: Teams that want TDD but prefer manual git workflow.

### 4.4 `tcr` (TCR Only)

```yaml
mode: tcr
```

- ❌ TDD Gate: Not enforced
- ✅ TCR Loop: Full test && commit || revert

**Best for**: Projects where TDD isn't practical but TCR discipline is wanted.

### 4.5 `off` (Disabled)

```yaml
mode: off
```

Everything disabled. Same as `enabled: false`.

---

## 5. Working with WIP Commits

TCR creates many small "WIP" commits. Before pushing, squash them.

### 5.1 Interactive Rebase

```bash
# Squash last N commits
git rebase -i HEAD~10

# Mark commits as 'squash' (s) except first one
# Save and write a meaningful commit message
```

### 5.2 Soft Reset

```bash
# Reset last N commits but keep changes
git reset --soft HEAD~10

# Recommit with meaningful message
git commit -m "feat: implement user authentication"
```

### 5.3 Before Push Checklist

1. Review commits: `git log --oneline -20`
2. Squash WIP commits
3. Write meaningful commit message
4. Push: `git push`

---

## 6. Understanding Error Messages

### 6.1 TDD Violation

```
🚫 TDD VIOLATION: No failing tests found

You must write a failing test before implementing.
File: src/index.ts
```

**What happened**: You tried to write implementation code without a failing test.

**What to do**: Write a test file first that exercises the code you want to write.

### 6.2 TCR Revert

```
❌ TCR: Tests failed → REVERTED

The code you just wrote did not pass tests.
It has been removed (git reset --hard HEAD).
```

**What happened**: Your code broke the tests. It has been deleted.

**What to do**: Take a smaller step. Write less code that keeps tests passing.

### 6.3 Protected Path

```
🚫 BLOCKED: Cannot modify protected path

Path: .opencode/tcr/data/config.yml
TCR Enforcer protects its own configuration.
```

**What happened**: You (or the agent) tried to modify TCR's configuration.

**What to do**: This is intentional self-protection. Edit config manually if needed.

### 6.4 Revert Streak Warning

```
⚠️  3 reverts in a row!

Consider:
  • Taking an even smaller step
  • Re-reading the failing test
  • Checking if the test is correct
  • Running tests manually to debug
```

**What happened**: You've had multiple consecutive reverts.

**What to do**: Slow down. Make your changes even smaller. Maybe run tests manually to understand what's failing.

---

## 7. Tips for Success

### 7.1 Start Small

If you keep getting reverted, you're writing too much code at once.

**Too big**:
```
"Implement the entire user authentication system"
```

**Just right**:
```
"Write a test that checks if a user can be created with an email"
"Implement the User constructor that takes an email"
"Write a test that validates email format"
"Implement email validation"
```

### 7.2 One Test at a Time

Don't write multiple tests before implementing. The TDD cycle is:

1. ONE failing test
2. Minimal implementation to pass
3. Refactor
4. Repeat

### 7.3 Trust the Process

Getting reverted feels painful at first. That's the point. The "pain" teaches you to work in smaller increments.

After a few sessions, you'll naturally:
- Write smaller chunks
- Think before coding
- Have higher confidence in your code

### 7.4 Use Relaxed Mode to Learn

If full TCR is too aggressive, start with relaxed mode:

```yaml
mode: relaxed
```

You still get auto-commits on green, but failed tests won't delete your code.

---

## 8. Troubleshooting

### 8.1 Tests not running

**Symptom**: Changes commit without tests running.

**Check**:
1. Is `testCommand` correct in config?
2. Does the command work manually? `npm test`
3. Is the test reporter installed?

### 8.2 Test reporter not writing results

**Symptom**: TDD gate always blocks (can't see failing tests).

**Check**:
1. Is reporter in vitest/jest config?
2. Does `.opencode/tcr/data/test.json` exist after running tests?
3. Run tests manually and check if file is created

### 8.3 Everything is blocked

**Symptom**: Can't write any files.

**Check**:
1. Check config: `cat .opencode/tcr/data/config.yml`
2. Try `mode: relaxed` or `mode: off` temporarily
3. Delete state files and restart: `rm .opencode/tcr/data/*.json`

### 8.4 Agent disabling the plugin

**Symptom**: Agent keeps trying to modify config.

**Solution**: This should be blocked automatically. If not:
1. Update to latest plugin version
2. Check that plugin is in `.opencode/plugin/`
3. Report bug if protection isn't working

---

## 9. FAQ

**Q: Can I disable TCR temporarily?**

A: Yes, set `enabled: false` in config or use `TCR_ENABLED=false opencode`.

**Q: What if I need to make a quick fix without tests?**

A: Use `mode: off` temporarily. But consider: is this fix so urgent you can't write a test?

**Q: How do I handle existing code without tests?**

A: Use `mode: tcr` (no TDD gate) while adding tests to existing code.

**Q: Will this slow down my development?**

A: Initially, yes. But you'll spend less time debugging, so overall it's faster.

**Q: What if the test framework isn't supported?**

A: You can write a custom reporter that outputs to `.opencode/tcr/data/test.json`.

**Q: Can I use this with Claude Code instead of OpenCode?**

A: See [tdd-guard](https://github.com/nizos/tdd-guard) for Claude Code.

---

## 10. Command Reference (Future)

These tools may be available via the plugin:

| Command | Description |
|---------|-------------|
| `tcr_status` | Show current status and stats |
| `tcr_toggle` | Toggle enforcement on/off |
| `tcr_mode` | Change enforcement mode |
| `tcr_squash` | Squash WIP commits |
| `tcr_stats` | Show commit/revert statistics |

---

## 11. Getting Help

- **Documentation**: This guide
- **Issues**: GitHub issues (when published)
- **Source**: Check the plugin source code
