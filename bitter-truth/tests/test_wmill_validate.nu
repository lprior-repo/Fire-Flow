#!/usr/bin/env nu
# Tests for wmill-validate.nu
#
# Run with: nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/test_wmill_validate.nu'
#
# These tests validate the Windmill validation tool itself, not the Windmill instance.
# Some tests require a running Windmill instance at localhost:8200.

use std assert

# Helper to run wmill-validate.nu with given args
def run_wmill_validate [args: list<string>] {
    let tools_dir = $env.PWD | path join "tools"
    let script_path = $tools_dir | path join "wmill-validate.nu"
    ^nu $script_path ...$args | complete
}

# Helper to check if wmill CLI is available
def wmill_available [] {
    (which wmill | length) > 0
}

# Helper to check if Windmill server is reachable
def windmill_server_available [] {
    let result = do { ^curl -s --max-time 2 http://localhost:8200/api/version } | complete
    $result.exit_code == 0
}

#[test]
def test_wmill_validate_cli_check [] {
    # This test verifies the CLI check works
    if not (wmill_available) {
        print "Skipping: wmill CLI not available"
        return
    }

    # Run with --check to avoid actual deployment
    let result = run_wmill_validate ["--check"]
    
    # Should complete (exit 0 or 1 depending on validation)
    assert ($result.exit_code == 0 or $result.exit_code == 1) "Should complete with exit 0 or 1"
    assert ($result.stdout | str contains "Windmill Validation Tool") "Should show tool header"
}

#[test]
def test_wmill_validate_ci_mode_json_output [] {
    if not (wmill_available) {
        print "Skipping: wmill CLI not available"
        return
    }

    let result = run_wmill_validate ["--ci", "--check"]
    
    # CI mode should output JSON
    let lines = $result.stdout | lines | where {|line| $line | str starts-with "{"}
    assert (($lines | length) >= 1) "CI mode should output at least one JSON line"
    
    # Parse the JSON output
    let json_line = $lines | last
    let output = $json_line | from json
    
    assert ($output | get success? | describe | str starts-with "bool") "JSON should have success field"
    assert ($output | get results? | is-not-empty) "JSON should have results field"
    assert ($output | get duration_ms? | is-not-empty) "JSON should have duration_ms field"
}

#[test]
def test_wmill_validate_scripts_only [] {
    if not (wmill_available) {
        print "Skipping: wmill CLI not available"
        return
    }

    let result = run_wmill_validate ["--scripts-only", "--check"]
    
    # Should show script validation but not flow validation
    assert ($result.stdout | str contains "scripts") "Should mention scripts"
    # In scripts-only mode, flows validation is skipped
}

#[test]
def test_wmill_validate_flows_only [] {
    if not (wmill_available) {
        print "Skipping: wmill CLI not available"
        return
    }

    let result = run_wmill_validate ["--flows-only", "--check"]
    
    # Should show flow validation but not script validation
    assert ($result.stdout | str contains "flows") "Should mention flows"
}

#[test]
def test_wmill_validate_verbose_mode [] {
    if not (wmill_available) {
        print "Skipping: wmill CLI not available"
        return
    }

    let result = run_wmill_validate ["--check", "--verbose"]
    
    # Verbose mode should still work
    assert ($result.stdout | str contains "Validation Tool") "Should show header"
}

#[test]
def test_wmill_validate_info_subcommand [] {
    if not (wmill_available) {
        print "Skipping: wmill CLI not available"
        return
    }

    let result = run_wmill_validate ["info"]
    
    # Info should show workspace information
    assert ($result.stdout | str contains "Workspace") "Should mention Workspace"
}

#[test]
def test_wmill_validate_check_mode_skips_push [] {
    if not (wmill_available) {
        print "Skipping: wmill CLI not available"
        return
    }

    let result = run_wmill_validate ["--check"]
    
    # Check mode should skip actual push
    assert ($result.stdout | str contains "Check mode") "Should mention check mode"
}

#[test]
def test_wmill_validate_summary_output [] {
    if not (wmill_available) {
        print "Skipping: wmill CLI not available"
        return
    }

    let result = run_wmill_validate ["--check"]
    
    # Should show summary
    assert ($result.stdout | str contains "Summary") "Should show Summary"
    assert ($result.stdout | str contains "Passed:") "Should show Passed count"
    assert ($result.stdout | str contains "Failed:") "Should show Failed count"
    assert ($result.stdout | str contains "Duration:") "Should show Duration"
}

#[test]
def test_wmill_validate_checks_uncommitted_changes [] {
    if not (wmill_available) {
        print "Skipping: wmill CLI not available"
        return
    }

    let result = run_wmill_validate ["--check"]
    
    # Should check for uncommitted changes
    assert ($result.stdout | str contains "uncommitted changes") "Should check for uncommitted changes"
}

#[test]
def test_wmill_validate_json_structure [] {
    if not (wmill_available) {
        print "Skipping: wmill CLI not available"
        return
    }

    let result = run_wmill_validate ["--ci", "--check"]
    
    # Extract JSON from output
    let json_lines = $result.stdout | lines | where {|line| $line | str starts-with "{"}
    if (($json_lines | length) == 0) {
        assert false "Should have JSON output in CI mode"
        return
    }
    
    let output = $json_lines | last | from json
    
    # Validate structure
    assert ($output.results? | is-not-empty) "Should have results"
    assert ($output.results.scripts? | is-not-empty) "Should have scripts results"
    assert ($output.results.flows? | is-not-empty) "Should have flows results"
    assert ($output.results.sync? | is-not-empty) "Should have sync results"
    
    # Each result category should have passed/failed/errors
    let scripts = $output.results.scripts
    assert ($scripts.passed? | describe | str starts-with "int") "scripts.passed should be int"
    assert ($scripts.failed? | describe | str starts-with "int") "scripts.failed should be int"
    assert ($scripts.errors? | describe | str starts-with "list") "scripts.errors should be list"
}

# Integration test - requires running Windmill
#[test]
def test_wmill_validate_with_server [] {
    if not (wmill_available) {
        print "Skipping: wmill CLI not available"
        return
    }
    
    if not (windmill_server_available) {
        print "Skipping: Windmill server not available at localhost:8200"
        return
    }

    # Run full validation (without --check to test actual sync)
    # But we still use --check to avoid deploying
    let result = run_wmill_validate ["--check"]
    
    assert equal $result.exit_code 0 "Should pass validation"
    assert ($result.stdout | str contains "All validations passed") "Should pass all validations"
}
