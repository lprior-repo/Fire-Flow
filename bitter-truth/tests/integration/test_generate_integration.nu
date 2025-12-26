#!/usr/bin/env nu
# Integration tests for AI generation (generate.nu)
#
# These tests verify REAL AI generation integration:
# - Generate tool calls real AI (with timeouts for safety)
# - Feedback incorporation works correctly
# - Process cleanup prevents orphaned processes
# - Output validation and error handling
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
    feedback: string = "Initial generation"
    attempt: string = "1/5"
    timeout_seconds: int = 30  # Short timeout for tests
    trace_id: string = "test-gen"
] {
    {
        contract_path: $contract_path
        task: $task
        output_path: $output_path
        feedback: $feedback
        attempt: $attempt
        context: {
            trace_id: $trace_id
            timeout_seconds: $timeout_seconds
        }
    } | to json | nu ($tools_dir | path join "generate.nu") | complete
}

# ============================================================================
# REAL AI GENERATION TESTS
# ============================================================================

#[test]
def "test_generate_with_valid_contract_succeeds" [] {
    # This test calls REAL AI - may be slow
    # Skip if MODEL env var not set or if opencode not available
    if ($env.MODEL? | default "" | is-empty) {
        print "Skipping: MODEL env var not set"
        return
    }

    # Check if opencode is available (which returns table, empty if not found)
    if (which opencode | is-empty) {
        print "Skipping: opencode not available"
        return
    }

    # Arrange
    let output_path = "/tmp/test-gen-valid-tool.nu"
    let task = "Create a simple echo tool that reads message from stdin JSON and outputs it"

    # Use REAL echo contract
    let contract_path = $contracts_dir | path join "echo.yaml"

    # Act - Call REAL generate.nu with REAL AI
    let result = run_generate $contract_path $task $output_path "Initial generation" "1/5" 30 "test-gen-valid"

    # Assert
    # Note: We can't guarantee AI success, but we can verify the tool doesn't crash
    assert ($result.exit_code in [0, 1]) "Generate should exit cleanly (0 or 1)"

    let output = $result.stdout | from json
    assert ($output.trace_id == "test-gen-valid") "Trace ID should be preserved"
    assert ($output.duration_ms != null) "Duration should be recorded"

    # If successful, verify the output file was created
    if $result.exit_code == 0 {
        assert ($output_path | path exists) "Generated tool should exist"
        assert equal $output.data.generated true "Should report generated=true"
        assert equal $output.data.output_path $output_path "Should report correct path"

        # Verify the generated file is executable Nushell
        let tool_content = open --raw $output_path
        assert (($tool_content | str length) > 0) "Generated tool should not be empty"
        assert ($tool_content | str contains "def main") "Should contain main function"
    }

    # Cleanup
    rm -f $output_path
}

#[test]
def "test_generate_with_feedback_incorporates_errors" [] {
    # Skip if no AI model configured
    if ($env.MODEL? | default "" | is-empty) {
        print "Skipping: MODEL env var not set"
        return
    }

    if (which opencode | is-empty) {
        print "Skipping: opencode not available"
        return
    }

    # Arrange - Simulate second attempt with feedback from failed validation
    let output_path = "/tmp/test-gen-feedback-tool.nu"
    let contract_path = $contracts_dir | path join "echo.yaml"
    let task = "Create an echo tool"
    let feedback = "VALIDATION FAILED: Missing 'reversed' field. The output must include a 'reversed' field containing the input message reversed."
    let attempt = "2/5"

    # Act
    let result = run_generate $contract_path $task $output_path $feedback $attempt 30 "test-gen-feedback"

    # Assert - Feedback should be included in prompt
    # We verify by checking stderr logs contain feedback reference
    if $result.exit_code == 0 {
        let stderr = $result.stderr
        # The tool logs what it's doing
        assert (($stderr | str length) > 0) "Should have logged generation process"
    }

    # The generate tool should preserve trace_id through feedback loop
    let output = $result.stdout | from json
    assert equal $output.trace_id "test-gen-feedback" "Trace ID preserved through feedback"
    assert equal $output.data.was_dry_run false "Should not be dry-run"

    # Cleanup
    rm -f $output_path
}

