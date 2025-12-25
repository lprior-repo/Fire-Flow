#!/usr/bin/env nu
# Purity tests for reproducibility - Cross-run consistency
#
# Tests that outputs maintain stable formats, field ordering, and structure
# across different executions and time periods.
#
# Run with: nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/purity'

use std assert
use ../helpers/constants.nu *
use ../helpers/builders.nu *
use ../helpers/assertions.nu *

#[test]
def test_output_format_stable [] {
    # Arrange: Test that ToolResponse format is stable
    let input = build_echo_input "format test" "trace-format"

    # Act: Run multiple times
    let outputs = 0..<5 | each { |i|
        let result = do {
            $input | to json | nu (echo_tool)
        } | complete
        $result.stdout | from json
    }

    # Assert: All outputs should have same top-level fields
    let first_fields = $outputs | first | columns | sort
    let expected_fields = ["success", "data", "trace_id", "duration_ms"] | sort

    assert equal $first_fields $expected_fields "Should have expected top-level fields"

    # Assert: All subsequent outputs have same fields
    $outputs | skip 1 | each { |output|
        let fields = $output | columns | sort
        assert equal $fields $expected_fields "All outputs should have same fields"
    }

    # Assert: data substructure is stable
    let first_data_fields = $outputs | first | get data | columns | sort
    let expected_data_fields = ["echo", "reversed", "length", "was_dry_run"] | sort

    assert equal $first_data_fields $expected_data_fields "data should have expected fields"

    $outputs | skip 1 | each { |output|
        let data_fields = $output | get data | columns | sort
        assert equal $data_fields $expected_data_fields "All data structures should match"
    }
}

#[test]
def test_json_serialization_stable [] {
    # Arrange: Test that JSON serialization is consistent
    let input = build_echo_input "serialization test" "trace-serial"

    # Act: Run and collect raw JSON strings
    let json_strings = 0..<5 | each { |i|
        let result = do {
            $input | to json | nu (echo_tool)
        } | complete
        $result.stdout
    }

    # Assert: All JSON strings should be parseable
    let parsed = $json_strings | each { |json_str|
        try {
            $json_str | from json
        } catch {
            error make { msg: "JSON should be parseable" }
        }
    }

    assert equal ($parsed | length) 5 "All outputs should be valid JSON"

    # Assert: Structural equality (fields and values match)
    let first = $parsed | first
    $parsed | skip 1 | each { |output|
        assert equal $output.success $first.success "success should match"
        assert equal $output.data.echo $first.data.echo "data.echo should match"
        assert equal $output.data.reversed $first.data.reversed "data.reversed should match"
        assert equal $output.data.length $first.data.length "data.length should match"
    }
}

#[test]
def test_error_format_stable [] {
    # Arrange: Test that error responses have stable format
    let input = build_echo_input "" "trace-err-format"  # Empty message triggers error

    # Act: Run multiple times to get errors
    let outputs = 0..<5 | each { |i|
        let result = do {
            $input | to json | nu (echo_tool)
        } | complete
        $result.stdout | from json
    }

    # Assert: All error responses have same fields
    let first = $outputs | first
    let first_fields = $first | columns | sort
    let expected_fields = ["success", "error", "trace_id", "duration_ms"] | sort

    assert equal $first_fields $expected_fields "Error response should have expected fields"

    $outputs | skip 1 | each { |output|
        let fields = $output | columns | sort
        assert equal $fields $expected_fields "All error responses should have same fields"
    }

    # Assert: Error messages are identical
    $outputs | skip 1 | each { |output|
        assert equal $output.error $first.error "Error messages should be identical"
    }
}

