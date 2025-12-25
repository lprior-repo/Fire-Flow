#!/usr/bin/env nu
# Tests for generate.nu using nutest
# Run with: use nutest; nutest run-tests --match-suites generate

use std assert

const SCRIPT_DIR = "/home/lewis/src/Fire-Flow/bitter-truth/tools"
const GENERATE_SCRIPT = "/home/lewis/src/Fire-Flow/bitter-truth/tools/generate.nu"
const TEST_CONTRACT = "/home/lewis/src/Fire-Flow/bitter-truth/contracts/tools/echo.yaml"

@test
def "generate dry run returns success" [] {
    let input = {
        contract_path: $TEST_CONTRACT
        task: "Echo the input message"
        feedback: "Test feedback"
        attempt: "1/1"
        output_path: "/tmp/test-tool.nu"
        context: {
            trace_id: "test-dry-run"
            dry_run: true
            timeout_seconds: 10
        }
    }

    let result = $input | to json | nu $GENERATE_SCRIPT | complete

    assert equal $result.exit_code 0 "Expected exit code 0"

    let output = $result.stdout | from json
    assert equal $output.success true "Expected success=true"
    assert equal $output.data.was_dry_run true "Expected was_dry_run=true"
    assert equal $output.data.generated true "Expected generated=true"
}

@test
def "generate fails with missing contract_path" [] {
    let input = {
        task: "Test task"
        context: { trace_id: "test-no-contract" }
    }

    let result = $input | to json | nu $GENERATE_SCRIPT | complete

    assert not equal $result.exit_code 0 "Expected non-zero exit code"

    let output = $result.stdout | from json
    assert equal $output.success false "Expected success=false"
    assert str contains $output.error "contract_path" "Expected error about contract_path"
}

@test
def "generate fails with missing task" [] {
    let input = {
        contract_path: $TEST_CONTRACT
        context: { trace_id: "test-no-task" }
    }

    let result = $input | to json | nu $GENERATE_SCRIPT | complete

    assert not equal $result.exit_code 0 "Expected non-zero exit code"

    let output = $result.stdout | from json
    assert equal $output.success false "Expected success=false"
    assert str contains $output.error "task" "Expected error about task"
}

@test
def "generate fails with non-existent contract" [] {
    let input = {
        contract_path: "/nonexistent/contract.yaml"
        task: "Test task"
        context: { trace_id: "test-bad-contract" }
    }

    let result = $input | to json | nu $GENERATE_SCRIPT | complete

    assert not equal $result.exit_code 0 "Expected non-zero exit code"

    let output = $result.stdout | from json
    assert equal $output.success false "Expected success=false"
    assert str contains $output.error "not found" "Expected error about contract not found"
}

@test
def "generate includes trace_id in output" [] {
    let input = {
        contract_path: $TEST_CONTRACT
        task: "Echo test"
        context: {
            trace_id: "my-custom-trace-id"
            dry_run: true
        }
    }

    let result = $input | to json | nu $GENERATE_SCRIPT | complete
    let output = $result.stdout | from json

    assert equal $output.trace_id "my-custom-trace-id" "Expected trace_id in output"
}

@test
def "generate includes duration_ms in output" [] {
    let input = {
        contract_path: $TEST_CONTRACT
        task: "Echo test"
        context: { dry_run: true }
    }

    let result = $input | to json | nu $GENERATE_SCRIPT | complete
    let output = $result.stdout | from json

    assert ($output.duration_ms >= 0) "Expected non-negative duration_ms"
}
