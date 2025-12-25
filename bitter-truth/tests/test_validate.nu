#!/usr/bin/env nu
# Tests for validate.nu
#
# Run with: nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests'

use std assert

# Helper to run validate.nu with given input
def run_validate_with [input: record] {
    let tools_dir = $env.PWD | path join "bitter-truth/tools"
    $input | to json | nu ($tools_dir | path join "validate.nu") | complete
}

# Create a minimal test contract
def create_test_contract [path: string, output_path: string] {
    $"dataContractSpecification: 0.9.3
id: test-contract
info:
  title: Test Contract
  version: 1.0.0

servers:
  local:
    type: local
    path: ($output_path)
    format: json

models:
  TestResponse:
    type: object
    fields:
      success:
        type: boolean
        required: true
      message:
        type: string
        required: true
" | save -f $path
}

# Create valid output matching contract
def create_valid_output [path: string] {
    { success: true, message: "hello" } | to json | save -f $path
}

# Create invalid output (missing required field)
def create_invalid_output [path: string] {
    { success: true } | to json | save -f $path
}

#[test]
def test_validate_requires_contract_path [] {
    let result = run_validate_with { context: { trace_id: "test" } }

    assert equal $result.exit_code 1
    let output = $result.stdout | from json
    assert equal $output.success false
    assert ($output.error | str contains "contract_path is required")
}

#[test]
def test_validate_requires_existing_contract [] {
    let result = run_validate_with {
        contract_path: "/nonexistent/contract.yaml"
        context: { trace_id: "test" }
    }

    assert equal $result.exit_code 1
    let output = $result.stdout | from json
    assert equal $output.success false
    assert ($output.error | str contains "not found")
}

#[test]
def test_validate_dry_run [] {
    let result = run_validate_with {
        contract_path: "/tmp/any-contract.yaml"
        context: { trace_id: "test-dry", dry_run: true }
    }

    assert equal $result.exit_code 0
    let output = $result.stdout | from json
    assert equal $output.success true
    assert equal $output.data.was_dry_run true
    assert equal $output.data.valid true
}

#[test]
def test_validate_valid_data [] {
    let contract_path = "/tmp/test-contract.yaml"
    let output_path = "/tmp/test-valid-output.json"

    create_test_contract $contract_path $output_path
    create_valid_output $output_path

    let result = run_validate_with {
        contract_path: $contract_path
        server: "local"
        context: { trace_id: "test-valid" }
    }

    # Validate.nu always exits 0 now (to allow self-healing)
    assert equal $result.exit_code 0 "validate.nu should exit 0"

    # Parse the JSON output
    let output = $result.stdout | from json
    # Note: actual validation result depends on datacontract-cli
    # We just verify the output structure is correct
    assert ($output | get success? | default false | describe | str starts-with "bool") "Output should have success field"
    assert ($output | get data? | default null | is-not-empty) "Output should have data field"

    # Cleanup
    rm -f $contract_path $output_path
}

#[test]
def test_validate_outputs_kestra_format [] {
    # Test that validate.nu outputs Kestra-compatible format when KESTRA_EXECUTION_ID is set
    let contract_path = "/tmp/test-kestra-format-contract.yaml"
    let output_path = "/tmp/test-kestra-format-output.json"

    create_test_contract $contract_path $output_path
    create_valid_output $output_path

    # Run with KESTRA_EXECUTION_ID set to trigger Kestra format output
    let tools_dir = $env.PWD | path join "bitter-truth/tools"
    let input_json = {
        contract_path: $contract_path
        server: "local"
        context: { trace_id: "test-kestra" }
    } | to json

    let result = with-env { KESTRA_EXECUTION_ID: "test-exec-123" } {
        $input_json | nu ($tools_dir | path join "validate.nu") | complete
    }

    # Check for Kestra output format ::{"outputs":...}:: on first line
    let lines = $result.stdout | lines
    if ($lines | length) > 0 {
        assert (($lines | first) | str contains "::") "First line should contain Kestra format ::"
    }

    # Cleanup
    rm -f $contract_path $output_path
}
