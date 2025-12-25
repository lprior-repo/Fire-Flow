#!/usr/bin/env nu
# Test assertions - Specialized assertions for bitter-truth testing
#
# Usage:
#   use bitter-truth/tests/helpers/assertions.nu *
#   assert_tool_response $response
#   assert_contract_valid $output_path $contract_path

use std assert

# Assert that response has valid ToolResponse structure
#
# Args:
#   response: record - ToolResponse to validate
#
# Validates:
#   - Has 'success' field (boolean)
#   - If success=true, has 'data' field
#   - If success=false, has 'error' field
#   - Optional: trace_id, duration_ms
#
# Example:
#   let response = $result.stdout | from json
#   assert_tool_response $response
export def assert_tool_response [
    response: record
] {
    # Check success field exists and is boolean
    assert ("success" in $response) "ToolResponse must have 'success' field"
    assert equal ($response.success | describe) "bool" "success must be boolean"

    if $response.success {
        # Success=true requires data field
        assert ("data" in $response) "ToolResponse with success=true must have 'data' field"
    } else {
        # Success=false requires error field
        assert ("error" in $response) "ToolResponse with success=false must have 'error' field"
        assert (($response.error | str length) > 0) "error message must not be empty"
    }

    # Optional fields validation
    if ("trace_id" in $response) {
        assert equal ($response.trace_id | describe) "string" "trace_id must be string"
    }

    if ("duration_ms" in $response) {
        let duration_type = $response.duration_ms | describe
        assert ($duration_type in ["int", "float"]) "duration_ms must be numeric"
        assert ($response.duration_ms >= 0) "duration_ms must be non-negative"
    }
}

# Assert that output conforms to contract using datacontract-cli
#
# Args:
#   output_path: string - path to JSON output file
#   contract_path: string - path to data contract YAML
#
# This runs the actual validate.nu tool to check contract conformance
#
# Example:
#   assert_contract_valid "/tmp/output.json" "/path/contract.yaml"
export def assert_contract_valid [
    output_path: string
    contract_path: string
] {
    assert ($output_path | path exists) $"Output file must exist: ($output_path)"
    assert ($contract_path | path exists) $"Contract file must exist: ($contract_path)"

    let tools_dir = $env.PWD | path join "bitter-truth/tools"
    let validate_tool = $tools_dir | path join "validate.nu"

    # Run validate.nu
    let result = {
        contract_path: $contract_path
        server: "local"
        context: { trace_id: "assertion-check" }
    } | to json | nu $validate_tool | complete

    assert equal $result.exit_code 0 $"validate.nu should exit 0, got ($result.exit_code)"

    let output = $result.stdout | from json
    assert_tool_response $output

    assert equal $output.success true "Validation should succeed for valid contract"
    assert equal $output.data.valid true $"Output does not conform to contract: ($contract_path)"
}

# Assert files exist at given paths
#
# Args:
#   paths: list<string> - list of file paths to check
#
# Example:
#   assert_files_exist ["/tmp/output.json", "/tmp/logs.json"]
export def assert_files_exist [
    paths: list<string>
] {
    $paths | each { |path|
        assert ($path | path exists) $"File must exist: ($path)"
    }
}

# Assert JSON is valid and parseable
#
# Args:
#   json_path: string - path to JSON file
#
# Returns: record - parsed JSON data
#
# Example:
#   let data = assert_json_valid "/tmp/output.json"
export def assert_json_valid [
    json_path: string
] {
    assert ($json_path | path exists) $"JSON file must exist: ($json_path)"

    let content = open --raw $json_path

    assert (($content | str length) > 0) $"JSON file must not be empty: ($json_path)"

    let parsed = try {
        $content | from json
    } catch {
        error make {
            msg: $"Invalid JSON in file: ($json_path)"
            label: {
                text: $"Failed to parse JSON"
                span: (metadata $json_path).span
            }
        }
    }

    $parsed
}

# Assert exit code matches expectation
#
# Args:
#   result: record - result from `complete`
#   expected_code: int - expected exit code (default: 0)
#   message: string - optional custom error message
#
# Example:
#   assert_exit_code $result 0 "Tool should succeed"
#   assert_exit_code $result 1 "Tool should fail"
export def assert_exit_code [
    result: record
    expected_code: int = 0
    message?: string
] {
    let msg = if ($message | is-empty) {
        $"Expected exit code ($expected_code), got ($result.exit_code)"
    } else {
        $message
    }

    assert equal $result.exit_code $expected_code $msg
}

