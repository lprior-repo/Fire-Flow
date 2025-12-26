# Configuration Reference: TCR Enforcer for OpenCode

## Document Info

| Field | Value |
|-------|-------|
| Version | 0.1.0 |
| Status | Draft |
| Author | Lewis |
| Created | 2025-12-12 |

---

## 1. Configuration File Location

### Project-Level (Recommended)

```
your-project/
└── .opencode/
    └── tcr/
        └── data/
            └── config.yml    ← Project config
```

### Global (All Projects)

```
~/.config/opencode/
└── tcr/
    └── data/
        └── config.yml        ← Global config
```

Project config overrides global config.

---

## 2. Full Configuration Schema

```yaml
# ═══════════════════════════════════════════════════════════════════════════
# TCR Enforcer Configuration
# ═══════════════════════════════════════════════════════════════════════════

# ───────────────────────────────────────────────────────────────────────────
# Core Settings
# ───────────────────────────────────────────────────────────────────────────

# Enable/disable the entire plugin
# Type: boolean
# Default: true
enabled: true

# Enforcement mode
# Options:
#   - "both"    : Full TDD gate + TCR loop (recommended)
#   - "tdd"     : Only TDD gate (blocks impl without failing tests)
#   - "tcr"     : Only TCR loop (test && commit || revert)
#   - "relaxed" : TCR without revert (just skip commit on red)
#   - "off"     : Disabled (same as enabled: false)
# Type: string
# Default: "both"
mode: both

# ───────────────────────────────────────────────────────────────────────────
# Test Settings
# ───────────────────────────────────────────────────────────────────────────

# Command to run tests
# This is executed in your project root after each file change
# Type: string
# Default: "npm test"
# Examples:
#   - "bun test"
#   - "pnpm test"
#   - "yarn test"
#   - "vitest run"
#   - "jest"
#   - "pytest"
#   - "go test ./..."
#   - "cargo test"
testCommand: npm test

# Delay before running tests (milliseconds)
# Helps group rapid consecutive edits into a single test run
# Type: number
# Default: 100
debounceMs: 100

# Show test output on failure
# Type: boolean
# Default: true
showTestOutput: true

# Maximum characters of test output to show
# Longer output is truncated with "..."
# Type: number
# Default: 500
testOutputLimit: 500

# ───────────────────────────────────────────────────────────────────────────
# Git Settings
# ───────────────────────────────────────────────────────────────────────────

# Commit message for auto-commits
# TCR creates many small commits; squash before push
# Type: string
# Default: "WIP"
commitMessage: WIP

# ───────────────────────────────────────────────────────────────────────────
# File Patterns
# ───────────────────────────────────────────────────────────────────────────

# Patterns to identify test files (regex)
# Test files are always allowed to be edited (no TDD gate)
# Type: array of strings
# Default: (see below)
testPatterns:
  - "\\.test\\.[jt]sx?$"     # *.test.ts, *.test.js, *.test.tsx, *.test.jsx
  - "\\.spec\\.[jt]sx?$"     # *.spec.ts, *.spec.js, etc.
  - "_test\\.go$"            # *_test.go
  - "test_.*\\.py$"          # test_*.py
  - ".*_test\\.py$"          # *_test.py
  - "Test\\.php$"            # *Test.php
  - "_test\\.rs$"            # *_test.rs

# Paths protected from modification
# Agent cannot edit these files (self-protection)
# Type: array of strings
# Default: (see below)
protectedPaths:
  - opencode.json
  - .opencode/plugin
  - .opencode/tcr
  - .git
```

---

## 3. Configuration Options Detail

### 3.1 `enabled`

| Property | Value |
|----------|-------|
| Type | `boolean` |
| Default | `true` |
| Required | No |

Controls whether the plugin is active. Set to `false` to disable without removing the plugin.

```yaml
# Disable temporarily
enabled: false
```

### 3.2 `mode`

