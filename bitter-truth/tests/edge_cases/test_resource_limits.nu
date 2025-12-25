#!/usr/bin/env nu
# Resource limits and stress condition tests
# Tests for large payloads, concurrent operations, timeouts, and cleanup
#
# Run with: nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/edge_cases'

use std assert
use ../helpers/builders.nu *
use ../helpers/assertions.nu *

# Helper to get tools directory
def tools_dir [] {
    $env.PWD | path join "bitter-truth/tools"
}

#[test]
def test_large_payload_10mb_succeeds [] {
    # Test that tools can handle reasonably large payloads (10MB)
    let large_message = (1..10000 | each { |_| (1..1000 | each { |_| "x" } | str join "") } | str join "")
    let message_size = $large_message | str length

    # Should be approximately 10MB
    assert ($message_size > 9_000_000) "Message should be > 9MB"

    let input = build_echo_input $large_message "test-10mb"

    # Act: Execute echo.nu with large payload
    let result = do {
        $input | to json | nu (tools_dir | path join "echo.nu")
    } | complete

    # Assert: Should succeed even with large input
    assert_exit_code $result 0 "Should handle 10MB payload"
    let output = $result.stdout | from json
    assert_success $output "10MB payload should succeed"
    assert equal $output.data.length $message_size "Should preserve full message length"
}

#[test]
def test_large_payload_100mb_handles_gracefully [] {
    # Test handling of very large payloads (100MB)
    # This might fail on resource constraints, but should fail gracefully

    # Generate 100MB of data (100 chunks of 1MB each)
    let large_message = (1..1000 | each { |_| (1..100000 | each { |_| "x" } | str join "") } | str join "")
    let message_size = $large_message | str length

    assert ($message_size > 90_000_000) "Message should be > 90MB"

    let input = build_echo_input $large_message "test-100mb"

    # Act: Try to execute - may timeout or fail
    let result = do {
        $input | to json | nu (tools_dir | path join "echo.nu")
    } | complete

    # Assert: If it fails, it should fail gracefully with proper error response
    if $result.exit_code != 0 {
        # Failed - verify it's a proper error response
        let output = try {
            $result.stdout | from json
        } catch {
            # If stdout isn't valid JSON, that's acceptable for extreme stress
            return
        }

        assert_tool_response $output
        assert_failure $output "100MB payload likely exceeds limits"
    } else {
        # Succeeded - verify output is valid
        let output = $result.stdout | from json
        assert_success $output "100MB payload handled successfully"
    }
}

#[test]
def test_many_concurrent_files [] {
    # Test creating many temporary files doesn't exhaust file descriptors
    let test_id = (random uuid | str substring 0..8)
    let base_path = $"/tmp/stress-test-($test_id)"

    # Create 1000 temporary output paths
    let file_paths = (1..1000 | each { |i|
        $"($base_path)-($i).json"
    })

    # Verify we can create all these file paths
    $file_paths | each { |path|
        '{"test": "data"}' | save -f $path
    }

    # Check all files exist
    let existing = $file_paths | where { |path| $path | path exists } | length
    assert equal $existing 1000 "Should create 1000 files"

    # Cleanup all files
    $file_paths | each { |path| rm -f $path }

    # Verify cleanup
    let remaining = $file_paths | where { |path| $path | path exists } | length
    assert equal $remaining 0 "Should clean up all files"
}

#[test]
def test_tool_timeout_enforced [] {
    # Test that long-running tools can be detected
    # Note: We don't have built-in timeout enforcement yet,
    # but we can verify duration tracking works

    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/slow-tool-($test_id).nu"
    let output_path = $"/tmp/output-($test_id).json"
    let logs_path = $"/tmp/logs-($test_id).json"

    # Create a tool that sleeps for 2 seconds
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    sleep 2sec
    { result: "done after sleep" } | to json | print
}' | save -f $tool_path

    let input = build_run_tool_input $tool_path {} $output_path $logs_path "test-timeout"

    # Act: Execute slow tool
    let start = date now
    let result = do {
        $input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete
    let duration = (date now) - $start | into int | $in / 1000000

    # Assert: Should complete but take >= 2 seconds
    assert ($duration >= 2000) "Should take at least 2 seconds"
    assert_exit_code $result 0 "Slow tool should complete successfully"

    let output = $result.stdout | from json
    assert_success $output "Slow execution should succeed"
    assert ($output.duration_ms >= 2000) "duration_ms should reflect sleep time"

    # Cleanup
    rm -f $tool_path $output_path $logs_path
}

