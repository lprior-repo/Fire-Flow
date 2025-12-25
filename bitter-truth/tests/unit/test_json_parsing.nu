#!/usr/bin/env nu
# Unit tests for JSON parsing across all tools
# Tests the consistency and robustness of JSON input handling
#
# Run with: nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/unit'

use std assert

# Helper to get tools directory
def tools_dir [] {
    $env.PWD | path join "bitter-truth/tools"
}

#[test]
def test_parse_valid_json_succeeds [] {
    # Arrange: Create valid JSON input for echo.nu
    let input = {
        message: "test message"
        context: { trace_id: "test-valid-json" }
    }

    # Act: Execute echo.nu with valid JSON
    let result = do {
        $input | to json | nu (tools_dir | path join "echo.nu")
    } | complete

    # Assert: Should succeed with exit 0
    assert equal $result.exit_code 0 "Valid JSON should be parsed successfully"
    let output = $result.stdout | from json
    assert equal $output.success true "Response should have success=true"
    assert equal $output.trace_id "test-valid-json" "Trace ID should be preserved"
}

#[test]
def test_parse_empty_stdin_fails_gracefully [] {
    # Arrange: Empty stdin input
    let empty_input = ""

    # Act: Execute run-tool.nu with empty stdin
    let result = do {
        echo $empty_input | nu (tools_dir | path join "run-tool.nu")
    } | complete

    # Assert: Should fail with exit 1 and proper error response
    assert equal $result.exit_code 1 "Empty stdin should exit with code 1"
    let output = $result.stdout | from json
    assert equal $output.success false "Response should have success=false"
    assert ($output.error | str contains "Invalid JSON") "Error should mention invalid JSON"
    assert (($output | get duration_ms | describe) == "int") "Should include duration_ms"
}

#[test]
def test_parse_malformed_json_returns_error_response [] {
    # Arrange: Malformed JSON (incomplete object)
    let malformed_input = '{"message": "test", "context":'

    # Act: Execute validate.nu with malformed JSON
    let result = do {
        echo $malformed_input | nu (tools_dir | path join "validate.nu")
    } | complete

    # Assert: Should fail gracefully with proper error response
    assert equal $result.exit_code 1 "Malformed JSON should exit with code 1"
    let output = $result.stdout | from json
    assert equal $output.success false "Response should have success=false"
    assert ($output.error | str contains "Invalid JSON") "Error should indicate invalid JSON"

    # Verify error was logged to stderr
    assert ($result.stderr | str contains "invalid JSON input") "Should log error to stderr"
}

#[test]
def test_parse_incomplete_json_fails [] {
    # Arrange: JSON with missing closing braces
    let incomplete_json = '{"message": "test"'

    # Act: Execute echo.nu with incomplete JSON
    let result = do {
        echo $incomplete_json | nu (tools_dir | path join "echo.nu")
    } | complete

    # Assert: Should fail with exit 1
    assert equal $result.exit_code 1 "Incomplete JSON should fail"
    let output = $result.stdout | from json
    assert equal $output.success false "Response should have success=false"
    assert equal $output.trace_id "" "Trace ID should be empty on parse error"
}

#[test]
def test_parse_json_with_unicode_succeeds [] {
    # Arrange: JSON with Unicode characters
    let input = {
        message: "Hello 世界 🚀 Привет"
        context: { trace_id: "test-unicode" }
    }

    # Act: Execute echo.nu with Unicode JSON
    let result = do {
        $input | to json | nu (tools_dir | path join "echo.nu")
    } | complete

    # Assert: Should handle Unicode correctly
    assert equal $result.exit_code 0 "Unicode JSON should parse successfully"
    let output = $result.stdout | from json
    assert equal $output.success true "Response should succeed"
    assert equal $output.data.echo "Hello 世界 🚀 Привет" "Unicode should be preserved"
}

#[test]
def test_parse_nested_json_succeeds [] {
    # Arrange: Deeply nested JSON structure
    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/test-nested-tool-($test_id).nu"

    # Create a simple echo tool
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    { received: $input.tool_input } | to json | print
}' | save -f $tool_path

    let input = {
        tool_path: $tool_path
        tool_input: {
            level1: {
                level2: {
                    level3: {
                        level4: {
                            message: "deeply nested"
                        }
                    }
                }
            }
        }
        output_path: $"/tmp/test-nested-output-($test_id).json"
        logs_path: $"/tmp/test-nested-logs-($test_id).json"
        context: { trace_id: "test-nested" }
    }

    # Act: Execute run-tool.nu with nested JSON
    let result = do {
        $input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    # Assert: Should handle nested structures
    assert equal $result.exit_code 0 "Nested JSON should parse successfully"
    let output = $result.stdout | from json
    assert equal $output.success true "Response should succeed"

    # Verify the tool received the nested structure
    let tool_output = open $input.output_path
    assert equal $tool_output.received.level1.level2.level3.level4.message "deeply nested" "Nested structure should be preserved"

    # Cleanup
    rm -f $tool_path $input.output_path $input.logs_path
}

