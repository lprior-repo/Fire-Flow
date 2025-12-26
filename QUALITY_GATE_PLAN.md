# Quality Gate System: OODA Loop Architecture

## Vision

A **recursive, self-improving quality gate system** that leverages:
- Kestra orchestration for flow control
- DataContract CLI for schema validation
- Nushell as the **primary implementation language** (tools, orchestration scripts)
- **Multi-language support** for generated code (Nushell, Python, Rust, Go, TypeScript, etc.)
- OpenCode + Qwen Coder 3 30B3 @ 250 tok/s for AI generation
- OODA loop (Observe → Orient → Decide → Act) for iterative refinement

## The Problem

Current system has 8 quality gates but lacks:
1. **Coverage metrics** - Tests exist but no coverage measurement
2. **Linting** - No static analysis of generated code
3. **Mutation testing** - No testing of the tests themselves
4. **Hostile review** - No adversarial AI review of generated code
5. **Recursive depth** - Single feedback loop, not nested OODA
6. **Language-agnostic gates** - Current gates assume Nushell only

---

## OODA Loop Quality Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         OUTER OODA LOOP                             │
│  (Strategic: Did we solve the right problem?)                       │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    INNER OODA LOOP                          │   │
│  │  (Tactical: Does the code work correctly?)                  │   │
│  │                                                             │   │
│  │  ┌─────────────────────────────────────────────────────┐   │   │
│  │  │              MICRO OODA LOOP                        │   │   │
│  │  │  (Technical: Is the code well-formed?)              │   │   │
│  │  │                                                     │   │   │
│  │  │   OBSERVE: Parse code, run linter                   │   │   │
│  │  │   ORIENT: Categorize issues (syntax, style, smell)  │   │   │
│  │  │   DECIDE: Auto-fix or regenerate?                   │   │   │
│  │  │   ACT: Apply fix or feed back to generator          │   │   │
│  │  └─────────────────────────────────────────────────────┘   │   │
│  │                                                             │   │
│  │   OBSERVE: Run tests, measure coverage                      │   │
│  │   ORIENT: Identify gaps (uncovered paths, failures)         │   │
│  │   DECIDE: Add tests, fix code, or escalate?                 │   │
│  │   ACT: Generate tests, fix code, collect feedback           │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│   OBSERVE: Contract validation, hostile review                      │
│   ORIENT: Does output match intent? Security issues?                │
│   DECIDE: Accept, refine, or reject entirely?                       │
│   ACT: Ship, iterate, or redesign approach                          │
└─────────────────────────────────────────────────────────────────────┘
```

---

---

## Multi-Language Architecture

### Supported Languages & Tooling

| Language | Syntax Check | Linter | Type Check | Test Runner | Coverage |
|----------|--------------|--------|------------|-------------|----------|
| **Nushell** | `nu --commands "source $file"` | `lint-nushell.nu` (custom) | N/A | `nu test.nu` | Trace-based |
| **Python** | `python -m py_compile` | `ruff check` | `mypy` | `pytest` | `coverage.py` |
| **Rust** | `cargo check` | `clippy` | Built-in | `cargo test` | `cargo-tarpaulin` |
| **Go** | `go build` | `golangci-lint` | Built-in | `go test` | `go test -cover` |
| **TypeScript** | `tsc --noEmit` | `eslint` | `tsc` | `vitest` | `c8` |
| **JavaScript** | `node --check` | `eslint` | N/A | `vitest` | `c8` |

### Language Detection

The system auto-detects language from:
1. Contract `metadata.language` field (explicit)
2. File extension (`.nu`, `.py`, `.rs`, `.go`, `.ts`, `.js`)
3. Shebang line (`#!/usr/bin/env nu`, `#!/usr/bin/env python3`)

### Contract Extension for Multi-Language

```yaml
# contracts/tools/example.yaml
dataContractSpecification: 0.9.3
id: example-tool
info:
  title: Example Tool
  version: 1.0.0

# NEW: Language specification
metadata:
  language: nushell          # nushell | python | rust | go | typescript
  language_version: "0.100"  # Optional: minimum version
  dependencies: []           # Optional: required packages

servers:
  local:
    type: local
    path: ./output.json
    format: json

models:
  ToolResponse:
    type: object
    fields:
      - name: success
        type: boolean
        required: true
      # ... rest of schema
```

---

## Quality Gate Stages (12 Gates)

### PHASE 1: GENERATION (Gates 1-3)

```
┌──────────────────────────────────────────────────────────────┐
│  GATE 1: CONTRACT PARSING                                    │
│  ─────────────────────────────────────────────────────────── │
│  Input: contract.yaml                                        │
│  Check: Valid YAML, valid DataContract schema                │
│  Tool: datacontract lint                                     │
│  Fail: Reject with schema errors                             │
└──────────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────┐
│  GATE 2: PROMPT CONSTRUCTION                                 │
│  ─────────────────────────────────────────────────────────── │
│  Input: contract + task + feedback                           │
│  Check: Prompt size limits, context window fit               │
│  Tool: prompt-builder.nu (new)                               │
│  Fail: Truncate feedback, summarize context                  │
└──────────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────┐
│  GATE 3: CODE GENERATION                                     │
│  ─────────────────────────────────────────────────────────── │
│  Input: prompt                                               │
│  Model: Qwen Coder 3 30B @ 250 tok/s                         │
│  Tool: opencode run -m local/qwen3-coder                     │
│  Fail: Timeout, empty output, model unavailable              │
└──────────────────────────────────────────────────────────────┘
```

### PHASE 2: STATIC ANALYSIS (Gates 4-6) - MICRO OODA

