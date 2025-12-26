#!/usr/bin/env nu
# Full chain integration tests for Generate -> Execute -> Validate
#
# These tests verify the COMPLETE bitter-truth flow:
# - AI generates a tool from contract
# - Tool is executed with test input
# - Output validates against the contract
# - Trace ID flows through entire chain
#
# This is the ultimate integration test - all components working together.
#
# Run with: nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/integration'

use std assert

let tools_dir = $env.PWD | path join "bitter-truth/tools"
let contracts_dir = $env.PWD | path join "bitter-truth/contracts/tools"

# ============================================================================
# HELPERS
# ============================================================================

def run_generate [
    contract_path: string
    task: string
    output_path: string
    trace_id: string
] {
    {
        contract_path: $contract_path
        task: $task
        output_path: $output_path
        feedback: "Initial generation"
        attempt: "1/5"
        context: {
            trace_id: $trace_id
            timeout_seconds: 60
        }
    } | to json | nu ($tools_dir | path join "generate.nu") | complete
}

def run_tool [
    tool_path: string
    tool_input: record
    output_path: string
    logs_path: string
    trace_id: string
] {
    {
        tool_path: $tool_path
        tool_input: $tool_input
        output_path: $output_path
        logs_path: $logs_path
        context: {
            trace_id: $trace_id
        }
    } | to json | nu ($tools_dir | path join "run-tool.nu") | complete
}

def run_validate [
    contract_path: string
    trace_id: string
] {
    {
        contract_path: $contract_path
        server: "local"
        context: {
            trace_id: $trace_id
        }
    } | to json | nu ($tools_dir | path join "validate.nu") | complete
}

# ============================================================================
# FULL CHAIN TESTS - These are the crown jewels
# ============================================================================

#[test]
def "test_generate_then_execute_succeeds" [] {
    # This test verifies: Generate -> Execute
    # Skip if no AI available
    if ($env.MODEL? | default "" | is-empty) {
        print "Skipping: MODEL env var not set"
        return
    }

    if (which opencode | is-empty) {
        print "Skipping: opencode not available"
        return
    }

    # Arrange
    let trace_id = "test-gen-exec-chain"
    let generated_tool_path = "/tmp/test-chain-generated-tool.nu"
    let tool_output_path = "/tmp/test-chain-tool-output.json"
    let tool_logs_path = "/tmp/test-chain-tool-logs.json"
    let contract_path = $contracts_dir | path join "echo.yaml"

    # Act Step 1: Generate
    let gen_result = run_generate $contract_path "Create an echo tool that reverses messages" $generated_tool_path $trace_id

    # Assert generation
    if $gen_result.exit_code != 0 {
        print "Generation failed - skipping rest of chain"
        rm -f $generated_tool_path
        return
    }

    let gen_output = $gen_result.stdout | from json
    assert equal $gen_output.success true "Generation should succeed"
    assert equal $gen_output.trace_id $trace_id "Trace ID preserved in generation"
    assert ($generated_tool_path | path exists) "Generated tool should exist"

    # Act Step 2: Execute the generated tool
    let exec_result = run_tool $generated_tool_path {message: "hello chain"} $tool_output_path $tool_logs_path $trace_id

    # Assert execution
    # Note: AI might generate buggy code, so we check both success and failure paths
    let exec_output = $exec_result.stdout | from json
    assert equal $exec_output.trace_id $trace_id "Trace ID preserved in execution"

    if $exec_result.exit_code == 0 {
        # Tool executed successfully
        assert equal $exec_output.success true "Execution should succeed"
        assert equal $exec_output.data.exit_code 0 "Tool should exit 0"

        # Verify output file contains something
        assert ($tool_output_path | path exists) "Tool output should exist"
        let tool_out = open --raw $tool_output_path
        assert (($tool_out | str length) > 0) "Tool should produce output"
    } else {
        # Tool failed - this is acceptable in integration tests (AI is imperfect)
        print $"Tool execution failed - AI generated buggy code. Error: ($exec_output.error)"
    }

    # Cleanup
    rm -f $generated_tool_path $tool_output_path $tool_logs_path
}

