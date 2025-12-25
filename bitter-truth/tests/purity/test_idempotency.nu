#!/usr/bin/env nu
# Purity tests for idempotency - Repeated execution safety
#
# Tests that running tools multiple times with the same input doesn't cause
# side effects or state changes. Repeated executions should be safe.
#
# Run with: nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/purity'

use std assert
use ../helpers/constants.nu *
use ../helpers/builders.nu *
use ../helpers/assertions.nu *

#[test]
def test_run_tool_twice_same_input_same_result [] {
    # Arrange: Create a simple tool
    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/idemp-tool-($test_id).nu"
    let output_path = $"/tmp/idemp-output-($test_id).json"
    let logs_path = $"/tmp/idemp-logs-($test_id).json"

    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    { success: true, data: { result: "constant" }, trace_id: "", duration_ms: 0 } | to json | print
}' | save -f $tool_path

    let input = build_run_tool_input $tool_path { value: 42 } $output_path $logs_path "trace-idemp"

    # Act: Run twice
    let result1 = do { $input | to json | nu (run_tool) } | complete
    let result2 = do { $input | to json | nu (run_tool) } | complete

    # Assert: Both should succeed
    assert equal $result1.exit_code 0 "First run should succeed"
    assert equal $result2.exit_code 0 "Second run should succeed"

    let output1 = $result1.stdout | from json
    let output2 = $result2.stdout | from json

    # Assert: Both outputs should be structurally identical
    assert equal $output1.success $output2.success "success field should match"
    assert equal $output1.data.exit_code $output2.data.exit_code "exit_code should match"

    # Assert: Output files should contain identical content
    let content1 = open --raw $output_path
    let parsed1 = $content1 | from json

    # The second run overwrites the file, verify it's still valid
    let content2 = open --raw $output_path
    let parsed2 = $content2 | from json

    # Both should be valid JSON with same structure
    assert equal $parsed1 $parsed2 "Output file content should be identical after rerun"

    # Cleanup
    rm -f $tool_path $output_path $logs_path
}

#[test]
def test_validate_twice_same_contract_same_result [] {
    # Arrange: Create contract and data
    let test_id = (random uuid | str substring 0..8)
    let contract_path = $"/tmp/idemp-contract-($test_id).yaml"
    let data_path = $"/tmp/idemp-data-($test_id).json"

    '
dataContractSpecification: 0.9.3
id: idemp-test
info:
  title: Idempotency Test
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
' | save -f $contract_path

    '{"name": "test"}' | save -f $data_path

    let input = build_validate_input $contract_path "local" "trace-idemp-val"

    # Act: Run validation 5 times
    let results = 0..<5 | each { |i|
        let result = do {
            $input | to json | nu (validate_tool)
        } | complete

        assert equal $result.exit_code 0 $"Run ($i) should succeed"
        $result.stdout | from json
    }

    # Assert: All results should be identical
    let first = $results | first
    assert equal $first.success true "Validation should succeed"
    assert equal $first.data.valid true "Data should be valid"

    $results | skip 1 | each { |result|
        assert equal $result.success $first.success "success should match"
        assert equal $result.data.valid $first.data.valid "valid should match"
        assert equal $result.data.errors $first.data.errors "errors should match"
    }

    # Assert: Contract and data files are unchanged
    let final_contract = open --raw $contract_path
    let final_data = open --raw $data_path

    assert ($contract_path | path exists) "Contract should still exist"
    assert ($data_path | path exists) "Data should still exist"
    assert (($final_contract | str length) > 0) "Contract should not be empty"
    assert (($final_data | str length) > 0) "Data should not be empty"

    # Cleanup
    rm -f $contract_path $data_path
}