```
┌──────────────────────────────────────────────────────────────┐
│  GATE 4: SYNTAX VALIDATION                                   │
│  ─────────────────────────────────────────────────────────── │
│  Input: generated.nu                                         │
│  Check: Valid Nushell syntax                                 │
│  Tool: nu --commands "source $file" (parse-only)             │
│  Fail: Syntax errors → regenerate with error context         │
└──────────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────┐
│  GATE 5: LINTING (Language-Aware)                            │
│  ─────────────────────────────────────────────────────────── │
│  Input: generated code file                                  │
│  Dispatcher: lint-dispatch.nu (routes to language linter)    │
│                                                              │
│  Language-Specific Linters:                                  │
│    Nushell:    lint-nushell.nu (custom rules)                │
│    Python:     ruff check --output-format=json               │
│    Rust:       cargo clippy --message-format=json            │
│    Go:         golangci-lint run --out-format=json           │
│    TypeScript: eslint --format=json                          │
│                                                              │
│  Common Checks (all languages):                              │
│    - No hardcoded paths (/home/, /tmp/ without variable)     │
│    - No credential patterns (API keys, passwords)            │
│    - Required entry point (main, def main, etc.)             │
│    - Style consistency per language                          │
│                                                              │
│  Tool: lint-dispatch.nu (new)                                │
│  Fail: Linting errors → regenerate with lint feedback        │
└──────────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────┐
│  GATE 6: SECURITY SCAN                                       │
│  ─────────────────────────────────────────────────────────── │
│  Input: generated.nu                                         │
│  Checks:                                                     │
│    - No credential patterns                                  │
│    - No dangerous commands (rm -rf, :>, etc.)                │
│    - No network calls without explicit contract permission   │
│    - No file writes outside allowed paths                    │
│  Tool: security-scan.nu (new)                                │
│  Fail: Security issue → regenerate with security feedback    │
└──────────────────────────────────────────────────────────────┘
```

### PHASE 3: DYNAMIC TESTING (Gates 7-9) - INNER OODA

```
┌──────────────────────────────────────────────────────────────┐
│  GATE 7: EXECUTION TEST                                      │
│  ─────────────────────────────────────────────────────────── │
│  Input: generated.nu + test_input.json                       │
│  Check: Tool executes without crash                          │
│  Tool: run-tool.nu (existing)                                │
│  Fail: Runtime error → regenerate with error + stack trace   │
└──────────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────┐
│  GATE 8: CONTRACT VALIDATION                                 │
│  ─────────────────────────────────────────────────────────── │
│  Input: output.json + contract.yaml                          │
│  Check: Output matches contract schema exactly               │
│  Tool: datacontract test (existing validate.nu)              │
│  Fail: Schema mismatch → regenerate with validation errors   │
└──────────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────┐
│  GATE 9: COVERAGE ANALYSIS                                   │
│  ─────────────────────────────────────────────────────────── │
│  Input: generated.nu execution traces                        │
│  Checks:                                                     │
│    - All branches exercised                                  │
│    - All error handlers reachable                            │
│    - Edge case inputs tested                                 │
│  Tool: coverage-check.nu (new)                               │
│  Fail: Low coverage → generate additional test cases         │
└──────────────────────────────────────────────────────────────┘
```

### PHASE 4: ADVERSARIAL REVIEW (Gates 10-12) - OUTER OODA

```
┌──────────────────────────────────────────────────────────────┐
│  GATE 10: MUTATION TESTING                                   │
│  ─────────────────────────────────────────────────────────── │
│  Input: generated.nu + test_cases                            │
│  Process:                                                    │
│    1. Generate mutants (change operators, constants, logic)  │
│    2. Run tests against mutants                              │
│    3. Count surviving mutants (test weakness indicator)      │
│  Tool: mutate-test.nu (new)                                  │
│  Fail: High mutant survival → generate stronger tests        │
└──────────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────┐
│  GATE 11: HOSTILE REVIEW                                     │
│  ─────────────────────────────────────────────────────────── │
│  Input: generated.nu + contract + task                       │
│  Reviewer: Second AI instance (skeptical persona)            │
│  Questions:                                                  │
│    - Does this actually solve the stated problem?            │
│    - What edge cases are missed?                             │
│    - What could go wrong in production?                      │
│    - Is this over-engineered or under-engineered?            │
│    - Any hidden assumptions?                                 │
│  Tool: hostile-review.nu (new)                               │
│  Output: Structured critique with severity levels            │
│  Fail: Critical issues → regenerate with critique            │
└──────────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────┐
│  GATE 12: SEMANTIC VALIDATION                                │
│  ─────────────────────────────────────────────────────────── │
│  Input: generated.nu + original task                         │
│  Check: Does the code actually do what was asked?            │
│  Method:                                                     │
│    1. AI summarizes what the code does                       │
│    2. Compare summary to original task                       │
│    3. Flag semantic drift                                    │
│  Tool: semantic-check.nu (new)                               │
│  Fail: Semantic mismatch → regenerate with clarification     │
└──────────────────────────────────────────────────────────────┘
```

---

## New Tools Required

> **Pattern Reference**: All tools follow the patterns established in `validate.nu` and `generate.nu`:
> - Shebang: `#!/usr/bin/env nu`
> - Entry point: `def main []`
> - Input: JSON from stdin via `open --raw /dev/stdin | from json`
> - Output: `ToolResponse` format to stdout
> - Logs: Structured JSON to stderr via `{ level: "info", msg: "...", trace_id: $trace_id } | to json -r | print -e`
> - Duration tracking: `let start = date now` ... `(date now) - $start | into int | $in / 1000000`
> - Context extraction: `$input.context?`, `trace_id`, `dry_run`
> - Exit 0 always (self-healing pattern)

### 1. lint-dispatch.nu (Language Router)

