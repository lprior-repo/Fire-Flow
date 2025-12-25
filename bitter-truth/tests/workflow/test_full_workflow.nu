#!/usr/bin/env nu
# Full Workflow End-to-End Tests
#
# Tests complete happy path workflows:
# - Contract loop with successful generation
# - Full pipeline with multiple inputs
# - Output correctness verification
# - Timing and performance checks
# - Complete log verification

use std assert

const TOOLS_DIR = "bitter-truth/tools"
const ECHO_CONTRACT = "bitter-truth/contracts/tools/echo.yaml"

# Helper: Create a working echo tool
def create_working_echo_tool [path: string] {
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    let message = $input.message? | default ""
    let tid = $input.context?.trace_id? | default ""

    {
        success: true
        data: {
            echo: $message
            reversed: ($message | split chars | reverse | str join)
            length: ($message | str length)
            was_dry_run: false
        }
        trace_id: $tid
        duration_ms: 1.5
    } | to json | print
}' | save -f $path

    chmod +x $path
}

#[test]
def "full_workflow_contract_loop_happy_path" [] {
    # Test: Complete workflow - Generate -> Execute -> Validate -> Success

    let trace_id = "full-workflow-happy"
    let tool_path = "/tmp/full-happy-tool.nu"
    let output_file = "/tmp/output.json"
    let logs_file = "/tmp/full-happy-logs.json"

    # Step 1: Generate tool (simulated - AI would generate this)
    create_working_echo_tool $tool_path

    assert ($tool_path | path exists) "Step 1: Tool should be generated"

    # Step 2: Execute the tool
    let run_input = {
        tool_path: $tool_path
        tool_input: { message: "Full workflow test" }
        output_path: $output_file
        logs_path: $logs_file
        context: { trace_id: $trace_id }
    }

    let run_result = do {
        $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete

    assert equal $run_result.exit_code 0 "Step 2: Execution should succeed"
    assert ($output_file | path exists) "Step 2: Output should be created"

    let run_response = $run_result.stdout | from json
    assert equal $run_response.success true "Step 2: run-tool should return success"

    # Step 3: Validate against contract
    let validate_input = {
        contract_path: $ECHO_CONTRACT
        output_path: $output_file
        server: "local"
        context: { trace_id: $trace_id, dry_run: false }
    }

    let validate_result = do {
        $validate_input | to json | nu ($TOOLS_DIR | path join "validate.nu")
    } | complete

    assert equal $validate_result.exit_code 0 "Step 3: Validation should exit 0"

    let validate_response = $validate_result.stdout | from json
    assert equal $validate_response.success true "Step 3: Validation should succeed"

    # Step 4: Verify final output correctness
    let final_output = open $output_file | from json
    assert equal $final_output.success true "Step 4: Final output should be successful"
    assert equal $final_output.data.echo "Full workflow test" "Step 4: Echo should match input"
    assert equal $final_output.data.reversed "tset krowflow lluF" "Step 4: Reversed should be correct"
    assert equal $final_output.data.length 18 "Step 4: Length should be correct"

    # Cleanup
    rm -f $tool_path $output_file $logs_file
}

#[test]
def "full_workflow_pipeline_with_multiple_inputs" [] {
    # Test: Run full pipeline with different inputs, verify each succeeds

    let tool_path = "/tmp/full-multi-tool.nu"
    create_working_echo_tool $tool_path

    let test_inputs = [
        { message: "First test", expected_len: 10 }
        { message: "Second test case", expected_len: 16 }
        { message: "Third", expected_len: 5 }
        { message: "Fourth test scenario with longer message", expected_len: 40 }
    ]

    let trace_id = "multi-input-test"
    let results = []

    for idx in 0..(($test_inputs | length) - 1) {
        let test_case = ($test_inputs | get $idx)
        let output_file = $"/tmp/full-multi-output-($idx).json"
        let logs_file = $"/tmp/full-multi-logs-($idx).json"

        # Execute
        let run_input = {
            tool_path: $tool_path
            tool_input: { message: $test_case.message }
            output_path: $output_file
            logs_path: $logs_file
            context: { trace_id: $"($trace_id)-($idx)" }
        }

        let run_result = do {
            $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
        } | complete

        # Validate
        let validate_input = {
            contract_path: $ECHO_CONTRACT
            output_path: $output_file
            server: "local"
            context: { trace_id: $"($trace_id)-($idx)", dry_run: false }
        }

        let validate_result = do {
            $validate_input | to json | nu ($TOOLS_DIR | path join "validate.nu")
        } | complete

        let validate_response = $validate_result.stdout | from json

        let results = ($results | append {
            idx: $idx
            message: $test_case.message
            success: $validate_response.success
            output_file: $output_file
        })
    }

    # All inputs should succeed
    let success_count = ($results | where success | length)
    assert equal $success_count ($test_inputs | length) "All inputs should process successfully"

    # Verify each output
    for idx in 0..(($test_inputs | length) - 1) {
        let test_case = ($test_inputs | get $idx)
        let output_file = $"/tmp/full-multi-output-($idx).json"
        let output = open $output_file | from json

        assert equal $output.data.echo $test_case.message $"Input ($idx) should echo correctly"
        assert equal $output.data.length $test_case.expected_len $"Input ($idx) should have correct length"
    }

    # Cleanup
    rm -f $tool_path
    for idx in 0..(($test_inputs | length) - 1) {
        rm -f $"/tmp/full-multi-output-($idx).json" $"/tmp/full-multi-logs-($idx).json"
    }
}

#[test]
def "full_workflow_output_correctness" [] {
    # Test: Verify output data integrity through entire pipeline

    let tool_path = "/tmp/full-correctness-tool.nu"
    create_working_echo_tool $tool_path

    let test_message = "Test message with special chars: !@#$%^&*()"
    let trace_id = "correctness-test"
    let output_file = "/tmp/output.json"
    let logs_file = "/tmp/full-correctness-logs.json"

    # Execute
    let run_input = {
        tool_path: $tool_path
        tool_input: { message: $test_message }
        output_path: $output_file
        logs_path: $logs_file
        context: { trace_id: $trace_id }
    }

    do { $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu") } | complete | null

    # Read and verify output
    let output = open $output_file | from json

    # Verify structure
    assert ($output | columns | any { |c| $c == "success" }) "Output should have 'success' field"
    assert ($output | columns | any { |c| $c == "data" }) "Output should have 'data' field"
    assert ($output | columns | any { |c| $c == "trace_id" }) "Output should have 'trace_id' field"

    # Verify data integrity
    assert equal $output.data.echo $test_message "Echo should preserve exact input"
    assert equal $output.data.reversed (")(*&^%$#@! :srahc laiceps htiw egassem tseT") "Reversed should be accurate"
    assert equal $output.data.length ($test_message | str length) "Length should be exact"

    # Verify types
    assert ($output.success | describe | str contains "bool") "success should be boolean"
    assert ($output.data.length | describe | str contains "int") "length should be integer"
    assert ($output.data.echo | describe | str contains "string") "echo should be string"

    # Verify trace_id propagation
    assert equal $output.trace_id $trace_id "trace_id should flow through"

    # Cleanup
    rm -f $tool_path $output_file $logs_file
}

#[test]
def "full_workflow_timing_reasonable" [] {
    # Test: Full workflow completes in reasonable time

    let tool_path = "/tmp/full-timing-tool.nu"
    create_working_echo_tool $tool_path

    let output_file = "/tmp/output.json"
    let logs_file = "/tmp/full-timing-logs.json"

    let start_time = date now

    # Execute workflow
    let run_input = {
        tool_path: $tool_path
        tool_input: { message: "timing test" }
        output_path: $output_file
        logs_path: $logs_file
        context: { trace_id: "timing-test" }
    }

    do { $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu") } | complete | null

    # Validate
    let validate_input = {
        contract_path: $ECHO_CONTRACT
        output_path: $output_file
        server: "local"
        context: { trace_id: "timing-test", dry_run: false }
    }

    do { $validate_input | to json | nu ($TOOLS_DIR | path join "validate.nu") } | complete | null

    let end_time = date now
    let duration_ms = ($end_time - $start_time) | into int | $in / 1000000

    # Workflow should complete quickly (under 5 seconds for simple echo)
    assert ($duration_ms < 5000) "Full workflow should complete in under 5 seconds"
    assert ($duration_ms > 0) "Duration should be positive"

    # Verify tool reported timing
    let output = open $output_file | from json
    assert ($output.duration_ms? != null) "Output should include duration_ms"
    assert ($output.duration_ms > 0) "Tool duration should be positive"

    # Cleanup
    rm -f $tool_path $output_file $logs_file
}

#[test]
def "full_workflow_logs_complete" [] {
    # Test: Verify logs are captured throughout workflow

    let tool_path = "/tmp/full-logs-tool.nu"

    # Tool that logs to stderr
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    let message = $input.message? | default ""
    let tid = $input.context?.trace_id? | default ""

    # Log to stderr
    { level: "info", msg: "processing", trace_id: $tid } | to json -r | print -e
    { level: "debug", msg: "reversing string" } | to json -r | print -e

    {
        success: true
        data: {
            echo: $message
            reversed: ($message | split chars | reverse | str join)
            length: ($message | str length)
            was_dry_run: false
        }
        trace_id: $tid
        duration_ms: 2.0
    } | to json | print

    { level: "info", msg: "complete" } | to json -r | print -e
}' | save -f $tool_path

    let output_file = "/tmp/output.json"
    let logs_file = "/tmp/full-logs-file.json"
    let trace_id = "logs-test"

    # Execute
    let run_input = {
        tool_path: $tool_path
        tool_input: { message: "log test" }
        output_path: $output_file
        logs_path: $logs_file
        context: { trace_id: $trace_id }
    }

    do { $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu") } | complete | null

    # Verify logs were captured
    assert ($logs_file | path exists) "Logs file should be created"

    let logs_content = open -r $logs_file
    assert ($logs_content | str length > 0) "Logs should have content"
    assert ($logs_content | str contains "processing") "Logs should contain 'processing'"
    assert ($logs_content | str contains "complete") "Logs should contain 'complete'"
    assert ($logs_content | str contains $trace_id) "Logs should include trace_id"

    # Verify output also succeeded
    let output = open $output_file | from json
    assert equal $output.success true "Output should indicate success"

    # Cleanup
    rm -f $tool_path $output_file $logs_file
}

#[test]
def "full_workflow_end_to_end_with_validation_details" [] {
    # Test: Complete E2E with detailed validation result inspection

    let tool_path = "/tmp/full-e2e-tool.nu"
    create_working_echo_tool $tool_path

    let trace_id = "e2e-validation-details"
    let output_file = "/tmp/output.json"
    let logs_file = "/tmp/full-e2e-logs.json"

    # Execute
    let run_input = {
        tool_path: $tool_path
        tool_input: { message: "E2E validation test" }
        output_path: $output_file
        logs_path: $logs_file
        context: { trace_id: $trace_id }
    }

    let run_result = do {
        $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete

    assert equal $run_result.exit_code 0 "Execution should succeed"

    # Validate with detailed inspection
    let validate_input = {
        contract_path: $ECHO_CONTRACT
        output_path: $output_file
        server: "local"
        context: { trace_id: $trace_id, dry_run: false }
    }

    let validate_result = do {
        $validate_input | to json | nu ($TOOLS_DIR | path join "validate.nu")
    } | complete

    let validate_response = $validate_result.stdout | from json

    # Inspect validation result structure
    assert ($validate_response | columns | any { |c| $c == "success" }) "Validation should have 'success'"
    assert ($validate_response | columns | any { |c| $c == "data" }) "Validation should have 'data'"

    # Check validation data
    assert equal $validate_response.success true "Validation should succeed"

    # Cleanup
    rm -f $tool_path $output_file $logs_file
}

#[test]
def "full_workflow_handles_empty_input" [] {
    # Test: Workflow handles empty/minimal input gracefully

    let tool_path = "/tmp/full-empty-tool.nu"
    create_working_echo_tool $tool_path

    let output_file = "/tmp/output.json"
    let logs_file = "/tmp/full-empty-logs.json"

    # Execute with empty message
    let run_input = {
        tool_path: $tool_path
        tool_input: { message: "" }
        output_path: $output_file
        logs_path: $logs_file
        context: { trace_id: "empty-input-test" }
    }

    let run_result = do {
        $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete

    assert equal $run_result.exit_code 0 "Should handle empty input"

    let output = open $output_file | from json
    assert equal $output.data.echo "" "Echo should be empty string"
    assert equal $output.data.reversed "" "Reversed should be empty string"
    assert equal $output.data.length 0 "Length should be 0"

    # Validate
    let validate_input = {
        contract_path: $ECHO_CONTRACT
        output_path: $output_file
        server: "local"
        context: { trace_id: "empty-input-test", dry_run: false }
    }

    let validate_result = do {
        $validate_input | to json | nu ($TOOLS_DIR | path join "validate.nu")
    } | complete

    let validate_response = $validate_result.stdout | from json
    assert equal $validate_response.success true "Empty input should still validate"

    # Cleanup
    rm -f $tool_path $output_file $logs_file
}

#[test]
def "full_workflow_large_message" [] {
    # Test: Workflow handles large input messages

    let tool_path = "/tmp/full-large-tool.nu"
    create_working_echo_tool $tool_path

    let large_message = (1..1000 | each { |_| "test " } | str join)
    let output_file = "/tmp/output.json"
    let logs_file = "/tmp/full-large-logs.json"

    # Execute with large message
    let run_input = {
        tool_path: $tool_path
        tool_input: { message: $large_message }
        output_path: $output_file
        logs_path: $logs_file
        context: { trace_id: "large-message-test" }
    }

    let run_result = do {
        $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete

    assert equal $run_result.exit_code 0 "Should handle large message"

    let output = open $output_file | from json
    assert equal $output.data.echo $large_message "Echo should preserve large message"
    assert equal $output.data.length ($large_message | str length) "Length should be correct for large message"

    # Validate
    let validate_input = {
        contract_path: $ECHO_CONTRACT
        output_path: $output_file
        server: "local"
        context: { trace_id: "large-message-test", dry_run: false }
    }

    let validate_result = do {
        $validate_input | to json | nu ($TOOLS_DIR | path join "validate.nu")
    } | complete

    let validate_response = $validate_result.stdout | from json
    assert equal $validate_response.success true "Large message should validate"

    # Cleanup
    rm -f $tool_path $output_file $logs_file
}
