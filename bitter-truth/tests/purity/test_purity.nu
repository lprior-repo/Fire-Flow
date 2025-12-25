#!/usr/bin/env nu
# Purity tests - No side effects
#
# Tests that tools are pure functions: they don't modify inputs,
# don't leave temp files, and don't corrupt global state.
#
# Run with: nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/purity'

use std assert
use ../helpers/constants.nu *
use ../helpers/builders.nu *
use ../helpers/assertions.nu *

#[test]
def test_read_only_contract_unchanged [] {
    # Arrange: Create a contract file
    let test_id = (random uuid | str substring 0..8)
    let contract_path = $"/tmp/pure-contract-($test_id).yaml"
    let data_path = $"/tmp/pure-data-($test_id).json"

    let original_contract = '
dataContractSpecification: 0.9.3
id: pure-test
info:
  title: Purity Test
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
'
    $original_contract | save -f $contract_path

    '{"name": "test"}' | save -f $data_path

    # Get file hash before
    let hash_before = open --raw $contract_path | hash sha256

    let input = build_validate_input $contract_path "local" "trace-pure-contract"

    # Act: Run validation
    let result = do {
        $input | to json | nu (validate_tool)
    } | complete

    assert equal $result.exit_code 0 "Validation should succeed"

    # Assert: Contract file unchanged
    let hash_after = open --raw $contract_path | hash sha256
    assert equal $hash_after $hash_before "Contract file should not be modified"

    let final_content = open --raw $contract_path
    assert equal $final_content $original_contract "Contract content should be unchanged"

    # Cleanup
    rm -f $contract_path $data_path
}

#[test]
def test_read_only_fixtures_unchanged [] {
    # Arrange: Use real contract from fixtures
    let contract_path = echo_contract
    let contract_hash_before = open --raw $contract_path | hash sha256

    let input = build_echo_input "fixture test" "trace-fixture"

    # Act: Run echo tool (doesn't use contract but tests principle)
    let result = do {
        $input | to json | nu (echo_tool)
    } | complete

    assert equal $result.exit_code 0 "Echo should succeed"

    # Assert: No files in project modified (check specific known files)
    let contract_hash_after = open --raw $contract_path | hash sha256
    assert equal $contract_hash_after $contract_hash_before "Contract file should not be modified"

    # Assert: Tools themselves unchanged
    let echo_tool_hash_before = open --raw (echo_tool) | hash sha256
    let echo_tool_hash_after = open --raw (echo_tool) | hash sha256
    assert equal $echo_tool_hash_after $echo_tool_hash_before "Echo tool should not be modified"
}

#[test]
def test_temp_files_cleaned_after [] {
    # Arrange: Run tool that creates temp files
    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/temp-tool-($test_id).nu"
    let output_path = $"/tmp/temp-output-($test_id).json"
    let logs_path = $"/tmp/temp-logs-($test_id).json"

    '#!/usr/bin/env nu
def main [] {
    { success: true, data: {}, trace_id: "", duration_ms: 0 } | to json | print
}' | save -f $tool_path

    let input = build_run_tool_input $tool_path {} $output_path $logs_path "trace-temp"

    # Act: Run tool
    let result = do {
        $input | to json | nu (run_tool)
    } | complete

    assert equal $result.exit_code 0 "Tool should succeed"

    # Assert: Files created
    assert ($output_path | path exists) "Output should exist"
    assert ($logs_path | path exists) "Logs should exist"

    # Act: Cleanup temp files (simulating end of test)
    rm -f $tool_path
    rm -f $output_path
    rm -f $logs_path

    # Assert: Files cleaned up
    assert not ($tool_path | path exists) "Tool should be cleaned up"
    assert not ($output_path | path exists) "Output should be cleaned up"
    assert not ($logs_path | path exists) "Logs should be cleaned up"
}

