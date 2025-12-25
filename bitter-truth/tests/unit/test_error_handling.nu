#!/usr/bin/env nu
# Unit tests for error response format consistency
# Validates that all tools return consistent error responses
#
# Run with: nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/unit'

use std assert

# Helper to get tools directory
def tools_dir [] {
    $env.PWD | path join "bitter-truth/tools"
}

#[test]
def test_error_response_has_required_fields [] {
    # Arrange: Create input that will fail validation (missing required field)
    let input = {
        context: { trace_id: "test-error-fields" }
        # Missing 'message' field - should fail
    }

    # Act: Execute echo.nu which requires 'message'
    let result = do {
        $input | to json | nu (tools_dir | path join "echo.nu")
    } | complete

    # Assert: Error response should have all required fields
    assert equal $result.exit_code 1 "Should exit with code 1"
    let output = $result.stdout | from json

    # Check required fields
    assert (($output | get success | describe) == "bool") "Should have 'success' field (bool)"
    assert equal $output.success false "success should be false"

    assert (($output | get error | describe) == "string") "Should have 'error' field (string)"
    assert (($output.error | str length) > 0) "error should be non-empty"

    assert (($output | get trace_id | describe) == "string") "Should have 'trace_id' field (string)"
    assert equal $output.trace_id "test-error-fields" "trace_id should match input"

    assert (($output | get duration_ms | describe) == "int") "Should have 'duration_ms' field (int)"
    assert (($output.duration_ms >= 0)) "duration_ms should be non-negative"
}

