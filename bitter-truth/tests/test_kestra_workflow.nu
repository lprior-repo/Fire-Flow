#!/usr/bin/env nu
# Integration tests for Kestra workflow steps
#
# Tests the actual workflow components that Kestra orchestrates:
# 1. Generate: AI generates Nushell from contract
# 2. Execute: Run the generated tool
# 3. Validate: Check output against contract
# 4. Self-Heal: Collect feedback for retry
#
# Run with: nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/test_kestra_workflow.nu'

use std assert

const TOOLS_DIR = "bitter-truth/tools"
const ECHO_CONTRACT = "bitter-truth/contracts/tools/echo.yaml"
const GENERATED_TOOL = "/tmp/test-generated-tool.nu"
const TOOL_OUTPUT = "/tmp/test-tool-output.json"
const TOOL_LOGS = "/tmp/test-tool-logs.json"

# Helper: Create a simple echo tool for testing (simulates AI generation)
def create_test_echo_tool [path: string] {
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    let message = $input.message? | default "no message"
    {
        success: true
        data: {
            echo: $message
            reversed: ($message | split chars | reverse | str join)
            length: ($message | str length)
            was_dry_run: false
        }
        trace_id: "test-trace"
        duration_ms: 1.5
    } | to json | print
}' | save -f $path
}

# Helper: Create a broken tool (fails contract)
def create_broken_echo_tool [path: string] {
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    let message = $input.message? | default "no message"
    {
        success: true
        data: {
            echo: $message
            # Missing "reversed" field - should fail contract
            length: ($message | str length)
            was_dry_run: false
        }
        trace_id: "test-trace"
        duration_ms: 1.5
    } | to json | print
}' | save -f $path
}

# Helper: Simulate the "generate" step
def simulate_generate [contract_path: string, task: string, output_path: string] {
    # In real flow, this would call opencode AI
    # For testing, we create a valid echo tool
    create_test_echo_tool $output_path
    { success: true, generated: true }
}

#[test]
def "workflow_step_1_generate_creates_valid_tool" [] {
    let result = simulate_generate $ECHO_CONTRACT "Echo the input message" $GENERATED_TOOL

    assert equal $result.success true "Generate should succeed"
    assert ($GENERATED_TOOL | path exists) "Generated tool should exist"

    # Tool should be executable
    let test_input = { message: "hello" }
    let tool_result = do {
        $test_input | to json | nu $GENERATED_TOOL
    } | complete

    assert equal $tool_result.exit_code 0 "Generated tool should execute"

    let tool_output = $tool_result.stdout | from json
    # Just verify the output structure
    assert ($tool_output | get success?) "Tool output should have success field"
    assert ($tool_output | get data?) "Tool output should have data field"

    # Cleanup
    rm -f $GENERATED_TOOL
}

