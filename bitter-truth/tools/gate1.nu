#!/usr/bin/env nu
# Gate 1: Syntax Check (Parse + Lint + Type)
#
# Contract: contracts/tools/gate1.yaml
# Input: JSON from stdin (Gate1Input)
# Output: JSON to stdout (ToolResponse wrapping Gate1Output)
# Logs: JSON to stderr
#
# This is the first gate in the validation pipeline.
# Binary pass/fail - if any check fails, discard the branch.
#
# Checks performed:
# 1. Parse/Syntax - Is the code syntactically valid?
# 2. Lint - Does the code follow style guidelines?
# 3. Type - Does the code type-check correctly?

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
        exit 1
    }

    # Extract context
    let ctx = $input.context? | default {}
    let trace_id = $ctx.trace_id? | default ""
    let dry_run = $ctx.dry_run? | default false

    # Extract validation inputs
    let code_path = $input.code_path? | default ""
    let language = $input.language? | default ""

    # Validate required fields
    if ($code_path | is-empty) {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "error", msg: "code_path is required", trace_id: $trace_id } | to json -r | print -e
        { success: false, error: "code_path is required", trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 1
    }

    if ($language | is-empty) {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "error", msg: "language is required", trace_id: $trace_id } | to json -r | print -e
        { success: false, error: "language is required", trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 1
    }

    # Dry run mode
    if $dry_run {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "info", msg: "dry-run mode - skipping Gate 1", trace_id: $trace_id } | to json -r | print -e
        let output = {
            passed: true
            syntax_ok: true
            lint_ok: true
            type_ok: true
            errors: []
            was_dry_run: true
        }
        { success: true, data: $output, trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 0
    }

    # Check file exists
    if not ($code_path | path exists) {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "error", msg: $"code file not found: ($code_path)", trace_id: $trace_id } | to json -r | print -e
        { success: false, error: $"Code file not found: ($code_path)", trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 1
    }

    { level: "info", msg: "starting Gate 1 validation", trace_id: $trace_id, code_path: $code_path, language: $language } | to json -r | print -e

    # Run all checks based on language
    let checks = match $language {
        "rust" | "rs" => (check_rust $code_path $trace_id),
        "python" | "py" => (check_python $code_path $trace_id),
        "typescript" | "ts" => (check_typescript $code_path $trace_id),
        "go" => (check_go $code_path $trace_id),
        _ => {
            { level: "error", msg: $"unsupported language: ($language)", trace_id: $trace_id } | to json -r | print -e
            { passed: false, syntax_ok: false, lint_ok: false, type_ok: false, errors: [$"Unsupported language: ($language)"] }
        }
    }

    let duration_ms = (date now) - $start | into int | $in / 1000000
    let passed = $checks.passed

    { level: "info", msg: "Gate 1 complete", passed: $passed, duration_ms: $duration_ms, trace_id: $trace_id } | to json -r | print -e

    let output = {
        passed: $passed
        syntax_ok: $checks.syntax_ok
        lint_ok: $checks.lint_ok
        type_ok: $checks.type_ok
        errors: $checks.errors
        was_dry_run: false
    }

    if $passed {
        { success: true, data: $output, trace_id: $trace_id, duration_ms: $duration_ms } | to json | print
    } else {
        { success: false, data: $output, error: "Gate 1 validation failed", trace_id: $trace_id, duration_ms: $duration_ms } | to json | print
    }
    exit 0
}

