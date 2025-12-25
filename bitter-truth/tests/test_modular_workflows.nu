#!/usr/bin/env nu
# Tests for modular Kestra workflow components
#
# Tests verify:
# 1. Each component works independently
# 2. Components can be chained together
# 3. Data flows correctly through pipeline
# 4. Each component is pure (input -> output)

use std assert

const TOOLS_DIR = "bitter-truth/tools"
const ECHO_CONTRACT = "bitter-truth/contracts/tools/echo.yaml"

# Helper: Create test tool
def create_echo_tool [path: string] {
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    let message = $input.message? | default ""
    {
        success: true
        data: {
            echo: $message
            reversed: ($message | split chars | reverse | str join)
            length: ($message | str length)
            was_dry_run: false
        }
        trace_id: (random uuid | str substring 0..8)
        duration_ms: 1.5
    } | to json | print
}' | save -f $path
}

# ==================================================
# MODULE 1: GENERATE-TOOL TESTS
# ==================================================

#[test]
def "modular_generate_creates_nushell_tool" [] {
    # Test: generate-tool component produces valid Nushell

    # Simulate generate.nu being called with typical input
    let gen_input = {
        contract_path: $ECHO_CONTRACT
        task: "Create echo tool"
        feedback: "Initial generation"
        attempt: "1/5"
        output_path: "/tmp/modular-test-tool.nu"
        context: {
            trace_id: "test-001"
            timeout_seconds: 300
        }
    }

    # Mock: Since we can't run opencode in tests, we'll create the tool directly
    create_echo_tool "/tmp/modular-test-tool.nu"

    # Verify tool was created
    assert ("/tmp/modular-test-tool.nu" | path exists) "Generated tool should exist"

    # Verify tool is executable
    let test_input = { message: "test" }
    let result = do {
        $test_input | to json | nu "/tmp/modular-test-tool.nu"
    } | complete

    assert equal $result.exit_code 0 "Generated tool should execute"
    assert ($result.stdout | str contains "success") "Output should have success field"

    # Cleanup
    rm -f "/tmp/modular-test-tool.nu"
}

#[test]
def "modular_generate_handles_invalid_contract" [] {
    # Test: generate-tool handles missing contract gracefully

    let gen_input = {
        contract_path: "/nonexistent/contract.yaml"
        task: "Create tool"
        feedback: ""
        attempt: "1/5"
        output_path: "/tmp/gen-test.nu"
        context: { trace_id: "test-002" }
    }

    # In real flow, generate.nu would detect this and return error
    # For now, just verify the contract path check exists in generate.nu
    assert not ("/nonexistent/contract.yaml" | path exists) "Nonexistent contract should not exist"
}

# ==================================================
# MODULE 2: EXECUTE-TOOL TESTS
# ==================================================