#[test]
def test_response_structure_stable [] {
    # Arrange: Test different tools maintain their response structures
    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/struct-test-tool-($test_id).nu"
    let output_path = $"/tmp/struct-output-($test_id).json"
    let logs_path = $"/tmp/struct-logs-($test_id).json"

    '#!/usr/bin/env nu
def main [] {
    { success: true, data: { value: 42 }, trace_id: "", duration_ms: 0 } | to json | print
}' | save -f $tool_path

    let echo_input = build_echo_input "structure test"
    let run_input = build_run_tool_input $tool_path {} $output_path $logs_path "trace-struct"

    # Act: Run each tool multiple times
    let echo_outputs = 0..<3 | each { |i|
        let result = do {
            $echo_input | to json | nu (echo_tool)
        } | complete
        $result.stdout | from json
    }

    let run_outputs = 0..<3 | each { |i|
        let result = do {
            $run_input | to json | nu (run_tool)
        } | complete
        $result.stdout | from json
    }

    # Assert: echo outputs maintain structure
    let echo_fields = $echo_outputs | first | get data | columns | sort
    $echo_outputs | skip 1 | each { |output|
        let fields = $output | get data | columns | sort
        assert equal $fields $echo_fields "Echo data structure should be stable"
    }

    # Assert: run-tool outputs maintain structure
    let run_fields = $run_outputs | first | get data | columns | sort
    $run_outputs | skip 1 | each { |output|
        let fields = $output | get data | columns | sort
        assert equal $fields $run_fields "Run-tool data structure should be stable"
    }

    # Assert: Different tools have different but stable structures
    assert not equal $echo_fields $run_fields "Different tools should have different data structures"

    # Cleanup
    rm -f $tool_path
    $run_outputs | each { |o|
        rm -f $o.data.output_path
        rm -f $o.data.logs_path
    }
}

#[test]
def test_field_ordering_stable [] {
    # Arrange: Test that field order is consistent
    let input = build_echo_input "field order test" "trace-field-order"

    # Act: Run multiple times
    let outputs = 0..<10 | each { |i|
        let result = do {
            $input | to json | nu (echo_tool)
        } | complete
        $result.stdout | from json
    }

    # Assert: All outputs have fields in same order
    # (Nushell records may not guarantee order, but columns should be consistent)
    let first_columns = $outputs | first | columns
    $outputs | skip 1 | each { |output|
        let columns = $output | columns
        assert equal $columns $first_columns "Column order should be stable"
    }

    # Assert: Nested data fields also in same order
    let first_data_columns = $outputs | first | get data | columns
    $outputs | skip 1 | each { |output|
        let data_columns = $output | get data | columns
        assert equal $data_columns $first_data_columns "Data column order should be stable"
    }
}

#[test]
def test_type_stability [] {
    # Arrange: Test that field types don't change across runs
    let input = build_echo_input "type test" "trace-type"

    # Act: Run multiple times
    let outputs = 0..<5 | each { |i|
        let result = do {
            $input | to json | nu (echo_tool)
        } | complete
        $result.stdout | from json
    }

    # Assert: All outputs have consistent types
    $outputs | each { |output|
        assert equal ($output.success | describe) "bool" "success should be bool"
        assert equal ($output.trace_id | describe) "string" "trace_id should be string"
        assert equal ($output.data.echo | describe) "string" "data.echo should be string"
        assert equal ($output.data.reversed | describe) "string" "data.reversed should be string"
        assert equal ($output.data.length | describe) "int" "data.length should be int"
        assert equal ($output.data.was_dry_run | describe) "bool" "data.was_dry_run should be bool"

        # duration_ms should be numeric (int or float)
        let duration_type = $output.duration_ms | describe
        assert ($duration_type in ["int", "float"]) "duration_ms should be numeric"
    }
}

#[test]
def test_validation_output_format_stable [] {
    # Arrange: Test validate.nu output format stability
    let test_id = (random uuid | str substring 0..8)
    let contract_path = $"/tmp/format-contract-($test_id).yaml"
    let data_path = $"/tmp/format-data-($test_id).json"

    '
dataContractSpecification: 0.9.3
id: format-test
info:
  title: Format Test
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
' | save -f $contract_path

    '{"name": "test"}' | save -f $data_path

    let input = build_validate_input $contract_path "local" "trace-val-format"

    # Act: Run validation multiple times
    let outputs = 0..<5 | each { |i|
        let result = do {
            $input | to json | nu (validate_tool)
        } | complete
        $result.stdout | from json
    }

    # Assert: All have same top-level structure
    let expected_fields = ["success", "data", "trace_id", "duration_ms"] | sort
    $outputs | each { |output|
        let fields = $output | columns | sort
        assert equal $fields $expected_fields "Validate output should have stable fields"
    }

    # Assert: data substructure is stable
    let expected_data_fields = ["valid", "errors", "stdout", "stderr", "was_dry_run"] | sort
    $outputs | each { |output|
        let data_fields = $output | get data | columns | sort
        assert equal $data_fields $expected_data_fields "Validate data should have stable fields"
    }

    # Assert: Types are consistent
    $outputs | each { |output|
        assert equal ($output.data.valid | describe) "bool" "valid should be bool"
        assert equal ($output.data.errors | describe) "list<any>" "errors should be list"
        assert equal ($output.data.was_dry_run | describe) "bool" "was_dry_run should be bool"
    }

    # Cleanup
    rm -f $contract_path $data_path
}