# Rust validation: cargo check (includes parse + type), cargo clippy (lint)
def check_rust [code_path: string, trace_id: string] {
    let code_dir = $code_path | path dirname
    let errors = []

    { level: "debug", msg: "checking Rust syntax and types", trace_id: $trace_id } | to json -r | print -e

    # First, try simple rustc syntax check on the file
    # Use --emit=dep-info which doesn't require writing output
    let syntax_result = do { rustc --edition 2021 --emit=dep-info --out-dir /tmp $code_path } | complete
    let syntax_ok = $syntax_result.exit_code == 0

    if not $syntax_ok {
        { level: "warn", msg: "Rust syntax check failed", stderr: $syntax_result.stderr, trace_id: $trace_id } | to json -r | print -e
        return {
            passed: false
            syntax_ok: false
            lint_ok: false
            type_ok: false
            errors: ($syntax_result.stderr | lines | where { |l| ($l | str length) > 0 })
        }
    }

    { level: "debug", msg: "Rust syntax OK", trace_id: $trace_id } | to json -r | print -e

    # Check if there's a Cargo.toml for more comprehensive checking
    let cargo_toml = $code_dir | path join "Cargo.toml"
    let has_cargo = $cargo_toml | path exists

    mut type_ok = true
    mut lint_ok = true
    mut all_errors = []

    if $has_cargo {
        # Run cargo check for type checking
        { level: "debug", msg: "running cargo check", trace_id: $trace_id } | to json -r | print -e
        let check_result = do { cargo check --manifest-path $cargo_toml } | complete

        if $check_result.exit_code != 0 {
            $type_ok = false
            $all_errors = ($all_errors | append ($check_result.stdout | lines | where { |l| ($l | str length) > 0 }))
        }

        # Run cargo clippy for linting (if available)
        let has_clippy = (do { cargo clippy --version } | complete).exit_code == 0
        if $has_clippy {
            { level: "debug", msg: "running cargo clippy", trace_id: $trace_id } | to json -r | print -e
            let clippy_result = do { cargo clippy --manifest-path $cargo_toml -- -D warnings } | complete

            if $clippy_result.exit_code != 0 {
                $lint_ok = false
                $all_errors = ($all_errors | append ($clippy_result.stdout | lines | where { |l| ($l | str length) > 0 }))
            }
        } else {
            { level: "warn", msg: "cargo clippy not installed, skipping lint check", trace_id: $trace_id } | to json -r | print -e
        }
    } else {
        { level: "debug", msg: "no Cargo.toml found, skipping cargo check/clippy", trace_id: $trace_id } | to json -r | print -e
    }

    {
        passed: ($syntax_ok and $type_ok and $lint_ok)
        syntax_ok: $syntax_ok
        lint_ok: $lint_ok
        type_ok: $type_ok
        errors: $all_errors
    }
}

# Python validation: py_compile (syntax), ruff (lint), mypy (type)
def check_python [code_path: string, trace_id: string] {
    mut syntax_ok = true
    mut lint_ok = true
    mut type_ok = true
    mut all_errors = []

    # Syntax check with py_compile
    { level: "debug", msg: "checking Python syntax", trace_id: $trace_id } | to json -r | print -e
    let syntax_result = do { python -m py_compile $code_path } | complete

    if $syntax_result.exit_code != 0 {
        $syntax_ok = false
        $all_errors = ($all_errors | append ($syntax_result.stderr | lines | where { |l| ($l | str length) > 0 }))
        return {
            passed: false
            syntax_ok: false
            lint_ok: false
            type_ok: false
            errors: $all_errors
        }
    }

    { level: "debug", msg: "Python syntax OK", trace_id: $trace_id } | to json -r | print -e

    # Lint with ruff (if available)
    let has_ruff = (which ruff | length) > 0
    if $has_ruff {
        { level: "debug", msg: "running ruff lint", trace_id: $trace_id } | to json -r | print -e
        let ruff_result = do { ruff check $code_path } | complete

        if $ruff_result.exit_code != 0 {
            $lint_ok = false
            $all_errors = ($all_errors | append ($ruff_result.stdout | lines | where { |l| ($l | str length) > 0 }))
        }
    } else {
        { level: "warn", msg: "ruff not installed, skipping lint check", trace_id: $trace_id } | to json -r | print -e
    }

    # Type check with mypy (if available)
    let has_mypy = (which mypy | length) > 0
    if $has_mypy {
        { level: "debug", msg: "running mypy type check", trace_id: $trace_id } | to json -r | print -e
        let mypy_result = do { mypy --ignore-missing-imports $code_path } | complete

        if $mypy_result.exit_code != 0 {
            $type_ok = false
            $all_errors = ($all_errors | append ($mypy_result.stdout | lines | where { |l| ($l | str length) > 0 }))
        }
    } else {
        { level: "warn", msg: "mypy not installed, skipping type check", trace_id: $trace_id } | to json -r | print -e
    }

    {
        passed: ($syntax_ok and $lint_ok and $type_ok)
        syntax_ok: $syntax_ok
        lint_ok: $lint_ok
        type_ok: $type_ok
        errors: $all_errors
    }
}

