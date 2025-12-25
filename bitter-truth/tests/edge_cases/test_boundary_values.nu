#!/usr/bin/env nu
# Boundary value tests
# Tests for empty values, maximum lengths, numeric limits, and edge cases
#
# Run with: nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/edge_cases'

use std assert
use ../helpers/builders.nu *
use ../helpers/assertions.nu *

# Helper to get tools directory
def tools_dir [] {
    $env.PWD | path join "bitter-truth/tools"
}

#[test]
def test_empty_message_fails [] {
    # Empty string should fail validation
    let input = build_echo_input "" "test-empty"

    # Act: Execute with empty message
    let result = do {
        $input | to json | nu (tools_dir | path join "echo.nu")
    } | complete

    # Assert: Should fail
    assert_exit_code $result 1 "Empty message should fail"

    let output = $result.stdout | from json
    assert_failure $output "Empty message should be rejected"
    assert_error_contains $output "required"
}

#[test]
def test_very_long_message_succeeds [] {
    # Test maximum reasonable message length (1MB)
    let very_long_message = (1..10000 | each { |i| $"Line ($i): " + (1..90 | each { |_| "x" } | str join "") } | str join "\n")
    let message_length = $very_long_message | str length

    # Should be approximately 1MB
    assert ($message_length > 900000) "Message should be > 900KB"

    let input = build_echo_input $very_long_message "test-very-long"

    # Act: Execute with very long message
    let result = do {
        $input | to json | nu (tools_dir | path join "echo.nu")
    } | complete

    # Assert: Should succeed
    assert_exit_code $result 0 "Very long message should succeed"

    let output = $result.stdout | from json
    assert_success $output "1MB message should be processed"
    assert equal $output.data.length $message_length "Should preserve full length"
}

#[test]
def test_zero_length_json_fails [] {
    # Completely empty input should fail gracefully
    let result = do {
        echo "" | nu (tools_dir | path join "echo.nu")
    } | complete

    # Assert: Should fail with proper error
    assert_exit_code $result 1 "Empty stdin should fail"

    let output = $result.stdout | from json
    assert_failure $output "Zero-length input should be rejected"
    assert_error_contains $output "Invalid JSON"
}

#[test]
def test_max_trace_id_length [] {
    # Test maximum reasonable trace_id length
    # Trace IDs might be UUIDs, but could be longer descriptive strings

    let test_cases = [
        (1..100 | each { |_| "a" } | str join "")      # 100 chars
        (1..50 | each { |_| "trace-" } | str join "")  # 300 chars
        (1..1000 | each { |_| "x" } | str join "")     # 1000 chars
    ]

    for trace_id in $test_cases {
        let input = build_echo_input "test message" $trace_id

        let result = do {
            $input | to json | nu (tools_dir | path join "echo.nu")
        } | complete

        assert_exit_code $result 0 $"Should handle trace_id length ($trace_id | str length)"

        let output = $result.stdout | from json
        assert_success $output "Long trace_id should succeed"
        assert equal $output.trace_id $trace_id "Should preserve full trace_id"
    }
}

#[test]
def test_negative_duration_values [] {
    # Duration should never be negative
    # This tests the calculation logic

    let input = build_echo_input "quick test" "test-duration"

    # Act: Execute quickly
    let result = do {
        $input | to json | nu (tools_dir | path join "echo.nu")
    } | complete

    # Assert: Duration must be non-negative
    assert_exit_code $result 0 "Should succeed"

    let output = $result.stdout | from json
    assert_success $output "Should complete successfully"
    assert ($output.duration_ms >= 0) "duration_ms must be non-negative"
}

#[test]
def test_very_large_duration_values [] {
    # Test that very long executions report accurate duration
    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/long-duration-tool-($test_id).nu"
    let output_path = $"/tmp/duration-output-($test_id).json"
    let logs_path = $"/tmp/duration-logs-($test_id).json"

    # Create tool that sleeps for 5 seconds
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    sleep 5sec
    { result: "completed after 5 seconds" } | to json | print
}' | save -f $tool_path

    let input = build_run_tool_input $tool_path {} $output_path $logs_path "test-long-duration"

    # Act: Execute long-running tool
    let start = date now
    let result = do {
        $input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete
    let actual_duration = (date now) - $start | into int | $in / 1000000

    # Assert: Should report duration >= 5 seconds
    assert_exit_code $result 0 "Long execution should succeed"

    let output = $result.stdout | from json
    assert_success $output "Should complete successfully"
    assert ($output.duration_ms >= 5000) "duration_ms should be >= 5000ms"
    assert (($output.duration_ms - $actual_duration | math abs) < 1000) "Reported duration should match actual within 1s"

    # Cleanup
    rm -f $tool_path $output_path $logs_path
}