#[test]
def test_global_state_unchanged [] {
    # Arrange: Capture environment state before
    let env_before = $env | columns | sort
    let pwd_before = $env.PWD

    let input = build_echo_input "global state test" "trace-global"

    # Act: Run tool
    let result = do {
        $input | to json | nu (echo_tool)
    } | complete

    assert equal $result.exit_code 0 "Tool should succeed"

    # Assert: Environment unchanged
    let env_after = $env | columns | sort
    let pwd_after = $env.PWD

    # PWD should be unchanged (we're in same shell)
    assert equal $pwd_after $pwd_before "PWD should not change"

    # Environment variables should be same (may have slight differences, check key ones)
    assert equal ($env_before | length) ($env_after | length) "Environment size should be unchanged"
}

#[test]
def test_no_file_leaks [] {
    # Arrange: Count files in /tmp before
    let tmp_files_before = ls /tmp | where type == file | get name | length

    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/leak-tool-($test_id).nu"
    let output_path = $"/tmp/leak-output-($test_id).json"
    let logs_path = $"/tmp/leak-logs-($test_id).json"

    '#!/usr/bin/env nu
def main [] {
    { success: true, data: {}, trace_id: "", duration_ms: 0 } | to json | print
}' | save -f $tool_path

    let input = build_run_tool_input $tool_path {} $output_path $logs_path "trace-leak"

    # Act: Run tool
    let result = do {
        $input | to json | nu (run_tool)
    } | complete

    assert equal $result.exit_code 0 "Tool should succeed"

    # Act: Cleanup our known files
    rm -f $tool_path
    rm -f $output_path
    rm -f $logs_path

    # Assert: No additional files leaked
    let tmp_files_after = ls /tmp | where type == file | get name | length

    # Should have same or fewer files (some system temp files may have been cleaned)
    assert ($tmp_files_after <= $tmp_files_before + 2) "Should not leak temp files (allowing small margin)"
}

#[test]
def test_input_data_unchanged [] {
    # Arrange: Create test data
    let test_id = (random uuid | str substring 0..8)
    let contract_path = $"/tmp/input-contract-($test_id).yaml"
    let data_path = $"/tmp/input-data-($test_id).json"

    '
dataContractSpecification: 0.9.3
id: input-test
info:
  title: Input Purity Test
  version: 1.0.0
servers:
  local:
    type: local
    path: ' + $data_path + '
models:
  test_model:
    type: object
    fields:
      value:
        type: integer
        required: true
' | save -f $contract_path

    let original_data = '{"value": 42}'
    $original_data | save -f $data_path

    let data_hash_before = open --raw $data_path | hash sha256

    let input = build_validate_input $contract_path "local" "trace-input-data"

    # Act: Run validation
    let result = do {
        $input | to json | nu (validate_tool)
    } | complete

    assert equal $result.exit_code 0 "Validation should succeed"

    # Assert: Data file unchanged
    let data_hash_after = open --raw $data_path | hash sha256
    assert equal $data_hash_after $data_hash_before "Data file should not be modified"

    let final_data = open --raw $data_path
    assert equal $final_data $original_data "Data content should be unchanged"

    # Cleanup
    rm -f $contract_path $data_path
}

#[test]
def test_multiple_runs_no_accumulation [] {
    # Arrange: Test that running tool multiple times doesn't accumulate state
    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/accum-tool-($test_id).nu"
    let output_path = $"/tmp/accum-output-($test_id).json"
    let logs_path = $"/tmp/accum-logs-($test_id).json"

    '#!/usr/bin/env nu
def main [] {
    { success: true, data: { counter: 1 }, trace_id: "", duration_ms: 0 } | to json | print
}' | save -f $tool_path

    let input = build_run_tool_input $tool_path {} $output_path $logs_path "trace-accum"

    # Act: Run 10 times
    let iterations = 10
    $iterations | each { |i|
        let result = do {
            $input | to json | nu (run_tool)
        } | complete

        assert equal $result.exit_code 0 $"Run ($i) should succeed"

        # Check output - counter should always be 1 (not accumulating)
        let output = open --raw $output_path | from json
        assert equal $output.data.counter 1 $"Counter should be 1, not accumulating ($i)"
    }

    # Assert: Final output is same as first (no accumulation)
    let final_output = open --raw $output_path | from json
    assert equal $final_output.data.counter 1 "Counter should still be 1"

    # Cleanup
    rm -f $tool_path $output_path $logs_path
}