| Property | Value |
|----------|-------|
| Type | `string` |
| Default | `"both"` |
| Required | No |
| Options | `both`, `tdd`, `tcr`, `relaxed`, `off` |

Controls which enforcement mechanisms are active.

| Mode | TDD Gate | TCR Loop | Revert on Fail |
|------|----------|----------|----------------|
| `both` | ✅ | ✅ | ✅ |
| `tdd` | ✅ | ❌ | ❌ |
| `tcr` | ❌ | ✅ | ✅ |
| `relaxed` | ❌ | ✅ | ❌ |
| `off` | ❌ | ❌ | ❌ |

**Recommendations:**
- Start with `relaxed` if new to TCR
- Use `both` for full enforcement
- Use `tdd` if you want to commit manually

### 3.3 `testCommand`

| Property | Value |
|----------|-------|
| Type | `string` |
| Default | `"npm test"` |
| Required | No |

The command executed to run your test suite. Must exit 0 on success, non-zero on failure.

**Examples by framework:**

```yaml
# JavaScript/TypeScript
testCommand: npm test
testCommand: bun test
testCommand: pnpm test
testCommand: vitest run
testCommand: jest --passWithNoTests

# Python
testCommand: pytest
testCommand: python -m pytest

# Go
testCommand: go test ./...

# Rust
testCommand: cargo test

# PHP
testCommand: ./vendor/bin/phpunit

# Custom with flags
testCommand: npm test -- --coverage --silent
```

### 3.4 `debounceMs`

| Property | Value |
|----------|-------|
| Type | `number` |
| Default | `100` |
| Required | No |

Milliseconds to wait after a file change before running tests. Helps batch rapid consecutive edits.

```yaml
# Faster feedback (might run tests multiple times)
debounceMs: 50

# Slower, batch more edits
debounceMs: 500
```

### 3.5 `testPatterns`

| Property | Value |
|----------|-------|
| Type | `array of string` |
| Default | (see schema) |
| Required | No |

Regex patterns to identify test files. Matched files are always allowed to be edited without a failing test.

**Adding custom patterns:**

```yaml
testPatterns:
  # Include defaults
  - "\\.test\\.[jt]sx?$"
  - "\\.spec\\.[jt]sx?$"
  
  # Add custom patterns
  - "/__tests__/.*\\.[jt]sx?$"    # Jest __tests__ directory
  - "\\.stories\\.[jt]sx?$"       # Storybook stories
  - "\\.e2e\\.[jt]sx?$"           # E2E tests
```

### 3.6 `protectedPaths`

| Property | Value |
|----------|-------|
| Type | `array of string` |
| Default | (see schema) |
| Required | No |

Paths that cannot be modified. Prevents the agent from disabling the enforcer.

**Extending protection:**

```yaml
protectedPaths:
  # Keep defaults
  - opencode.json
  - .opencode/plugin
  - .opencode/tcr
  - .git
  
  # Add more
  - .env              # Don't modify secrets
  - package-lock.json # Don't mess with lockfile
```

### 3.7 `commitMessage`

| Property | Value |
|----------|-------|
| Type | `string` |
| Default | `"WIP"` |
| Required | No |

Message used for auto-commits. Keep it short; you'll squash these commits later.

```yaml
# Default
commitMessage: WIP

# With prefix
commitMessage: "wip: auto-commit"

# With timestamp (not recommended, clutters history)
# commitMessage: "wip: ${timestamp}"  # NOT SUPPORTED
```

### 3.8 `showTestOutput`

| Property | Value |
|----------|-------|
| Type | `boolean` |
| Default | `true` |
| Required | No |

Whether to display test output when tests fail and code is reverted.

```yaml
# Show output (helpful for debugging)
showTestOutput: true

# Hide output (cleaner, but less info)
showTestOutput: false
```

### 3.9 `testOutputLimit`

| Property | Value |
|----------|-------|
| Type | `number` |
| Default | `500` |
| Required | No |

