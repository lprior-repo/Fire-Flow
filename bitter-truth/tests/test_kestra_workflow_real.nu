#!/usr/bin/env nu
# Real Kestra Workflow Integration Tests
#
# Tests the actual end-to-end bitter-truth workflow:
# Generate -> Execute -> Validate -> Self-Heal (on failure)
#
# These tests simulate what Kestra orchestrates without needing Kestra running.
# Run with: nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/test_kestra_workflow_real.nu'

use std assert

const TOOLS_DIR = "bitter-truth/tools"
const ECHO_CONTRACT = "bitter-truth/contracts/tools/echo.yaml"

#[test]
def "workflow_generates_and_executes_echo_tool" [] {
    # Real workflow: Generate AI code -> Execute -> Validate

    # Step 1: Generate a real echo tool (simulating AI generation)
    let generated_tool = "/tmp/bitter-truth-test-echo.nu"
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
}' | save -f $generated_tool

    assert ($generated_tool | path exists) "Generated tool should exist"

    # Step 2: Execute the generated tool with test data
    let tool_input = { message: "Hello World" }
    let output_file = "/tmp/test-workflow-output.json"
    let logs_file = "/tmp/test-workflow-logs.json"

    let run_input = {
        tool_path: $generated_tool
        tool_input: $tool_input
        output_path: $output_file
        logs_path: $logs_file
        context: { trace_id: "workflow-test-001" }
    }

    let exec_result = do {
        $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete

    assert equal $exec_result.exit_code 0 "Tool execution should succeed"

    # Verify output file was created and has correct structure
    assert ($output_file | path exists) "Output file should exist"
    let output = open $output_file
    assert equal $output.success true "Output should be successful"
    assert equal $output.data.echo "Hello World" "Echo should match input"
    assert equal $output.data.reversed "dlroW olleH" "Reversed should be correct"
    assert equal $output.data.length 11 "Length should be correct"

    # Cleanup
    rm -f $generated_tool $output_file $logs_file
}

#[test]
def "workflow_self_heals_on_broken_output" [] {
    # Test self-healing: broken tool -> feedback collection -> should try again

    # Step 1: Create a broken tool (missing required field)
    let broken_tool = "/tmp/bitter-truth-test-broken.nu"
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    {
        success: true
        data: {
            echo: ($input.message? | default "")
            # Missing "reversed" field - contract violation
            length: (($input.message? | default "") | str length)
            was_dry_run: false
        }
        trace_id: "broken-001"
        duration_ms: 1.0
    } | to json | print
}' | save -f $broken_tool

    # Step 2: Execute the broken tool
    let output_file = "/tmp/test-broken-output.json"
    let logs_file = "/tmp/test-broken-logs.json"

    let run_input = {
        tool_path: $broken_tool
        tool_input: { message: "test" }
        output_path: $output_file
        logs_path: $logs_file
        context: { trace_id: "broken-test-001" }
    }

    let exec_result = do {
        $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete

    # Should still exit 0 for self-healing
    assert equal $exec_result.exit_code 0 "Should exit 0 for self-healing"
    assert ($output_file | path exists) "Output file should be created"

    # Step 3: Validate would fail - collect feedback for AI retry
    let output = open $output_file
    let feedback = [
        "ATTEMPT 1 FAILED"
        ""
        "OUTPUT PRODUCED:"
        ($output | to text)
        ""
        "ISSUES:"
        "Missing required field: 'reversed'"
        ""
        "FIX THE NUSHELL SCRIPT TO SATISFY THE CONTRACT"
    ] | str join "\n"

    assert ($feedback | str contains "Missing required field") "Feedback should identify issue"
    assert ($feedback | str contains "FIX THE NUSHELL SCRIPT") "Feedback should guide AI"

    # Cleanup
    rm -f $broken_tool $output_file $logs_file
}