```nushell
#!/usr/bin/env nu
# Lint Dispatch - Routes to language-specific linters
#
# Contract: contracts/tools/lint-dispatch.yaml
# Input: JSON from stdin (LintInput)
# Output: JSON to stdout (ToolResponse wrapping LintOutput)
# Logs: JSON to stderr

def main [] {
    let start = date now

    # Read JSON from stdin with error handling
    let raw = open --raw /dev/stdin
    let input = try {
        $raw | from json
    } catch {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "error", msg: "invalid JSON input" } | to json -r | print -e
        { success: false, error: "Invalid JSON input", trace_id: "", duration_ms: $dur } | to json | print
        exit 0
    }

    # Extract context
    let ctx = $input.context? | default {}
    let trace_id = $ctx.trace_id? | default ""
    let dry_run = $ctx.dry_run? | default false

    # Extract lint configuration
    let tool_path = $input.tool_path? | default ""
    let contract_path = $input.contract_path? | default ""

    if ($tool_path | is-empty) {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "error", msg: "tool_path is required", trace_id: $trace_id } | to json -r | print -e
        { success: false, error: "tool_path is required", trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 0
    }

    { level: "info", msg: "detecting language", trace_id: $trace_id, tool_path: $tool_path } | to json -r | print -e

    # Detect language from extension or contract
    let lang = detect-language $tool_path $contract_path

    { level: "info", msg: "language detected", lang: $lang, trace_id: $trace_id } | to json -r | print -e

    if $dry_run {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "info", msg: "dry-run mode - skipping lint", trace_id: $trace_id } | to json -r | print -e
        let output = { passed: true, issues: [], summary: { errors: 0, warnings: 0, info: 0 }, was_dry_run: true }
        { success: true, data: $output, trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 0
    }

    # Route to language-specific linter
    let result = match $lang {
        "nushell" => (lint-nushell $tool_path $trace_id),
        "python" => (lint-python $tool_path $trace_id),
        "rust" => (lint-rust $tool_path $trace_id),
        "go" => (lint-go $tool_path $trace_id),
        "typescript" | "javascript" => (lint-js $tool_path $trace_id),
        _ => { passed: false, issues: [{ line: 0, rule: "unknown-language", message: $"Unsupported language: ($lang)", severity: "error" }], summary: { errors: 1, warnings: 0, info: 0 } }
    }

    let duration_ms = (date now) - $start | into int | $in / 1000000
    { level: "info", msg: "lint complete", passed: $result.passed, duration_ms: $duration_ms } | to json -r | print -e

    if $result.passed {
        { success: true, data: $result, trace_id: $trace_id, duration_ms: $duration_ms } | to json | print
    } else {
        { success: false, data: $result, error: "linting failed", trace_id: $trace_id, duration_ms: $duration_ms } | to json | print
    }
    exit 0
}

def detect-language [tool_path: string, contract_path: string] -> string {
    # 1. Try contract metadata first
    if ($contract_path | is-not-empty) and ($contract_path | path exists) {
        let contract = try { open $contract_path } catch { {} }
        let lang = $contract.metadata?.language? | default ""
        if ($lang | is-not-empty) { return $lang }
    }

    # 2. Fall back to file extension
    let ext = $tool_path | path parse | get extension | default ""
    match $ext {
        "nu" => "nushell",
        "py" => "python",
        "rs" => "rust",
        "go" => "go",
        "ts" => "typescript",
        "js" => "javascript",
        _ => "unknown"
    }
}

def lint-nushell [tool_path: string, trace_id: string] -> record {
    # Custom Nushell linting rules
    let content = open --raw $tool_path
    let lines = $content | lines

    mut issues = []

    # Rule: no-hardcoded-paths
    for line_info in ($lines | enumerate) {
        let line = $line_info.item
        let num = $line_info.index + 1

        if ($line | str contains "/home/") and not ($line | str contains "$env.HOME") {
            $issues = ($issues | append { line: $num, column: 0, rule: "no-hardcoded-paths", message: "Avoid hardcoded /home/ paths, use $env.HOME", severity: "warning" })
        }

        if ($line | str contains "/tmp/") and not ($line | str contains "$") {
            $issues = ($issues | append { line: $num, column: 0, rule: "no-hardcoded-paths", message: "Avoid hardcoded /tmp/ paths, use variables", severity: "warning" })
        }

        # Rule: require-error-handling for external commands
        if ($line =~ '\^[a-zA-Z]') and not ($line | str contains "try") and not ($line | str contains "| complete") {
            $issues = ($issues | append { line: $num, column: 0, rule: "require-error-handling", message: "External commands should use try/catch or | complete", severity: "warning" })
        }
    }

    # Rule: require-main
    if not ($content | str contains "def main") {
        $issues = ($issues | append { line: 1, column: 0, rule: "require-main", message: "Script must define 'def main []' entry point", severity: "error" })
    }

    let errors = $issues | where severity == "error" | length
    let warnings = $issues | where severity == "warning" | length
    let info = $issues | where severity == "info" | length

    { passed: ($errors == 0), issues: $issues, summary: { errors: $errors, warnings: $warnings, info: $info } }
}

def lint-python [tool_path: string, trace_id: string] -> record {
    let result = do { ruff check --output-format=json $tool_path } | complete
    if $result.exit_code == 0 {
        { passed: true, issues: [], summary: { errors: 0, warnings: 0, info: 0 } }
    } else {
        let issues = try { $result.stdout | from json } catch { [] }
        let errors = $issues | length
        { passed: false, issues: $issues, summary: { errors: $errors, warnings: 0, info: 0 } }
    }
}

def lint-rust [tool_path: string, trace_id: string] -> record {
    # Rust requires cargo project context
    let dir = $tool_path | path dirname
    let result = do { cargo clippy --manifest-path $"($dir)/Cargo.toml" --message-format=json 2>&1 } | complete
    # Parse clippy JSON output...
    { passed: ($result.exit_code == 0), issues: [], summary: { errors: 0, warnings: 0, info: 0 } }
}

def lint-go [tool_path: string, trace_id: string] -> record {
    let result = do { golangci-lint run --out-format=json $tool_path } | complete
    { passed: ($result.exit_code == 0), issues: [], summary: { errors: 0, warnings: 0, info: 0 } }
}

def lint-js [tool_path: string, trace_id: string] -> record {
    let result = do { eslint --format=json $tool_path } | complete
    { passed: ($result.exit_code == 0), issues: [], summary: { errors: 0, warnings: 0, info: 0 } }
}
```

### 2. security-scan.nu

