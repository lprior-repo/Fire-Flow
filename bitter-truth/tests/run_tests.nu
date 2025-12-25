#!/usr/bin/env nu
# Run all bitter-truth tests
#
# Usage:
#   nu bitter-truth/tests/run_tests.nu           # Run all tests
#   nu bitter-truth/tests/run_tests.nu --quick   # Run fast tests only (skip integration)

use /tmp/nutest/nutest

def main [
    --quick (-q)  # Skip slow integration tests
] {
    let test_dir = $env.FILE_PWD

    print "╭─────────────────────────────────────────╮"
    print "│  bitter-truth Test Suite                │"
    print "╰─────────────────────────────────────────╯"
    print ""

    # Ensure we're in project root
    let project_root = $test_dir | path dirname | path dirname
    cd $project_root

    # Check prerequisites
    print "Checking prerequisites..."

    let llm_cleaner = "tools/llm-cleaner/target/release/llm-cleaner"
    if not ($llm_cleaner | path exists) {
        print $"(ansi red)ERROR: llm-cleaner not built. Run:(ansi reset)"
        print $"  cargo build --release --manifest-path=tools/llm-cleaner/Cargo.toml"
        exit 1
    }

    print $"  ✓ llm-cleaner found"
    print ""

    # Run tests
    if $quick {
        print "Running quick tests (excluding integration)..."
        nutest run-tests --path $test_dir --match-test "^(?!.*integration).*$"
    } else {
        print "Running all tests..."
        nutest run-tests --path $test_dir
    }
}
