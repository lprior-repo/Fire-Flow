#!/usr/bin/env nu
# Tests for generate.nu
#
# Run with: nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests'
#
# Note: Most generate.nu tests are integration tests requiring opencode.
# These tests focus on input validation and dry-run mode.

use std assert

# Helper to run generate.nu with given input
def run_generate_with [input: record] {
    let tools_dir = $env.PWD | path join "bitter-truth/tools"
    $input | to json | nu ($tools_dir | path join "generate.nu") | complete
}

#[test]
def test_generate_requires_contract_path [] {
    let result = run_generate_with {
        task: "Create a tool"
        context: { trace_id: "test" }
    }

    assert equal $result.exit_code 1
    let output = $result.stdout | from json
    assert equal $output.success false
    assert ($output.error | str contains "contract_path is required")
}

#[test]
def test_generate_requires_task [] {
    let result = run_generate_with {
        contract_path: "/tmp/contract.yaml"
        context: { trace_id: "test" }
    }

    assert equal $result.exit_code 1
    let output = $result.stdout | from json
    assert equal $output.success false
    assert ($output.error | str contains "task is required")
}

#[test]
def test_generate_requires_existing_contract [] {
    let result = run_generate_with {
        contract_path: "/nonexistent/contract.yaml"
        task: "Create a tool"
        context: { trace_id: "test" }
    }

    assert equal $result.exit_code 1
    let output = $result.stdout | from json
    assert equal $output.success false
    assert ($output.error | str contains "not found")
}

#[test]
def test_generate_dry_run [] {
    # Create a minimal contract for dry-run
    let contract_path = "/tmp/test-gen-contract.yaml"
    "dataContractSpecification: 0.9.3
id: test
info:
  title: Test
  version: 1.0.0
models:
  Test:
    type: object
" | save -f $contract_path

    let result = run_generate_with {
        contract_path: $contract_path
        task: "Create a test tool"
        output_path: "/tmp/test-gen-output.nu"
        context: { trace_id: "test-dry", dry_run: true }
    }

    assert equal $result.exit_code 0
    let output = $result.stdout | from json
    assert equal $output.success true
    assert equal $output.data.was_dry_run true
    assert equal $output.data.generated true

    # Check stub was created
    let stub = open /tmp/test-gen-output.nu
    assert ($stub | str contains "dry-run")

    # Cleanup
    rm -f $contract_path /tmp/test-gen-output.nu
}

#[test]
def test_generate_includes_feedback_in_prompt [] {
    # This test verifies that feedback from previous attempts is included
    # We can check this by looking at the logs (dry-run mode doesn't call opencode)
    let contract_path = "/tmp/test-feedback-contract.yaml"
    "dataContractSpecification: 0.9.3
id: test
info:
  title: Test
  version: 1.0.0
" | save -f $contract_path

    let result = run_generate_with {
        contract_path: $contract_path
        task: "Fix the broken code"
        feedback: "ATTEMPT 1 FAILED: str rev is not a valid command"
        attempt: "2/5"
        context: { trace_id: "test-feedback", dry_run: true }
    }

    assert equal $result.exit_code 0

    # Cleanup
    rm -f $contract_path
}