```nushell
#!/usr/bin/env nu
# Security Scan - Detect vulnerabilities in generated code
#
# Contract: contracts/tools/security-scan.yaml
# Input: JSON from stdin (SecurityScanInput)
# Output: JSON to stdout (ToolResponse wrapping SecurityScanOutput)
# Logs: JSON to stderr

def main [] {
    let start = date now

    let raw = open --raw /dev/stdin
    let input = try { $raw | from json } catch {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "error", msg: "invalid JSON input" } | to json -r | print -e
        { success: false, error: "Invalid JSON input", trace_id: "", duration_ms: $dur } | to json | print
        exit 0
    }

    let ctx = $input.context? | default {}
    let trace_id = $ctx.trace_id? | default ""
    let dry_run = $ctx.dry_run? | default false

    let tool_path = $input.tool_path? | default ""
    let allowed_paths = $input.allowed_paths? | default []
    let allowed_network = $input.allowed_network? | default false

    if ($tool_path | is-empty) {
        let dur = (date now) - $start | into int | $in / 1000000
        { success: false, error: "tool_path is required", trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 0
    }

    if $dry_run {
        let dur = (date now) - $start | into int | $in / 1000000
        { success: true, data: { secure: true, vulnerabilities: [], risk_score: 0.0, was_dry_run: true }, trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 0
    }

    { level: "info", msg: "scanning for security issues", trace_id: $trace_id, tool_path: $tool_path } | to json -r | print -e

    let content = open --raw $tool_path
    let lines = $content | lines

    mut vulnerabilities = []
    mut risk_score = 0.0

    for line_info in ($lines | enumerate) {
        let line = $line_info.item
        let num = $line_info.index + 1

        # Credential patterns
        if ($line =~ '(?i)(api[_-]?key|password|secret|token)\s*[:=]\s*["\'][^"\']+["\']') {
            $vulnerabilities = ($vulnerabilities | append { type: "hardcoded-credential", line: $num, description: "Possible hardcoded credential", severity: "critical" })
            $risk_score = $risk_score + 3.0
        }

        # Dangerous commands
        if ($line =~ 'rm\s+-rf\s+/') or ($line =~ 'chmod\s+777') or ($line =~ '>\s*/dev/s') {
            $vulnerabilities = ($vulnerabilities | append { type: "dangerous-command", line: $num, description: "Dangerous system command", severity: "high" })
            $risk_score = $risk_score + 2.0
        }

        # Network access without permission
        if not $allowed_network {
            if ($line =~ '(http|fetch|curl|wget|nc\s)') {
                $vulnerabilities = ($vulnerabilities | append { type: "unauthorized-network", line: $num, description: "Network access not permitted", severity: "medium" })
                $risk_score = $risk_score + 1.0
            }
        }

        # Code injection vectors
        if ($line =~ '\^"\$') or ($line =~ 'eval\s') or ($line =~ 'exec\s') {
            $vulnerabilities = ($vulnerabilities | append { type: "code-injection", line: $num, description: "Potential code injection vector", severity: "high" })
            $risk_score = $risk_score + 2.0
        }
    }

    $risk_score = [10.0, $risk_score] | math min
    let secure = ($vulnerabilities | where severity == "critical" or severity == "high" | length) == 0

    let duration_ms = (date now) - $start | into int | $in / 1000000
    { level: "info", msg: "security scan complete", secure: $secure, risk_score: $risk_score, vuln_count: ($vulnerabilities | length) } | to json -r | print -e

    let output = { secure: $secure, vulnerabilities: $vulnerabilities, risk_score: $risk_score, was_dry_run: false }

    if $secure {
        { success: true, data: $output, trace_id: $trace_id, duration_ms: $duration_ms } | to json | print
    } else {
        { success: false, data: $output, error: "security issues found", trace_id: $trace_id, duration_ms: $duration_ms } | to json | print
    }
    exit 0
}
```

### 3. hostile-review.nu

```nushell
#!/usr/bin/env nu
# Hostile Review - Skeptical AI code review
#
# Contract: contracts/tools/hostile-review.yaml
# Input: JSON from stdin (HostileReviewInput)
# Output: JSON to stdout (ToolResponse wrapping HostileReviewOutput)
# Logs: JSON to stderr
#
# Uses a second AI call with a skeptical persona to critique generated code.

def main [] {
    let start = date now

    let raw = open --raw /dev/stdin
    let input = try { $raw | from json } catch {
        let dur = (date now) - $start | into int | $in / 1000000
        { success: false, error: "Invalid JSON input", trace_id: "", duration_ms: $dur } | to json | print
        exit 0
    }

    let ctx = $input.context? | default {}
    let trace_id = $ctx.trace_id? | default ""
    let dry_run = $ctx.dry_run? | default false
    let timeout_seconds = $ctx.timeout_seconds? | default 120

    let tool_path = $input.tool_path? | default ""
    let contract_path = $input.contract_path? | default ""
    let task = $input.task? | default ""

    if ($tool_path | is-empty) or ($task | is-empty) {
        let dur = (date now) - $start | into int | $in / 1000000
        { success: false, error: "tool_path and task are required", trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 0
    }

    if $dry_run {
        let dur = (date now) - $start | into int | $in / 1000000
        { success: true, data: { approved: true, critique: [], questions: [], overall_assessment: "dry-run", was_dry_run: true }, trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 0
    }

    { level: "info", msg: "starting hostile review", trace_id: $trace_id } | to json -r | print -e

    let code = open --raw $tool_path
    let contract = if ($contract_path | is-not-empty) and ($contract_path | path exists) {
        open --raw $contract_path
    } else {
        "(no contract provided)"
    }

    # Build skeptical reviewer prompt
    let prompt = $"You are a HOSTILE code reviewer. Your job is to find problems, not praise.

ORIGINAL TASK: ($task)

CONTRACT:
($contract)

CODE TO REVIEW:
```
($code)
```

Review this code SKEPTICALLY. Look for:
1. Does it ACTUALLY solve the stated task? (semantic correctness)
2. What edge cases are MISSED?
3. What could go WRONG in production?
4. Is it OVER-ENGINEERED or UNDER-ENGINEERED?
5. Any HIDDEN ASSUMPTIONS?
6. SECURITY issues?
7. PERFORMANCE problems?

Output your review as JSON:
{
  \"approved\": boolean,
  \"critique\": [{\"aspect\": \"...\", \"issue\": \"...\", \"severity\": \"critical|high|medium|low\", \"suggestion\": \"...\"}],
  \"questions\": [\"questions you'd ask the developer\"],
  \"overall_assessment\": \"one paragraph summary\"
}

Be harsh but fair. If it's good, say so. If it's bad, explain why."

    let model = $env.MODEL? | default "local/qwen3-coder"
    { level: "info", msg: "calling AI for hostile review", model: $model } | to json -r | print -e

    let prompt_file = $"/tmp/hostile-review-($trace_id).txt"
    $prompt | save -f $prompt_file

    let result = do {
        timeout --foreground --kill-after=5 $"($timeout_seconds)s" opencode run -m $model (open --raw $prompt_file)
    } | complete

    rm -f $prompt_file

    let duration_ms = (date now) - $start | into int | $in / 1000000

    if $result.exit_code != 0 {
        { level: "error", msg: "hostile review AI call failed", exit_code: $result.exit_code } | to json -r | print -e
        { success: false, error: "AI review failed", trace_id: $trace_id, duration_ms: $duration_ms } | to json | print
        exit 0
    }

    # Parse AI response (extract JSON from potentially chatty output)
    let review = try {
        # Try to find JSON in the output
        let output = $result.stdout
        let json_start = $output | str index-of "{"
        let json_end = $output | str last-index-of "}"
        if $json_start >= 0 and $json_end > $json_start {
            $output | str substring $json_start..($json_end + 1) | from json
        } else {
            { approved: false, critique: [{ aspect: "parse-error", issue: "Could not parse AI response", severity: "high", suggestion: "Check AI output format" }], questions: [], overall_assessment: "Review failed to parse" }
        }
    } catch {
        { approved: false, critique: [{ aspect: "parse-error", issue: "JSON parse failed", severity: "high", suggestion: "Check AI output" }], questions: [], overall_assessment: "Review failed" }
    }

    { level: "info", msg: "hostile review complete", approved: $review.approved } | to json -r | print -e

    let output = $review | merge { was_dry_run: false }

    if $review.approved {
        { success: true, data: $output, trace_id: $trace_id, duration_ms: $duration_ms } | to json | print
    } else {
        { success: false, data: $output, error: "hostile review rejected code", trace_id: $trace_id, duration_ms: $duration_ms } | to json | print
    }
    exit 0
}
```