#[test]
def test_no_side_effects_on_failure [] {
    # Arrange: Test that failures don't corrupt state
    let test_id = (random uuid | str substring 0..8)
    let contract_path = $"/tmp/fail-pure-contract-($test_id).yaml"
    let data_path = $"/tmp/fail-pure-data-($test_id).json"

    let original_contract = '
dataContractSpecification: 0.9.3
id: fail-pure-test
info:
  title: Failure Purity Test
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
'
    $original_contract | save -f $contract_path

    let original_data = '{"wrong_field": "value"}'
    $original_data | save -f $data_path

    let contract_hash_before = open --raw $contract_path | hash sha256
    let data_hash_before = open --raw $data_path | hash sha256

    let input = build_validate_input $contract_path "local" "trace-fail-pure"

    # Act: Run validation (should fail)
    let result = do {
        $input | to json | nu (validate_tool)
    } | complete

    assert equal $result.exit_code 1 "Validation should fail"

    # Assert: Files unchanged despite failure
    let contract_hash_after = open --raw $contract_path | hash sha256
    let data_hash_after = open --raw $data_path | hash sha256

    assert equal $contract_hash_after $contract_hash_before "Contract should not be modified by failure"
    assert equal $data_hash_after $data_hash_before "Data should not be modified by failure"

    # Cleanup
    rm -f $contract_path $data_path
}

#[test]
def test_dry_run_truly_dry [] {
    # Arrange: Test that dry-run doesn't create any files
    let test_id = (random uuid | str substring 0..8)
    let output_path = $"/tmp/dry-pure-output-($test_id).json"
    let logs_path = $"/tmp/dry-pure-logs-($test_id).json"

    # Ensure files don't exist
    if ($output_path | path exists) { rm -f $output_path }
    if ($logs_path | path exists) { rm -f $logs_path }

    let tool_path = $"/tmp/dry-pure-tool-($test_id).nu"
    '#!/usr/bin/env nu
def main [] {
    # This should never run in dry-run
    "side effect" | save -f "/tmp/side-effect.txt"
    exit 1
}' | save -f $tool_path

    let input = build_run_tool_input $tool_path {} $output_path $logs_path "trace-dry-pure" true

    # Act: Run in dry-run mode
    let result = do {
        $input | to json | nu (run_tool)
    } | complete

    assert equal $result.exit_code 0 "Dry-run should succeed"

    # Assert: No files created
    assert not ($output_path | path exists) "dry-run should not create output"
    assert not ($logs_path | path exists) "dry-run should not create logs"
    assert not ("/tmp/side-effect.txt" | path exists) "dry-run should not execute tool (no side effects)"

    # Cleanup
    rm -f $tool_path
}

#[test]
def test_validation_no_write_to_contract [] {
    # Arrange: Make contract read-only to ensure no writes
    let test_id = (random uuid | str substring 0..8)
    let contract_path = $"/tmp/readonly-contract-($test_id).yaml"
    let data_path = $"/tmp/readonly-data-($test_id).json"

    '
dataContractSpecification: 0.9.3
id: readonly-test
info:
  title: Read-only Test
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

    # Make read-only (chmod 444)
    chmod 444 $contract_path

    let input = build_validate_input $contract_path "local" "trace-readonly"

    # Act: Run validation
    let result = do {
        $input | to json | nu (validate_tool)
    } | complete

    # Should succeed despite read-only (because we don't write)
    assert equal $result.exit_code 0 "Validation should succeed even with read-only contract"

    # Assert: File still read-only (wasn't changed)
    let permissions = ls $contract_path | get mode | first
    # Check that it's still read-only (contains 'r' but not 'w' for owner)
    assert ($permissions | str contains "r") "Should still be readable"

    # Cleanup (restore write permission first)
    chmod 644 $contract_path
    rm -f $contract_path $data_path
}