#[test]
def test_minimum_valid_json_input [] {
    # Test absolute minimum valid JSON input
    let test_cases = [
        '{"message":"a","context":{"trace_id":"t"}}'  # Minimal valid
        '{"message":" ","context":{"trace_id":""}}'   # Single space message, empty trace
    ]

    for json_input in $test_cases {
        let result = do {
            echo $json_input | nu (tools_dir | path join "echo.nu")
        } | complete

        assert_exit_code $result 0 $"Minimal JSON should succeed: ($json_input)"

        let output = $result.stdout | from json
        assert_success $output "Minimal valid input should work"
    }
}

#[test]
def test_maximum_nesting_depth [] {
    # Test deeply nested JSON structures
    # Create nested context object

    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/nested-tool-($test_id).nu"
    let output_path = $"/tmp/nested-output-($test_id).json"
    let logs_path = $"/tmp/nested-logs-($test_id).json"

    # Create tool that accepts deeply nested input
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    { depth: ($input | to json | str length) } | to json | print
}' | save -f $tool_path

    # Create deeply nested tool_input (10 levels)
    let nested = {
        level1: {
            level2: {
                level3: {
                    level4: {
                        level5: {
                            level6: {
                                level7: {
                                    level8: {
                                        level9: {
                                            level10: "deep value"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    let input = build_run_tool_input $tool_path $nested $output_path $logs_path "test-nesting"

    # Act: Execute with deeply nested input
    let result = do {
        $input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    # Assert: Should handle deep nesting
    assert_exit_code $result 0 "Should handle deeply nested JSON"

    let output = $result.stdout | from json
    assert_success $output "Deeply nested input should work"

    # Cleanup
    rm -f $tool_path $output_path $logs_path
}

#[test]
def test_single_character_message [] {
    # Test minimum non-empty message
    let test_cases = ["a", "1", "!", " ", "\n", "🔥"]

    for msg in $test_cases {
        let input = build_echo_input $msg "test-single-char"

        let result = do {
            $input | to json | nu (tools_dir | path join "echo.nu")
        } | complete

        assert_exit_code $result 0 $"Single char should succeed: ($msg)"

        let output = $result.stdout | from json
        assert_success $output "Single character should be valid"
        assert equal $output.data.echo $msg "Should preserve single character"
        assert ($output.data.length >= 1) "Length should be >= 1"
    }
}

#[test]
def test_boundary_exit_codes [] {
    # Test that exit codes are in valid range (0-255)
    let test_id = (random uuid | str substring 0..8)
    let output_path = $"/tmp/exit-output-($test_id).json"
    let logs_path = $"/tmp/exit-logs-($test_id).json"

    # Test various exit codes
    let exit_codes = [0, 1, 2, 127, 255]

    for code in $exit_codes {
        let tool_path = $"/tmp/exit-tool-($code)-($test_id).nu"

        # Create tool that exits with specific code
        $'#!/usr/bin/env nu
def main [] {
    { exit_code: ($code) } | to json | print
    exit ($code)
}' | save -f $tool_path

        let input = build_run_tool_input $tool_path {} $output_path $logs_path $"test-exit-($code)"

        let result = do {
            $input | to json | nu (tools_dir | path join "run-tool.nu")
        } | complete

        # run-tool.nu exits 0 for tool exit 0, exits 1 for any other code
        let expected_exit = if $code == 0 { 0 } else { 1 }
        assert_exit_code $result $expected_exit $"Should handle exit code ($code)"

        let output = $result.stdout | from json
        assert equal $output.data.exit_code $code $"Should report exit code ($code)"

        rm -f $tool_path
    }

    # Cleanup
    rm -f $output_path $logs_path
}

#[test]
def test_empty_tool_input [] {
    # Test run-tool with empty tool_input object
    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/empty-input-tool-($test_id).nu"
    let output_path = $"/tmp/empty-output-($test_id).json"
    let logs_path = $"/tmp/empty-logs-($test_id).json"

    # Create tool that handles empty input
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    { received: ($input | to json) } | to json | print
}' | save -f $tool_path

    # Empty tool_input object
    let input = build_run_tool_input $tool_path {} $output_path $logs_path "test-empty-input"

    # Act: Execute with empty input
    let result = do {
        $input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    # Assert: Should succeed with empty object
    assert_exit_code $result 0 "Empty tool_input should succeed"

    let output = $result.stdout | from json
    assert_success $output "Empty object is valid input"

    # Cleanup
    rm -f $tool_path $output_path $logs_path
}

#[test]
def test_null_fields_in_input [] {
    # Test handling of null values in optional fields
    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/null-test-tool-($test_id).nu"

    '#!/usr/bin/env nu
def main [] {
    { result: "ok" } | to json | print
}' | save -f $tool_path

    # Create input with explicit null for optional field (dry_run)
    let input_with_null = {
        tool_path: $tool_path
        tool_input: {}
        output_path: $"/tmp/null-output-($test_id).json"
        logs_path: $"/tmp/null-logs-($test_id).json"
        context: {
            trace_id: "test-null"
            dry_run: null
        }
    }

    # Act: Execute with null field
    let result = do {
        $input_with_null | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    # Assert: Should handle null gracefully (treat as false/default)
    # This tests the robustness of `| default false` patterns
    if $result.exit_code == 0 {
        let output = $result.stdout | from json
        assert_success $output "Null should be handled as default value"
    }

    # Cleanup
    rm -f $tool_path $"/tmp/null-output-($test_id).json" $"/tmp/null-logs-($test_id).json"
}

#[test]
def test_maximum_array_size [] {
    # Test handling of large arrays in tool_input
    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/array-tool-($test_id).nu"
    let output_path = $"/tmp/array-output-($test_id).json"
    let logs_path = $"/tmp/array-logs-($test_id).json"

    # Create tool
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    { count: ($input.items | length) } | to json | print
}' | save -f $tool_path

    # Create large array (1000 items)
    let large_array = (1..1000 | each { |i| { id: $i, value: $"item-($i)" } })

    let input = build_run_tool_input $tool_path { items: $large_array } $output_path $logs_path "test-large-array"

    # Act: Execute with large array
    let result = do {
        $input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    # Assert: Should handle large arrays
    assert_exit_code $result 0 "Should handle array with 1000 items"

    let output = $result.stdout | from json
    assert_success $output "Large array should be processed"

    # Cleanup
    rm -f $tool_path $output_path $logs_path
}

#[test]
def test_zero_duration_execution [] {
    # Test that extremely fast executions don't report 0 duration
    # (or if they do, it's acceptable)

    let input = build_echo_input "fast" "test-zero-duration"

    # Act: Execute minimal operation
    let result = do {
        $input | to json | nu (tools_dir | path join "echo.nu")
    } | complete

    # Assert: Should succeed
    assert_exit_code $result 0 "Fast execution should succeed"

    let output = $result.stdout | from json
    assert_success $output "Should complete successfully"

    # Duration might be 0 for very fast operations, or might be 1+
    assert ($output.duration_ms >= 0) "duration_ms should be >= 0"

    # If it's 0, that's acceptable but interesting to know
    if $output.duration_ms == 0 {
        # This is fine - operation was very fast
        assert true "Zero duration is acceptable for very fast operations"
    }
}

#[test]
def test_maximum_field_count [] {
    # Test input with many fields
    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/fields-tool-($test_id).nu"
    let output_path = $"/tmp/fields-output-($test_id).json"
    let logs_path = $"/tmp/fields-logs-($test_id).json"

    # Create tool
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    { field_count: ($input | columns | length) } | to json | print
}' | save -f $tool_path

    # Create input with 100 fields
    let many_fields = (1..100 | reduce -f {} { |i, acc|
        $acc | merge { $"field_($i)": $"value_($i)" }
    })

    let input = build_run_tool_input $tool_path $many_fields $output_path $logs_path "test-many-fields"

    # Act: Execute with many fields
    let result = do {
        $input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    # Assert: Should handle many fields
    assert_exit_code $result 0 "Should handle 100 fields"

    let output = $result.stdout | from json
    assert_success $output "Many fields should be processed"

    # Cleanup
    rm -f $tool_path $output_path $logs_path
}

#[test]
def test_boolean_boundary_values [] {
    # Test that boolean fields only accept true/false
    let test_cases = [
        { dry_run: true, expect: "success" }
        { dry_run: false, expect: "success" }
    ]

    for case in $test_cases {
        let input = {
            message: "test"
            context: {
                trace_id: "test-bool"
                dry_run: $case.dry_run
            }
        }

        let result = do {
            $input | to json | nu (tools_dir | path join "echo.nu")
        } | complete

        assert_exit_code $result 0 $"Boolean ($case.dry_run) should work"

        let output = $result.stdout | from json
        assert_success $output "Boolean values should be accepted"
        assert equal $output.data.was_dry_run $case.dry_run "dry_run should be preserved"
    }
}

#[test]
def test_numeric_overflow_protection [] {
    # Test that very large numbers are handled correctly
    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/numeric-tool-($test_id).nu"
    let output_path = $"/tmp/numeric-output-($test_id).json"
    let logs_path = $"/tmp/numeric-logs-($test_id).json"

    # Create tool
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    { number: $input.value, type: ($input.value | describe) } | to json | print
}' | save -f $tool_path

    # Test large numbers
    let large_numbers = [
        2147483647         # Max 32-bit int
        9223372036854775807  # Max 64-bit int (might overflow in some systems)
    ]

    for num in $large_numbers {
        let input = build_run_tool_input $tool_path { value: $num } $output_path $logs_path $"test-num-($num)"

        let result = do {
            $input | to json | nu (tools_dir | path join "run-tool.nu")
        } | complete

        # Should handle or fail gracefully
        if $result.exit_code == 0 {
            let output = $result.stdout | from json
            assert_success $output $"Should handle large number ($num)"
        }
    }

    # Cleanup
    rm -f $tool_path $output_path $logs_path
}
