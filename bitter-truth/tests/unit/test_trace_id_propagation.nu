#!/usr/bin/env nu
# Unit tests for trace_id propagation and observability
# Ensures trace_id flows correctly through all tools for request tracing
#
# Run with: nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/unit'

use std assert

# Helper to get tools directory
def tools_dir [] {
    $env.PWD | path join "bitter-truth/tools"
}

#[test]
def test_trace_id_passes_through_generate [] {
    # Arrange: Create input with specific trace_id
    let trace_id = $"gen-trace-(random uuid | str substring 0..8)"
    let contract_path = $env.PWD | path join "bitter-truth/contracts/tools/echo.yaml"

    let input = {
        contract_path: $contract_path
        task: "test task"
        context: {
            trace_id: $trace_id
            dry_run: true  # Use dry_run to avoid actual AI generation
        }
    }

    # Act: Execute generate.nu
    let result = do {
        $input | to json | nu (tools_dir | path join "generate.nu")
    } | complete

    # Assert: trace_id should be in output
    assert equal $result.exit_code 0 "Should succeed in dry_run"
    let output = $result.stdout | from json
    assert equal $output.trace_id $trace_id "trace_id should be preserved in output"

    # Verify trace_id appears in stderr logs
    assert ($result.stderr | str contains $trace_id) "trace_id should appear in logs"
}

#[test]
def test_trace_id_passes_through_run_tool [] {
    # Arrange: Create tool and input with trace_id
    let trace_id = $"run-trace-(random uuid | str substring 0..8)"
    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/test-trace-tool-($test_id).nu"
    let output_path = $"/tmp/test-output-($test_id).json"
    let logs_path = $"/tmp/test-logs-($test_id).json"

    # Create simple echo tool
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    { echo: "ok" } | to json | print
}' | save -f $tool_path

    let input = {
        tool_path: $tool_path
        tool_input: { data: "test" }
        output_path: $output_path
        logs_path: $logs_path
        context: { trace_id: $trace_id }
    }

    # Act: Execute run-tool.nu
    let result = do {
        $input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    # Assert: trace_id should be preserved
    assert equal $result.exit_code 0 "Should succeed"
    let output = $result.stdout | from json
    assert equal $output.trace_id $trace_id "trace_id should be in response"

    # Verify trace_id in logs
    assert ($result.stderr | str contains $trace_id) "trace_id should be in stderr logs"

    # Cleanup
    rm -f $tool_path $output_path $logs_path
}

#[test]
def test_trace_id_passes_through_validate [] {
    # Arrange: Create validation input with trace_id
    let trace_id = $"val-trace-(random uuid | str substring 0..8)"
    let contract_path = $env.PWD | path join "bitter-truth/contracts/tools/echo.yaml"

    let input = {
        contract_path: $contract_path
        context: {
            trace_id: $trace_id
            dry_run: true  # Skip actual validation
        }
    }

    # Act: Execute validate.nu
    let result = do {
        $input | to json | nu (tools_dir | path join "validate.nu")
    } | complete

    # Assert: trace_id should be preserved
    assert equal $result.exit_code 0 "Should succeed in dry_run"
    let output = $result.stdout | from json
    assert equal $output.trace_id $trace_id "trace_id should be in output"

    # Verify trace_id in logs
    assert ($result.stderr | str contains $trace_id) "trace_id should be in logs"
}

#[test]
def test_trace_id_in_error_responses [] {
    # Arrange: Test trace_id preservation in error scenarios
    let trace_id = $"err-trace-(random uuid | str substring 0..8)"

    let test_cases = [
        {
            tool: "echo.nu"
            input: { message: "", context: { trace_id: $trace_id } }
        }
        {
            tool: "run-tool.nu"
            input: { tool_path: "/no/such/tool.nu", context: { trace_id: $trace_id } }
        }
        {
            tool: "validate.nu"
            input: { contract_path: "/no/contract.yaml", context: { trace_id: $trace_id } }
        }
        {
            tool: "generate.nu"
            input: { contract_path: "/no/contract.yaml", task: "test", context: { trace_id: $trace_id } }
        }
    ]

    # Act & Assert: trace_id should be in all error responses
    for case in $test_cases {
        let result = do {
            $case.input | to json | nu (tools_dir | path join $case.tool)
        } | complete

        assert equal $result.exit_code 1 $"($case.tool): should fail"
        let output = $result.stdout | from json
        assert equal $output.trace_id $trace_id $"($case.tool): trace_id should be in error response"
        assert ($result.stderr | str contains $trace_id) $"($case.tool): trace_id should be in error logs"
    }
}