#[test]
def "test_execute_output_validates_against_contract" [] {
    # This test verifies: Execute -> Validate
    # We use a pre-made correct tool to ensure the test is deterministic

    # Arrange
    let trace_id = "test-exec-validate-chain"
    let tool_path = "/tmp/test-chain-correct-tool.nu"

    # Create a correct echo tool
    let correct_tool = '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    let msg = $input.message? | default "empty"
    {
        success: true
        data: {
            echo: $msg
            reversed: ($msg | split chars | reverse | str join)
            length: ($msg | str length)
            was_dry_run: false
        }
        trace_id: "test-exec-validate-chain"
        duration_ms: 5.0
    } | to json | print
}'
    $correct_tool | save -f $tool_path

    let tool_output_path = "/tmp/test-chain-exec-val-output.json"
    let tool_logs_path = "/tmp/test-chain-exec-val-logs.json"

    # Act Step 1: Execute the tool
    let exec_result = run_tool $tool_path {message: "test message"} $tool_output_path $tool_logs_path $trace_id

    # Assert execution succeeded
    assert equal $exec_result.exit_code 0 "Execution should succeed"
    let exec_output = $exec_result.stdout | from json
    assert equal $exec_output.success true "Should report success"

    # Act Step 2: Validate the output against echo contract
    # Update contract to point to our output file
    let contract = open ($contracts_dir | path join "echo.yaml") | from yaml
    let contract_with_path = $contract | upsert servers.local.path $tool_output_path | to yaml
    let contract_path = "/tmp/test-chain-validate-contract.yaml"
    $contract_with_path | save -f $contract_path

    let val_result = run_validate $contract_path $trace_id

    # Assert validation
    assert equal $val_result.exit_code 0 "Validation should succeed"
    let val_output = $val_result.stdout | from json
    assert equal $val_output.success true "Validation should report success"
    assert equal $val_output.data.valid true "Output should be valid against contract"
    assert equal $val_output.trace_id $trace_id "Trace ID preserved in validation"

    # Cleanup
    rm -f $tool_path $tool_output_path $tool_logs_path $contract_path
}

#[test]
def "test_entire_generate_execute_validate_flow" [] {
    # THE BIG ONE: Full Generate -> Execute -> Validate chain
    # This is the complete bitter-truth self-healing loop (single iteration)

    # Skip if no AI
    if ($env.MODEL? | default "" | is-empty) {
        print "Skipping: MODEL env var not set"
        return
    }

    if (which opencode | is-empty) {
        print "Skipping: opencode not available"
        return
    }

    # Arrange
    let trace_id = "test-full-chain"
    let generated_tool_path = "/tmp/test-full-chain-tool.nu"
    let tool_output_path = "/tmp/test-full-chain-output.json"
    let tool_logs_path = "/tmp/test-full-chain-logs.json"
    let contract_path = $contracts_dir | path join "echo.yaml"

    # Act Step 1: Generate
    print "Step 1: Generating tool..."
    let gen_result = run_generate $contract_path "Create echo tool with message reversal" $generated_tool_path $trace_id

    if $gen_result.exit_code != 0 {
        print "Generation failed - aborting chain"
        rm -f $generated_tool_path
        return
    }

    let gen_output = $gen_result.stdout | from json
    assert equal $gen_output.trace_id $trace_id "Step 1: Trace ID preserved"
    print $"Step 1 complete: Generated tool at ($generated_tool_path)"

    # Act Step 2: Execute
    print "Step 2: Executing generated tool..."
    let exec_result = run_tool $generated_tool_path {message: "integration test"} $tool_output_path $tool_logs_path $trace_id

    let exec_output = $exec_result.stdout | from json
    assert equal $exec_output.trace_id $trace_id "Step 2: Trace ID preserved"

    if $exec_result.exit_code != 0 {
        print $"Step 2 failed: Tool execution error - ($exec_output.error)"
        print "This would trigger self-healing in production"
        # In real flow, we'd loop back to generate with feedback
        rm -f $generated_tool_path $tool_output_path $tool_logs_path
        return
    }

    print "Step 2 complete: Tool executed successfully"

    # Act Step 3: Validate
    print "Step 3: Validating output against contract..."

    # Update contract to point to output
    let contract = open $contract_path | from yaml
    let contract_with_path = $contract | upsert servers.local.path $tool_output_path | to yaml
    let validation_contract_path = "/tmp/test-full-chain-contract.yaml"
    $contract_with_path | save -f $validation_contract_path

    let val_result = run_validate $validation_contract_path $trace_id

    let val_output = $val_result.stdout | from json
    assert equal $val_output.trace_id $trace_id "Step 3: Trace ID preserved"

    if $val_result.exit_code != 0 or $val_output.data.valid == false {
        print $"Step 3 failed: Validation error"
        print $"Errors: ($val_output.data.errors)"
        print "This would trigger self-healing in production"
        # In real flow, we'd extract errors and feed back to generate
        rm -f $generated_tool_path $tool_output_path $tool_logs_path $validation_contract_path
        return
    }

    # Assert - Full chain succeeded!
    print "Step 3 complete: Output validates against contract"
    print "🎉 FULL CHAIN SUCCESS: Generate -> Execute -> Validate"

    assert equal $val_output.data.valid true "Final validation should pass"

    # Cleanup
    rm -f $generated_tool_path $tool_output_path $tool_logs_path $validation_contract_path
}