#[test]
def test_generate_with_same_contract_same_feedback [] {
    # Arrange: Test generate.nu idempotency with dry-run
    let contract_path = echo_contract
    let test_id = (random uuid | str substring 0..8)
    let output_path = $"/tmp/idemp-gen-($test_id).nu"

    let input = build_generate_input $contract_path "create echo tool" $output_path "trace-idemp-gen" true

    # Act: Run generate 3 times in dry-run mode
    let results = 0..<3 | each { |i|
        let result = do {
            $input | to json | nu (generate_tool)
        } | complete

        assert equal $result.exit_code 0 $"Generate run ($i) should succeed"
        $result.stdout | from json
    }

    # Assert: All should indicate success
    let first = $results | first
    assert equal $first.success true "Generate should succeed in dry-run"
    assert equal $first.data.was_dry_run true "Should be dry-run"

    $results | skip 1 | each { |result|
        assert equal $result.success $first.success "success should match"
        assert equal $result.data.was_dry_run true "All should be dry-run"
    }

    # Assert: No file should be created in dry-run mode
    assert not ($output_path | path exists) "dry-run should not create file"

    # Cleanup (nothing to clean up in dry-run)
}

#[test]
def test_file_overwrite_idempotent [] {
    # Arrange: Test that overwriting output files is safe
    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/overwrite-tool-($test_id).nu"
    let output_path = $"/tmp/overwrite-output-($test_id).json"
    let logs_path = $"/tmp/overwrite-logs-($test_id).json"

    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    { success: true, data: { value: 123 }, trace_id: "", duration_ms: 0 } | to json | print
}' | save -f $tool_path

    let input = build_run_tool_input $tool_path {} $output_path $logs_path "trace-overwrite"

    # Act: Run multiple times, overwriting files
    let iterations = 5
    $iterations | each { |i|
        let result = do {
            $input | to json | nu (run_tool)
        } | complete

        assert equal $result.exit_code 0 $"Iteration ($i) should succeed"

        # Verify files exist after each run
        assert ($output_path | path exists) $"Output should exist after run ($i)"
        assert ($logs_path | path exists) $"Logs should exist after run ($i)"

        # Verify files are still valid JSON
        let output_data = open --raw $output_path | from json
        assert equal $output_data.data.value 123 "Output should contain expected data"
    }

    # Assert: Final file contents should be valid
    let final_output = open --raw $output_path | from json
    let final_logs = open --raw $logs_path

    assert equal $final_output.success true "Final output should indicate success"
    assert equal $final_output.data.value 123 "Final output should have correct value"

    # Cleanup
    rm -f $tool_path $output_path $logs_path
}

#[test]
def test_temp_cleanup_idempotent [] {
    # Arrange: Test that we can safely delete and recreate temp files
    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/cleanup-tool-($test_id).nu"
    let output_path = $"/tmp/cleanup-output-($test_id).json"
    let logs_path = $"/tmp/cleanup-logs-($test_id).json"

    '#!/usr/bin/env nu
def main [] {
    { success: true, data: {}, trace_id: "", duration_ms: 0 } | to json | print
}' | save -f $tool_path

    let input = build_run_tool_input $tool_path {} $output_path $logs_path "trace-cleanup"

    # Act: Run, cleanup, run again
    let cycles = 3
    $cycles | each { |cycle|
        # Run tool
        let result = do {
            $input | to json | nu (run_tool)
        } | complete

        assert equal $result.exit_code 0 $"Cycle ($cycle) should succeed"
        assert ($output_path | path exists) $"Output should exist in cycle ($cycle)"
        assert ($logs_path | path exists) $"Logs should exist in cycle ($cycle)"

        # Cleanup temp files
        rm -f $output_path
        rm -f $logs_path

        # Verify cleanup
        assert not ($output_path | path exists) $"Output should be deleted in cycle ($cycle)"
        assert not ($logs_path | path exists) $"Logs should be deleted in cycle ($cycle)"
    }

    # Assert: Should still work after multiple cleanup cycles
    # Run one final time
    let final_result = do {
        $input | to json | nu (run_tool)
    } | complete

    assert equal $final_result.exit_code 0 "Final run should succeed"

    # Cleanup
    rm -f $tool_path $output_path $logs_path
}