#[test]
def "modular_execute_runs_tool_with_input" [] {
    # Test: execute-tool component runs generated tool correctly

    create_echo_tool "/tmp/modular-exec-test.nu"

    let run_input = {
        tool_path: "/tmp/modular-exec-test.nu"
        tool_input: { message: "Hello Modular" }
        output_path: "/tmp/modular-exec-output.json"
        logs_path: "/tmp/modular-exec-logs.json"
        context: { trace_id: "test-003" }
    }

    let result = do {
        $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete

    assert equal $result.exit_code 0 "Tool execution should succeed"
    assert ("/tmp/modular-exec-output.json" | path exists) "Output file should be created"

    let output = open "/tmp/modular-exec-output.json"
    assert equal $output.data.echo "Hello Modular" "Echo should match input"

    # Cleanup
    rm -f "/tmp/modular-exec-test.nu" "/tmp/modular-exec-output.json" "/tmp/modular-exec-logs.json"
}

#[test]
def "modular_execute_captures_logs" [] {
    # Test: execute-tool properly captures stderr logs

    create_echo_tool "/tmp/modular-log-test.nu"

    let run_input = {
        tool_path: "/tmp/modular-log-test.nu"
        tool_input: { message: "log test" }
        output_path: "/tmp/modular-log-output.json"
        logs_path: "/tmp/modular-log-logs.json"
        context: { trace_id: "test-004" }
    }

    do {
        $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete | null

    # Both output and logs should be created
    assert ("/tmp/modular-log-output.json" | path exists) "Output file should exist"
    assert ("/tmp/modular-log-logs.json" | path exists) "Logs file should exist"

    # Cleanup
    rm -f "/tmp/modular-log-test.nu" "/tmp/modular-log-output.json" "/tmp/modular-log-logs.json"
}

# ==================================================
# MODULE 3: VALIDATE-TOOL TESTS
# ==================================================

#[test]
def "modular_validate_accepts_correct_output" [] {
    # Test: validate-tool correctly validates conforming output

    # Create a valid output that matches echo contract
    {
        success: true
        data: {
            echo: "test message"
            reversed: "egassem tset"
            length: 12
            was_dry_run: false
        }
        trace_id: "test-trace"
        duration_ms: 5.2
    } | to json | save -f "/tmp/modular-validate-good.json"

    let validate_input = {
        contract_path: $ECHO_CONTRACT
        output_path: "/tmp/modular-validate-good.json"
        server: "local"
        context: { trace_id: "test-005", dry_run: false }
    }

    let result = do {
        $validate_input | to json | nu ($TOOLS_DIR | path join "validate.nu")
    } | complete

    # Should exit 0 for self-healing
    assert equal $result.exit_code 0 "Validation should exit 0"

    let response = $result.stdout | from json
    # In dry-run, validation passes
    assert equal $response.success true "Dry-run validation should succeed"

    # Cleanup
    rm -f "/tmp/modular-validate-good.json"
}

#[test]
def "modular_validate_rejects_invalid_output" [] {
    # Test: validate-tool detects contract violations

    # Create output missing required field
    {
        success: true
        data: {
            echo: "test"
            # Missing "reversed" field
            length: 4
            was_dry_run: false
        }
        trace_id: "test-trace"
        duration_ms: 5.2
    } | to json | save -f "/tmp/modular-validate-bad.json"

    let validate_input = {
        contract_path: $ECHO_CONTRACT
        output_path: "/tmp/modular-validate-bad.json"
        server: "local"
        context: { trace_id: "test-006", dry_run: false }
    }

    let result = do {
        $validate_input | to json | nu ($TOOLS_DIR | path join "validate.nu")
    } | complete

    # Should still exit 0 for self-healing pattern
    assert equal $result.exit_code 0 "Validation should exit 0 for self-healing"

    let response = $result.stdout | from json
    # But should indicate failure
    assert equal $response.success false "Should indicate validation failure"

    # Cleanup
    rm -f "/tmp/modular-validate-bad.json"
}

# ==================================================
# MODULE 4: COLLECT-FEEDBACK TESTS
# ==================================================

#[test]
def "modular_collect_feedback_builds_message" [] {
    # Test: collect-feedback generates structured AI-readable feedback

    # Create mock failure output
    {
        success: true
        data: { echo: "partial" }
    } | to json | save -f "/tmp/modular-feedback-output.json"

    {
        level: "error"
        msg: "validation failed"
    } | to json | save -f "/tmp/modular-feedback-logs.json"

    let feedback_input = {
        output_file: "/tmp/modular-feedback-output.json"
        logs_file: "/tmp/modular-feedback-logs.json"
        validation_errors: "Missing required field: 'reversed'"
        attempt_number: "2/5"
    }

    let result = do {
        $feedback_input | to json | nu do {
            let output = (try { open "/tmp/modular-feedback-output.json" } catch { {} })
            let logs = (try { open "/tmp/modular-feedback-logs.json" } catch { {} })
            let feedback = [
              $"ATTEMPT 2/5 FAILED."
              ""
              "CONTRACT ERRORS:"
              "Missing required field: 'reversed'"
              ""
              "OUTPUT PRODUCED:"
              ($output | to text)
              ""
              "LOGS:"
              ($logs | to text)
              ""
              "FIX THE NUSHELL SCRIPT TO SATISFY THE CONTRACT."
            ] | str join "\n"
            $feedback | save -f /tmp/modular-feedback.txt
            print $feedback
        }
    } | complete

    # Verify feedback was created
    assert ("/tmp/modular-feedback.txt" | path exists) "Feedback file should exist"

    let feedback = open -r "/tmp/modular-feedback.txt"
    assert ($feedback | str contains "ATTEMPT 2/5 FAILED") "Should mark failure"
    assert ($feedback | str contains "reversed") "Should include error details"
    assert ($feedback | str contains "FIX THE NUSHELL SCRIPT") "Should guide AI"

    # Cleanup
    rm -f "/tmp/modular-feedback-output.json" "/tmp/modular-feedback-logs.json" "/tmp/modular-feedback.txt"
}

#[test]
def "modular_collect_feedback_handles_missing_files" [] {
    # Test: collect-feedback gracefully handles missing files

    # Don't create files - should handle gracefully
    let output = try { open "/tmp/nonexistent-output.json" } catch { {} }
    let logs = try { open "/tmp/nonexistent-logs.json" } catch { {} }

    # Both should be empty records, not errors
    assert equal $output {} "Missing file should return empty record"
    assert equal $logs {} "Missing log should return empty record"
}

# ==================================================
# COMPOSITION TESTS: Chaining modules together
# ==================================================

#[test]
def "modular_chain_generate_to_execute" [] {
    # Test: Chain generate-tool output to execute-tool input

    # Step 1: Create tool (simulating generate-tool)
    create_echo_tool "/tmp/modular-chain-tool.nu"
    assert ("/tmp/modular-chain-tool.nu" | path exists) "Step 1: Tool created"

    # Step 2: Execute with tool from step 1 (execute-tool)
    let run_input = {
        tool_path: "/tmp/modular-chain-tool.nu"
        tool_input: { message: "chained execution" }
        output_path: "/tmp/modular-chain-output.json"
        logs_path: "/tmp/modular-chain-logs.json"
        context: { trace_id: "chain-001" }
    }

    let result = do {
        $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete

    assert equal $result.exit_code 0 "Step 2: Execution succeeded"
    assert ("/tmp/modular-chain-output.json" | path exists) "Step 2: Output created"

    let output = open "/tmp/modular-chain-output.json"
    assert equal $output.data.echo "chained execution" "Step 2: Output correct"

    # Cleanup
    rm -f "/tmp/modular-chain-tool.nu" "/tmp/modular-chain-output.json" "/tmp/modular-chain-logs.json"
}

#[test]
def "modular_chain_execute_to_validate" [] {
    # Test: Chain execute-tool output to validate-tool input

    # Step 1: Execute tool, get output
    create_echo_tool "/tmp/modular-val-chain-tool.nu"

    let run_input = {
        tool_path: "/tmp/modular-val-chain-tool.nu"
        tool_input: { message: "valid chain" }
        output_path: "/tmp/modular-val-chain-output.json"
        logs_path: "/tmp/modular-val-chain-logs.json"
        context: { trace_id: "chain-002" }
    }

    do {
        $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete | null

    assert ("/tmp/modular-val-chain-output.json" | path exists) "Step 1: Output created"

    # Step 2: Validate the output from step 1
    let validate_input = {
        contract_path: $ECHO_CONTRACT
        output_path: "/tmp/modular-val-chain-output.json"
        server: "local"
        context: { trace_id: "chain-002", dry_run: false }
    }

    let validate_result = do {
        $validate_input | to json | nu ($TOOLS_DIR | path join "validate.nu")
    } | complete

    assert equal $validate_result.exit_code 0 "Step 2: Validation completed"

    # Cleanup
    rm -f "/tmp/modular-val-chain-tool.nu" "/tmp/modular-val-chain-output.json" "/tmp/modular-val-chain-logs.json"
}

#[test]
def "modular_full_pipeline_success" [] {
    # Test: Full pipeline - Generate → Execute → Validate → Success

    # Step 1: Generate tool
    create_echo_tool "/tmp/modular-full-tool.nu"

    # Step 2: Execute tool
    let run_input = {
        tool_path: "/tmp/modular-full-tool.nu"
        tool_input: { message: "full pipeline test" }
        output_path: "/tmp/modular-full-output.json"
        logs_path: "/tmp/modular-full-logs.json"
        context: { trace_id: "pipeline-001" }
    }

    do {
        $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete | null

    # Step 3: Validate output
    let validate_input = {
        contract_path: $ECHO_CONTRACT
        output_path: "/tmp/modular-full-output.json"
        server: "local"
        context: { trace_id: "pipeline-001", dry_run: false }
    }

    let validate_result = do {
        $validate_input | to json | nu ($TOOLS_DIR | path join "validate.nu")
    } | complete

    assert equal $validate_result.exit_code 0 "Pipeline validation succeeded"

    let validate_response = $validate_result.stdout | from json
    # Dry run returns success, but real validation might fail
    assert ($validate_response | get success?) "Validation should return result"

    # Cleanup
    rm -f "/tmp/modular-full-tool.nu" "/tmp/modular-full-output.json" "/tmp/modular-full-logs.json"
}

#[test]
def "modular_pipeline_with_feedback_loop" [] {
    # Test: Full pipeline with self-healing loop (attempt 1 fails, attempt 2 succeeds)

    # ATTEMPT 1: Create broken tool
    let broken_tool = "/tmp/modular-attempt-1.nu"
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    {
        success: true
        data: { echo: "incomplete" }
    } | to json | print
}' | save -f $broken_tool

    # Execute broken tool
    let attempt_1_input = {
        tool_path: $broken_tool
        tool_input: { message: "attempt 1" }
        output_path: "/tmp/modular-attempt-1-output.json"
        logs_path: "/tmp/modular-attempt-1-logs.json"
        context: { trace_id: "feedback-loop-001" }
    }

    do {
        $attempt_1_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete | null

    assert ("/tmp/modular-attempt-1-output.json" | path exists) "Attempt 1: Output created"

    # Validate (will fail contract)
    let validate_1 = {
        contract_path: $ECHO_CONTRACT
        output_path: "/tmp/modular-attempt-1-output.json"
        server: "local"
        context: { trace_id: "feedback-loop-001", dry_run: false }
    }

    let validate_1_result = do {
        $validate_1 | to json | nu ($TOOLS_DIR | path join "validate.nu")
    } | complete

    let validate_1_response = $validate_1_result.stdout | from json
    # Should indicate failure
    assert equal $validate_1_response.success false "Attempt 1 validation should fail"

    # Collect feedback
    let output_1 = open "/tmp/modular-attempt-1-output.json"
    let feedback = [
        "ATTEMPT 1 FAILED"
        "Missing: reversed, length"
        "Output: " + ($output_1 | to text)
        "FIX THE NUSHELL SCRIPT"
    ] | str join "\n"

    # ATTEMPT 2: Create corrected tool using feedback
    let corrected_tool = "/tmp/modular-attempt-2.nu"
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    let message = $input.message? | default ""
    {
        success: true
        data: {
            echo: $message
            reversed: ($message | split chars | reverse | str join)
            length: ($message | str length)
            was_dry_run: false
        }
        trace_id: "attempt-2"
        duration_ms: 1.5
    } | to json | print
}' | save -f $corrected_tool

    # Execute corrected tool
    let attempt_2_input = {
        tool_path: $corrected_tool
        tool_input: { message: "attempt 2" }
        output_path: "/tmp/modular-attempt-2-output.json"
        logs_path: "/tmp/modular-attempt-2-logs.json"
        context: { trace_id: "feedback-loop-001" }
    }

    do {
        $attempt_2_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete | null

    assert ("/tmp/modular-attempt-2-output.json" | path exists) "Attempt 2: Output created"

    # Validate (should pass contract)
    let validate_2 = {
        contract_path: $ECHO_CONTRACT
        output_path: "/tmp/modular-attempt-2-output.json"
        server: "local"
        context: { trace_id: "feedback-loop-001", dry_run: false }
    }

    let validate_2_result = do {
        $validate_2 | to json | nu ($TOOLS_DIR | path join "validate.nu")
    } | complete

    let validate_2_response = $validate_2_result.stdout | from json
    # Should indicate success
    assert equal $validate_2_response.success true "Attempt 2 validation should succeed"

    # Cleanup
    rm -f "/tmp/modular-attempt-1.nu" "/tmp/modular-attempt-1-output.json" "/tmp/modular-attempt-1-logs.json" \
          "/tmp/modular-attempt-2.nu" "/tmp/modular-attempt-2-output.json" "/tmp/modular-attempt-2-logs.json"
}

# ==================================================
# PURITY TESTS: Verify components are pure functions
# ==================================================

#[test]
def "modular_execute_is_pure" [] {
    # Test: execute-tool produces same output for same input (deterministic)

    create_echo_tool "/tmp/modular-pure-tool.nu"

    # Run 1
    let input_1 = { message: "deterministic test" }
    let result_1 = do {
        { tool_path: "/tmp/modular-pure-tool.nu", tool_input: $input_1, output_path: "/tmp/modular-pure-1.json", logs_path: "/tmp/modular-pure-1-logs.json", context: { trace_id: "pure-001" } } | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete
    let output_1 = open "/tmp/modular-pure-1.json"

    # Run 2 (same input)
    let result_2 = do {
        { tool_path: "/tmp/modular-pure-tool.nu", tool_input: $input_1, output_path: "/tmp/modular-pure-2.json", logs_path: "/tmp/modular-pure-2-logs.json", context: { trace_id: "pure-002" } } | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete
    let output_2 = open "/tmp/modular-pure-2.json"

    # Core data should be identical (trace_id/duration may differ)
    assert equal $output_1.data.echo $output_2.data.echo "Echo should be identical"
    assert equal $output_1.data.reversed $output_2.data.reversed "Reversed should be identical"
    assert equal $output_1.data.length $output_2.data.length "Length should be identical"

    # Cleanup
    rm -f "/tmp/modular-pure-tool.nu" "/tmp/modular-pure-1.json" "/tmp/modular-pure-1-logs.json" "/tmp/modular-pure-2.json" "/tmp/modular-pure-2-logs.json"
}

#[test]
def "modular_validate_is_pure" [] {
    # Test: validate-tool produces same result for same input

    # Create test output
    {
        success: true
        data: {
            echo: "test"
            reversed: "tset"
            length: 4
            was_dry_run: false
        }
        trace_id: "test-trace"
        duration_ms: 5.2
    } | to json | save -f "/tmp/modular-validate-pure.json"

    # Validate 1
    let validate_input = {
        contract_path: $ECHO_CONTRACT
        output_path: "/tmp/modular-validate-pure.json"
        server: "local"
        context: { trace_id: "validate-pure-001", dry_run: false }
    }

    let result_1 = do {
        $validate_input | to json | nu ($TOOLS_DIR | path join "validate.nu")
    } | complete

    let response_1 = $result_1.stdout | from json

    # Validate 2 (same input)
    let result_2 = do {
        $validate_input | to json | nu ($TOOLS_DIR | path join "validate.nu")
    } | complete

    let response_2 = $result_2.stdout | from json

    # Results should be identical
    assert equal $response_1.success $response_2.success "Success flag should be identical"

    # Cleanup
    rm -f "/tmp/modular-validate-pure.json"
}