#[test]
def test_parse_large_json_succeeds [] {
    # Arrange: Large JSON payload (10MB simulated with repeated data)
    let test_id = (random uuid | str substring 0..8)

    # Create a large string (100k characters)
    let large_data = (1..10000 | each { |i| $"item($i)" } | str join ",")

    let input = {
        message: $large_data
        context: { trace_id: "test-large-json" }
    }

    # Act: Execute echo.nu with large JSON
    let result = do {
        $input | to json | nu (tools_dir | path join "echo.nu")
    } | complete

    # Assert: Should handle large JSON without crashing
    assert equal $result.exit_code 0 "Large JSON should parse successfully"
    let output = $result.stdout | from json
    assert equal $output.success true "Response should succeed"
    assert equal ($output.data.echo | str length) ($large_data | str length) "Large data should be preserved"
}

#[test]
def test_parse_circular_reference_fails [] {
    # Arrange: Test that we can't create circular references in JSON
    # Note: Nushell's to json command should prevent this
    let test_id = (random uuid | str substring 0..8)

    # We can't actually create a circular reference in Nushell,
    # but we can test that malformed circular-like JSON fails
    let circular_json = '{"a": {"b": {"c": "{{REF:a}}"}}}'

    # Act: Execute run-tool.nu with pseudo-circular JSON
    let result = do {
        echo $circular_json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    # Assert: This is valid JSON (Nushell prevents true circular refs)
    # The "{{REF:a}}" is just a string value
    assert equal $result.exit_code 1 "Should fail due to missing tool_path"
    let output = $result.stdout | from json
    assert equal $output.success false "Response should indicate failure"
}

#[test]
def test_parse_special_characters_in_json [] {
    # Arrange: JSON with special characters that need escaping
    let input = {
        message: "Line1\nLine2\tTabbed\"Quoted\"\\Backslash"
        context: { trace_id: "test-special-chars" }
    }

    # Act: Execute echo.nu with special characters
    let result = do {
        $input | to json | nu (tools_dir | path join "echo.nu")
    } | complete

    # Assert: Special characters should be handled correctly
    assert equal $result.exit_code 0 "Special characters should parse correctly"
    let output = $result.stdout | from json
    assert equal $output.success true "Response should succeed"
    assert ($output.data.echo | str contains "\n") "Newlines should be preserved"
    assert ($output.data.echo | str contains "\t") "Tabs should be preserved"
}

#[test]
def test_parse_json_with_null_values [] {
    # Arrange: JSON with explicit null values
    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/test-null-tool-($test_id).nu"

    # Create tool that accepts null
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    { has_optional: ($input.tool_input.optional? != null) } | to json | print
}' | save -f $tool_path

    let input = {
        tool_path: $tool_path
        tool_input: {
            required: "value"
            optional: null
        }
        output_path: $"/tmp/test-null-output-($test_id).json"
        logs_path: $"/tmp/test-null-logs-($test_id).json"
        context: { trace_id: "test-null" }
    }

    # Act: Execute with null values
    let result = do {
        $input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    # Assert: Null values should be handled
    assert equal $result.exit_code 0 "Null values should be accepted"
    let output = $result.stdout | from json
    assert equal $output.success true "Response should succeed"

    # Cleanup
    rm -f $tool_path $input.output_path $input.logs_path
}

#[test]
def test_parse_json_with_arrays [] {
    # Arrange: JSON with array values
    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/test-array-tool-($test_id).nu"

    # Create tool that processes arrays
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    { count: ($input.tool_input.items | length) } | to json | print
}' | save -f $tool_path

    let input = {
        tool_path: $tool_path
        tool_input: {
            items: ["one", "two", "three"]
        }
        output_path: $"/tmp/test-array-output-($test_id).json"
        logs_path: $"/tmp/test-array-logs-($test_id).json"
        context: { trace_id: "test-arrays" }
    }

    # Act: Execute with array values
    let result = do {
        $input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    # Assert: Arrays should be preserved
    assert equal $result.exit_code 0 "Arrays should parse successfully"
    let output = $result.stdout | from json
    assert equal $output.success true "Response should succeed"

    let tool_output = open $input.output_path
    assert equal $tool_output.count 3 "Array length should be preserved"

    # Cleanup
    rm -f $tool_path $input.output_path $input.logs_path
}

#[test]
def test_parse_json_only_whitespace_fails [] {
    # Arrange: Input with only whitespace
    let whitespace_input = "   \n\t  "

    # Act: Execute validate.nu with whitespace
    let result = do {
        echo $whitespace_input | nu (tools_dir | path join "validate.nu")
    } | complete

    # Assert: Should fail with JSON parse error
    assert equal $result.exit_code 1 "Whitespace-only input should fail"
    let output = $result.stdout | from json
    assert equal $output.success false "Response should have success=false"
    assert ($output.error | str contains "Invalid JSON") "Should indicate invalid JSON"
}
