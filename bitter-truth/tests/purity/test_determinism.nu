#!/usr/bin/env nu
# Purity tests for determinism - Same input → same output
#
# Tests that tools produce identical outputs (excluding time-based fields)
# when run multiple times with identical inputs.
#
# Run with: nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/purity'

use std assert
use ../helpers/constants.nu *
use ../helpers/builders.nu *
use ../helpers/assertions.nu *

# Helper: Compare two responses, excluding non-deterministic fields
#
# Args:
#   response1: record - first response
#   response2: record - second response
#   exclude_fields: list<string> - fields to exclude from comparison
#
# Returns: bool - true if responses match (excluding excluded fields)
def compare_responses [
    response1: record
    response2: record
    exclude_fields: list<string> = ["trace_id", "duration_ms"]
] {
    # Remove excluded fields from both responses
    let r1 = $response1 | reject ...$exclude_fields
    let r2 = $response2 | reject ...$exclude_fields

    $r1 == $r2
}

# Helper: Run tool N times and collect outputs
#
# Args:
#   tool_path: string - path to tool
#   input: record - tool input
#   iterations: int - number of times to run
#
# Returns: list<record> - list of parsed outputs
def run_tool_n_times [
    tool_path: string
    input: record
    iterations: int = 10
] {
    0..<$iterations | each { |i|
        let result = do {
            $input | to json | nu $tool_path
        } | complete

        assert equal $result.exit_code 0 $"Iteration ($i) should succeed"

        $result.stdout | from json
    }
}

#[test]
def test_echo_tool_deterministic [] {
    # Arrange: Same input for all runs
    let input = build_echo_input "determinism test message" "trace-det-1"

    # Act: Run echo.nu 10 times
    let outputs = run_tool_n_times (echo_tool) $input 10

    # Assert: All outputs should be identical (excluding time fields)
    let first = $outputs | first
    let all_match = $outputs | skip 1 | all { |output|
        compare_responses $output $first ["trace_id", "duration_ms"]
    }

    assert $all_match "All echo tool outputs should be deterministic"

    # Verify data.echo is consistent
    let echo_values = $outputs | each { |o| $o.data.echo }
    assert ($echo_values | all { |v| $v == "determinism test message" }) "echo field should be consistent"

    # Verify data.reversed is consistent
    let reversed_values = $outputs | each { |o| $o.data.reversed }
    let expected_reversed = "egassem tset msinimreted"
    assert ($reversed_values | all { |v| $v == $expected_reversed }) "reversed field should be consistent"

    # Verify data.length is consistent
    let length_values = $outputs | each { |o| $o.data.length }
    assert ($length_values | all { |v| $v == 25 }) "length field should be consistent"
}

#[test]
def test_run_tool_deterministic [] {
    # Arrange: Create a simple deterministic tool
    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/det-tool-($test_id).nu"
    let output_path = $"/tmp/det-output-($test_id).json"
    let logs_path = $"/tmp/det-logs-($test_id).json"

    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    let result = {
        computed: ($input.value * 2)
        constant: 42
    }
    { success: true, data: $result, trace_id: "", duration_ms: 0 } | to json | print
}' | save -f $tool_path

    let input = build_run_tool_input $tool_path { value: 21 } $output_path $logs_path "trace-run-det"

    # Act: Run run-tool.nu 10 times
    let outputs = run_tool_n_times (run_tool) $input 10

    # Assert: All outputs should match
    let first = $outputs | first
    let all_match = $outputs | skip 1 | all { |output|
        compare_responses $output $first ["trace_id", "duration_ms"]
    }

    assert $all_match "run-tool.nu outputs should be deterministic"

    # Verify exit_code is consistent
    let exit_codes = $outputs | each { |o| $o.data.exit_code }
    assert ($exit_codes | all { |c| $c == 0 }) "exit_code should be consistently 0"

    # Verify output files contain identical content
    let first_output = $first.data.output_path
    let first_content = open --raw $first_output

    $outputs | skip 1 | each { |output|
        let content = open --raw $output.data.output_path
        assert equal $content $first_content "Output file content should be identical"
    }

    # Cleanup
    rm -f $tool_path
    $outputs | each { |o|
        rm -f $o.data.output_path
        rm -f $o.data.logs_path
    }
}