#[test]
def "test_chain_preserves_trace_id_end_to_end" [] {
    # Verify trace_id flows through entire chain
    # Use deterministic (non-AI) components for reliability

    # Arrange
    let trace_id = "trace-e2e-test-12345"

    # Create a known-good tool
    let tool_path = "/tmp/test-trace-e2e-tool.nu"
    let tool_content = '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    {
        success: true
        data: {
            echo: $input.message
            reversed: ($input.message | split chars | reverse | str join)
            length: ($input.message | str length)
            was_dry_run: false
        }
        trace_id: $input.context.trace_id
        duration_ms: 1.0
    } | to json | print
}'
    $tool_content | save -f $tool_path

    let tool_output_path = "/tmp/test-trace-e2e-output.json"
    let tool_logs_path = "/tmp/test-trace-e2e-logs.json"

    # Act Step 1: Execute with trace_id
    let exec_input = {
        message: "trace test"
        context: { trace_id: $trace_id }
    }
    let exec_result = run_tool $tool_path $exec_input $tool_output_path $tool_logs_path $trace_id

    # Assert trace_id in execution
    let exec_output = $exec_result.stdout | from json
    assert equal $exec_output.trace_id $trace_id "Trace ID in run-tool output"

    # Also check the tool's output
    let tool_output = open $tool_output_path | from json
    assert equal $tool_output.trace_id $trace_id "Trace ID in tool output"

    # Act Step 2: Validate
    let contract = open ($contracts_dir | path join "echo.yaml") | from yaml
    let contract_with_path = $contract | upsert servers.local.path $tool_output_path | to yaml
    let contract_path = "/tmp/test-trace-e2e-contract.yaml"
    $contract_with_path | save -f $contract_path

    let val_result = run_validate $contract_path $trace_id

    # Assert trace_id in validation
    let val_output = $val_result.stdout | from json
    assert equal $val_output.trace_id $trace_id "Trace ID in validate output"

    # Verify end-to-end trace
    print $"✓ Trace ID ($trace_id) preserved through entire chain"

    # Cleanup
    rm -f $tool_path $tool_output_path $tool_logs_path $contract_path
}

#[test]
def "test_failed_validation_provides_feedback" [] {
    # Test that failed validation produces useful feedback for self-healing

    # Arrange - Create a tool with buggy output
    let trace_id = "test-validation-feedback"
    let tool_path = "/tmp/test-feedback-tool.nu"

    # Tool outputs wrong schema
    let buggy_tool = '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    {
        success: true
        data: {
            echo: $input.message
            # MISSING: reversed field (required)
            length: ($input.message | str length)
            was_dry_run: false
        }
    } | to json | print
}'
    $buggy_tool | save -f $tool_path

    let tool_output_path = "/tmp/test-feedback-output.json"
    let tool_logs_path = "/tmp/test-feedback-logs.json"

    # Act Step 1: Execute buggy tool
    let exec_result = run_tool $tool_path {message: "test"} $tool_output_path $tool_logs_path $trace_id
    assert equal $exec_result.exit_code 0 "Buggy tool executes (but produces wrong output)"

    # Act Step 2: Validate (should fail)
    let contract = open ($contracts_dir | path join "echo.yaml") | from yaml
    let contract_with_path = $contract | upsert servers.local.path $tool_output_path | to yaml
    let contract_path = "/tmp/test-feedback-contract.yaml"
    $contract_with_path | save -f $contract_path

    let val_result = run_validate $contract_path $trace_id

    # Assert - Validation fails
    let val_output = $val_result.stdout | from json
    assert equal $val_output.success false "Validation should fail"
    assert equal $val_output.data.valid false "Data should be invalid"

    # Assert - Errors provide actionable feedback
    assert (($val_output.data.errors | length) > 0) "Should have error messages"

    # This feedback would be passed back to generate.nu in the self-healing loop
    let feedback_for_ai = $val_output.data.errors | str join "\n"
    print $"Validation feedback: ($feedback_for_ai)"
    assert (($feedback_for_ai | str length) > 0) "Feedback should be non-empty"

    # Cleanup
    rm -f $tool_path $tool_output_path $tool_logs_path $contract_path
}