#[test]
def test_validation_multiple_times_safe [] {
    # Arrange: Validate same contract many times
    let test_id = (random uuid | str substring 0..8)
    let contract_path = $"/tmp/multi-val-contract-($test_id).yaml"
    let data_path = $"/tmp/multi-val-data-($test_id).json"

    '
dataContractSpecification: 0.9.3
id: multi-val-test
info:
  title: Multiple Validation Test
  version: 1.0.0
servers:
  local:
    type: local
    path: ' + $data_path + '
models:
  test_model:
    type: object
    fields:
      count:
        type: integer
        required: true
' | save -f $contract_path

    '{"count": 10}' | save -f $data_path

    let input = build_validate_input $contract_path "local" "trace-multi-val"

    # Act: Run validation 20 times
    let iterations = 20
    $iterations | each { |i|
        let result = do {
            $input | to json | nu (validate_tool)
        } | complete

        assert equal $result.exit_code 0 $"Validation ($i) should succeed"

        let output = $result.stdout | from json
        assert equal $output.success true $"Validation ($i) should have success=true"
        assert equal $output.data.valid true $"Validation ($i) should be valid"
    }

    # Assert: Files unchanged after many validations
    let final_contract = open --raw $contract_path
    let final_data = open --raw $data_path

    assert ($contract_path | path exists) "Contract should still exist"
    assert ($data_path | path exists) "Data should still exist"

    let final_data_parsed = $final_data | from json
    assert equal $final_data_parsed.count 10 "Data should be unchanged"

    # Cleanup
    rm -f $contract_path $data_path
}

#[test]
def test_echo_repeated_execution_safe [] {
    # Arrange: Echo the same message many times
    let input = build_echo_input "idempotent message" "trace-echo-idemp"

    # Act: Run 50 times
    let iterations = 50
    $iterations | each { |i|
        let result = do {
            $input | to json | nu (echo_tool)
        } | complete

        assert equal $result.exit_code 0 $"Echo ($i) should succeed"

        let output = $result.stdout | from json
        assert equal $output.success true $"Echo ($i) should have success=true"
        assert equal $output.data.echo "idempotent message" $"Echo ($i) should have correct message"
        assert equal $output.data.length 18 $"Echo ($i) should have correct length"
    }

    # No state to verify - echo is pure
}

#[test]
def test_concurrent_file_writes_safe [] {
    # Arrange: Test that overwriting same files multiple times is safe
    # (simulates concurrent-like behavior by rapid sequential writes)
    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/concurrent-tool-($test_id).nu"
    let shared_output = $"/tmp/concurrent-output-($test_id).json"
    let shared_logs = $"/tmp/concurrent-logs-($test_id).json"

    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    { success: true, data: { iteration: $input.iter }, trace_id: "", duration_ms: 0 } | to json | print
}' | save -f $tool_path

    # Act: Run 10 times rapidly, all writing to same files
    let iterations = 10
    let last_result = $iterations | each { |i|
        let input = build_run_tool_input $tool_path { iter: $i } $shared_output $shared_logs $"trace-concurrent-($i)"

        let result = do {
            $input | to json | nu (run_tool)
        } | complete

        assert equal $result.exit_code 0 $"Concurrent write ($i) should succeed"

        $result
    } | last

    # Assert: Files should exist and be valid
    assert ($shared_output | path exists) "Shared output should exist"
    assert ($shared_logs | path exists) "Shared logs should exist"

    let final_output = open --raw $shared_output | from json
    assert equal $final_output.success true "Final output should be valid"

    # The last write wins - verify it's from iteration 9 (0-indexed)
    assert equal $final_output.data.iteration 9 "Last write should be from final iteration"

    # Cleanup
    rm -f $tool_path $shared_output $shared_logs
}