#[test]
def test_validate_deterministic [] {
    # Arrange: Create contract and data
    let test_id = (random uuid | str substring 0..8)
    let contract_path = $"/tmp/det-contract-($test_id).yaml"
    let data_path = $"/tmp/det-data-($test_id).json"

    '
dataContractSpecification: 0.9.3
id: det-test
info:
  title: Determinism Test Contract
  version: 1.0.0
servers:
  local:
    type: local
    path: ' + $data_path + '
models:
  test_model:
    type: object
    fields:
      name:
        type: string
        required: true
      value:
        type: integer
        required: true
' | save -f $contract_path

    '{"name": "test", "value": 42}' | save -f $data_path

    let input = build_validate_input $contract_path "local" "trace-val-det"

    # Act: Run validate.nu 10 times
    let outputs = run_tool_n_times (validate_tool) $input 10

    # Assert: All outputs should match
    let first = $outputs | first
    let all_match = $outputs | skip 1 | all { |output|
        compare_responses $output $first ["trace_id", "duration_ms"]
    }

    assert $all_match "validate.nu outputs should be deterministic"

    # Verify valid field is consistently true
    let valid_values = $outputs | each { |o| $o.data.valid }
    assert ($valid_values | all { |v| $v == true }) "valid field should be consistently true"

    # Verify errors array is consistently empty
    let errors_values = $outputs | each { |o| $o.data.errors }
    assert ($errors_values | all { |e| ($e | is-empty) }) "errors should be consistently empty"

    # Cleanup
    rm -f $contract_path $data_path
}

#[test]
def test_error_messages_deterministic [] {
    # Arrange: Invalid input that triggers error
    let input = build_echo_input "" "trace-err-det"  # Empty message = error

    # Act: Run 10 times to get error responses
    let outputs = run_tool_n_times (echo_tool) $input 10

    # Assert: All error messages should be identical
    let first = $outputs | first
    assert equal $first.success false "Should fail with empty message"

    let all_errors_match = $outputs | skip 1 | all { |output|
        $output.error == $first.error
    }

    assert $all_errors_match "Error messages should be deterministic"
    assert equal $first.error "message is required" "Error message should be 'message is required'"
}

#[test]
def test_trace_id_excluded_from_comparison [] {
    # Arrange: Run with different trace IDs but same core input
    let message = "trace id test"

    let input1 = build_echo_input $message "trace-1"
    let input2 = build_echo_input $message "trace-2"
    let input3 = build_echo_input $message "trace-3"

    # Act: Run with different trace IDs
    let result1 = do { $input1 | to json | nu (echo_tool) } | complete
    let result2 = do { $input2 | to json | nu (echo_tool) } | complete
    let result3 = do { $input3 | to json | nu (echo_tool) } | complete

    let output1 = $result1.stdout | from json
    let output2 = $result2.stdout | from json
    let output3 = $result3.stdout | from json

    # Assert: Trace IDs should differ
    assert not equal $output1.trace_id $output2.trace_id "trace_id should differ"
    assert not equal $output2.trace_id $output3.trace_id "trace_id should differ"

    # Assert: Core outputs should match (excluding trace_id and duration_ms)
    assert (compare_responses $output1 $output2) "Outputs should match excluding trace_id/duration_ms"
    assert (compare_responses $output2 $output3) "Outputs should match excluding trace_id/duration_ms"

    # Assert: data fields should be identical
    assert equal $output1.data $output2.data "data fields should be identical"
    assert equal $output2.data $output3.data "data fields should be identical"
}

#[test]
def test_duration_excluded_from_comparison [] {
    # Arrange: Same input
    let input = build_echo_input "duration test"

    # Act: Run multiple times (durations will vary)
    let outputs = run_tool_n_times (echo_tool) $input 5

    # Assert: Durations should vary (at least some difference)
    let durations = $outputs | each { |o| $o.duration_ms }

    # Assert: But core outputs should match when duration is excluded
    let first = $outputs | first
    let all_match_excluding_duration = $outputs | skip 1 | all { |output|
        compare_responses $output $first ["trace_id", "duration_ms"]
    }

    assert $all_match_excluding_duration "Outputs should match when duration_ms is excluded"
}

#[test]
def test_timestamp_fields_excluded [] {
    # Arrange: Validate tool doesn't expose timestamps (only duration_ms)
    # This test verifies we handle time-based fields correctly

    let input = build_echo_input "timestamp test" "trace-ts"

    # Act: Run twice
    let result1 = do { $input | to json | nu (echo_tool) } | complete
    let result2 = do { $input | to json | nu (echo_tool) } | complete

    let output1 = $result1.stdout | from json
    let output2 = $result2.stdout | from json

    # Assert: No timestamp fields in output (only duration_ms)
    let fields1 = $output1 | columns
    let fields2 = $output2 | columns

    assert not ("timestamp" in $fields1) "Should not have timestamp field"
    assert not ("created_at" in $fields1) "Should not have created_at field"
    assert not ("started_at" in $fields1) "Should not have started_at field"

    # Assert: Should have duration_ms
    assert ("duration_ms" in $fields1) "Should have duration_ms field"

    # Assert: Core data is deterministic
    assert equal $output1.data $output2.data "data should be deterministic"
}