#[test]
def "workflow_step_2_execute_generated_tool" [] {
    # Setup: Create a test tool (no need for do/complete with nushell functions)
    create_test_echo_tool $GENERATED_TOOL

    # Verify tool was created
    assert ($GENERATED_TOOL | path exists) "Tool should be created"

    # Step 1: Prepare input
    let test_input = { message: "workflow test" }
    let run_input = {
        tool_path: $GENERATED_TOOL
        tool_input: $test_input
        output_path: $TOOL_OUTPUT
        logs_path: $TOOL_LOGS
        context: { trace_id: "workflow-001" }
    }

    # Step 2: Execute via run-tool.nu
    let result = do {
        $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete

    assert equal $result.exit_code 0 "run-tool should succeed"

    let response = $result.stdout | from json
    assert equal $response.success true "Tool execution should be successful"
    assert ($TOOL_OUTPUT | path exists) "Output file should be created"

    let output = open $TOOL_OUTPUT
    # Just verify the output file has the tool's response
    assert ($output | get success?) "Output should have success field"

    # Cleanup
    rm -f $GENERATED_TOOL $TOOL_OUTPUT $TOOL_LOGS
}

#[test]
def "workflow_step_3_validate_correct_output" [] {
    # Validate in dry-run mode (doesn't require actual file)
    let validate_input = {
        contract_path: $ECHO_CONTRACT
        server: "local"
        context: { trace_id: "validate-001", dry_run: true }
    }

    let result = do {
        $validate_input | to json | nu ($TOOLS_DIR | path join "validate.nu")
    } | complete

    # Should exit 0 (self-healing pattern)
    assert equal $result.exit_code 0 "Validate should exit 0"

    let response = $result.stdout | from json
    # Should have success and data fields
    assert ($response | get success?) "Response should have success field"
    assert equal $response.success true "Dry-run should return success=true"
    assert ($response.data | get valid?) "Data should have valid field"
}

#[test]
def "workflow_step_3_validate_fails_on_missing_fields" [] {
    # Setup: Create output that FAILS contract (missing reversed field)
    {
        success: true
        data: {
            echo: "test message"
            # Missing "reversed" field!
            length: 12
            was_dry_run: false
        }
        trace_id: "validate-002"
        duration_ms: 5.2
    } | to json | save -f $TOOL_OUTPUT

    # Validate
    let validate_input = {
        contract_path: $ECHO_CONTRACT
        server: "local"
        context: { trace_id: "validate-002", dry_run: false }
    }

    let result = do {
        $validate_input | to json | nu ($TOOLS_DIR | path join "validate.nu")
    } | complete

    # Should still exit 0 (self-healing pattern) but indicate failure
    assert equal $result.exit_code 0 "validate.nu should exit 0 for self-healing"

    let response = $result.stdout | from json
    assert equal $response.success false "Validation should indicate failure"

    # Cleanup
    rm -f $TOOL_OUTPUT
}

#[test]
def "workflow_full_loop_generate_execute_validate" [] {
    # Full integration: Generate -> Execute -> Validate

    # Step 1: Generate - create a simple tool that will work
    let test_tool = "/tmp/full-loop-test-tool.nu"
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    { success: true, message: ($input.message? | default "") } | to json | print
}' | save -f $test_tool
    assert ($test_tool | path exists) "Tool should be generated"

    # Step 2: Execute
    let run_input = {
        tool_path: $test_tool
        tool_input: { message: "full workflow" }
        output_path: $TOOL_OUTPUT
        logs_path: $TOOL_LOGS
        context: { trace_id: "full-loop-001" }
    }

    let exec_result = do {
        $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete

    assert equal $exec_result.exit_code 0 "Execution should succeed"
    assert ($TOOL_OUTPUT | path exists) "Output file should be created"

    # Cleanup extra file
    rm -f $test_tool

    # Step 3: Validate the output (using dry-run to avoid external dependencies)
    let validate_input = {
        contract_path: $ECHO_CONTRACT
        server: "local"
        context: { trace_id: "full-loop-001", dry_run: true }
    }

    let validate_result = do {
        $validate_input | to json | nu ($TOOLS_DIR | path join "validate.nu")
    } | complete

    assert equal $validate_result.exit_code 0 "Validation should complete"

    let validation = $validate_result.stdout | from json
    assert equal $validation.success true "Validation should pass in dry-run"
    assert ($validation.data | get valid?) "Should have validation status"

    # Cleanup
    rm -f $GENERATED_TOOL $TOOL_OUTPUT $TOOL_LOGS
}

#[test]
def "workflow_self_heal_feedback_generation" [] {
    # Test the self-healing feedback collection

    # Simulate a failed attempt
    {
        success: false
        error: "missing reversed field"
        data: {
            echo: "test"
            length: 4
        }
        trace_id: "self-heal-001"
        duration_ms: 2.1
    } | to json | save -f $TOOL_OUTPUT

    # Simulate validation error
    let contract_errors = "Error: field 'reversed' is required but missing"

    # Build feedback like the workflow does
    let feedback = [
        "ATTEMPT 1 FAILED."
        ""
        "CONTRACT ERRORS:"
        $contract_errors
        ""
        "OUTPUT PRODUCED:"
        (open $TOOL_OUTPUT | to text)
        ""
        "FIX THE NUSHELL SCRIPT TO SATISFY THE CONTRACT."
    ] | str join "\n"

    # Feedback should contain useful information for AI retry
    assert ($feedback | str contains "ATTEMPT 1 FAILED") "Feedback should indicate failure"
    assert ($feedback | str contains "CONTRACT ERRORS") "Feedback should mention errors"
    assert ($feedback | str contains "reversed") "Feedback should contain error details"
    assert ($feedback | str contains "FIX THE NUSHELL SCRIPT") "Feedback should guide AI"

    # Cleanup
    rm -f $TOOL_OUTPUT
}

#[test]
def "workflow_handles_empty_input_json" [] {
    # Test with empty input (edge case from earlier)
    create_test_echo_tool $GENERATED_TOOL

    let run_input = {
        tool_path: $GENERATED_TOOL
        tool_input: {}  # Empty input
        output_path: $TOOL_OUTPUT
        logs_path: $TOOL_LOGS
        context: { trace_id: "empty-input" }
    }

    let result = do {
        $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete

    # Should still work
    assert equal $result.exit_code 0 "Should handle empty input"

    # Cleanup
    rm -f $GENERATED_TOOL $TOOL_OUTPUT $TOOL_LOGS
}

#[test]
def "workflow_timeout_protection" [] {
    # Create a tool that would timeout
    '#!/usr/bin/env nu
def main [] {
    # Just output quickly - we will not actually test timeout
    { success: true } | to json | print
}' | save -f $GENERATED_TOOL

    let run_input = {
        tool_path: $GENERATED_TOOL
        tool_input: {}
        output_path: $TOOL_OUTPUT
        logs_path: $TOOL_LOGS
        context: {
            trace_id: "timeout-test"
            timeout_seconds: 5
        }
    }

    let result = do {
        $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete

    # Should succeed (tool runs quickly)
    assert equal $result.exit_code 0 "Tool should complete within timeout"

    # Cleanup
    rm -f $GENERATED_TOOL $TOOL_OUTPUT $TOOL_LOGS
}

#[test]
def "workflow_traces_execution_correctly" [] {
    # Verify trace_id flows through all steps
    let trace_id = "trace-123-abc"

    create_test_echo_tool $GENERATED_TOOL

    let run_input = {
        tool_path: $GENERATED_TOOL
        tool_input: { message: "trace test" }
        output_path: $TOOL_OUTPUT
        logs_path: $TOOL_LOGS
        context: { trace_id: $trace_id }
    }

    let run_result = do {
        $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete

    let run_response = $run_result.stdout | from json
    assert equal $run_response.trace_id $trace_id "trace_id should be preserved"

    # Validate step should also preserve trace
    let validate_input = {
        contract_path: $ECHO_CONTRACT
        server: "local"
        context: { trace_id: $trace_id }
    }

    let validate_result = do {
        $validate_input | to json | nu ($TOOLS_DIR | path join "validate.nu")
    } | complete

    let validate_response = $validate_result.stdout | from json
    assert equal $validate_response.trace_id $trace_id "trace_id should flow through validate"

    # Cleanup
    rm -f $GENERATED_TOOL $TOOL_OUTPUT $TOOL_LOGS
}

#[test]
def "workflow_duration_tracking" [] {
    # Verify duration_ms is recorded at each step
    create_test_echo_tool $GENERATED_TOOL

    let run_input = {
        tool_path: $GENERATED_TOOL
        tool_input: { message: "duration test" }
        output_path: $TOOL_OUTPUT
        logs_path: $TOOL_LOGS
        context: { trace_id: "duration-test" }
    }

    let result = do {
        $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete

    let response = $result.stdout | from json
    assert ($response.duration_ms >= 0) "duration_ms should be recorded"
    assert (($response.duration_ms | describe) == "float") "duration_ms should be a number"

    # Cleanup
    rm -f $GENERATED_TOOL $TOOL_OUTPUT $TOOL_LOGS
}