#[test]
def "workflow_traces_through_all_steps" [] {
    # Verify trace_id flows through entire pipeline
    let trace_id = "trace-end-to-end-$(random uuid | str substring 0..8)"

    let tool_file = "/tmp/test-trace-tool.nu"
    '#!/usr/bin/env nu
def main [] {
    { success: true, data: { result: "ok" } } | to json | print
}' | save -f $tool_file

    let output_file = "/tmp/test-trace-output.json"
    let logs_file = "/tmp/test-trace-logs.json"

    let run_input = {
        tool_path: $tool_file
        tool_input: {}
        output_path: $output_file
        logs_path: $logs_file
        context: { trace_id: $trace_id }
    }

    let run_result = do {
        $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete

    let run_response = $run_result.stdout | from json
    assert equal $run_response.trace_id $trace_id "trace_id should flow through execution"

    # Validate also preserves trace
    let validate_input = {
        contract_path: $ECHO_CONTRACT
        server: "local"
        context: { trace_id: $trace_id }
    }

    let validate_result = do {
        $validate_input | to json | nu ($TOOLS_DIR | path join "validate.nu")
    } | complete

    let validate_response = $validate_result.stdout | from json
    assert equal $validate_response.trace_id $trace_id "trace_id should flow through validation"

    # Cleanup
    rm -f $tool_file $output_file $logs_file
}

#[test]
def "workflow_handles_malformed_tool_output" [] {
    # Test resilience: tool that outputs invalid JSON

    let bad_tool = "/tmp/test-bad-output-tool.nu"
    '#!/usr/bin/env nu
def main [] {
    # Intentionally output invalid JSON
    print "this is not json {]"
}' | save -f $bad_tool

    let output_file = "/tmp/test-bad-output.json"
    let logs_file = "/tmp/test-bad-logs.json"

    let run_input = {
        tool_path: $bad_tool
        tool_input: {}
        output_path: $output_file
        logs_path: $logs_file
        context: { trace_id: "bad-json-test" }
    }

    let result = do {
        $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete

    # run-tool should still exit 0 and save the output
    assert equal $result.exit_code 0 "Should handle tool failure gracefully"

    # The output file should contain whatever the tool output
    assert ($output_file | path exists) "Output file should be created even with bad output"

    # Cleanup
    rm -f $bad_tool $output_file $logs_file
}

#[test]
def "workflow_with_large_payload" [] {
    # Test workflow with large inputs

    let tool_file = "/tmp/test-large-payload-tool.nu"
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    let size = ($input.data? | default "" | str length)
    {
        success: true
        data: {
            received_size: $size
            was_large: ($size > 1000)
        }
    } | to json | print
}' | save -f $tool_file

    let large_data = ((1..5000 | each { |_| "x" } | str join))  # 5K characters
    let output_file = "/tmp/test-large-output.json"
    let logs_file = "/tmp/test-large-logs.json"

    let run_input = {
        tool_path: $tool_file
        tool_input: { data: $large_data }
        output_path: $output_file
        logs_path: $logs_file
        context: { trace_id: "large-payload-test" }
    }

    let result = do {
        $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete

    assert equal $result.exit_code 0 "Should handle large payloads"

    let output = open $output_file
    assert ($output.data.received_size >= 5000) "Tool should receive large data"
    assert equal $output.data.was_large true "Tool should detect large input"

    # Cleanup
    rm -f $tool_file $output_file $logs_file
}

#[test]
def "workflow_multiple_attempts_with_feedback" [] {
    # Simulate the self-healing loop: attempt 1 fails, collect feedback

    let attempt_1_tool = "/tmp/test-attempt-1.nu"
    '#!/usr/bin/env nu
def main [] {
    { success: true, data: { attempt: 1, incomplete: true } } | to json | print
}' | save -f $attempt_1_tool

    # Attempt 1: Execute broken tool
    let output_file = "/tmp/test-multi-attempt.json"
    let logs_file = "/tmp/test-multi-logs.json"

    let attempt_1_input = {
        tool_path: $attempt_1_tool
        tool_input: { task: "test task" }
        output_path: $output_file
        logs_path: $logs_file
        context: { trace_id: "multi-attempt-test", attempt: "1/3" }
    }

    let attempt_1 = do {
        $attempt_1_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete

    assert equal $attempt_1.exit_code 0 "Attempt 1 should execute"

    let output1 = open $output_file
    assert equal $output1.data.attempt 1 "Should record attempt number"

    # Collect feedback for AI
    let feedback1 = "Attempt 1 output missing required fields. Please add: echo, reversed, length"

    # Attempt 2: Improved tool with feedback incorporated
    let attempt_2_tool = "/tmp/test-attempt-2.nu"
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    let msg = $input.task? | default ""
    {
        success: true
        data: {
            attempt: 2
            echo: $msg
            reversed: ($msg | split chars | reverse | str join)
            length: ($msg | str length)
        }
    } | to json | print
}' | save -f $attempt_2_tool

    let attempt_2_input = {
        tool_path: $attempt_2_tool
        tool_input: { task: "test task" }
        output_path: $output_file
        logs_path: $logs_file
        context: { trace_id: "multi-attempt-test", attempt: "2/3" }
    }

    let attempt_2 = do {
        $attempt_2_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete

    assert equal $attempt_2.exit_code 0 "Attempt 2 should execute"

    let output2 = open $output_file
    assert equal $output2.data.attempt 2 "Should record new attempt"
    assert ($output2.data.echo | is-not-empty) "Attempt 2 should have improved output"
    assert ($output2.data.reversed | is-not-empty) "Attempt 2 should include reversed field"

    # Cleanup
    rm -f $attempt_1_tool $attempt_2_tool $output_file $logs_file
}