#[test]
def test_trace_id_consistent_across_pipeline [] {
    # Arrange: Simulate a pipeline of generate -> run -> validate
    let trace_id = $"pipeline-trace-(random uuid | str substring 0..8)"
    let test_id = (random uuid | str substring 0..8)
    let contract_path = $env.PWD | path join "bitter-truth/contracts/tools/echo.yaml"

    # Step 1: Generate (dry_run)
    let gen_input = {
        contract_path: $contract_path
        task: "echo tool"
        context: {
            trace_id: $trace_id
            dry_run: true
        }
    }

    let gen_result = do {
        $gen_input | to json | nu (tools_dir | path join "generate.nu")
    } | complete

    assert equal $gen_result.exit_code 0 "Generate should succeed"
    let gen_output = $gen_result.stdout | from json
    assert equal $gen_output.trace_id $trace_id "Generate: trace_id should match"

    # Step 2: Run tool (using dry_run output)
    let tool_path = $gen_output.data.output_path
    let run_input = {
        tool_path: $tool_path
        tool_input: { message: "test" }
        output_path: $"/tmp/run-output-($test_id).json"
        logs_path: $"/tmp/run-logs-($test_id).json"
        context: { trace_id: $trace_id }
    }

    let run_result = do {
        $run_input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    assert equal $run_result.exit_code 0 "Run should succeed"
    let run_output = $run_result.stdout | from json
    assert equal $run_output.trace_id $trace_id "Run: trace_id should match"

    # Step 3: Validate (dry_run)
    let val_input = {
        contract_path: $contract_path
        context: {
            trace_id: $trace_id
            dry_run: true
        }
    }

    let val_result = do {
        $val_input | to json | nu (tools_dir | path join "validate.nu")
    } | complete

    assert equal $val_result.exit_code 0 "Validate should succeed"
    let val_output = $val_result.stdout | from json
    assert equal $val_output.trace_id $trace_id "Validate: trace_id should match"

    # Assert: All three steps should have the same trace_id
    assert equal $gen_output.trace_id $run_output.trace_id "Generate and Run should share trace_id"
    assert equal $run_output.trace_id $val_output.trace_id "Run and Validate should share trace_id"

    # Cleanup
    rm -f $tool_path $run_input.output_path $run_input.logs_path
}

#[test]
def test_trace_id_in_all_log_levels [] {
    # Arrange: Execute successful operation to get various log levels
    let trace_id = $"log-trace-(random uuid | str substring 0..8)"
    let input = {
        message: "test message for logging"
        context: { trace_id: $trace_id }
    }

    # Act: Execute echo.nu
    let result = do {
        $input | to json | nu (tools_dir | path join "echo.nu")
    } | complete

    # Assert: trace_id should appear in all log lines
    assert equal $result.exit_code 0 "Should succeed"

    let log_lines = $result.stderr | lines | where { |line| ($line | str length) > 0 }
    assert (($log_lines | length) > 0) "Should have log lines"

    # Parse each log line and verify trace_id
    for log_line in $log_lines {
        let log = $log_line | from json
        assert equal $log.trace_id $trace_id $"All log lines should contain trace_id: ($log_line | str substring 0..50)"
    }
}

#[test]
def test_empty_trace_id_is_preserved [] {
    # Arrange: Input with empty trace_id
    let input = {
        message: "test"
        context: { trace_id: "" }
    }

    # Act: Execute echo.nu
    let result = do {
        $input | to json | nu (tools_dir | path join "echo.nu")
    } | complete

    # Assert: Empty trace_id should be preserved as empty string
    assert equal $result.exit_code 0 "Should succeed"
    let output = $result.stdout | from json
    assert (($output | get trace_id | describe) == "string") "trace_id should be string type"
    assert equal $output.trace_id "" "Empty trace_id should be preserved"
}

#[test]
def test_missing_trace_id_defaults_to_empty [] {
    # Arrange: Input without trace_id in context
    let input = {
        message: "test"
        context: {}  # No trace_id
    }

    # Act: Execute echo.nu
    let result = do {
        $input | to json | nu (tools_dir | path join "echo.nu")
    } | complete

    # Assert: Should default to empty string
    assert equal $result.exit_code 0 "Should succeed"
    let output = $result.stdout | from json
    assert equal $output.trace_id "" "Missing trace_id should default to empty string"
}

#[test]
def test_trace_id_with_special_characters [] {
    # Arrange: Test trace_id with various special characters
    let special_trace_ids = [
        "trace-with-dashes-123"
        "trace_with_underscores_456"
        "trace.with.dots.789"
        "trace:with:colons:abc"
        "trace/with/slashes/def"
        "CamelCaseTrace123"
    ]

    # Act & Assert: All special trace_ids should be preserved
    for trace_id in $special_trace_ids {
        let input = {
            message: "test"
            context: { trace_id: $trace_id }
        }

        let result = do {
            $input | to json | nu (tools_dir | path join "echo.nu")
        } | complete

        assert equal $result.exit_code 0 $"Should succeed with trace_id: ($trace_id)"
        let output = $result.stdout | from json
        assert equal $output.trace_id $trace_id $"trace_id should be preserved: ($trace_id)"
    }
}

#[test]
def test_trace_id_in_nested_tool_calls [] {
    # Arrange: Create a tool that calls another tool, preserving trace_id
    let trace_id = $"nested-trace-(random uuid | str substring 0..8)"
    let test_id = (random uuid | str substring 0..8)

    # Create inner tool
    let inner_tool = $"/tmp/inner-tool-($test_id).nu"
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    { inner_result: "success", trace_id: $input.trace_id } | to json | print
}' | save -f $inner_tool

    # Create outer tool that calls inner tool
    let outer_tool = $"/tmp/outer-tool-($test_id).nu"
    $'#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    let inner_input = { trace_id: $input.trace_id }
    let inner_result = $inner_input | to json | nu ($inner_tool) | complete
    { outer_result: "called inner", inner_stdout: $inner_result.stdout } | to json | print
}' | save -f $outer_tool

    # Execute outer tool via run-tool.nu
    let input = {
        tool_path: $outer_tool
        tool_input: { trace_id: $trace_id }
        output_path: $"/tmp/outer-output-($test_id).json"
        logs_path: $"/tmp/outer-logs-($test_id).json"
        context: { trace_id: $trace_id }
    }

    # Act: Execute run-tool.nu
    let result = do {
        $input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    # Assert: trace_id should propagate through nested calls
    assert equal $result.exit_code 0 "Should succeed"
    let output = $result.stdout | from json
    assert equal $output.trace_id $trace_id "Outer: trace_id should match"

    # Check inner tool received trace_id
    let outer_output = open $input.output_path
    let inner_output = $outer_output.inner_stdout | from json
    assert equal $inner_output.trace_id $trace_id "Inner: trace_id should match"

    # Cleanup
    rm -f $inner_tool $outer_tool $input.output_path $input.logs_path
}

