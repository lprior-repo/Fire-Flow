#!/usr/bin/env nu
# Example tests demonstrating test helper usage
#
# This file shows best practices for using the test helper infrastructure.
# Run with: nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/test_helpers_example.nu'

use std assert
use bitter-truth/tests/helpers/constants.nu *
use bitter-truth/tests/helpers/fixtures.nu *
use bitter-truth/tests/helpers/builders.nu *
use bitter-truth/tests/helpers/assertions.nu *

# ============================================================================
# BASIC USAGE EXAMPLES
# ============================================================================

#[test]
def "example_basic_echo_test_with_helpers" [] {
    # Arrange - Initialize temp tracking and create test context
    init_temp_tracker
    let ctx = build_test_context

    # Build input using helper
    let input = build_echo_input "hello world" $ctx.trace_id

    # Act - Execute echo tool
    let result = $input | to json | nu (echo_tool) | complete

    # Assert - Use specialized assertions
    assert_completed_successfully $result "Echo tool should execute successfully"

    let response = $result.stdout | from json
    assert_success $response "Echo should succeed with valid input"
    assert_trace_id_propagated $response $ctx.trace_id
    assert_data_fields $response ["echo", "reversed", "length"]
    assert_duration_reasonable $response 5000

    # Verify actual data
    assert equal $response.data.echo "hello world"
    assert equal $response.data.reversed "dlrow olleh"
    assert equal $response.data.length 11

    # Cleanup - Always cleanup temp files
    cleanup_temp_files
}

#[test]
def "example_using_fixtures" [] {
    # Arrange
    init_temp_tracker

    # Load fixture tool and input
    let tool_code = load_fixture "tools" "echo-correct"
    let input_data = load_fixture "inputs" "echo-valid"

    # Create temp tool file
    let tool_path = create_temp_tool $tool_code "echo-test"
    let ctx = build_test_context

    # Act - Use run-tool to execute the fixture tool
    let run_input = build_run_tool_input $tool_path $input_data $ctx.output_path $ctx.logs_path
    let result = $run_input | to json | nu (run_tool) | complete

    # Assert
    assert_completed_successfully $result
    let response = $result.stdout | from json
    assert_success $response

    # Verify files were created
    assert_files_exist [$ctx.output_path, $ctx.logs_path]

    # Validate output JSON
    let output = assert_json_valid $ctx.output_path
    assert_success $output
    assert equal $output.data.echo "hello world"

    # Cleanup
    cleanup_temp_files
}

#[test]
def "example_testing_error_conditions" [] {
    # Arrange
    init_temp_tracker
    let ctx = build_test_context

    # Create input with empty message (should fail)
    let input = build_echo_input "" $ctx.trace_id

    # Act
    let result = $input | to json | nu (echo_tool) | complete

    # Assert - Expect failure
    assert_exit_code $result 1 "Empty message should cause failure"

    let response = $result.stdout | from json
    assert_failure $response "Echo should fail with empty message"
    assert_error_contains $response "message is required"

    # Cleanup
    cleanup_temp_files
}

#[test]
def "example_testing_buggy_tool" [] {
    # Arrange
    init_temp_tracker

    # Load buggy tool fixture
    let buggy_code = load_fixture "tools" "echo-buggy"
    let tool_path = create_temp_tool $buggy_code "buggy-echo"

    let input_data = load_fixture "inputs" "echo-valid"
    let ctx = build_test_context

    # Act - Execute buggy tool via run-tool
    let run_input = build_run_tool_input $tool_path $input_data $ctx.output_path $ctx.logs_path
    let result = $run_input | to json | nu (run_tool) | complete

    # Assert - run-tool should exit 0 but report failure
    assert_exit_code $result 1 "run-tool exits 1 when tool fails"

    let response = $result.stdout | from json
    assert_failure $response "Buggy tool should fail"

    # Check logs contain the error
    let logs = open --raw $ctx.logs_path
    assert ($logs | str contains "str rev") "Logs should capture the actual error"

    # Cleanup
    cleanup_temp_files
}

# ============================================================================
# ADVANCED USAGE EXAMPLES
# ============================================================================

#[test]
def "example_contract_validation" [] {
    # Arrange
    init_temp_tracker
    let ctx = build_test_context

    # Create a valid output that conforms to ToolResponse + EchoOutput
    let valid_output = {
        success: true
        data: {
            echo: "test message"
            reversed: "egassem tset"
            length: 12
            was_dry_run: false
        }
        trace_id: $ctx.trace_id
        duration_ms: 5
    }

    # Save to file
    $valid_output | to json | save -f $ctx.output_path

    # Act & Assert - Validate against contract
    # This will fail if output doesn't match the contract schema
    assert_contract_valid $ctx.output_path (echo_contract)

    # Cleanup
    cleanup_temp_files
}

#[test]
def "example_parallel_test_safety" [] {
    # Each test gets unique IDs, so they don't interfere
    init_temp_tracker
    let ctx = build_test_context

    # This test's files are uniquely named with ctx.test_id
    print $"Test ID: ($ctx.test_id)"
    print $"Output: ($ctx.output_path)"

    # Even if another test runs in parallel, it will have different paths
    assert ($ctx.output_path | str contains $ctx.test_id)

    cleanup_temp_files
}