### 4. mutate-test.nu

```nushell
#!/usr/bin/env nu
# Mutation Testing - Test the tests by introducing bugs
#
# Contract: contracts/tools/mutation.yaml
# Input: JSON from stdin (MutationInput)
# Output: JSON to stdout (ToolResponse wrapping MutationOutput)
# Logs: JSON to stderr

def main [] {
    let start = date now

    let raw = open --raw /dev/stdin
    let input = try { $raw | from json } catch {
        let dur = (date now) - $start | into int | $in / 1000000
        { success: false, error: "Invalid JSON input", trace_id: "", duration_ms: $dur } | to json | print
        exit 0
    }

    let ctx = $input.context? | default {}
    let trace_id = $ctx.trace_id? | default ""
    let dry_run = $ctx.dry_run? | default false

    let tool_path = $input.tool_path? | default ""
    let test_inputs = $input.test_inputs? | default []
    let mutation_count = $input.mutation_count? | default 10
    let threshold = $input.threshold? | default 0.6

    if ($tool_path | is-empty) or ($test_inputs | is-empty) {
        let dur = (date now) - $start | into int | $in / 1000000
        { success: false, error: "tool_path and test_inputs are required", trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 0
    }

    if $dry_run {
        let dur = (date now) - $start | into int | $in / 1000000
        { success: true, data: { mutation_score: 1.0, surviving_mutants: [], test_quality: "dry-run", was_dry_run: true }, trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 0
    }

    { level: "info", msg: "starting mutation testing", trace_id: $trace_id, mutation_count: $mutation_count } | to json -r | print -e

    let original_code = open --raw $tool_path
    mut killed = 0
    mut surviving = []

    # Define mutation operators
    let mutations = [
        { name: "negate-condition", pattern: "==", replacement: "!=" },
        { name: "negate-condition", pattern: "!=", replacement: "==" },
        { name: "flip-comparison", pattern: "<", replacement: ">=" },
        { name: "flip-comparison", pattern: ">", replacement: "<=" },
        { name: "flip-logic", pattern: " and ", replacement: " or " },
        { name: "flip-logic", pattern: " or ", replacement: " and " },
        { name: "off-by-one", pattern: "+ 1", replacement: "+ 2" },
        { name: "off-by-one", pattern: "- 1", replacement: "- 2" },
        { name: "remove-not", pattern: "not ", replacement: "" },
        { name: "empty-string", pattern: '""', replacement: '"mutant"' },
    ]

    # Apply mutations and test
    for mutation in ($mutations | take $mutation_count) {
        if ($original_code | str contains $mutation.pattern) {
            let mutant_code = $original_code | str replace $mutation.pattern $mutation.replacement
            let mutant_path = $"/tmp/mutant-($trace_id).nu"
            $mutant_code | save -f $mutant_path

            # Run tests against mutant
            mut mutant_killed = false
            for test_input in $test_inputs {
                let result = do { $test_input | to json | nu $mutant_path } | complete
                # If test fails or output differs, mutant is killed
                if $result.exit_code != 0 {
                    $mutant_killed = true
                    break
                }
            }

            rm -f $mutant_path

            if $mutant_killed {
                $killed = $killed + 1
                { level: "debug", msg: "mutant killed", mutation: $mutation.name } | to json -r | print -e
            } else {
                $surviving = ($surviving | append { location: $mutation.pattern, mutation: $mutation.name, reason: "All tests passed with mutation" })
                { level: "warn", msg: "mutant survived", mutation: $mutation.name } | to json -r | print -e
            }
        }
    }

    let total = $killed + ($surviving | length)
    let score = if $total > 0 { $killed / $total } else { 1.0 }
    let quality = if $score >= 0.8 { "strong" } else if $score >= 0.6 { "adequate" } else { "weak" }

    let duration_ms = (date now) - $start | into int | $in / 1000000
    { level: "info", msg: "mutation testing complete", score: $score, killed: $killed, survived: ($surviving | length) } | to json -r | print -e

    let output = { mutation_score: $score, surviving_mutants: $surviving, test_quality: $quality, was_dry_run: false }
    let passed = $score >= $threshold

    if $passed {
        { success: true, data: $output, trace_id: $trace_id, duration_ms: $duration_ms } | to json | print
    } else {
        { success: false, data: $output, error: $"mutation score ($score) below threshold ($threshold)", trace_id: $trace_id, duration_ms: $duration_ms } | to json | print
    }
    exit 0
}
```

### 5. syntax-check.nu

```nushell
#!/usr/bin/env nu
# Syntax Check - Language-aware syntax validation
#
# Contract: contracts/tools/syntax-check.yaml
# Input: JSON from stdin
# Output: JSON to stdout (ToolResponse)
# Logs: JSON to stderr

def main [] {
    let start = date now

    let raw = open --raw /dev/stdin
    let input = try { $raw | from json } catch {
        let dur = (date now) - $start | into int | $in / 1000000
        { success: false, error: "Invalid JSON input", trace_id: "", duration_ms: $dur } | to json | print
        exit 0
    }

    let ctx = $input.context? | default {}
    let trace_id = $ctx.trace_id? | default ""
    let tool_path = $input.tool_path? | default ""

    if ($tool_path | is-empty) {
        let dur = (date now) - $start | into int | $in / 1000000
        { success: false, error: "tool_path is required", trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 0
    }

    { level: "info", msg: "checking syntax", trace_id: $trace_id, tool_path: $tool_path } | to json -r | print -e

    let ext = $tool_path | path parse | get extension | default ""

    let result = match $ext {
        "nu" => (do { nu --commands $"source ($tool_path)" } | complete),
        "py" => (do { python -m py_compile $tool_path } | complete),
        "rs" => (do { rustfmt --check $tool_path } | complete),
        "go" => (do { gofmt -e $tool_path } | complete),
        "ts" => (do { tsc --noEmit $tool_path } | complete),
        "js" => (do { node --check $tool_path } | complete),
        _ => { exit_code: 1, stderr: $"Unknown extension: ($ext)" }
    }

    let duration_ms = (date now) - $start | into int | $in / 1000000
    let valid = $result.exit_code == 0

    { level: "info", msg: "syntax check complete", valid: $valid } | to json -r | print -e

    let output = { valid: $valid, errors: (if $valid { [] } else { [$result.stderr] }), language: $ext }

    if $valid {
        { success: true, data: $output, trace_id: $trace_id, duration_ms: $duration_ms } | to json | print
    } else {
        { success: false, data: $output, error: "syntax check failed", trace_id: $trace_id, duration_ms: $duration_ms } | to json | print
    }
    exit 0
}
```