# Assert trace_id is propagated through response
#
# Args:
#   response: record - ToolResponse to check
#   expected_trace_id: string - expected trace ID
#
# Example:
#   assert_trace_id_propagated $response "test-123"
export def assert_trace_id_propagated [
    response: record
    expected_trace_id: string
] {
    assert ("trace_id" in $response) "Response must have trace_id field"
    assert equal $response.trace_id $expected_trace_id $"trace_id should be ($expected_trace_id), got ($response.trace_id)"
}

# Assert response indicates success
#
# Args:
#   response: record - ToolResponse to check
#   message: string - optional custom error message
#
# Example:
#   assert_success $response "Echo tool should succeed"
export def assert_success [
    response: record
    message?: string
] {
    assert_tool_response $response

    let msg = if ($message | is-empty) {
        $"Expected success=true, got success=($response.success)"
    } else {
        $message
    }

    assert equal $response.success true $msg
}

# Assert response indicates failure
#
# Args:
#   response: record - ToolResponse to check
#   message: string - optional custom error message
#
# Example:
#   assert_failure $response "Invalid input should fail"
export def assert_failure [
    response: record
    message?: string
] {
    assert_tool_response $response

    let msg = if ($message | is-empty) {
        $"Expected success=false, got success=($response.success)"
    } else {
        $message
    }

    assert equal $response.success false $msg
}

# Assert error message contains expected text
#
# Args:
#   response: record - ToolResponse with error
#   expected_text: string - text that should appear in error
#
# Example:
#   assert_error_contains $response "message is required"
export def assert_error_contains [
    response: record
    expected_text: string
] {
    assert_failure $response

    let error = $response.error
    assert ($error | str contains $expected_text) $"Error should contain '($expected_text)', got: ($error)"
}

# Assert data field has expected structure
#
# Args:
#   response: record - ToolResponse to check
#   required_fields: list<string> - list of field names that must exist in data
#
# Example:
#   assert_data_fields $response ["echo", "reversed", "length"]
export def assert_data_fields [
    response: record
    required_fields: list<string>
] {
    assert_success $response

    $required_fields | each { |field|
        assert ($field in $response.data) $"data must have field: ($field)"
    }
}

# Assert duration is within reasonable bounds
#
# Args:
#   response: record - ToolResponse with duration_ms
#   max_ms: int - maximum acceptable duration (default: 30000)
#
# Example:
#   assert_duration_reasonable $response 5000
export def assert_duration_reasonable [
    response: record
    max_ms: int = 30000
] {
    assert ("duration_ms" in $response) "Response must have duration_ms"
    assert ($response.duration_ms >= 0) "duration_ms must be non-negative"
    assert ($response.duration_ms <= $max_ms) $"duration_ms ($response.duration_ms) exceeds max ($max_ms)"
}

# Assert JSON output matches expected structure (deep equality)
#
# Args:
#   actual: record - actual data
#   expected: record - expected data
#   path: string - current path for error messages (for recursion)
#
# Example:
#   assert_json_equals $actual $expected
export def assert_json_equals [
    actual: any
    expected: any
    path: string = "root"
] {
    let actual_type = $actual | describe
    let expected_type = $expected | describe

    assert equal $actual_type $expected_type $"Type mismatch at ($path): expected ($expected_type), got ($actual_type)"

    if $actual_type == "record" {
        # Check all expected keys exist
        let expected_keys = $expected | columns
        $expected_keys | each { |key|
            assert ($key in $actual) $"Missing key at ($path).($key)"

            assert_json_equals ($actual | get $key) ($expected | get $key) $"($path).($key)"
        }
    } else if $actual_type == "list" {
        assert equal ($actual | length) ($expected | length) $"List length mismatch at ($path)"

        $actual | enumerate | each { |item|
            assert_json_equals $item.item ($expected | get $item.index) $"($path)[($item.index)]"
        }
    } else {
        # Primitive types - direct comparison
        assert equal $actual $expected $"Value mismatch at ($path): expected ($expected), got ($actual)"
    }
}

# Assert command completed without error (for `complete` results)
#
# Args:
#   result: record - result from `complete`
#   message: string - optional custom message
#
# Example:
#   assert_completed_successfully $result "echo tool execution"
export def assert_completed_successfully [
    result: record
    message?: string
] {
    assert_exit_code $result 0 $message

    # stdout should not be empty for tools (they always output JSON)
    assert (($result.stdout | str length) > 0) "stdout should not be empty"
}