#[test]
def test_run_tool_output_format_stable [] {
    # Arrange: Test run-tool.nu output format stability
    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/run-format-tool-($test_id).nu"
    let output_path = $"/tmp/run-format-output-($test_id).json"
    let logs_path = $"/tmp/run-format-logs-($test_id).json"

    '#!/usr/bin/env nu
def main [] {
    { success: true, data: {}, trace_id: "", duration_ms: 0 } | to json | print
}' | save -f $tool_path

    let input = build_run_tool_input $tool_path {} $output_path $logs_path "trace-run-format"

    # Act: Run multiple times
    let outputs = 0..<5 | each { |i|
        let result = do {
            $input | to json | nu (run_tool)
        } | complete
        $result.stdout | from json
    }

    # Assert: All have same structure
    let expected_fields = ["success", "data", "trace_id", "duration_ms"] | sort
    $outputs | each { |output|
        let fields = $output | columns | sort
        assert equal $fields $expected_fields "Run-tool output should have stable fields"
    }

    # Assert: data substructure is stable
    let expected_data_fields = ["exit_code", "output_path", "logs_path", "was_dry_run"] | sort
    $outputs | each { |output|
        let data_fields = $output | get data | columns | sort
        assert equal $data_fields $expected_data_fields "Run-tool data should have stable fields"
    }

    # Assert: Types are consistent
    $outputs | each { |output|
        assert equal ($output.data.exit_code | describe) "int" "exit_code should be int"
        assert equal ($output.data.output_path | describe) "string" "output_path should be string"
        assert equal ($output.data.logs_path | describe) "string" "logs_path should be string"
        assert equal ($output.data.was_dry_run | describe) "bool" "was_dry_run should be bool"
    }

    # Cleanup
    rm -f $tool_path
    $outputs | each { |o|
        rm -f $o.data.output_path
        rm -f $o.data.logs_path
    }
}

#[test]
def test_error_types_stable [] {
    # Arrange: Test that error types are consistent
    let test_cases = [
        {
            name: "Missing field"
            input: { context: { trace_id: "err-1" } }  # Missing message
            expected_error: "message is required"
        }
        {
            name: "Empty field"
            input: { message: "", context: { trace_id: "err-2" } }
            expected_error: "message is required"
        }
        {
            name: "Invalid JSON"
            raw_input: "not json"
            expected_error: "Invalid JSON input"
        }
    ]

    # Act & Assert: Run each error case multiple times
    for case in $test_cases {
        let outputs = 0..<3 | each { |i|
            let result = if ("raw_input" in $case) {
                do {
                    echo $case.raw_input | nu (echo_tool)
                } | complete
            } else {
                do {
                    $case.input | to json | nu (echo_tool)
                } | complete
            }

            assert equal $result.exit_code 1 $"($case.name) should fail"
            $result.stdout | from json
        }

        # All outputs should have same error message
        $outputs | each { |output|
            assert equal $output.success false $"($case.name) should have success=false"
            assert equal $output.error $case.expected_error $"($case.name) error should be consistent"
        }

        # All outputs should have same structure
        let first_fields = $outputs | first | columns | sort
        $outputs | skip 1 | each { |output|
            let fields = $output | columns | sort
            assert equal $fields $first_fields $"($case.name) error structure should be stable"
        }
    }
}

