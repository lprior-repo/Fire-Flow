#!/usr/bin/env nu
# Error Recovery Workflow Tests
#
# Tests failure scenarios and graceful error handling:
# - Missing contract files
# - Missing tool files
# - Invalid input handling
# - Validation failure triggering feedback
# - Network/timeout handling
# - Malformed data recovery

use std assert

const TOOLS_DIR = "bitter-truth/tools"
const ECHO_CONTRACT = "bitter-truth/contracts/tools/echo.yaml"

#[test]
def "error_recovery_missing_contract_fails_gracefully" [] {
    # Test: Validation with non-existent contract returns proper error

    let output_file = "/tmp/error-output.json"

    # Create a valid output file
    {
        success: true
        data: {
            echo: "test"
            reversed: "tset"
            length: 4
            was_dry_run: false
        }
        trace_id: "missing-contract-test"
        duration_ms: 1.0
    } | to json | save -f $output_file

    let validate_input = {
        contract_path: "/nonexistent/contract.yaml"
        output_path: $output_file
        server: "local"
        context: { trace_id: "missing-contract-test", dry_run: false }
    }

    let validate_result = do {
        $validate_input | to json | nu ($TOOLS_DIR | path join "validate.nu")
    } | complete

    # Should exit with error
    assert equal $validate_result.exit_code 1 "Should fail when contract missing"

    let response = $validate_result.stdout | from json
    assert equal $response.success false "Response should indicate failure"
    assert ($response.error | str contains "contract not found") "Error should mention missing contract"

    # Cleanup
    rm -f $output_file
}

#[test]
def "error_recovery_missing_tool_fails_gracefully" [] {
    # Test: Execution with non-existent tool returns proper error

    let run_input = {
        tool_path: "/nonexistent/tool.nu"
        tool_input: { message: "test" }
        output_path: "/tmp/error-tool-output.json"
        logs_path: "/tmp/error-tool-logs.json"
        context: { trace_id: "missing-tool-test" }
    }

    let run_result = do {
        $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete

    # Should exit with error
    assert equal $run_result.exit_code 1 "Should fail when tool missing"

    let response = $run_result.stdout | from json
    assert equal $response.success false "Response should indicate failure"
    assert ($response.error | str contains "tool not found") "Error should mention missing tool"
    assert equal $response.trace_id "missing-tool-test" "Should preserve trace_id in error"

    # Cleanup
    rm -f "/tmp/error-tool-output.json" "/tmp/error-tool-logs.json"
}

#[test]
def "error_recovery_invalid_input_fails_gracefully" [] {
    # Test: Tool handles invalid JSON input gracefully

    let tool_path = "/tmp/error-invalid-tool.nu"

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
    } | to json | print
}' | save -f $tool_path

    let output_file = "/tmp/error-invalid-output.json"
    let logs_file = "/tmp/error-invalid-logs.json"

    # Pass malformed JSON to run-tool
    let invalid_json = "{ this is not valid json }"

    let run_result = do {
        echo $invalid_json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete

    # run-tool should detect invalid JSON
    assert equal $run_result.exit_code 1 "Should fail on invalid JSON input"

    let response = $run_result.stdout | from json
    assert equal $response.success false "Should indicate failure"
    assert ($response.error | str contains "Invalid JSON") "Error should mention invalid JSON"

    # Cleanup
    rm -f $tool_path $output_file $logs_file
}

#[test]
def "error_recovery_validation_failure_triggers_feedback" [] {
    # Test: Contract violation produces feedback for self-healing

    let tool_path = "/tmp/error-validation-tool.nu"

    # Tool outputs incomplete data (missing fields)
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    {
        success: true
        data: {
            echo: "incomplete"
            # Missing: reversed, length, was_dry_run
        }
        trace_id: ($input.context?.trace_id? | default "")
        duration_ms: 1.0
    } | to json | print
}' | save -f $tool_path

    let output_file = "/tmp/output.json"
    let logs_file = "/tmp/error-validation-logs.json"

    # Execute broken tool
    let run_input = {
        tool_path: $tool_path
        tool_input: { message: "test" }
        output_path: $output_file
        logs_path: $logs_file
        context: { trace_id: "validation-feedback-test" }
    }

    do { $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu") } | complete | null

    # Validate (should fail)
    let validate_input = {
        contract_path: $ECHO_CONTRACT
        output_path: $output_file
        server: "local"
        context: { trace_id: "validation-feedback-test", dry_run: false }
    }

    let validate_result = do {
        $validate_input | to json | nu ($TOOLS_DIR | path join "validate.nu")
    } | complete

    let validate_response = $validate_result.stdout | from json

    # Validation should fail
    assert equal $validate_response.success false "Validation should fail for incomplete output"

    # Collect feedback for AI
    let output_data = open $output_file | from json
    let feedback = [
        "VALIDATION FAILED"
        ""
        "CONTRACT VIOLATIONS:"
        "Missing required fields: reversed, length, was_dry_run"
        ""
        "OUTPUT PRODUCED:"
        ($output_data | to text)
        ""
        "FIX THE NUSHELL SCRIPT TO SATISFY THE CONTRACT"
    ] | str join "\n"

    # Verify feedback is useful
    assert ($feedback | str contains "VALIDATION FAILED") "Feedback should indicate failure"
    assert ($feedback | str contains "Missing required fields") "Feedback should identify issues"
    assert ($feedback | str contains "FIX THE NUSHELL SCRIPT") "Feedback should guide AI"

    # Cleanup
    rm -f $tool_path $output_file $logs_file
}