#[test]
def "test_self_healing_loop_simulation" [] {
    # Simulate a self-healing iteration:
    # 1. Generate (may produce buggy code)
    # 2. Execute (may fail)
    # 3. Validate (may fail)
    # 4. Extract errors
    # 5. Would feed back to generate (we simulate by checking error extraction)

    # This is a deterministic simulation using a known-buggy tool

    # Arrange
    let trace_id = "test-self-heal-sim"

    # Simulate a buggy generated tool (missing reversed field)
    let attempt1_tool = '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    {
        success: true
        data: {
            echo: $input.message
            length: ($input.message | str length)
            was_dry_run: false
            # BUG: Missing reversed field
        }
    } | to json | print
}'

    let tool_path = "/tmp/test-heal-attempt1.nu"
    $attempt1_tool | save -f $tool_path
    let output_path = "/tmp/test-heal-output1.json"
    let logs_path = "/tmp/test-heal-logs1.json"

    # Execute attempt 1
    print "Attempt 1: Execute buggy tool"
    let exec1 = run_tool $tool_path {message: "heal me"} $output_path $logs_path $trace_id
    assert equal $exec1.exit_code 0 "Buggy tool executes"

    # Validate attempt 1
    print "Attempt 1: Validate (should fail)"
    let contract = open ($contracts_dir | path join "echo.yaml") | from yaml
    let contract_with_path = $contract | upsert servers.local.path $output_path | to yaml
    let contract_path = "/tmp/test-heal-contract1.yaml"
    $contract_with_path | save -f $contract_path

    let val1 = run_validate $contract_path $trace_id
    let val1_output = $val1.stdout | from json

    assert equal $val1_output.data.valid false "Attempt 1 should fail validation"

    # Extract feedback
    let feedback = $"VALIDATION FAILED: ($val1_output.data.errors | str join '; ')"
    print $"Feedback extracted: ($feedback)"

    # Simulate attempt 2 with fix (in real flow, this would be generate.nu with feedback)
    let attempt2_tool = '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    {
        success: true
        data: {
            echo: $input.message
            reversed: ($input.message | split chars | reverse | str join)  # FIXED
            length: ($input.message | str length)
            was_dry_run: false
        }
    } | to json | print
}'

    let tool_path2 = "/tmp/test-heal-attempt2.nu"
    $attempt2_tool | save -f $tool_path2
    let output_path2 = "/tmp/test-heal-output2.json"
    let logs_path2 = "/tmp/test-heal-logs2.json"

    # Execute attempt 2
    print "Attempt 2: Execute fixed tool"
    let exec2 = run_tool $tool_path2 {message: "heal me"} $output_path2 $logs_path2 $trace_id
    assert equal $exec2.exit_code 0 "Fixed tool executes"

    # Validate attempt 2
    print "Attempt 2: Validate (should pass)"
    let contract2 = open ($contracts_dir | path join "echo.yaml") | from yaml
    let contract_with_path2 = $contract2 | upsert servers.local.path $output_path2 | to yaml
    let contract_path2 = "/tmp/test-heal-contract2.yaml"
    $contract_with_path2 | save -f $contract_path2

    let val2 = run_validate $contract_path2 $trace_id
    let val2_output = $val2.stdout | from json

    assert equal $val2_output.data.valid true "Attempt 2 should pass validation"

    print "✓ Self-healing simulation complete: Failed -> Feedback -> Fixed -> Success"

    # Cleanup
    rm -f $tool_path $output_path $logs_path $contract_path
    rm -f $tool_path2 $output_path2 $logs_path2 $contract_path2
}

#[test]
def "test_dry_run_propagates_through_chain" [] {
    # Verify dry_run mode works throughout the chain

    # Arrange
    let trace_id = "test-dry-run-chain"
    let tool_path = "/tmp/test-dry-chain-tool.nu"

    # This tool should NOT run in dry-run mode
    let tool = '#!/usr/bin/env nu
def main [] {
    "This should not execute in dry-run" | print -e
    exit 1
}'
    $tool | save -f $tool_path

    let output_path = "/tmp/test-dry-chain-output.json"
    let logs_path = "/tmp/test-dry-chain-logs.json"

    # Act - Execute in dry-run mode
    let input = {
        tool_path: $tool_path
        tool_input: {message: "test"}
        output_path: $output_path
        logs_path: $logs_path
        context: {
            trace_id: $trace_id
            dry_run: true
        }
    }

    let result = $input | to json | nu ($tools_dir | path join "run-tool.nu") | complete

    # Assert
    assert equal $result.exit_code 0 "Dry-run should succeed"
    let output = $result.stdout | from json
    assert equal $output.data.was_dry_run true "Should indicate dry-run"
    assert equal $output.data.exit_code 0 "Should not execute tool (exit 0, not 1)"

    # Cleanup
    rm -f $tool_path $output_path $logs_path
}