#[test]
def test_nested_structure_stability [] {
    # Arrange: Test deeply nested structures remain stable
    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/nested-tool-($test_id).nu"
    let output_path = $"/tmp/nested-output-($test_id).json"
    let logs_path = $"/tmp/nested-logs-($test_id).json"

    '#!/usr/bin/env nu
def main [] {
    let data = {
        level1: {
            level2: {
                level3: {
                    value: "deep"
                }
            }
            array: [1, 2, 3]
        }
        root_value: "top"
    }
    { success: true, data: $data, trace_id: "", duration_ms: 0 } | to json | print
}' | save -f $tool_path

    let input = build_run_tool_input $tool_path {} $output_path $logs_path "trace-nested"

    # Act: Run multiple times
    let outputs = 0..<5 | each { |i|
        let result = do {
            $input | to json | nu (run_tool)
        } | complete
        $result.stdout | from json
    }

    # Assert: Nested structure is stable
    $outputs | each { |output|
        let tool_output = open --raw $output.data.output_path | from json

        assert equal $tool_output.data.root_value "top" "Root value should be stable"
        assert equal $tool_output.data.level1.level2.level3.value "deep" "Deep nesting should be stable"
        assert equal $tool_output.data.level1.array [1, 2, 3] "Array should be stable"
    }

    # Cleanup
    rm -f $tool_path
    $outputs | each { |o|
        rm -f $o.data.output_path
        rm -f $o.data.logs_path
    }
}

#[test]
def test_boolean_representation_stable [] {
    # Arrange: Test that booleans are consistently represented
    let true_input = build_echo_input "test" "trace-bool-true" false
    let dry_input = build_echo_input "test" "trace-bool-dry" true

    # Act: Run with different boolean contexts
    let false_outputs = 0..<3 | each { |i|
        let result = do {
            $true_input | to json | nu (echo_tool)
        } | complete
        $result.stdout | from json
    }

    let true_outputs = 0..<3 | each { |i|
        let result = do {
            $dry_input | to json | nu (echo_tool)
        } | complete
        $result.stdout | from json
    }

    # Assert: Booleans are consistent
    $false_outputs | each { |output|
        assert equal $output.success true "success should be bool true"
        assert equal $output.data.was_dry_run false "was_dry_run should be bool false"
        assert equal ($output.success | describe) "bool" "success should be bool type"
        assert equal ($output.data.was_dry_run | describe) "bool" "was_dry_run should be bool type"
    }

    $true_outputs | each { |output|
        assert equal $output.success true "success should be bool true"
        assert equal $output.data.was_dry_run true "was_dry_run should be bool true"
    }
}

#[test]
def test_numeric_representation_stable [] {
    # Arrange: Test that numbers are consistently typed
    let input = build_echo_input "12345" "trace-numeric"

    # Act: Run multiple times
    let outputs = 0..<5 | each { |i|
        let result = do {
            $input | to json | nu (echo_tool)
        } | complete
        $result.stdout | from json
    }

    # Assert: Numeric fields have stable types
    $outputs | each { |output|
        # length should be int
        assert equal ($output.data.length | describe) "int" "length should be int"
        assert equal $output.data.length 5 "length should be 5"

        # duration_ms should be numeric
        let duration_type = $output.duration_ms | describe
        assert ($duration_type in ["int", "float"]) "duration_ms should be numeric"
        assert ($output.duration_ms >= 0) "duration_ms should be non-negative"
    }
}

#[test]
def test_empty_collections_stable [] {
    # Arrange: Test that empty arrays/objects are consistently represented
    let test_id = (random uuid | str substring 0..8)
    let contract_path = $"/tmp/empty-contract-($test_id).yaml"
    let data_path = $"/tmp/empty-data-($test_id).json"

    '
dataContractSpecification: 0.9.3
id: empty-test
info:
  title: Empty Test
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
' | save -f $contract_path

    '{"name": "test"}' | save -f $data_path

    let input = build_validate_input $contract_path "local" "trace-empty"

    # Act: Run validation (should pass, errors should be empty)
    let outputs = 0..<5 | each { |i|
        let result = do {
            $input | to json | nu (validate_tool)
        } | complete
        $result.stdout | from json
    }

    # Assert: Empty arrays are consistently represented
    $outputs | each { |output|
        assert equal ($output.data.errors | describe) "list<any>" "errors should be list type"
        assert equal ($output.data.errors | length) 0 "errors should be empty list"
        assert equal $output.data.errors [] "errors should equal empty list"
    }

    # Cleanup
    rm -f $contract_path $data_path
}