Maximum characters of test output to display. Prevents overwhelming output from large test failures.

```yaml
# Short output
testOutputLimit: 200

# More detail
testOutputLimit: 1000
```

---

## 4. Example Configurations

### 4.1 Minimal (Defaults)

```yaml
# config.yml - Uses all defaults
enabled: true
```

### 4.2 TypeScript/Vitest Project

```yaml
enabled: true
mode: both
testCommand: vitest run
testPatterns:
  - "\\.test\\.tsx?$"
  - "\\.spec\\.tsx?$"
```

### 4.3 Python Project

```yaml
enabled: true
mode: both
testCommand: pytest -x
testPatterns:
  - "test_.*\\.py$"
  - ".*_test\\.py$"
```

### 4.4 Go Project

```yaml
enabled: true
mode: both
testCommand: go test ./...
testPatterns:
  - "_test\\.go$"
```

### 4.5 Monorepo

```yaml
enabled: true
mode: both
testCommand: pnpm test --filter @myorg/affected
testPatterns:
  - "\\.test\\.[jt]sx?$"
  - "\\.spec\\.[jt]sx?$"
protectedPaths:
  - opencode.json
  - .opencode/
  - .git
  - pnpm-lock.yaml
  - "packages/*/package.json"
```

### 4.6 Relaxed (Learning Mode)

```yaml
enabled: true
mode: relaxed
testCommand: npm test
showTestOutput: true
testOutputLimit: 1000
```

### 4.7 TDD Only (Manual Commits)

```yaml
enabled: true
mode: tdd
testCommand: npm test
```

---

## 5. Environment Variables

The plugin also respects these environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `TCR_ENABLED` | Override enabled state | - |
| `TCR_MODE` | Override mode | - |
| `TCR_TEST_COMMAND` | Override test command | - |

Environment variables take precedence over config file.

```bash
# Temporarily disable
TCR_ENABLED=false opencode

# Use different mode
TCR_MODE=relaxed opencode
```

---

## 6. Runtime Files

These files are managed by the plugin (don't edit manually):

### 6.1 `test.json` (Test Results)

Written by test reporter after each test run.

```json
{
  "passed": ["should add numbers", "should handle edge case"],
  "failed": ["should multiply correctly"],
  "timestamp": 1702400000000,
  "total": 3,
  "duration": 245
}
```

### 6.2 `stats.json` (Statistics)

Written by plugin to track metrics.

```json
{
  "commits": 42,
  "reverts": 7,
  "revertStreak": 0,
  "lastRevertReason": "",
  "lastActivity": 1702400000000,
  "sessionStart": 1702395000000
}
```

### 6.3 `state.json` (Runtime State)

Optional, for persisting runtime overrides.

```json
{
  "enabled": true,
  "modeOverride": null
}
```

---

## 7. Configuration Validation

The plugin validates configuration on load:

| Field | Validation |
|-------|------------|
| `enabled` | Must be boolean |
| `mode` | Must be one of valid options |
| `testCommand` | Must be non-empty string |
| `debounceMs` | Must be positive number |
| `testOutputLimit` | Must be positive number |
| `testPatterns` | Must be array of valid regex strings |
| `protectedPaths` | Must be array of strings |

Invalid configuration falls back to defaults with a warning.

---

## 8. Troubleshooting

### Config not loading

1. Check file location: `.opencode/tcr/data/config.yml`
2. Verify YAML syntax: `cat config.yml | python -c "import yaml, sys; yaml.safe_load(sys.stdin)"`
3. Check file permissions

### Test command not working

1. Run manually: `cd /your/project && your-test-command`
2. Check exit codes: `echo $?` (should be 0 on pass)
3. Verify command is in PATH

### Test files not recognized

1. Check pattern syntax (regex)
2. Test pattern: `echo "file.test.ts" | grep -E "\.test\.[jt]sx?$"`
3. Add pattern to `testPatterns` array
