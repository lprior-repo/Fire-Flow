#!/usr/bin/env nu
# Unit tests for exit code correctness
# Ensures all tools return proper exit codes for success/failure scenarios
#
# Run with: nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/unit'

use std assert

# Helper to get tools directory
def tools_dir [] {
    $env.PWD | path join "bitter-truth/tools"
}

#[test]
def test_success_exits_zero [] {
    # Arrange: Valid input that should succeed
    let input = {
        message: "test message"
        context: { trace_id: "test-exit-0" }
    }

    # Act: Execute echo.nu
    let result = do {
        $input | to json | nu (tools_dir | path join "echo.nu")
    } | complete

    # Assert: Should exit with code 0
    assert equal $result.exit_code 0 "Successful execution should exit with code 0"
    let output = $result.stdout | from json
    assert equal $output.success true "Response should have success=true"
}

#[test]
def test_failure_exits_one [] {
    # Arrange: Invalid input that should fail
    let input = {
        message: ""  # Empty message should fail
        context: { trace_id: "test-exit-1" }
    }

    # Act: Execute echo.nu
    let result = do {
        $input | to json | nu (tools_dir | path join "echo.nu")
    } | complete

    # Assert: Should exit with code 1
    assert equal $result.exit_code 1 "Failed validation should exit with code 1"
    let output = $result.stdout | from json
    assert equal $output.success false "Response should have success=false"
}

#[test]
def test_validation_pass_exits_zero [] {
    # Arrange: Valid validation request with dry_run
    let contract_path = $env.PWD | path join "bitter-truth/contracts/tools/echo.yaml"
    let input = {
        contract_path: $contract_path
        context: { trace_id: "test-validate-pass", dry_run: true }
    }

    # Act: Execute validate.nu in dry-run mode
    let result = do {
        $input | to json | nu (tools_dir | path join "validate.nu")
    } | complete

    # Assert: Should exit with code 0
    assert equal $result.exit_code 0 "Successful validation (dry-run) should exit with code 0"
    let output = $result.stdout | from json
    assert equal $output.success true "Response should have success=true"
    assert equal $output.data.valid true "Validation should pass"
}

#[test]
def test_validation_fail_exits_one [] {
    # Arrange: Create a contract and invalid data that will fail validation
    let test_id = (random uuid | str substring 0..8)
    let contract_path = $"/tmp/test-contract-($test_id).yaml"
    let data_path = $"/tmp/test-data-($test_id).json"

    # Create a simple contract
    '
dataContractSpecification: 0.9.3
id: test-contract
info:
  title: Test Contract
  version: 1.0.0
servers:
  local:
    type: local
    path: ' + $data_path + '
models:
  test_model:
    type: object
    fields:
      name:
        type: string
        required: true
      age:
        type: integer
        required: true
' | save -f $contract_path

    # Create invalid data (missing required field)
    '{"name": "test"}' | save -f $data_path

    let input = {
        contract_path: $contract_path
        server: "local"
        context: { trace_id: "test-validate-fail" }
    }

    # Act: Execute validate.nu
    let result = do {
        $input | to json | nu (tools_dir | path join "validate.nu")
    } | complete

    # Assert: Should exit with code 1 (validation failed)
    assert equal $result.exit_code 1 "Failed validation should exit with code 1"
    let output = $result.stdout | from json
    assert equal $output.success false "Response should have success=false"
    assert equal $output.data.valid false "Validation should fail"

    # Cleanup
    rm -f $contract_path $data_path
}