---

## Kestra Flow Architecture

> **Pattern Reference**: All flows follow the patterns established in `contract-loop-modular.yml`
> - Process runner only (no Docker): `taskRunner.type: io.kestra.plugin.core.runner.Process`
> - Subflows for composition, not shared state
> - JSON I/O between components
> - Always exit 0 (use `success` field for control flow)
> - Trace ID propagation via `{{ execution.id }}`

### Main Orchestrator: quality-gate-loop.yml

```yaml
# bitter-truth: 12-Gate Quality System with Nested OODA Loops
#
# Uses composable workflow components:
# - generate-tool: AI generates code from contract
# - static-analysis: Syntax + Lint + Security (Micro OODA)
# - dynamic-testing: Execute + Validate + Coverage (Inner OODA)
# - adversarial-review: Mutation + Hostile + Semantic (Outer OODA)
#
# THE 4 LAWS:
# 1. No-Human Zone: AI writes all code, humans write contracts
# 2. Contract is Law: Validation is draconian, self-heal on failure
# 3. We Set the Standard: Human defines target, AI hits it
# 4. Orchestrator Runs Everything: Kestra owns execution
#
# PATTERN: Generate -> Static -> Dynamic -> Adversarial -> (Pass=Exit | Fail=Feedback->Retry)

id: quality-gate-loop
namespace: bitter

inputs:
  - id: contract
    type: STRING
    description: Path to DataContract (source of truth)

  - id: task
    type: STRING
    description: Natural language intent (what AI should generate)

  - id: input_json
    type: STRING
    defaults: "{}"
    description: JSON input for the generated tool

  - id: max_attempts
    type: INT
    defaults: 5
    description: Attempts before escalating to human

  - id: tools_dir
    type: STRING
    defaults: "./bitter-truth/tools"
    description: Directory containing bitter-truth tools

  - id: coverage_threshold
    type: STRING
    defaults: "0.8"
    description: Minimum code coverage (0.0-1.0)

  - id: mutation_threshold
    type: STRING
    defaults: "0.6"
    description: Minimum mutation score (0.0-1.0)

  - id: enable_hostile_review
    type: BOOLEAN
    defaults: true
    description: Enable adversarial AI review

variables:
  feedback: "Initial generation"
  trace_id: "{{ execution.id }}"
  tool_path: "/tmp/tool-{{ execution.id }}.nu"
  output_path: "/tmp/output-{{ execution.id }}.json"
  logs_path: "/tmp/logs-{{ execution.id }}.json"

tasks:
  # LOOP: Generate -> Static -> Dynamic -> Adversarial -> Self-Heal or Escalate
  - id: attempt_loop
    type: io.kestra.plugin.core.flow.ForEach
    values: "{{ range(1, inputs.max_attempts + 1) }}"
    tasks:

      # PHASE 1: GENERATION (Gate 1-3)
      - id: generate_step
        type: io.kestra.plugin.core.flow.Subflow
        namespace: bitter
        flowId: generate-tool-testable
        inputs:
          contract_path: "{{ inputs.contract }}"
          task: "{{ inputs.task }}"
          feedback: "{{ vars.feedback }}"
          attempt: "{{ taskrun.value }}/{{ inputs.max_attempts }}"
          output_path: "{{ vars.tool_path }}"
          timeout_seconds: 300
          trace_id: "{{ vars.trace_id }}"
          tools_dir: "{{ inputs.tools_dir }}"

      # PHASE 2: STATIC ANALYSIS - Micro OODA (Gates 4-6)
      - id: static_analysis
        type: io.kestra.plugin.core.flow.Subflow
        namespace: bitter
        flowId: micro-ooda-static-analysis
        inputs:
          tool_path: "{{ vars.tool_path }}"
          contract_path: "{{ inputs.contract }}"
          trace_id: "{{ vars.trace_id }}"
          tools_dir: "{{ inputs.tools_dir }}"

      # Check static analysis passed
      - id: check_static
        type: io.kestra.plugin.core.flow.If
        condition: "{% set result = outputs.static_analysis.result | from_json %}{{ not result.success }}"
        then:
          - id: static_feedback
            type: io.kestra.plugin.core.execution.SetVariables
            variables:
              feedback: "{{ outputs.static_analysis.feedback }}"

      # PHASE 3: DYNAMIC TESTING - Inner OODA (Gates 7-9)
      - id: dynamic_testing
        type: io.kestra.plugin.core.flow.Subflow
        namespace: bitter
        flowId: inner-ooda-dynamic-testing
        inputs:
          tool_path: "{{ vars.tool_path }}"
          contract_path: "{{ inputs.contract }}"
          input_json: "{{ inputs.input_json }}"
          output_path: "{{ vars.output_path }}"
          logs_path: "{{ vars.logs_path }}"
          coverage_threshold: "{{ inputs.coverage_threshold }}"
          trace_id: "{{ vars.trace_id }}"
          tools_dir: "{{ inputs.tools_dir }}"

      # Check dynamic testing passed
      - id: check_dynamic
        type: io.kestra.plugin.core.flow.If
        condition: "{% set result = outputs.dynamic_testing.result | from_json %}{{ not result.success }}"
        then:
          - id: dynamic_feedback
            type: io.kestra.plugin.core.execution.SetVariables
            variables:
              feedback: "{{ outputs.dynamic_testing.feedback }}"

      # PHASE 4: ADVERSARIAL REVIEW - Outer OODA (Gates 10-12)
      - id: adversarial_review
        type: io.kestra.plugin.core.flow.Subflow
        namespace: bitter
        flowId: outer-ooda-adversarial-review
        inputs:
          tool_path: "{{ vars.tool_path }}"
          contract_path: "{{ inputs.contract }}"
          task: "{{ inputs.task }}"
          mutation_threshold: "{{ inputs.mutation_threshold }}"
          enable_hostile_review: "{{ inputs.enable_hostile_review }}"
          trace_id: "{{ vars.trace_id }}"
          tools_dir: "{{ inputs.tools_dir }}"

      # FINAL CHECK: Did all gates pass?
      - id: check_all_pass
        type: io.kestra.plugin.core.flow.If
        condition: "{% set s = outputs.static_analysis.result | from_json %}{% set d = outputs.dynamic_testing.result | from_json %}{% set a = outputs.adversarial_review.result | from_json %}{{ s.success and d.success and a.success }}"
        then:
          - id: success_log
            type: io.kestra.plugin.core.log.Log
            message: "✓ All 12 gates passed on attempt {{ taskrun.value }}"

          - id: done
            type: io.kestra.plugin.core.execution.Exit
            state: SUCCESS

      # SELF-HEAL: Collect comprehensive feedback
      - id: collect_all_feedback
        type: io.kestra.plugin.core.flow.Subflow
        namespace: bitter
        flowId: collect-comprehensive-feedback
        inputs:
          static_result: "{{ outputs.static_analysis.result }}"
          dynamic_result: "{{ outputs.dynamic_testing.result }}"
          adversarial_result: "{{ outputs.adversarial_review.result }}"
          attempt_number: "{{ taskrun.value }}/{{ inputs.max_attempts }}"

      # UPDATE: Store feedback for next iteration
      - id: update_feedback
        type: io.kestra.plugin.core.execution.SetVariables
        variables:
          feedback: "{{ outputs.collect_all_feedback.feedback }}"

  # ESCALATE: Max attempts exceeded, page human
  - id: escalate
    type: io.kestra.plugin.core.log.Log
    level: ERROR
    message: |
      ⚠️ ESCALATION REQUIRED (Law 2)

      AI failed to pass all 12 gates after {{ inputs.max_attempts }} attempts.

      DO NOT FIX THE GENERATED CODE.
      FIX THE PROMPT OR THE CONTRACT.

      Task: {{ inputs.task }}
      Contract: {{ inputs.contract }}
      Last feedback: {{ vars.feedback }}

  - id: fail
    type: io.kestra.plugin.core.execution.Exit
    state: FAILED

outputs:
  - id: success
    type: BOOLEAN
    value: "{{ taskrun.outcomes contains('done') }}"

  - id: output_file
    type: STRING
    value: "{{ vars.output_path }}"

  - id: tool_file
    type: STRING
    value: "{{ vars.tool_path }}"
```