#[test]
def test_trace_id_length_preserved [] {
    # Arrange: Test trace_ids of various lengths
    let trace_ids = [
        "x"  # 1 char
        "short"  # 5 chars
        "medium-length-trace-id"  # 23 chars
        ($"very-long-trace-id-(random uuid)-(random uuid)-(random uuid)")  # ~100+ chars
    ]

    # Act & Assert: All trace_id lengths should be preserved
    for trace_id in $trace_ids {
        let input = {
            message: "test"
            context: { trace_id: $trace_id }
        }

        let result = do {
            $input | to json | nu (tools_dir | path join "echo.nu")
        } | complete

        assert equal $result.exit_code 0 $"Should succeed with length ($trace_id | str length)"
        let output = $result.stdout | from json
        assert equal ($output.trace_id | str length) ($trace_id | str length) "trace_id length should be preserved"
        assert equal $output.trace_id $trace_id "trace_id should be exactly preserved"
    }
}

#[test]
def test_trace_id_in_concurrent_calls [] {
    # Arrange: Simulate concurrent calls with different trace_ids
    let test_id = (random uuid | str substring 0..8)
    let trace_ids = [
        $"concurrent-1-($test_id)"
        $"concurrent-2-($test_id)"
        $"concurrent-3-($test_id)"
    ]

    # Act: Execute multiple calls "concurrently" (sequentially but rapidly)
    let results = $trace_ids | each { |tid|
        let input = {
            message: $"test for ($tid)"
            context: { trace_id: $tid }
        }

        let result = do {
            $input | to json | nu (tools_dir | path join "echo.nu")
        } | complete

        {
            trace_id: $tid
            exit_code: $result.exit_code
            output: ($result.stdout | from json)
        }
    }

    # Assert: Each call should preserve its own trace_id
    for i in 0..<($trace_ids | length) {
        let expected_tid = $trace_ids | get $i
        let result = $results | get $i

        assert equal $result.exit_code 0 $"Call ($i) should succeed"
        assert equal $result.output.trace_id $expected_tid $"Call ($i) should have correct trace_id"
    }
}

#[test]
def test_trace_id_appears_in_every_stderr_line [] {
    # Arrange: Execute operation that generates multiple log lines
    let trace_id = $"multi-log-trace-(random uuid | str substring 0..8)"
    let contract_path = $env.PWD | path join "bitter-truth/contracts/tools/echo.yaml"

    let input = {
        contract_path: $contract_path
        task: "test task"
        context: {
            trace_id: $trace_id
            dry_run: true
        }
    }

    # Act: Execute generate.nu (produces multiple log lines)
    let result = do {
        $input | to json | nu (tools_dir | path join "generate.nu")
    } | complete

    # Assert: Every non-empty stderr line should be valid JSON with trace_id
    assert equal $result.exit_code 0 "Should succeed"

    let log_lines = $result.stderr | lines | where { |line| ($line | str length) > 0 }
    assert (($log_lines | length) > 1) "Should have multiple log lines"

    for log_line in $log_lines {
        let log = $log_line | from json
        assert ("trace_id" in ($log | columns)) $"Log should have trace_id field: ($log_line | str substring 0..50)"
        assert equal $log.trace_id $trace_id $"Log trace_id should match: ($log_line | str substring 0..50)"
    }
}