#[test]
def "example_dry_run_mode" [] {
    # Arrange
    init_temp_tracker
    let ctx = build_test_context

    # Build input with dry_run = true
    let input = build_echo_input "test" $ctx.trace_id true

    # Act
    let result = $input | to json | nu (echo_tool) | complete

    # Assert
    assert_completed_successfully $result
    let response = $result.stdout | from json
    assert_success $response

    # Verify was_dry_run is true
    assert equal $response.data.was_dry_run true

    cleanup_temp_files
}

#[test]
def "example_deep_equality_assertion" [] {
    # Arrange
    let actual = {
        success: true
        data: {
            echo: "test"
            length: 4
        }
    }

    let expected = {
        success: true
        data: {
            echo: "test"
            length: 4
        }
    }

    # Act & Assert - Deep comparison
    assert_json_equals $actual $expected

    # This would fail:
    # let wrong = { success: false, data: { echo: "test" } }
    # assert_json_equals $actual $wrong  # Error: Value mismatch at root.success
}

#[test]
def "example_using_multiple_helpers_together" [] {
    # Arrange - Combine all helpers
    init_temp_tracker
    let ctx = build_test_context

    # Use constants
    assert ((echo_tool) | path exists) "Echo tool should exist"

    # Use builders
    let input = build_echo_input "integration test" $ctx.trace_id

    # Use fixtures for expected output
    let expected = load_fixture "outputs" "echo-expected"

    # Act
    let result = $input | to json | nu (echo_tool) | complete

    # Assert with multiple assertions
    assert_completed_successfully $result
    let response = $result.stdout | from json
    assert_tool_response $response
    assert_success $response
    assert_data_fields $response ["echo", "reversed", "length", "was_dry_run"]
    assert_duration_reasonable $response

    # Cleanup
    cleanup_temp_files
}

# ============================================================================
# INTEGRATION EXAMPLES
# ============================================================================

#[test]
def "example_full_pipeline_test" [] {
    # This shows how to test the full Generate -> Execute -> Validate flow
    # using all helper infrastructure

    # Arrange
    init_temp_tracker
    let ctx = build_test_context

    # Step 1: Use a pre-built correct tool (simulating successful generation)
    let tool_code = load_fixture "tools" "echo-correct"
    let tool_path = create_temp_tool $tool_code "pipeline"

    # Step 2: Execute the tool
    let input_data = load_fixture "inputs" "echo-valid"
    let run_input = build_run_tool_input $tool_path $input_data $ctx.output_path $ctx.logs_path
    let run_result = $run_input | to json | nu (run_tool) | complete

    # Assert execution succeeded
    assert_completed_successfully $run_result
    let run_response = $run_result.stdout | from json
    assert_success $run_response

    # Step 3: Validate output against contract
    # Note: This requires the output file to exist and conform to contract
    # For echo tool, we need to validate the inner tool output, not run-tool's response

    let tool_output = assert_json_valid $ctx.output_path
    assert_success $tool_output

    # Verify the complete flow
    assert equal $tool_output.data.echo "hello world"
    assert_files_exist [$ctx.output_path, $ctx.logs_path]

    # Cleanup
    cleanup_temp_files
}

#[test]
def "example_self_healing_simulation" [] {
    # This simulates the self-healing flow:
    # 1. Generate tool (buggy)
    # 2. Execute tool (fails)
    # 3. Capture feedback
    # 4. Use feedback to fix (load correct version)
    # 5. Execute again (succeeds)

    # Arrange
    init_temp_tracker
    let ctx = build_test_context

    # Attempt 1: Buggy tool
    let buggy_code = load_fixture "tools" "echo-buggy"
    let buggy_path = create_temp_tool $buggy_code "attempt-1"
    let input = load_fixture "inputs" "echo-valid"

    # Execute buggy tool
    let attempt1 = build_run_tool_input $buggy_path $input $ctx.output_path $ctx.logs_path
    let result1 = $attempt1 | to json | nu (run_tool) | complete

    # Assert first attempt failed
    assert_exit_code $result1 1
    let response1 = $result1.stdout | from json
    assert_failure $response1

    # Capture feedback (the error message)
    let feedback = $response1.error

    # Simulate self-heal: Load correct tool
    let correct_code = load_fixture "tools" "echo-correct"
    let correct_path = create_temp_tool $correct_code "attempt-2"

    # Attempt 2: Execute correct tool
    let ctx2 = build_test_context  # New paths for second attempt
    let attempt2 = build_run_tool_input $correct_path $input $ctx2.output_path $ctx2.logs_path
    let result2 = $attempt2 | to json | nu (run_tool) | complete

    # Assert second attempt succeeded
    assert_completed_successfully $result2
    let response2 = $result2.stdout | from json
    assert_success $response2

    # Cleanup
    cleanup_temp_files
}