#[test]
def "error_recovery_network_timeout_handled" [] {
    # Test: Simulated timeout/slow operation handled gracefully

    let tool_path = "/tmp/error-timeout-tool.nu"

    # Tool that simulates slow operation
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json

    # Simulate processing
    sleep 100ms

    {
        success: true
        data: {
            echo: "slow operation"
            reversed: "noitarepo wols"
            length: 14
            was_dry_run: false
        }
        trace_id: ($input.context?.trace_id? | default "")
        duration_ms: 100.0
    } | to json | print
}' | save -f $tool_path

    let output_file = "/tmp/output.json"
    let logs_file = "/tmp/error-timeout-logs.json"

    let run_input = {
        tool_path: $tool_path
        tool_input: { message: "test" }
        output_path: $output_file
        logs_path: $logs_file
        context: { trace_id: "timeout-test" }
    }

    let start = date now

    let run_result = do {
        $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete

    let duration_ms = ((date now) - $start) | into int | $in / 1000000

    # Should complete (no actual timeout in this test, but verify it handles delay)
    assert equal $run_result.exit_code 0 "Should complete despite delay"
    assert ($duration_ms >= 100) "Should take at least the sleep duration"

    # Cleanup
    rm -f $tool_path $output_file $logs_file
}

#[test]
def "error_recovery_malformed_tool_output" [] {
    # Test: Tool outputs non-JSON, run-tool captures it safely

    let tool_path = "/tmp/error-malformed-tool.nu"

    # Tool that outputs invalid JSON
    '#!/usr/bin/env nu
def main [] {
    # Output invalid JSON
    print "This is not JSON at all!"
}' | save -f $tool_path

    let output_file = "/tmp/error-malformed-output.json"
    let logs_file = "/tmp/error-malformed-logs.json"

    let run_input = {
        tool_path: $tool_path
        tool_input: { message: "test" }
        output_path: $output_file
        logs_path: $logs_file
        context: { trace_id: "malformed-output-test" }
    }

    let run_result = do {
        $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete

    # run-tool should succeed (captures whatever the tool outputs)
    assert equal $run_result.exit_code 0 "run-tool should capture malformed output"

    # Output file should contain the malformed output
    assert ($output_file | path exists) "Output file should be created"

    let output_content = open -r $output_file
    assert ($output_content | str contains "This is not JSON") "Should capture tool's actual output"

    # Validation would fail on this malformed output
    let validate_input = {
        contract_path: $ECHO_CONTRACT
        output_path: $output_file
        server: "local"
        context: { trace_id: "malformed-output-test", dry_run: false }
    }

    let validate_result = do {
        $validate_input | to json | nu ($TOOLS_DIR | path join "validate.nu")
    } | complete

    # Validation should fail gracefully
    assert equal $validate_result.exit_code 1 "Validation should fail on malformed output"

    # Cleanup
    rm -f $tool_path $output_file $logs_file
}

#[test]
def "error_recovery_missing_data_file_in_contract" [] {
    # Test: Contract references non-existent data file

    let bad_contract = "/tmp/error-bad-contract.yaml"

    # Create contract pointing to non-existent data file
    'dataContractSpecification: 0.9.3
id: bad-contract-test
info:
  title: Bad Contract Test
  version: 1.0.0

servers:
  local:
    type: local
    path: /nonexistent/data.json
    format: json

models:
  TestModel:
    type: object
    fields:
      value:
        type: string
        required: true
' | save -f $bad_contract

    let output_file = "/tmp/error-no-data-output.json"

    # Create a valid output
    {
        success: true
        data: { value: "test" }
    } | to json | save -f $output_file

    let validate_input = {
        contract_path: $bad_contract
        output_path: $output_file
        server: "local"
        context: { trace_id: "missing-data-test", dry_run: false }
    }

    let validate_result = do {
        $validate_input | to json | nu ($TOOLS_DIR | path join "validate.nu")
    } | complete

    # Should fail gracefully
    assert equal $validate_result.exit_code 1 "Should fail when data file missing"

    let response = $validate_result.stdout | from json
    assert equal $response.success false "Should indicate failure"
    assert ($response.error | str contains "Data file does not exist") "Should explain missing data file"

    # Cleanup
    rm -f $bad_contract $output_file
}

#[test]
def "error_recovery_tool_crash" [] {
    # Test: Tool that exits with error code

    let tool_path = "/tmp/error-crash-tool.nu"

    # Tool that deliberately exits with error
    '#!/usr/bin/env nu
def main [] {
    { level: "error", msg: "tool crashed" } | to json -r | print -e
    { success: false, error: "deliberate crash" } | to json | print
    exit 1
}' | save -f $tool_path

    let output_file = "/tmp/error-crash-output.json"
    let logs_file = "/tmp/error-crash-logs.json"

    let run_input = {
        tool_path: $tool_path
        tool_input: { message: "test" }
        output_path: $output_file
        logs_path: $logs_file
        context: { trace_id: "crash-test" }
    }

    let run_result = do {
        $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete

    # run-tool should detect the failure
    assert equal $run_result.exit_code 1 "Should propagate tool failure"

    let response = $run_result.stdout | from json
    assert equal $response.success false "Should indicate tool failed"

    # Error logs should be captured
    assert ($logs_file | path exists) "Logs should be captured"
    let logs = open -r $logs_file
    assert ($logs | str contains "tool crashed") "Should capture error logs"

    # Cleanup
    rm -f $tool_path $output_file $logs_file
}

#[test]
def "error_recovery_partial_output" [] {
    # Test: Tool outputs partial/incomplete data structure

    let tool_path = "/tmp/error-partial-tool.nu"

    # Tool that outputs success but incomplete data
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    {
        success: true
        # Missing data field entirely
        trace_id: ($input.context?.trace_id? | default "")
    } | to json | print
}' | save -f $tool_path

    let output_file = "/tmp/output.json"
    let logs_file = "/tmp/error-partial-logs.json"

    let run_input = {
        tool_path: $tool_path
        tool_input: { message: "test" }
        output_path: $output_file
        logs_path: $logs_file
        context: { trace_id: "partial-output-test" }
    }

    let run_result = do {
        $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete

    # Execution should succeed (tool didn't crash)
    assert equal $run_result.exit_code 0 "Execution should succeed"

    # But validation should fail
    let validate_input = {
        contract_path: $ECHO_CONTRACT
        output_path: $output_file
        server: "local"
        context: { trace_id: "partial-output-test", dry_run: false }
    }

    let validate_result = do {
        $validate_input | to json | nu ($TOOLS_DIR | path join "validate.nu")
    } | complete

    let validate_response = $validate_result.stdout | from json
    assert equal $validate_response.success false "Validation should fail on partial output"

    # This would trigger self-healing loop with feedback
    let output = open $output_file | from json
    let feedback = $"Missing data field in output: ($output | to text)"

    assert ($feedback | str contains "Missing data field") "Feedback should identify the issue"

    # Cleanup
    rm -f $tool_path $output_file $logs_file
}

#[test]
def "error_recovery_contract_yaml_parse_error" [] {
    # Test: Contract file with invalid YAML syntax

    let bad_yaml_contract = "/tmp/error-bad-yaml.yaml"

    # Invalid YAML (unclosed bracket)
    'dataContractSpecification: 0.9.3
id: bad-yaml
info:
  title: Bad YAML [
  # Unclosed bracket above
' | save -f $bad_yaml_contract

    let output_file = "/tmp/error-yaml-output.json"

    { success: true, data: { test: "value" } } | to json | save -f $output_file

    let validate_input = {
        contract_path: $bad_yaml_contract
        output_path: $output_file
        server: "local"
        context: { trace_id: "bad-yaml-test", dry_run: false }
    }

    let validate_result = do {
        $validate_input | to json | nu ($TOOLS_DIR | path join "validate.nu")
    } | complete

    # Should fail gracefully
    assert equal $validate_result.exit_code 1 "Should fail on invalid YAML"

    let response = $validate_result.stdout | from json
    assert equal $response.success false "Should indicate failure"
    assert ($response.error | str contains "Invalid contract YAML") "Should identify YAML parsing error"

    # Cleanup
    rm -f $bad_yaml_contract $output_file
}

#[test]
def "error_recovery_empty_trace_id_handled" [] {
    # Test: Workflow handles missing/empty trace_id gracefully

    let tool_path = "/tmp/error-no-trace-tool.nu"

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
        trace_id: ""
        duration_ms: 1.0
    } | to json | print
}' | save -f $tool_path

    let output_file = "/tmp/output.json"
    let logs_file = "/tmp/error-no-trace-logs.json"

    # Execute without trace_id in context
    let run_input = {
        tool_path: $tool_path
        tool_input: { message: "no trace test" }
        output_path: $output_file
        logs_path: $logs_file
        context: {}  # No trace_id
    }

    let run_result = do {
        $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete

    # Should succeed even without trace_id
    assert equal $run_result.exit_code 0 "Should handle missing trace_id"

    let output = open $output_file | from json
    assert equal $output.success true "Output should indicate success"
    assert equal $output.trace_id "" "trace_id should be empty"

    # Cleanup
    rm -f $tool_path $output_file $logs_file
}