# TypeScript validation: tsc --noEmit (syntax + type), eslint (lint)
def check_typescript [code_path: string, trace_id: string] {
    mut syntax_ok = true
    mut lint_ok = true
    mut type_ok = true
    mut all_errors = []

    # Check if tsc is available
    let has_tsc = (which tsc | length) > 0
    if not $has_tsc {
        { level: "error", msg: "tsc not installed", trace_id: $trace_id } | to json -r | print -e
        return {
            passed: false
            syntax_ok: false
            lint_ok: false
            type_ok: false
            errors: ["tsc (TypeScript compiler) not installed"]
        }
    }

    # TypeScript syntax + type check
    { level: "debug", msg: "checking TypeScript with tsc", trace_id: $trace_id } | to json -r | print -e
    let tsc_result = do { tsc --noEmit --skipLibCheck $code_path } | complete

    if $tsc_result.exit_code != 0 {
        $syntax_ok = false
        $type_ok = false
        $all_errors = ($all_errors | append ($tsc_result.stdout | lines | where { |l| ($l | str length) > 0 }))
        $all_errors = ($all_errors | append ($tsc_result.stderr | lines | where { |l| ($l | str length) > 0 }))
        return {
            passed: false
            syntax_ok: false
            lint_ok: false
            type_ok: false
            errors: $all_errors
        }
    }

    { level: "debug", msg: "TypeScript syntax/type OK", trace_id: $trace_id } | to json -r | print -e

    # Lint with eslint (if available)
    let has_eslint = (which eslint | length) > 0
    if $has_eslint {
        { level: "debug", msg: "running eslint", trace_id: $trace_id } | to json -r | print -e
        let eslint_result = do { eslint $code_path } | complete

        if $eslint_result.exit_code != 0 {
            $lint_ok = false
            $all_errors = ($all_errors | append ($eslint_result.stdout | lines | where { |l| ($l | str length) > 0 }))
        }
    } else {
        { level: "warn", msg: "eslint not installed, skipping lint check", trace_id: $trace_id } | to json -r | print -e
    }

    {
        passed: ($syntax_ok and $lint_ok and $type_ok)
        syntax_ok: $syntax_ok
        lint_ok: $lint_ok
        type_ok: $type_ok
        errors: $all_errors
    }
}

# Go validation: go build (syntax + type), go vet (lint)
def check_go [code_path: string, trace_id: string] {
    let code_dir = $code_path | path dirname
    mut syntax_ok = true
    mut lint_ok = true
    mut type_ok = true
    mut all_errors = []

    # Check if go is available
    let has_go = (which go | length) > 0
    if not $has_go {
        { level: "error", msg: "go not installed", trace_id: $trace_id } | to json -r | print -e
        return {
            passed: false
            syntax_ok: false
            lint_ok: false
            type_ok: false
            errors: ["go compiler not installed"]
        }
    }

    # Go syntax + type check
    { level: "debug", msg: "checking Go with go build", trace_id: $trace_id } | to json -r | print -e
    let build_result = do { go build -o /dev/null $code_path } | complete

    if $build_result.exit_code != 0 {
        $syntax_ok = false
        $type_ok = false
        $all_errors = ($all_errors | append ($build_result.stderr | lines | where { |l| ($l | str length) > 0 }))
        return {
            passed: false
            syntax_ok: false
            lint_ok: false
            type_ok: false
            errors: $all_errors
        }
    }

    { level: "debug", msg: "Go syntax/type OK", trace_id: $trace_id } | to json -r | print -e

    # Lint with go vet
    { level: "debug", msg: "running go vet", trace_id: $trace_id } | to json -r | print -e
    let vet_result = do { go vet $code_path } | complete

    if $vet_result.exit_code != 0 {
        $lint_ok = false
        $all_errors = ($all_errors | append ($vet_result.stderr | lines | where { |l| ($l | str length) > 0 }))
    }

    # Optional: golangci-lint if available
    let has_golangci = (which golangci-lint | length) > 0
    if $has_golangci {
        { level: "debug", msg: "running golangci-lint", trace_id: $trace_id } | to json -r | print -e
        let golint_result = do { golangci-lint run $code_path } | complete
        if $golint_result.exit_code != 0 {
            $lint_ok = false
            $all_errors = ($all_errors | append ($golint_result.stdout | lines | where { |l| ($l | str length) > 0 }))
        }
    } else {
        { level: "debug", msg: "golangci-lint not installed, skipping", trace_id: $trace_id } | to json -r | print -e
    }

    {
        passed: ($syntax_ok and $lint_ok and $type_ok)
        syntax_ok: $syntax_ok
        lint_ok: $lint_ok
        type_ok: $type_ok
        errors: $all_errors
    }
}