### Subflow: micro-ooda-static-analysis.yml (Gates 4-6)

```yaml
# Micro OODA Loop: Static Analysis
#
# Fast iteration on syntax, linting, and security issues.
# Can attempt auto-fix before regeneration.
#
# Gates:
#   4. Syntax Validation (language-aware)
#   5. Linting (language-aware)
#   6. Security Scan

id: micro-ooda-static-analysis
namespace: bitter

inputs:
  - id: tool_path
    type: STRING
    description: Path to generated code file

  - id: contract_path
    type: STRING
    description: Path to DataContract (for language detection)

  - id: trace_id
    type: STRING
    description: Trace ID for observability

  - id: tools_dir
    type: STRING
    defaults: "./bitter-truth/tools"

  - id: max_micro_attempts
    type: INT
    defaults: 3
    description: Auto-fix attempts before giving up

variables:
  micro_feedback: ""
  issues_found: "[]"

tasks:
  - id: micro_loop
    type: io.kestra.plugin.core.flow.ForEach
    values: "{{ range(1, inputs.max_micro_attempts + 1) }}"
    tasks:

      # GATE 4: Syntax Validation (Language-Aware)
      - id: gate_4_syntax
        type: io.kestra.plugin.scripts.shell.Commands
        taskRunner:
          type: io.kestra.plugin.core.runner.Process
        commands:
          - |
            echo '{"tool_path": "{{ inputs.tool_path }}", "contract_path": "{{ inputs.contract_path }}", "context": {"trace_id": "{{ inputs.trace_id }}"}}' | \
            nu {{ inputs.tools_dir }}/syntax-check.nu

      # GATE 5: Linting (Language-Aware)
      - id: gate_5_lint
        type: io.kestra.plugin.scripts.shell.Commands
        taskRunner:
          type: io.kestra.plugin.core.runner.Process
        commands:
          - |
            echo '{"tool_path": "{{ inputs.tool_path }}", "contract_path": "{{ inputs.contract_path }}", "context": {"trace_id": "{{ inputs.trace_id }}"}}' | \
            nu {{ inputs.tools_dir }}/lint-dispatch.nu

      # GATE 6: Security Scan
      - id: gate_6_security
        type: io.kestra.plugin.scripts.shell.Commands
        taskRunner:
          type: io.kestra.plugin.core.runner.Process
        commands:
          - |
            echo '{"tool_path": "{{ inputs.tool_path }}", "contract_path": "{{ inputs.contract_path }}", "context": {"trace_id": "{{ inputs.trace_id }}"}}' | \
            nu {{ inputs.tools_dir }}/security-scan.nu

      # Check all micro gates passed
      - id: micro_check
        type: io.kestra.plugin.core.flow.If
        condition: "{% set g4 = outputs.gate_4_syntax.outputFiles['stdout.txt'] | read | from_json %}{% set g5 = outputs.gate_5_lint.outputFiles['stdout.txt'] | read | from_json %}{% set g6 = outputs.gate_6_security.outputFiles['stdout.txt'] | read | from_json %}{{ g4.success and g5.success and g6.success }}"
        then:
          - id: micro_success
            type: io.kestra.plugin.core.execution.Exit
            state: SUCCESS
        else:
          # Try auto-fix if available
          - id: auto_fix
            type: io.kestra.plugin.scripts.shell.Commands
            taskRunner:
              type: io.kestra.plugin.core.runner.Process
            commands:
              - |
                echo '{"tool_path": "{{ inputs.tool_path }}", "issues": {{ vars.issues_found }}, "context": {"trace_id": "{{ inputs.trace_id }}"}}' | \
                nu {{ inputs.tools_dir }}/auto-fix.nu || true

outputs:
  - id: result
    type: STRING
    value: '{"success": {{ taskrun.outcomes contains("micro_success") }}, "gates": {"syntax": true, "lint": true, "security": true}}'

  - id: feedback
    type: STRING
    value: "{{ vars.micro_feedback }}"
```

---

## OODA Loop Decision Matrix

### Micro OODA (Static Analysis) Decisions

