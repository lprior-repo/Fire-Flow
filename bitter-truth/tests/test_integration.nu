#!/usr/bin/env nu
# Integration tests for bitter-truth pipeline
#
# These tests verify the full Generate -> Execute -> Validate flow works correctly.
# Run with: nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests'
#
# Martin Fowler's testing principles applied:
# - Tests describe behavior, not implementation
# - Each test is independent and isolated
# - Tests are deterministic (use fixtures, not live AI calls)
# - Test names explain the business requirement

use std assert

let tools_dir = $env.PWD | path join "bitter-truth/tools"
let contracts_dir = $env.PWD | path join "bitter-truth/contracts/tools"

# ============================================================================
# FIXTURES - Reusable test data
# ============================================================================

# A correctly implemented echo tool (what we expect AI to generate)
def fixture_correct_echo_tool [] {
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    let message = $input.message
    let reversed = ($message | str reverse)
    let length = ($message | str length)
    {
        success: true,
        data: {
            echo: $message,
            reversed: $reversed,
            length: $length,
            was_dry_run: false
        }
    } | to json | print
}'
}

# A buggy echo tool (common AI mistake - str rev instead of str reverse)
def fixture_buggy_echo_tool [] {
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    let message = $input.message
    let reversed = ($message | str rev)  # BUG: str rev does not exist
    let length = ($message | str length)
    { echo: $message, reversed: $reversed, length: $length } | to json | print
}'
}

# A tool that outputs wrong schema
def fixture_wrong_schema_tool [] {
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    # Missing required fields, wrong structure
    { wrong: "data" } | to json | print
}'
}

# ============================================================================
# BEHAVIOR TESTS - Testing what the system SHOULD do
# ============================================================================

#[test]
def "correctly_implemented_tool_executes_successfully" [] {
    # Arrange
    let tool_path = "/tmp/test-correct-tool.nu"
    fixture_correct_echo_tool | save -f $tool_path

    # Act
    let result = {
        tool_path: $tool_path
        tool_input: { message: "hello world" }
        output_path: "/tmp/test-correct-output.json"
        logs_path: "/tmp/test-correct-logs.json"
        context: { trace_id: "test-correct" }
    } | to json | nu ($tools_dir | path join "run-tool.nu") | complete

    # Assert
    assert equal $result.exit_code 0 "Tool execution should succeed"

    let output = $result.stdout | from json
    assert equal $output.success true "Output should indicate success"
    assert equal $output.data.exit_code 0 "Tool exit code should be 0"

    let tool_output = open /tmp/test-correct-output.json  # open auto-parses .json
    assert equal $tool_output.success true "Tool output should have success=true"
    assert equal $tool_output.data.echo "hello world" "Echo should match input"
    assert equal $tool_output.data.reversed "dlrow olleh" "Reversed should be correct"
    assert equal $tool_output.data.length 11 "Length should be 11"

    # Cleanup
    rm -f $tool_path /tmp/test-correct-output.json /tmp/test-correct-logs.json
}

#[test]
def "buggy_tool_fails_gracefully_without_crashing_flow" [] {
    # Arrange - This simulates the str rev bug we encountered
    let tool_path = "/tmp/test-buggy-tool.nu"
    fixture_buggy_echo_tool | save -f $tool_path

    # Act
    let result = {
        tool_path: $tool_path
        tool_input: { message: "test" }
        output_path: "/tmp/test-buggy-output.json"
        logs_path: "/tmp/test-buggy-logs.json"
        context: { trace_id: "test-buggy" }
    } | to json | nu ($tools_dir | path join "run-tool.nu") | complete

    # Assert - run-tool.nu should NOT crash (exit 0) but report failure
    assert equal $result.exit_code 0 "run-tool should exit 0 to allow self-healing"

    let output = $result.stdout | from json
    assert equal $output.success false "Output should indicate failure"
    assert (($output.error | str length) > 0) "Error message should be captured"

    # The logs should contain the actual error (logs are stderr text, not JSON)
    let logs = open --raw /tmp/test-buggy-logs.json
    assert ($logs | str contains "str rev") "Logs should capture the actual error"

    # Cleanup
    rm -f $tool_path /tmp/test-buggy-output.json /tmp/test-buggy-logs.json
}