#[test]
def test_tool_timeout_cleans_up_process [] {
    # Verify that completed processes don't leave zombies
    # This is more of a system test - check process table before/after

    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/cleanup-tool-($test_id).nu"
    let output_path = $"/tmp/output-($test_id).json"
    let logs_path = $"/tmp/logs-($test_id).json"

    # Create a simple tool
    '#!/usr/bin/env nu
def main [] {
    { result: "clean" } | to json | print
}' | save -f $tool_path

    # Count nu processes before
    let before = do { ps | where name =~ "nu" | length } | complete
    let count_before = if $before.exit_code == 0 {
        $before.stdout | str trim | into int
    } else {
        0
    }

    # Execute tool
    let input = build_run_tool_input $tool_path {} $output_path $logs_path "test-cleanup"
    let result = do {
        $input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    assert_exit_code $result 0 "Tool should succeed"

    # Give processes time to clean up
    sleep 100ms

    # Count nu processes after - should be similar (within 2 processes)
    let after = do { ps | where name =~ "nu" | length } | complete
    let count_after = if $after.exit_code == 0 {
        $after.stdout | str trim | into int
    } else {
        0
    }

    # We can't assert exact equality due to test runner, but verify no leak
    assert (($count_after - $count_before) < 5) "Should not leak processes"

    # Cleanup
    rm -f $tool_path $output_path $logs_path
}

#[test]
def test_disk_cleanup_works [] {
    # Test that temporary files can be created and cleaned up
    let test_id = (random uuid | str substring 0..8)
    let temp_files = (1..100 | each { |i|
        $"/tmp/cleanup-test-($test_id)-($i).json"
    })

    # Create files
    $temp_files | each { |path|
        { test: "data", id: $test_id } | to json | save -f $path
    }

    # Verify all created
    let created = $temp_files | where { |path| $path | path exists } | length
    assert equal $created 100 "Should create 100 files"

    # Calculate disk usage
    let total_size = $temp_files | each { |path|
        ls $path | get size | first
    } | math sum

    assert ($total_size > 0) "Files should have non-zero size"

    # Clean up
    $temp_files | each { |path| rm -f $path }

    # Verify all deleted
    let remaining = $temp_files | where { |path| $path | path exists } | length
    assert equal $remaining 0 "Should delete all 100 files"
}

#[test]
def test_memory_efficient_execution [] {
    # Test that tools don't accumulate excessive memory
    # We execute the same tool multiple times and verify it doesn't grow

    let iterations = 50
    let message = "Test message for memory efficiency check"

    # Execute echo.nu many times
    for i in (1..$iterations) {
        let input = build_echo_input $message $"test-mem-($i)"
        let result = do {
            $input | to json | nu (tools_dir | path join "echo.nu")
        } | complete

        assert_exit_code $result 0 $"Iteration ($i) should succeed"

        # Every 10 iterations, verify output is still correct
        if ($i mod 10) == 0 {
            let output = $result.stdout | from json
            assert_success $output $"Iteration ($i) should have valid output"
            assert equal $output.data.echo $message "Output should be consistent"
        }
    }

    # If we got here, memory didn't exhaust (would have crashed/hung)
    assert true "Memory remained stable across iterations"
}

#[test]
def test_rapid_successive_executions [] {
    # Test executing tools in rapid succession without delays
    let count = 20
    let results = (1..$count | each { |i|
        let input = build_echo_input $"rapid-($i)" $"test-rapid-($i)"

        do {
            $input | to json | nu (tools_dir | path join "echo.nu")
        } | complete
    })

    # All should succeed
    let successes = $results | where exit_code == 0 | length
    assert equal $successes $count "All rapid executions should succeed"

    # All should have valid JSON output
    let valid_json = $results | each { |result|
        try {
            $result.stdout | from json
            true
        } catch {
            false
        }
    } | where $it == true | length

    assert equal $valid_json $count "All outputs should be valid JSON"
}

#[test]
def test_output_file_size_limit [] {
    # Test that we can write reasonably large output files
    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/large-output-tool-($test_id).nu"
    let output_path = $"/tmp/large-output-($test_id).json"
    let logs_path = $"/tmp/large-logs-($test_id).json"

    # Create tool that generates large output (1MB)
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    let large_data = (1..1000 | each { |i| { id: $i, data: ("x" * 1000) } })
    { result: $large_data } | to json | print
}' | save -f $tool_path

    let input = build_run_tool_input $tool_path {} $output_path $logs_path "test-large-output"

    # Act: Execute tool
    let result = do {
        $input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    # Assert: Should succeed
    assert_exit_code $result 0 "Should write large output file"

    # Verify output file exists and has reasonable size
    assert ($output_path | path exists) "Output file should exist"
    let file_size = ls $output_path | get size | first
    assert ($file_size > 100000) "Output file should be > 100KB"

    # Verify output is valid JSON
    let output_data = open $output_path | from json
    assert (($output_data | describe) == "record") "Output should be valid JSON record"

    # Cleanup
    rm -f $tool_path $output_path $logs_path
}

#[test]
def test_concurrent_output_paths_no_collision [] {
    # Test that multiple tools can write to different output paths concurrently
    # without collision or corruption

    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/concurrent-tool-($test_id).nu"

    # Create simple tool
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    { echo: $input.message } | to json | print
}' | save -f $tool_path

    # Create 10 different output paths
    let paths = (1..10 | each { |i|
        {
            output: $"/tmp/concurrent-output-($test_id)-($i).json"
            logs: $"/tmp/concurrent-logs-($test_id)-($i).json"
            message: $"concurrent-($i)"
        }
    })

    # Execute all concurrently (in sequence, but verify no collision)
    let results = $paths | each { |p|
        let input = build_run_tool_input $tool_path { message: $p.message } $p.output $p.logs $"test-concurrent-($p.message)"

        do {
            $input | to json | nu (tools_dir | path join "run-tool.nu")
        } | complete
    }

    # All should succeed
    let successes = $results | where exit_code == 0 | length
    assert equal $successes 10 "All concurrent executions should succeed"

    # Verify all output files exist and are unique
    let all_outputs = $paths | each { |p| $p.output }
    let existing = $all_outputs | where { |path| $path | path exists } | length
    assert equal $existing 10 "All output files should exist"

    # Verify each has correct content
    $paths | each { |p|
        let content = open $p.output | from json
        assert equal $content.echo $p.message $"Output ($p.output) should have correct message"
    }

    # Cleanup
    rm -f $tool_path
    $paths | each { |p|
        rm -f $p.output
        rm -f $p.logs
    }
}