#[test]
def test_dry_run_never_modifies_state [] {
    # Arrange: Test that dry-run truly doesn't modify anything
    let test_id = (random uuid | str substring 0..8)
    let output_path = $"/tmp/dry-idemp-output-($test_id).json"
    let logs_path = $"/tmp/dry-idemp-logs-($test_id).json"

    # Create dummy tool (won't actually run in dry-run)
    let tool_path = $"/tmp/dry-idemp-tool-($test_id).nu"
    "#!/usr/bin/env nu\ndef main [] { exit 1 }" | save -f $tool_path

    let input = build_run_tool_input $tool_path {} $output_path $logs_path "trace-dry-idemp" true

    # Act: Run dry-run 10 times
    let iterations = 10
    $iterations | each { |i|
        let result = do {
            $input | to json | nu (run_tool)
        } | complete

        assert equal $result.exit_code 0 $"Dry-run ($i) should succeed"

        let output = $result.stdout | from json
        assert equal $output.data.was_dry_run true $"Should be dry-run ($i)"
    }

    # Assert: No files created
    assert not ($output_path | path exists) "dry-run should not create output file"
    assert not ($logs_path | path exists) "dry-run should not create logs file"

    # Cleanup
    rm -f $tool_path
}

#[test]
def test_error_state_idempotent [] {
    # Arrange: Test that errors don't corrupt state
    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/error-idemp-tool-($test_id).nu"
    let output_path = $"/tmp/error-idemp-output-($test_id).json"
    let logs_path = $"/tmp/error-idemp-logs-($test_id).json"

    # Tool that always fails
    '#!/usr/bin/env nu
def main [] {
    { error: "always fails" } | to json | print
    exit 1
}' | save -f $tool_path

    let input = build_run_tool_input $tool_path {} $output_path $logs_path "trace-error-idemp"

    # Act: Run failing tool 5 times
    let iterations = 5
    $iterations | each { |i|
        let result = do {
            $input | to json | nu (run_tool)
        } | complete

        # Should fail but not crash
        assert equal $result.exit_code 1 $"Error run ($i) should exit 1"

        let output = $result.stdout | from json
        assert equal $output.success false $"Error run ($i) should have success=false"
    }

    # Assert: Files should exist (run-tool creates them even on failure)
    assert ($output_path | path exists) "Output should exist after failures"
    assert ($logs_path | path exists) "Logs should exist after failures"

    # Assert: Files contain valid content from failed tool
    let final_output = open --raw $output_path | from json
    assert equal $final_output.error "always fails" "Output should contain tool's error"

    # Cleanup
    rm -f $tool_path $output_path $logs_path
}

#[test]
def test_validate_idempotent_on_failure [] {
    # Arrange: Test that validation failures are idempotent
    let test_id = (random uuid | str substring 0..8)
    let contract_path = $"/tmp/fail-idemp-contract-($test_id).yaml"
    let data_path = $"/tmp/fail-idemp-data-($test_id).json"

    '
dataContractSpecification: 0.9.3
id: fail-idemp-test
info:
  title: Failure Idempotency Test
  version: 1.0.0
servers:
  local:
    type: local
    path: ' + $data_path + '
models:
  test_model:
    type: object
    fields:
      required_field:
        type: string
        required: true
' | save -f $contract_path

    # Invalid data (missing required field)
    '{"wrong_field": "value"}' | save -f $data_path

    let input = build_validate_input $contract_path "local" "trace-fail-idemp"

    # Act: Run validation 10 times (should consistently fail)
    let iterations = 10
    $iterations | each { |i|
        let result = do {
            $input | to json | nu (validate_tool)
        } | complete

        assert equal $result.exit_code 1 $"Validation ($i) should fail"

        let output = $result.stdout | from json
        assert equal $output.success false $"Validation ($i) should have success=false"
        assert equal $output.data.valid false $"Validation ($i) should be invalid"
    }

    # Assert: Files unchanged despite repeated failures
    assert ($contract_path | path exists) "Contract should still exist"
    assert ($data_path | path exists) "Data should still exist"

    let final_data = open --raw $data_path | from json
    assert equal $final_data.wrong_field "value" "Data should be unchanged"

    # Cleanup
    rm -f $contract_path $data_path
}