#[test]
def test_error_preserves_trace_id [] {
    # Arrange: Create failing request with specific trace_id
    let trace_id = $"test-trace-(random uuid | str substring 0..8)"
    let input = {
        tool_path: "/nonexistent/path/to/tool.nu"
        context: { trace_id: $trace_id }
    }

    # Act: Execute run-tool.nu with nonexistent tool
    let result = do {
        $input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    # Assert: trace_id should be preserved in error response
    assert equal $result.exit_code 1 "Should fail with exit code 1"
    let output = $result.stdout | from json
    assert equal $output.success false "Should have success=false"
    assert equal $output.trace_id $trace_id "trace_id should be preserved"
}

#[test]
def test_error_includes_duration_ms [] {
    # Arrange: Create input that will fail quickly
    let input = {
        contract_path: "/nonexistent/contract.yaml"
        context: { trace_id: "test-duration" }
    }

    # Act: Execute validate.nu with nonexistent contract
    let result = do {
        $input | to json | nu (tools_dir | path join "validate.nu")
    } | complete

    # Assert: Error response should include duration_ms
    assert equal $result.exit_code 1 "Should fail"
    let output = $result.stdout | from json
    assert equal $output.success false "Should indicate failure"

    # Verify duration_ms is present and reasonable
    assert (($output | get duration_ms | describe) == "int") "duration_ms should be integer"
    assert (($output.duration_ms >= 0)) "duration_ms should be non-negative"
    assert (($output.duration_ms < 10000)) "duration_ms should be less than 10 seconds for quick failure"
}

#[test]
def test_error_logs_to_stderr [] {
    # Arrange: Create failing input
    let input = {
        message: ""  # Empty message should fail
        context: { trace_id: "test-stderr" }
    }

    # Act: Execute echo.nu
    let result = do {
        $input | to json | nu (tools_dir | path join "echo.nu")
    } | complete

    # Assert: Error should be logged to stderr
    assert equal $result.exit_code 1 "Should fail"
    assert (($result.stderr | str length) > 0) "Should write to stderr"

    # Verify stderr contains JSON log
    let log_lines = $result.stderr | lines | where { |line| ($line | str length) > 0 }
    assert (($log_lines | length) > 0) "Should have at least one log line"

    # Parse first log line as JSON
    let first_log = $log_lines | first | from json
    assert (($first_log | get level | describe) == "string") "Log should have level field"
    assert (($first_log | get msg | describe) == "string") "Log should have msg field"
    assert equal $first_log.level "error" "Error logs should have level=error"
}

#[test]
def test_error_exits_with_correct_code [] {
    # Arrange: Test various error scenarios
    let test_cases = [
        {
            tool: "echo.nu"
            input: { context: { trace_id: "test1" } }  # Missing message
            expected_exit: 1
        }
        {
            tool: "run-tool.nu"
            input: { context: { trace_id: "test2" } }  # Missing tool_path
            expected_exit: 1
        }
        {
            tool: "validate.nu"
            input: { context: { trace_id: "test3" } }  # Missing contract_path
            expected_exit: 1
        }
        {
            tool: "generate.nu"
            input: { context: { trace_id: "test4" } }  # Missing contract_path
            expected_exit: 1
        }
    ]

    # Act & Assert: Execute each test case
    for case in $test_cases {
        let result = do {
            $case.input | to json | nu (tools_dir | path join $case.tool)
        } | complete

        assert equal $result.exit_code $case.expected_exit $"($case.tool) should exit with code ($case.expected_exit)"
        let output = $result.stdout | from json
        assert equal $output.success false $"($case.tool) should return success=false"
    }
}

#[test]
def test_error_response_is_valid_json [] {
    # Arrange: Create various error scenarios
    let inputs = [
        { tool: "echo.nu", data: { message: "", context: { trace_id: "t1" } } }
        { tool: "run-tool.nu", data: { tool_path: "/no/such/file.nu", context: { trace_id: "t2" } } }
        { tool: "validate.nu", data: { contract_path: "/no/contract.yaml", context: { trace_id: "t3" } } }
    ]

    # Act & Assert: Verify all error outputs are valid JSON
    for input in $inputs {
        let result = do {
            $input.data | to json | nu (tools_dir | path join $input.tool)
        } | complete

        # Should be able to parse stdout as JSON
        let parse_result = try {
            $result.stdout | from json
            true
        } catch {
            false
        }

        assert $parse_result $"($input.tool) error output should be valid JSON"
    }
}

#[test]
def test_multiple_errors_accumulated [] {
    # Arrange: Create a scenario with multiple validation errors
    let input = {
        # Missing both required fields: contract_path and task
        context: { trace_id: "test-multi-error" }
    }

    # Act: Execute generate.nu with missing required fields
    let result = do {
        $input | to json | nu (tools_dir | path join "generate.nu")
    } | complete

    # Assert: Should fail on first missing field (contract_path checked first)
    assert equal $result.exit_code 1 "Should fail validation"
    let output = $result.stdout | from json
    assert equal $output.success false "Should indicate failure"
    assert ($output.error | str contains "contract_path") "Should mention first validation error"
}

#[test]
def test_error_message_is_descriptive [] {
    # Arrange: Create specific error scenarios
    let test_cases = [
        {
            tool: "echo.nu"
            input: { message: "", context: { trace_id: "test-desc-1" } }
            expected_keyword: "required"
        }
        {
            tool: "run-tool.nu"
            input: { tool_path: "/nonexistent.nu", context: { trace_id: "test-desc-2" } }
            expected_keyword: "not found"
        }
        {
            tool: "validate.nu"
            input: { contract_path: "/missing.yaml", context: { trace_id: "test-desc-3" } }
            expected_keyword: "required"
        }
    ]

    # Act & Assert: Verify error messages are descriptive
    for case in $test_cases {
        let result = do {
            $case.input | to json | nu (tools_dir | path join $case.tool)
        } | complete

        let output = $result.stdout | from json
        assert ($output.error | str contains $case.expected_keyword) $"($case.tool) error should contain '($case.expected_keyword)'"
    }
}

#[test]
def test_error_with_empty_trace_id [] {
    # Arrange: Input with empty trace_id
    let input = {
        message: ""  # Will fail
        context: { trace_id: "" }
    }

    # Act: Execute echo.nu
    let result = do {
        $input | to json | nu (tools_dir | path join "echo.nu")
    } | complete

    # Assert: Should handle empty trace_id gracefully
    assert equal $result.exit_code 1 "Should fail"
    let output = $result.stdout | from json
    assert equal $output.success false "Should indicate failure"
    assert (($output | get trace_id | describe) == "string") "trace_id should be string"
    assert equal $output.trace_id "" "Empty trace_id should be preserved"
}

#[test]
def test_error_response_format_consistency [] {
    # Arrange: Test that all tools use the same error response format
    let inputs = [
        { tool: "echo.nu", data: { context: { trace_id: "c1" } } }
        { tool: "run-tool.nu", data: { context: { trace_id: "c2" } } }
        { tool: "validate.nu", data: { context: { trace_id: "c3" } } }
        { tool: "generate.nu", data: { context: { trace_id: "c4" } } }
    ]

    # Act & Assert: Verify consistent field structure
    for input in $inputs {
        let result = do {
            $input.data | to json | nu (tools_dir | path join $input.tool)
        } | complete

        assert equal $result.exit_code 1 $"($input.tool) should exit 1"
        let output = $result.stdout | from json

        # All error responses should have these exact fields
        let fields = $output | columns | sort
        assert ("success" in $fields) $"($input.tool) should have 'success' field"
        assert ("error" in $fields) $"($input.tool) should have 'error' field"
        assert ("trace_id" in $fields) $"($input.tool) should have 'trace_id' field"
        assert ("duration_ms" in $fields) $"($input.tool) should have 'duration_ms' field"
    }
}

#[test]
def test_json_parse_error_has_empty_trace_id [] {
    # Arrange: Malformed JSON (before we can extract trace_id)
    let malformed = "not json at all"

    # Act: Execute any tool with malformed JSON
    let result = do {
        echo $malformed | nu (tools_dir | path join "echo.nu")
    } | complete

    # Assert: Should have empty trace_id (couldn't parse input)
    assert equal $result.exit_code 1 "Should fail"
    let output = $result.stdout | from json
    assert equal $output.success false "Should indicate failure"
    assert equal $output.trace_id "" "trace_id should be empty when JSON parsing fails"
    assert ($output.error | str contains "Invalid JSON") "Should indicate JSON parse error"
}

#[test]
def test_error_duration_is_monotonic [] {
    # Arrange: Create error scenario
    let input = {
        contract_path: "/nonexistent.yaml"
        context: { trace_id: "test-monotonic" }
    }

    # Act: Execute validate.nu
    let result = do {
        $input | to json | nu (tools_dir | path join "validate.nu")
    } | complete

    # Assert: duration_ms should be positive and reasonable
    let output = $result.stdout | from json
    assert (($output.duration_ms > 0)) "duration_ms should be positive"
    assert (($output.duration_ms < 1000)) "Quick failure should be under 1 second"
}

#[test]
def test_stderr_contains_trace_id [] {
    # Arrange: Create failing request with trace_id
    let trace_id = "test-stderr-trace-123"
    let input = {
        message: ""
        context: { trace_id: $trace_id }
    }

    # Act: Execute echo.nu
    let result = do {
        $input | to json | nu (tools_dir | path join "echo.nu")
    } | complete

    # Assert: stderr logs should contain trace_id
    assert ($result.stderr | str contains $trace_id) "stderr should contain trace_id"

    # Parse stderr as JSON log
    let log_lines = $result.stderr | lines | where { |line| ($line | str length) > 0 }
    let first_log = $log_lines | first | from json
    assert equal $first_log.trace_id $trace_id "Log should include trace_id field"
}