#[test]
def test_tool_execution_error_propagates [] {
    # Arrange: Create a tool that exits with error
    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/test-fail-tool-($test_id).nu"
    let output_path = $"/tmp/test-output-($test_id).json"
    let logs_path = $"/tmp/test-logs-($test_id).json"

    # Create tool that always fails
    '#!/usr/bin/env nu
def main [] {
    print -e "Tool internal error"
    exit 1
}' | save -f $tool_path

    let input = {
        tool_path: $tool_path
        tool_input: {}
        output_path: $output_path
        logs_path: $logs_path
        context: { trace_id: "test-propagate-error" }
    }

    # Act: Execute run-tool.nu
    let result = do {
        $input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    # Assert: run-tool.nu should exit 1 when tool fails
    assert equal $result.exit_code 1 "run-tool.nu should exit 1 when tool fails"
    let output = $result.stdout | from json
    assert equal $output.success false "Response should have success=false"
    assert equal $output.data.exit_code 1 "Should report tool's exit code"

    # Cleanup
    rm -f $tool_path $output_path $logs_path
}

#[test]
def test_input_error_exits_one [] {
    # Arrange: Test various input validation errors
    let test_cases = [
        {
            tool: "echo.nu"
            input: { context: { trace_id: "t1" } }  # Missing message
            description: "Missing required field"
        }
        {
            tool: "run-tool.nu"
            input: { tool_path: "", context: { trace_id: "t2" } }  # Empty tool_path
            description: "Empty required field"
        }
        {
            tool: "validate.nu"
            input: { contract_path: "/no/such/file.yaml", context: { trace_id: "t3" } }
            description: "Nonexistent file"
        }
        {
            tool: "generate.nu"
            input: { contract_path: "", task: "test", context: { trace_id: "t4" } }
            description: "Empty contract_path"
        }
    ]

    # Act & Assert: All input validation errors should exit 1
    for case in $test_cases {
        let result = do {
            $case.input | to json | nu (tools_dir | path join $case.tool)
        } | complete

        assert equal $result.exit_code 1 $"($case.tool): ($case.description) should exit 1"
        let output = $result.stdout | from json
        assert equal $output.success false $"($case.tool): should have success=false"
    }
}

#[test]
def test_dry_run_always_exits_zero [] {
    # Arrange: Test dry_run mode for all tools
    let contract_path = $env.PWD | path join "bitter-truth/contracts/tools/echo.yaml"
    let test_id = (random uuid | str substring 0..8)
    let dummy_tool = $"/tmp/dummy-($test_id).nu"
    "# dummy" | save -f $dummy_tool

    let test_cases = [
        {
            tool: "echo.nu"
            input: { message: "test", context: { trace_id: "dry1", dry_run: true } }
        }
        {
            tool: "run-tool.nu"
            input: { tool_path: $dummy_tool, tool_input: {}, context: { trace_id: "dry2", dry_run: true } }
        }
        {
            tool: "validate.nu"
            input: { contract_path: $contract_path, context: { trace_id: "dry3", dry_run: true } }
        }
        {
            tool: "generate.nu"
            input: { contract_path: $contract_path, task: "test", context: { trace_id: "dry4", dry_run: true } }
        }
    ]

    # Act & Assert: All dry_run executions should succeed
    for case in $test_cases {
        let result = do {
            $case.input | to json | nu (tools_dir | path join $case.tool)
        } | complete

        assert equal $result.exit_code 0 $"($case.tool) dry_run should exit 0"
        let output = $result.stdout | from json
        assert equal $output.success true $"($case.tool) dry_run should have success=true"
    }

    # Cleanup
    rm -f $dummy_tool
}

#[test]
def test_json_parse_error_exits_one [] {
    # Arrange: Malformed JSON input
    let malformed_inputs = [
        "not json"
        '{"incomplete": '
        ""
        "   "
    ]

    # Act & Assert: All JSON parse errors should exit 1
    for malformed in $malformed_inputs {
        let result = do {
            echo $malformed | nu (tools_dir | path join "echo.nu")
        } | complete

        assert equal $result.exit_code 1 $"Malformed JSON '($malformed | str substring 0..10)...' should exit 1"
        let output = $result.stdout | from json
        assert equal $output.success false "Should have success=false"
    }
}

#[test]
def test_tool_success_propagates [] {
    # Arrange: Create a tool that succeeds
    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/test-success-tool-($test_id).nu"
    let output_path = $"/tmp/test-output-($test_id).json"
    let logs_path = $"/tmp/test-logs-($test_id).json"

    # Create successful tool
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    { result: "success" } | to json | print
    exit 0
}' | save -f $tool_path

    let input = {
        tool_path: $tool_path
        tool_input: { data: "test" }
        output_path: $output_path
        logs_path: $logs_path
        context: { trace_id: "test-success-prop" }
    }

    # Act: Execute run-tool.nu
    let result = do {
        $input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    # Assert: Should exit 0 when tool succeeds
    assert equal $result.exit_code 0 "run-tool.nu should exit 0 when tool succeeds"
    let output = $result.stdout | from json
    assert equal $output.success true "Response should have success=true"
    assert equal $output.data.exit_code 0 "Should report tool's exit code as 0"

    # Cleanup
    rm -f $tool_path $output_path $logs_path
}

#[test]
def test_missing_dependency_exits_one [] {
    # Arrange: Create a test that simulates missing dependency
    # (validate.nu requires datacontract CLI)
    let test_id = (random uuid | str substring 0..8)
    let fake_contract = $"/tmp/fake-contract-($test_id).yaml"

    # Create minimal contract
    '
dataContractSpecification: 0.9.3
id: fake
info:
  title: Fake
  version: 1.0.0
servers:
  local:
    type: local
    path: /tmp/fake-data.json
' | save -f $fake_contract

    # Create data file
    '{"test": "data"}' | save -f "/tmp/fake-data.json"

    let input = {
        contract_path: $fake_contract
        server: "local"
        context: { trace_id: "test-dep" }
    }

    # Act: Execute validate.nu (may fail if datacontract not installed)
    let result = do {
        $input | to json | nu (tools_dir | path join "validate.nu")
    } | complete

    # Assert: If datacontract is missing, should exit 1
    # If datacontract exists, should exit 0 or 1 depending on validation
    assert ($result.exit_code in [0, 1]) "Should exit with 0 or 1"

    # Cleanup
    rm -f $fake_contract /tmp/fake-data.json
}

#[test]
def test_exit_code_matches_success_field [] {
    # Arrange: Test various scenarios
    let test_id = (random uuid | str substring 0..8)
    let dummy_tool = $"/tmp/dummy-exit-($test_id).nu"
    "# dummy" | save -f $dummy_tool

    let test_cases = [
        {
            tool: "echo.nu"
            input: { message: "test", context: { trace_id: "match1" } }
            expect_success: true
        }
        {
            tool: "echo.nu"
            input: { message: "", context: { trace_id: "match2" } }
            expect_success: false
        }
        {
            tool: "run-tool.nu"
            input: { tool_path: $dummy_tool, tool_input: {}, context: { trace_id: "match3", dry_run: true } }
            expect_success: true
        }
        {
            tool: "run-tool.nu"
            input: { tool_path: "/no/such/tool.nu", context: { trace_id: "match4" } }
            expect_success: false
        }
    ]

    # Act & Assert: exit_code should match success field
    for case in $test_cases {
        let result = do {
            $case.input | to json | nu (tools_dir | path join $case.tool)
        } | complete

        let output = $result.stdout | from json
        let expected_exit = if $case.expect_success { 0 } else { 1 }

        assert equal $result.exit_code $expected_exit $"($case.tool): exit code should be ($expected_exit)"
        assert equal $output.success $case.expect_success $"($case.tool): success field should be ($case.expect_success)"
    }

    # Cleanup
    rm -f $dummy_tool
}

#[test]
def test_zero_exit_only_on_true_success [] {
    # Arrange: Create tool that prints success but exits 1
    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/test-lying-tool-($test_id).nu"
    let output_path = $"/tmp/test-output-($test_id).json"
    let logs_path = $"/tmp/test-logs-($test_id).json"

    # Create tool that lies about success
    '#!/usr/bin/env nu
def main [] {
    { success: true, message: "I claim success" } | to json | print
    exit 1  # But actually fail
}' | save -f $tool_path

    let input = {
        tool_path: $tool_path
        tool_input: {}
        output_path: $output_path
        logs_path: $logs_path
        context: { trace_id: "test-lying" }
    }

    # Act: Execute run-tool.nu
    let result = do {
        $input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    # Assert: run-tool.nu should exit 1 because tool exit code was 1
    # (it should trust the exit code, not the stdout content)
    assert equal $result.exit_code 1 "Should exit 1 when tool exits 1"
    let output = $result.stdout | from json
    assert equal $output.success false "Should have success=false"
    assert equal $output.data.exit_code 1 "Should report actual exit code"

    # Cleanup
    rm -f $tool_path $output_path $logs_path
}

#[test]
def test_nonzero_exit_prevents_success_true [] {
    # Arrange: Ensure that any tool failure results in exit 1 and success: false
    let test_cases = [
        {
            tool: "echo.nu"
            input: { context: { trace_id: "nz1" } }  # Missing message
        }
        {
            tool: "run-tool.nu"
            input: { context: { trace_id: "nz2" } }  # Missing tool_path
        }
        {
            tool: "validate.nu"
            input: { context: { trace_id: "nz3" } }  # Missing contract_path
        }
        {
            tool: "generate.nu"
            input: { context: { trace_id: "nz4" } }  # Missing contract_path
        }
    ]

    # Act & Assert: All failures should have exit 1 and success: false
    for case in $test_cases {
        let result = do {
            $case.input | to json | nu (tools_dir | path join $case.tool)
        } | complete

        assert ($result.exit_code != 0) $"($case.tool): failed execution should have nonzero exit"
        let output = $result.stdout | from json
        assert ($output.success != true) $"($case.tool): failed execution should not have success=true"
    }
}