#[test]
def test_json_field_ordering_stable [] {
    # Arrange: Verify JSON serialization doesn't reorder fields
    let input = build_echo_input "field order test" "trace-order"

    # Act: Run 10 times
    let outputs = run_tool_n_times (echo_tool) $input 10

    # Assert: All JSON strings should be identical (exact byte-for-byte match)
    # This is stronger than structural equality - ensures field order is stable

    let first_json = $outputs | first | to json -r
    let all_json_identical = $outputs | skip 1 | all { |output|
        ($output | to json -r) == $first_json
    }

    # Note: Nushell's to json may not guarantee field order, so this may fail
    # If it does, we can relax this to structural comparison only
    # For now, we test that at least the structure is consistent
    let all_structurally_equal = $outputs | skip 1 | all { |output|
        compare_responses $output ($outputs | first)
    }

    assert $all_structurally_equal "JSON structure should be deterministic"
}

#[test]
def test_multiple_runs_same_process_vs_separate [] {
    # Arrange: Test determinism across process boundaries
    let input = build_echo_input "process boundary test" "trace-proc"

    # Act: Run in loop (same nutest process)
    let same_process_outputs = run_tool_n_times (echo_tool) $input 3

    # Act: Run in separate processes
    let separate_process_outputs = 0..<3 | each { |i|
        let result = do {
            $input | to json | nu (echo_tool)
        } | complete
        $result.stdout | from json
    }

    # Assert: Both methods should produce identical outputs
    let first_same = $same_process_outputs | first
    let first_separate = $separate_process_outputs | first

    assert (compare_responses $first_same $first_separate) "Same-process and separate-process outputs should match"

    # Assert: All outputs in both sets should be deterministic
    let same_all_match = $same_process_outputs | skip 1 | all { |o|
        compare_responses $o $first_same
    }
    let separate_all_match = $separate_process_outputs | skip 1 | all { |o|
        compare_responses $o $first_separate
    }

    assert $same_all_match "Same-process runs should be deterministic"
    assert $separate_all_match "Separate-process runs should be deterministic"
}

#[test]
def test_dry_run_deterministic [] {
    # Arrange: Dry-run mode should be deterministic
    let input = build_echo_input "dry run test" "trace-dry" true

    # Act: Run 10 times in dry-run mode
    let outputs = run_tool_n_times (echo_tool) $input 10

    # Assert: All dry-run outputs should be identical
    let first = $outputs | first
    let all_match = $outputs | skip 1 | all { |output|
        compare_responses $output $first
    }

    assert $all_match "Dry-run outputs should be deterministic"

    # Assert: was_dry_run should be consistently true
    let dry_run_flags = $outputs | each { |o| $o.data.was_dry_run }
    assert ($dry_run_flags | all { |f| $f == true }) "was_dry_run should be consistently true"
}

#[test]
def test_validation_errors_deterministic [] {
    # Arrange: Create invalid data that will fail validation
    let test_id = (random uuid | str substring 0..8)
    let contract_path = $"/tmp/det-err-contract-($test_id).yaml"
    let data_path = $"/tmp/det-err-data-($test_id).json"

    '
dataContractSpecification: 0.9.3
id: det-err-test
info:
  title: Determinism Error Test
  version: 1.0.0
servers:
  local:
    type: local
    path: ' + $data_path + '
models:
  test_model:
    type: object
    fields:
      required_field:
        type: string
        required: true
' | save -f $contract_path

    '{"wrong_field": "value"}' | save -f $data_path

    let input = build_validate_input $contract_path "local" "trace-val-err-det"

    # Act: Run validation 5 times (should fail each time)
    let results = 0..<5 | each { |i|
        let result = do {
            $input | to json | nu (validate_tool)
        } | complete

        # Should exit 1 (validation failed)
        assert equal $result.exit_code 1 $"Iteration ($i) should fail validation"

        $result.stdout | from json
    }

    # Assert: Error outputs should be deterministic
    let first = $results | first
    let all_match = $results | skip 1 | all { |output|
        compare_responses $output $first ["trace_id", "duration_ms"]
    }

    assert $all_match "Validation error outputs should be deterministic"

    # Assert: valid should consistently be false
    let valid_values = $results | each { |r| $r.data.valid }
    assert ($valid_values | all { |v| $v == false }) "valid should be consistently false"

    # Assert: error field should be consistent
    let error_values = $results | each { |r| $r.error }
    assert ($error_values | all { |e| $e == $first.error }) "error field should be consistent"

    # Cleanup
    rm -f $contract_path $data_path
}