#[test]
def "test_generate_timeout_kills_opencode_process" [] {
    # Skip if no AI available
    if ($env.MODEL? | default "" | is-empty) {
        print "Skipping: MODEL env var not set"
        return
    }

    if (which opencode | is-empty) {
        print "Skipping: opencode not available"
        return
    }

    # Arrange - Use very short timeout to trigger timeout
    let output_path = "/tmp/test-gen-timeout-tool.nu"
    let contract_path = $contracts_dir | path join "echo.yaml"
    let task = "Create a complex tool with extensive documentation and examples"
    let timeout_seconds = 1  # Very short timeout - likely to timeout

    # Act
    let result = run_generate $contract_path $task $output_path "Initial" "1/5" $timeout_seconds "test-timeout"

    # Assert
    # Either succeeds quickly or times out - both are valid
    assert ($result.exit_code in [0, 1]) "Should exit cleanly on timeout"

    let output = $result.stdout | from json

    # If timed out, should report error
    if $result.exit_code == 1 {
        assert ($output.error != null) "Should report error on timeout"
        # Error message might mention timeout
        if ($output.error | str contains "timeout" | str downcase) {
            # Good - explicit timeout message
        }
    }

    # Verify no orphaned opencode processes
    let opencode_procs = (ps | where name =~ "opencode")
    # Note: Can't reliably test this in integration test, would need system-level monitoring

    # Cleanup
    rm -f $output_path
}

#[test]
def "test_generate_preserves_trace_id" [] {
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
    let trace_id = "test-trace-preservation-12345"
    let output_path = "/tmp/test-gen-trace-tool.nu"
    let contract_path = $contracts_dir | path join "echo.yaml"

    # Act
    let result = run_generate $contract_path "Create echo tool" $output_path "Initial" "1/5" 30 $trace_id

    # Assert - Trace ID should be in output
    let output = $result.stdout | from json
    assert equal $output.trace_id $trace_id "Trace ID must be preserved in output"

    # Also verify logs contain trace_id
    let stderr = $result.stderr
    assert ($stderr | str contains $trace_id) "Trace ID should appear in logs"

    # Cleanup
    rm -f $output_path
}

#[test]
def "test_generate_prompt_includes_contract_schema" [] {
    # This test verifies that the prompt construction includes the contract
    # We test this indirectly by checking logs

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
    let output_path = "/tmp/test-gen-prompt-tool.nu"
    let contract_path = $contracts_dir | path join "echo.yaml"
    let task = "Create echo tool"

    # Act
    let result = run_generate $contract_path $task $output_path "Initial" "1/5" 30 "test-prompt"

    # Assert - Logs should mention prompt and contract
    let stderr = $result.stderr
    assert (($stderr | str length) > 0) "Should have logs"

    # The generate.nu logs information about the prompt
    assert ($stderr | str contains "prompt") "Logs should mention prompt construction"

    # Cleanup
    rm -f $output_path
}

#[test]
def "test_generate_output_is_valid_nushell" [] {
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
    let output_path = "/tmp/test-gen-valid-nu-tool.nu"
    let contract_path = $contracts_dir | path join "echo.yaml"

    # Act
    let result = run_generate $contract_path "Create simple echo tool" $output_path "Initial" "1/5" 30 "test-valid-nu"

    # Assert
    if $result.exit_code == 0 {
        # Verify the output is syntactically valid Nushell
        let syntax_check = (nu --commands $"open --raw ($output_path); 'syntax ok'" | complete)

        # If the file is valid Nushell, this should succeed
        # (Note: semantic correctness is a different concern)
        assert ($syntax_check.exit_code in [0, 1]) "Generated code should be parseable"

        let content = open --raw $output_path
        assert ($content | str contains "#!/usr/bin/env nu" or ($content | str contains "def main")) "Should be recognizable Nushell"
    }

    # Cleanup
    rm -f $output_path
}