#[test]
def "wrong_schema_tool_should_fail_contract_validation" [] {
    # Arrange
    let tool_path = "/tmp/test-wrong-schema-tool.nu"
    let output_path = "/tmp/test-wrong-schema-output.json"
    fixture_wrong_schema_tool | save -f $tool_path

    # Execute the tool first
    {
        tool_path: $tool_path
        tool_input: { message: "test" }
        output_path: $output_path
        logs_path: "/tmp/test-wrong-logs.json"
        context: { trace_id: "test-wrong" }
    } | to json | nu ($tools_dir | path join "run-tool.nu")

    # Act - Validate against echo contract
    let validate_result = {
        contract_path: ($contracts_dir | path join "echo.yaml")
        server: "local"
        context: { trace_id: "test-wrong" }
    } | to json | nu ($tools_dir | path join "validate.nu") | complete

    # Assert - Validation should fail (output doesn't match schema)
    # Note: validate.nu now exits 0 but sets success=false
    let output = $validate_result.stdout | from json
    assert equal $output.success false "Validation should fail for wrong schema"
    assert equal $output.data.valid false "Data should be marked invalid"

    # Cleanup
    rm -f $tool_path $output_path /tmp/test-wrong-logs.json
}

#[test]
def "llm_cleaner_extracts_code_from_chatty_response" [] {
    # Arrange - Simulate typical LLM output with explanation
    let llm_response = "I'll help you create the echo tool. Here's the implementation:

```nushell
#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    { echo: $input.message } | to json | print
}
```

This tool reads JSON from stdin and echoes the message field back."

    let llm_cleaner = "/home/lewis/src/Fire-Flow/tools/llm-cleaner/target/release/llm-cleaner"

    # Act
    let result = $llm_response | do { ^$llm_cleaner --lang nushell } | complete

    # Assert
    assert equal $result.exit_code 0 "Cleaner should extract code successfully"
    assert ($result.stdout | str contains "def main") "Extracted code should have main function"
    assert (not ($result.stdout | str contains "I'll help")) "Should not include explanation"
    assert (not ($result.stdout | str contains "```")) "Should not include markdown fences"
}

#[test]
def "pipeline_handles_empty_input_gracefully" [] {
    # Arrange
    let tool_path = "/tmp/test-empty-input-tool.nu"
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    let msg = $input.message? | default "no message"
    { echo: $msg } | to json | print
}' | save -f $tool_path

    # Act - Pass empty object
    let result = {
        tool_path: $tool_path
        tool_input: {}
        output_path: "/tmp/test-empty-output.json"
        logs_path: "/tmp/test-empty-logs.json"
        context: { trace_id: "test-empty" }
    } | to json | nu ($tools_dir | path join "run-tool.nu") | complete

    # Assert
    assert equal $result.exit_code 0 "Should handle empty input"
    let output = $result.stdout | from json
    assert equal $output.success true "Tool should succeed with default"

    # Cleanup
    rm -f $tool_path /tmp/test-empty-output.json /tmp/test-empty-logs.json
}

# ============================================================================
# SELF-HEALING TESTS - Verify feedback loop works
# ============================================================================

#[test]
def "feedback_contains_error_details_for_self_healing" [] {
    # Arrange - Create a tool that crashes
    let tool_path = "/tmp/test-crash-tool.nu"
    '#!/usr/bin/env nu
def main [] {
    # This will fail because $undefined is not defined
    print $undefined
}' | save -f $tool_path

    # Act
    let result = {
        tool_path: $tool_path
        tool_input: { message: "test" }
        output_path: "/tmp/test-crash-output.json"
        logs_path: "/tmp/test-crash-logs.json"
        context: { trace_id: "test-crash" }
    } | to json | nu ($tools_dir | path join "run-tool.nu") | complete

    # Assert - Error should be captured for feedback
    let output = $result.stdout | from json
    assert equal $output.success false
    assert (($output.error | str length) > 0) "Error should be captured"

    # Check logs contain the actual error (logs are plain text, not JSON)
    let logs = open --raw /tmp/test-crash-logs.json
    assert (($logs | str length) > 0) "Logs should capture stderr"
    assert ($logs | str contains "undefined") "Logs should contain error about undefined"

    # Cleanup
    rm -f $tool_path /tmp/test-crash-output.json /tmp/test-crash-logs.json
}