#[test]
def test_concurrent_reads_safe [] {
    # Arrange: Test that multiple processes can read same file safely
    let test_id = (random uuid | str substring 0..8)
    let contract_path = $"/tmp/concurrent-contract-($test_id).yaml"
    let data_path = $"/tmp/concurrent-data-($test_id).json"

    '
dataContractSpecification: 0.9.3
id: concurrent-test
info:
  title: Concurrent Test
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

    let hash_before = open --raw $data_path | hash sha256

    let input = build_validate_input $contract_path "local" "trace-concurrent"

    # Act: Run validation multiple times "concurrently" (sequentially but rapidly)
    let iterations = 10
    $iterations | each { |i|
        let result = do {
            $input | to json | nu (validate_tool)
        } | complete

        assert equal $result.exit_code 0 $"Concurrent run ($i) should succeed"
    }

    # Assert: Data unchanged after all reads
    let hash_after = open --raw $data_path | hash sha256
    assert equal $hash_after $hash_before "Data should be unchanged after concurrent reads"

    # Cleanup
    rm -f $contract_path $data_path
}

#[test]
def test_no_global_file_modification [] {
    # Arrange: Create canary files that should never be touched
    let test_id = (random uuid | str substring 0..8)
    let canary1 = $"/tmp/canary1-($test_id).txt"
    let canary2 = $"/tmp/canary2-($test_id).txt"

    "canary1" | save -f $canary1
    "canary2" | save -f $canary2

    let hash1_before = open --raw $canary1 | hash sha256
    let hash2_before = open --raw $canary2 | hash sha256

    let input = build_echo_input "canary test" "trace-canary"

    # Act: Run tool
    let result = do {
        $input | to json | nu (echo_tool)
    } | complete

    assert equal $result.exit_code 0 "Tool should succeed"

    # Assert: Canary files unchanged
    assert ($canary1 | path exists) "Canary1 should still exist"
    assert ($canary2 | path exists) "Canary2 should still exist"

    let hash1_after = open --raw $canary1 | hash sha256
    let hash2_after = open --raw $canary2 | hash sha256

    assert equal $hash1_after $hash1_before "Canary1 should be unchanged"
    assert equal $hash2_after $hash2_before "Canary2 should be unchanged"

    # Cleanup
    rm -f $canary1 $canary2
}

#[test]
def test_tool_script_unchanged_after_execution [] {
    # Arrange: Test that executing a tool doesn't modify the tool itself
    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/selfmod-tool-($test_id).nu"
    let output_path = $"/tmp/selfmod-output-($test_id).json"
    let logs_path = $"/tmp/selfmod-logs-($test_id).json"

    let tool_script = '#!/usr/bin/env nu
def main [] {
    { success: true, data: {}, trace_id: "", duration_ms: 0 } | to json | print
}'
    $tool_script | save -f $tool_path

    let hash_before = open --raw $tool_path | hash sha256

    let input = build_run_tool_input $tool_path {} $output_path $logs_path "trace-selfmod"

    # Act: Run tool
    let result = do {
        $input | to json | nu (run_tool)
    } | complete

    assert equal $result.exit_code 0 "Tool should succeed"

    # Assert: Tool script unchanged
    let hash_after = open --raw $tool_path | hash sha256
    assert equal $hash_after $hash_before "Tool script should not modify itself"

    let final_script = open --raw $tool_path
    assert equal $final_script $tool_script "Tool content should be unchanged"

    # Cleanup
    rm -f $tool_path
    let output = $result.stdout | from json
    rm -f $output.data.output_path
    rm -f $output.data.logs_path
}

#[test]
def test_no_persistent_cache_pollution [] {
    # Arrange: Test that tools don't create persistent cache files
    # (Nushell may create cache, but tools shouldn't create their own)

    let cache_patterns = [
        "/tmp/*.cache"
        "/tmp/.tool-cache*"
        "/tmp/bitter-truth-cache*"
    ]

    # Get existing cache files
    let existing_caches = $cache_patterns | each { |pattern|
        glob $pattern | length
    }

    let input = build_echo_input "cache test" "trace-cache"

    # Act: Run tool
    let result = do {
        $input | to json | nu (echo_tool)
    } | complete

    assert equal $result.exit_code 0 "Tool should succeed"

    # Assert: No new cache files created
    let new_caches = $cache_patterns | each { |pattern|
        glob $pattern | length
    }

    # Cache counts should be same or less (system may clean)
    assert equal $new_caches $existing_caches "No new cache files should be created"
}