| Observation | Orientation | Decision | Action |
|-------------|-------------|----------|--------|
| Syntax error | Parse failure | Auto-fix possible? | Regenerate with error context |
| Lint warning | Style issue | Severity check | Ignore INFO, fix WARN/ERROR |
| Lint error | Code smell | Pattern match | Regenerate with lint feedback |
| Security vuln | Risk assessment | Severity ≥ HIGH? | Block and regenerate |
| Security warn | Low risk | Acceptable? | Log and continue |

### Inner OODA (Dynamic Testing) Decisions

| Observation | Orientation | Decision | Action |
|-------------|-------------|----------|--------|
| Test pass | Happy path works | Coverage check | Continue or add tests |
| Test fail | Logic error | Fixable? | Regenerate with failure |
| Low coverage | Untested paths | Gap analysis | Generate test cases |
| Contract fail | Schema mismatch | Field analysis | Regenerate with schema errors |
| Timeout | Performance issue | Optimize? | Add timeout handling |

### Outer OODA (Adversarial Review) Decisions

| Observation | Orientation | Decision | Action |
|-------------|-------------|----------|--------|
| High mutant survival | Weak tests | Add tests? | Generate mutation-killing tests |
| Hostile critique | Design flaw | Severity? | Regenerate or accept |
| Semantic drift | Wrong solution | Alignment? | Clarify task, regenerate |
| All gates pass | Quality achieved | Ship it | Output final tool |

---

## Feedback Accumulation Strategy

### Feedback Structure

```yaml
feedback:
  attempt: 3
  history:
    - attempt: 1
      gates_failed: [5, 8, 11]
      issues:
        - gate: 5
          type: lint
          message: "Function too long (72 lines)"
        - gate: 8
          type: contract
          message: "Missing required field: trace_id"
        - gate: 11
          type: hostile_review
          message: "No error handling for empty input"
    - attempt: 2
      gates_failed: [8]
      issues:
        - gate: 8
          type: contract
          message: "trace_id must be string, got null"

  patterns_detected:
    - "Repeated trace_id issues - emphasize in prompt"
    - "Error handling frequently missing"

  successful_elements:
    - "Main logic correct"
    - "Output structure improved"
    - "Lint issues resolved"
```

### Progressive Prompt Enhancement

```
Attempt 1: Base prompt + contract + task
Attempt 2: + Previous errors + what worked
Attempt 3: + Pattern analysis + explicit constraints
Attempt 4: + Concrete examples + anti-patterns
Attempt 5: + Simplified task + fallback strategy
```

---

## Metrics & Observability

### Quality Metrics

```yaml
execution_metrics:
  trace_id: "abc123"
  total_duration_ms: 45000
  gates:
    - id: 1
      name: "contract_parse"
      status: pass
      duration_ms: 100
    - id: 5
      name: "lint"
      status: fail
      duration_ms: 500
      issues_found: 3
    # ...

  attempts: 3
  final_status: success

  quality_scores:
    coverage: 0.87
    mutation_score: 0.72
    hostile_review_score: 0.85
    security_score: 1.0

  feedback_effectiveness:
    issues_per_attempt: [5, 2, 0]
    convergence_rate: 0.6
```

### Dashboard Metrics

- **Gate Pass Rate**: % of executions passing each gate
- **Attempt Distribution**: Histogram of attempts needed
- **Common Failure Modes**: Top issues by gate
- **AI Efficiency**: Tokens spent vs. quality achieved
- **Time to Quality**: Duration from task to passing all gates

---

## Implementation Phases

### Phase 1: Foundation (Current + Enhancements)
- [ ] Add syntax validation gate (Gate 4)
- [ ] Create lint-nushell.nu tool (Gate 5)
- [ ] Create security-scan.nu tool (Gate 6)
- [ ] Deploy micro-ooda-static-analysis.yml flow

### Phase 2: Dynamic Testing
- [ ] Create coverage-check.nu tool (Gate 9)
- [ ] Implement test case generation
- [ ] Deploy inner-ooda-dynamic-testing.yml flow
- [ ] Add coverage threshold enforcement

### Phase 3: Adversarial Review
- [ ] Create mutate-test.nu tool (Gate 10)
- [ ] Create hostile-review.nu tool (Gate 11)
- [ ] Create semantic-check.nu tool (Gate 12)
- [ ] Deploy outer-ooda-adversarial-review.yml flow

### Phase 4: Integration
- [ ] Deploy quality-gate-loop.yml orchestrator
- [ ] Implement feedback accumulation
- [ ] Add metrics collection
- [ ] Create dashboard

### Phase 5: Optimization
- [ ] Tune thresholds based on data
- [ ] Optimize AI prompt templates
- [ ] Add caching for repeated patterns
- [ ] Implement parallel gate execution where possible

---

## Key Design Decisions

### 1. Recursive vs. Iterative

**Chosen: Hybrid**
- Micro OODA: Iterative (3 attempts, fast fixes)
- Inner OODA: Iterative (5 attempts, test improvements)
- Outer OODA: Recursive (can restart from generation)

### 2. Fail Fast vs. Collect All

**Chosen: Collect All per Phase, Fail Fast between Phases**
- Within a phase: Run all gates, collect all issues
- Between phases: Don't proceed if phase fails
- Reason: More feedback = better regeneration

### 3. AI Review: Same Model vs. Different Model

**Chosen: Same Model, Different Persona**
- Use Qwen Coder 3 for both generation and review
- Hostile reviewer uses skeptical system prompt
- Reason: Speed (250 tok/s), cost efficiency

### 4. Test Generation: AI vs. Property-Based

**Chosen: AI with Property-Based Fallback**
- Primary: AI generates test cases from contract
- Fallback: Property-based testing for edge cases
- Reason: AI understands intent, properties catch edges

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Infinite loops | Max attempts at each OODA level |
| Token explosion | Feedback summarization, context window management |
| False positives | Severity thresholds, human escape hatch |
| AI hallucination | Schema validation as ground truth |
| Performance | Parallel gates, caching, fast model |
| Circular feedback | Pattern detection, feedback deduplication |

---

## Success Criteria

1. **Correctness**: 95% of generated tools pass all 12 gates within 5 attempts
2. **Coverage**: 80% line coverage minimum on generated code
3. **Mutation Score**: 60% minimum (tests kill 60% of mutants)
4. **Security**: 0 high-severity vulnerabilities in shipped code
5. **Semantic Alignment**: <0.2 drift score between task and implementation
6. **Efficiency**: Average 2.5 attempts to pass all gates