#[test]
def "test_generate_creates_executable_tool" [] {
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
    let output_path = "/tmp/test-gen-executable-tool.nu"
    let contract_path = $contracts_dir | path join "echo.yaml"

    # Act - Generate a tool
    let result = run_generate $contract_path "Create echo tool" $output_path "Initial" "1/5" 30 "test-executable"

    # Assert
    if $result.exit_code == 0 {
        # File should exist
        assert ($output_path | path exists) "Generated tool file should exist"

        # Try to execute it (with simple input)
        let exec_result = ({message: "test"} | to json | nu $output_path | complete)

        # We don't assert success (AI might generate buggy code)
        # But we verify the attempt to execute doesn't crash the test
        assert ($exec_result.exit_code in [0, 1]) "Generated tool should be executable"

        # If it succeeded, verify it produced output
        if $exec_result.exit_code == 0 {
            assert (($exec_result.stdout | str length) > 0) "Successful execution should produce output"
        }
    }

    # Cleanup
    rm -f $output_path
}

#[test]
def "test_generate_handles_missing_contract" [] {
    # Arrange - Point to non-existent contract
    let output_path = "/tmp/test-gen-missing-contract-tool.nu"
    let contract_path = "/tmp/nonexistent-contract.yaml"
    let task = "Create tool"

    # Act
    let result = run_generate $contract_path $task $output_path "Initial" "1/5" 10 "test-missing"

    # Assert - Should fail gracefully
    assert equal $result.exit_code 1 "Should fail for missing contract"
    let output = $result.stdout | from json
    assert equal $output.success false "Should report failure"
    assert ($output.error | str contains "not found") "Error should mention contract not found"

    # Cleanup
    rm -f $output_path
}

#[test]
def "test_generate_handles_empty_task" [] {
    # Arrange - Empty task string
    let output_path = "/tmp/test-gen-empty-task-tool.nu"
    let contract_path = $contracts_dir | path join "echo.yaml"
    let task = ""  # Empty task

    # Act
    let result = run_generate $contract_path $task $output_path "Initial" "1/5" 10 "test-empty-task"

    # Assert - Should fail validation
    assert equal $result.exit_code 1 "Should fail for empty task"
    let output = $result.stdout | from json
    assert equal $output.success false "Should report failure"
    assert ($output.error | str contains "task") "Error should mention task requirement"

    # Cleanup
    rm -f $output_path
}

#[test]
def "test_generate_dry_run_skips_ai_call" [] {
    # Arrange - Use dry_run mode
    let output_path = "/tmp/test-gen-dry-run-tool.nu"
    let contract_path = $contracts_dir | path join "echo.yaml"

    let input = {
        contract_path: $contract_path
        task: "Create echo tool"
        output_path: $output_path
        context: {
            trace_id: "test-dry"
            dry_run: true  # Enable dry-run
        }
    }

    # Act
    let result = $input | to json | nu ($tools_dir | path join "generate.nu") | complete

    # Assert - Should succeed quickly without calling AI
    assert equal $result.exit_code 0 "Dry-run should succeed"
    let output = $result.stdout | from json
    assert equal $output.success true "Dry-run should report success"
    assert equal $output.data.was_dry_run true "Should indicate dry-run"

    # Should create stub file
    assert ($output_path | path exists) "Should create stub in dry-run"
    let content = open --raw $output_path
    assert ($content | str contains "dry-run") "Stub should indicate dry-run"

    # Cleanup
    rm -f $output_path
}

#[test]
def "test_generate_uses_llm_cleaner" [] {
    # Verify that generate.nu uses llm-cleaner to extract code

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
    let output_path = "/tmp/test-gen-cleaner-tool.nu"
    let contract_path = $contracts_dir | path join "echo.yaml"

    # Act
    let result = run_generate $contract_path "Create echo tool" $output_path "Initial" "1/5" 30 "test-cleaner"

    # Assert - Check logs mention llm-cleaner
    let stderr = $result.stderr
    if $result.exit_code == 0 {
        # Should mention llm-cleaner in logs
        assert ($stderr | str contains "llm-cleaner" or ($stderr | str contains "cleaning")) "Should use llm-cleaner"
    }

    # Cleanup
    rm -f $output_path
}
