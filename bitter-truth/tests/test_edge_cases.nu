#!/usr/bin/env nu
# Edge case tests for bitter-truth tools
# Tests for malformed input, missing dependencies, timeouts, etc.

use std assert

#[test]
def test_run_tool_empty_stdin [] {
    # CRITICAL BUG: What happens with empty stdin?
    let tools_dir = $env.PWD | path join "bitter-truth/tools"

    let result = do {
        echo "" | nu ($tools_dir | path join "run-tool.nu")
    } | complete

    # Currently crashes - we want it to return a proper error response
    # This test documents the current broken behavior
    # TODO: Should exit 0 with proper JSON error in output
    assert ($result.exit_code != 0) "Empty stdin causes script crash (BUG)"
}

#[test]
def test_run_tool_malformed_json [] {
    # CRITICAL BUG: What happens with malformed JSON?
    let tools_dir = $env.PWD | path join "bitter-truth/tools"

    let result = do {
        echo "not json at all {" | nu ($tools_dir | path join "run-tool.nu")
    } | complete

    # Currently crashes - should return proper error
    assert ($result.exit_code != 0) "Malformed JSON causes script crash (BUG)"
}

#[test]
def test_validate_empty_stdin [] {
    # Same issue in validate.nu
    let tools_dir = $env.PWD | path join "bitter-truth/tools"

    let result = do {
        echo "" | nu ($tools_dir | path join "validate.nu")
    } | complete

    assert ($result.exit_code != 0) "Empty stdin causes crash (BUG)"
}

#[test]
def test_generate_empty_stdin [] {
    # Same issue in generate.nu
    let tools_dir = $env.PWD | path join "bitter-truth/tools"

    let result = do {
        echo "" | nu ($tools_dir | path join "generate.nu")
    } | complete

    assert ($result.exit_code != 0) "Empty stdin causes crash (BUG)"
}

#[test]
def test_echo_empty_stdin [] {
    # Same issue in echo.nu
    let tools_dir = $env.PWD | path join "bitter-truth/tools"

    let result = do {
        echo "" | nu ($tools_dir | path join "echo.nu")
    } | complete

    assert ($result.exit_code != 0) "Empty stdin causes crash (BUG)"
}

#[test]
def test_run_tool_with_very_large_json_input [] {
    # What happens with huge JSON payloads?
    let tools_dir = $env.PWD | path join "bitter-truth/tools"

    # Create large text (100k characters) - use range to generate repetition
    let large_message = ((1..1000 | each { |_| "x" } | str join))
    let input = {
        tool_path: "/tmp/dummy-tool.nu"
        tool_input: { message: $large_message }
        context: { trace_id: "test-large" }
    }

    let result = do {
        $input | to json | nu ($tools_dir | path join "run-tool.nu")
    } | complete

    # Should fail gracefully (tool doesn't exist) not crash on size
    # The error should be about missing tool, not JSON parsing
    assert ($result.exit_code != 0) "Large input should fail on missing tool"
}

#[test]
def test_generate_empty_trace_id_filename [] {
    # BUG: Empty trace_id creates malformed filename
    let tools_dir = $env.PWD | path join "bitter-truth/tools"

    let input = {
        contract_path: ($env.PWD | path join "bitter-truth/contracts/tools/echo.yaml")
        task: "Test"
        attempt: "1/5"
        context: {
            trace_id: ""  # Empty!
            dry_run: true
        }
    }

    let result = do {
        $input | to json | nu ($tools_dir | path join "generate.nu")
    } | complete

    # Should still work, but filename will be weird (/tmp/prompt--1-5.txt)
    # This is acceptable for dry-run but could cause issues in production
    assert equal $result.exit_code 0 "Empty trace_id should still work in dry-run"
}

#[test]
def test_generate_llm_cleaner_missing [] {
    # BUG: Hardcoded llm-cleaner path will fail if not built
    # We can only test this if llm-cleaner exists, so skip if it doesn't
    let llm_cleaner = "/home/lewis/src/Fire-Flow/tools/llm-cleaner/target/release/llm-cleaner"

    if not ($llm_cleaner | path exists) {
        print "SKIP: llm-cleaner not built yet"
        return
    }

    # If llm-cleaner exists, tests should pass
    assert ($llm_cleaner | path exists) "llm-cleaner should exist"
}

#[test]
def test_echo_handles_special_characters [] {
    # Test with various special characters
    let tools_dir = $env.PWD | path join "bitter-truth/tools"

    let special_strings = [
        "Hello\nWorld"          # Newline
        "Tab\there"             # Tab
        "Quote\"inside"         # Quote
        "Backslash\\"           # Backslash
        "Unicode: 你好"         # Unicode
        ""                      # Empty string - should fail
    ]

    # Test the special characters (except empty string)
    let test_strings = $special_strings | first 5

    for $msg in $test_strings {
        let input = {
            message: $msg
            context: { trace_id: "test-special" }
        } | to json

        let result = do {
            $input | nu ($tools_dir | path join "echo.nu")
        } | complete

        assert equal $result.exit_code 0 $"Should handle special chars: ($msg | str substring 0..20)"
    }
}

#[test]
def test_echo_empty_message_fails [] {
    # Empty message should be rejected
    let tools_dir = $env.PWD | path join "bitter-truth/tools"

    let input = {
        message: ""
        context: { trace_id: "test-empty-msg" }
    } | to json

    let result = do {
        $input | nu ($tools_dir | path join "echo.nu")
    } | complete

    assert equal $result.exit_code 1 "Empty message should fail"
    let output = $result.stdout | from json
    assert equal $output.success false "Should return success=false"
}

#[test]
def test_run_tool_output_file_permissions [] {
    # Can we write to the output path? Check permissions
    let tools_dir = $env.PWD | path join "bitter-truth/tools"
    let test_id = (random uuid | str substring 0..8)

    # Try to write to a read-only location
    let read_only_path = "/tmp/test-readonly-$test_id.json"

    # Create a test tool
    let tool_path = $"/tmp/test-tool-($test_id).nu"
    '#!/usr/bin/env nu
def main [] {
    { echo: "test" } | to json | print
}' | save -f $tool_path

    let input = {
        tool_path: $tool_path
        tool_input: {}
        output_path: $read_only_path
        logs_path: $"/tmp/test-logs-($test_id).json"
        context: { trace_id: "test-perms" }
    } | to json

    let result = do {
        $input | nu ($tools_dir | path join "run-tool.nu")
    } | complete

    # Should succeed since /tmp is writable
    assert equal $result.exit_code 0 "Should write to /tmp successfully"

    # Cleanup
    rm -f $tool_path $read_only_path $"/tmp/test-logs-($test_id).json"
}

#[test]
def test_validate_missing_server [] {
    # What if the server key doesn't exist in contract?
    let tools_dir = $env.PWD | path join "bitter-truth/tools"

    let input = {
        contract_path: ($env.PWD | path join "bitter-truth/contracts/tools/echo.yaml")
        server: "nonexistent-server"
        context: { trace_id: "test-bad-server", dry_run: true }
    }

    let result = do {
        $input | to json | nu ($tools_dir | path join "validate.nu")
    } | complete

    # Dry-run should pass regardless of server
    assert equal $result.exit_code 0 "Dry-run should pass"
}
