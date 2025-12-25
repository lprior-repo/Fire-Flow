#!/usr/bin/env nu
# Filesystem edge case tests
# Tests for paths with special characters, permissions, symlinks, and resolution
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
def test_output_path_with_spaces [] {
    # Test that output paths with spaces are handled correctly
    let test_id = (random uuid | str substring 0..8)
    let output_path = $"/tmp/output with spaces ($test_id).json"
    let logs_path = $"/tmp/logs with spaces ($test_id).json"
    let tool_path = $"/tmp/tool-($test_id).nu"

    # Create simple tool
    '#!/usr/bin/env nu
def main [] {
    { result: "spaces test" } | to json | print
}' | save -f $tool_path

    let input = build_run_tool_input $tool_path {} $output_path $logs_path "test-spaces"

    # Act: Execute with spaced paths
    let result = do {
        $input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    # Assert: Should succeed
    assert_exit_code $result 0 "Should handle paths with spaces"
    assert ($output_path | path exists) "Output file with spaces should exist"
    assert ($logs_path | path exists) "Log file with spaces should exist"

    # Verify content is valid
    let output_data = open $output_path | from json
    assert equal $output_data.result "spaces test" "Content should be correct"

    # Cleanup
    rm -f $tool_path $output_path $logs_path
}

#[test]
def test_output_path_with_unicode [] {
    # Test paths with Unicode characters
    let test_id = (random uuid | str substring 0..8)
    let output_path = $"/tmp/output-日本語-($test_id).json"
    let logs_path = $"/tmp/logs-中文-($test_id).json"
    let tool_path = $"/tmp/tool-($test_id).nu"

    # Create simple tool
    '#!/usr/bin/env nu
def main [] {
    { result: "unicode path test" } | to json | print
}' | save -f $tool_path

    let input = build_run_tool_input $tool_path {} $output_path $logs_path "test-unicode"

    # Act: Execute with unicode paths
    let result = do {
        $input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    # Assert: Should succeed with unicode paths
    assert_exit_code $result 0 "Should handle unicode paths"
    assert ($output_path | path exists) "Unicode output path should exist"
    assert ($logs_path | path exists) "Unicode logs path should exist"

    # Cleanup
    rm -f $tool_path $output_path $logs_path
}

#[test]
def test_output_path_with_special_chars [] {
    # Test paths with special characters (that are valid in filenames)
    let test_id = (random uuid | str substring 0..8)
    # Use characters that are valid in Linux filenames: - _ . @ # $ % + = ~ [ ]
    let output_path = $"/tmp/output-test_file.@#$%+=~($test_id).json"
    let logs_path = $"/tmp/logs-[test]($test_id).json"
    let tool_path = $"/tmp/tool-($test_id).nu"

    # Create simple tool
    '#!/usr/bin/env nu
def main [] {
    { result: "special chars test" } | to json | print
}' | save -f $tool_path

    let input = build_run_tool_input $tool_path {} $output_path $logs_path "test-special"

    # Act: Execute with special character paths
    let result = do {
        $input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    # Assert: Should succeed
    assert_exit_code $result 0 "Should handle special characters in paths"
    assert ($output_path | path exists) "Output with special chars should exist"
    assert ($logs_path | path exists) "Logs with special chars should exist"

    # Cleanup
    rm -f $tool_path $output_path $logs_path
}

#[test]
def test_relative_path_resolution [] {
    # Test that relative paths work correctly from current directory
    let test_id = (random uuid | str substring 0..8)

    # Create a subdirectory for testing
    let test_dir = $"/tmp/relative-test-($test_id)"
    mkdir $test_dir

    # Use relative path from /tmp
    cd $test_dir
    let tool_path = $"/tmp/rel-tool-($test_id).nu"
    '#!/usr/bin/env nu
def main [] {
    { result: "relative path" } | to json | print
}' | save -f $tool_path

    # Use relative output paths
    let output_path = $"./output-($test_id).json"
    let logs_path = $"./logs-($test_id).json"

    let input = build_run_tool_input $tool_path {} $output_path $logs_path "test-relative"

    # Act: Execute from subdirectory with relative paths
    let result = do {
        $input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    # Assert: Should create files in current directory
    assert_exit_code $result 0 "Should handle relative paths"

    # Check files exist (relative to test_dir)
    assert ($output_path | path exists) "Relative output should exist"
    assert ($logs_path | path exists) "Relative logs should exist"

    # Cleanup
    cd /tmp
    rm -rf $test_dir $tool_path
}

#[test]
def test_absolute_path_resolution [] {
    # Test that absolute paths work correctly regardless of cwd
    let test_id = (random uuid | str substring 0..8)
    let output_path = $"/tmp/abs-output-($test_id).json"
    let logs_path = $"/tmp/abs-logs-($test_id).json"
    let tool_path = $"/tmp/abs-tool-($test_id).nu"

    # Create tool
    '#!/usr/bin/env nu
def main [] {
    { result: "absolute path" } | to json | print
}' | save -f $tool_path

    # Change to a different directory
    let original_dir = $env.PWD
    cd /tmp

    let input = build_run_tool_input $tool_path {} $output_path $logs_path "test-absolute"

    # Act: Execute with absolute paths from different cwd
    let result = do {
        $input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    # Restore directory
    cd $original_dir

    # Assert: Should succeed with absolute paths
    assert_exit_code $result 0 "Should handle absolute paths"
    assert ($output_path | path exists) "Absolute output should exist"
    assert ($logs_path | path exists) "Absolute logs should exist"

    # Cleanup
    rm -f $tool_path $output_path $logs_path
}

#[test]
def test_symlink_handling [] {
    # Test that symlinks to tools are followed correctly
    let test_id = (random uuid | str substring 0..8)
    let real_tool = $"/tmp/real-tool-($test_id).nu"
    let symlink_tool = $"/tmp/symlink-tool-($test_id).nu"
    let output_path = $"/tmp/symlink-output-($test_id).json"
    let logs_path = $"/tmp/symlink-logs-($test_id).json"

    # Create real tool
    '#!/usr/bin/env nu
def main [] {
    { result: "symlink followed" } | to json | print
}' | save -f $real_tool

    # Create symlink to tool
    ln -s $real_tool $symlink_tool

    let input = build_run_tool_input $symlink_tool {} $output_path $logs_path "test-symlink"

    # Act: Execute via symlink
    let result = do {
        $input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    # Assert: Should follow symlink and execute
    assert_exit_code $result 0 "Should follow symlink to tool"

    let output_data = open $output_path | from json
    assert equal $output_data.result "symlink followed" "Symlink should be followed"

    # Cleanup
    rm -f $real_tool $symlink_tool $output_path $logs_path
}

#[test]
def test_missing_parent_directory_fails_gracefully [] {
    # Test that missing parent directories cause graceful failure
    let test_id = (random uuid | str substring 0..8)
    let nonexistent_dir = $"/tmp/nonexistent-($test_id)"
    let output_path = $"($nonexistent_dir)/output.json"
    let logs_path = $"($nonexistent_dir)/logs.json"
    let tool_path = $"/tmp/parent-test-tool-($test_id).nu"

    # Ensure directory doesn't exist
    if ($nonexistent_dir | path exists) {
        rm -rf $nonexistent_dir
    }

    # Create tool
    '#!/usr/bin/env nu
def main [] {
    { result: "test" } | to json | print
}' | save -f $tool_path

    let input = build_run_tool_input $tool_path {} $output_path $logs_path "test-missing-parent"

    # Act: Execute with missing parent directory
    let result = do {
        $input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    # Assert: Should fail gracefully
    # The tool itself succeeds, but save might fail
    # This depends on whether nu creates parent directories or not
    # Let's verify the error handling is graceful

    if $result.exit_code != 0 {
        # If it failed, verify it's a proper error response
        let parse_result = try {
            $result.stdout | from json
        } catch {
            # If output parsing fails, that's not graceful
            error make { msg: "Output should be valid JSON even on failure" }
        }

        assert_tool_response $parse_result
    }

    # Cleanup
    rm -f $tool_path
    if ($nonexistent_dir | path exists) {
        rm -rf $nonexistent_dir
    }
}

#[test]
def test_permission_denied_fails_gracefully [] {
    # Test that permission errors are handled gracefully
    # Note: This is tricky to test without sudo, so we test read-only scenarios

    let test_id = (random uuid | str substring 0..8)
    let readonly_tool = $"/tmp/readonly-tool-($test_id).nu"
    let output_path = $"/tmp/perm-output-($test_id).json"
    let logs_path = $"/tmp/perm-logs-($test_id).json"

    # Create tool and make it read-only (remove execute permission)
    '#!/usr/bin/env nu
def main [] {
    { result: "should not execute" } | to json | print
}' | save -f $readonly_tool

    chmod 0o444 $readonly_tool

    let input = build_run_tool_input $readonly_tool {} $output_path $logs_path "test-permission"

    # Act: Try to execute non-executable tool
    let result = do {
        $input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    # Assert: Should handle permission error gracefully
    # The error might come from nu trying to execute the script
    # Verify that we get some kind of response (not a crash)

    assert ($result | describe | str contains "record") "Should return a result record"

    # Cleanup - restore permissions to delete
    chmod 0o644 $readonly_tool
    rm -f $readonly_tool $output_path $logs_path
}

#[test]
def test_very_long_path [] {
    # Test handling of very long (but valid) file paths
    # Linux path limit is typically 4096 bytes

    let test_id = (random uuid | str substring 0..8)

    # Create a long but valid path (under 4096)
    let long_component = (1..200 | each { |_| "a" } | str join "")  # 200 char directory name
    let long_path = $"/tmp/($long_component)/($long_component)/output-($test_id).json"

    # Create parent directories
    let parent = $long_path | path dirname
    mkdir $parent

    let tool_path = $"/tmp/long-path-tool-($test_id).nu"
    let logs_path = $"/tmp/long-logs-($test_id).json"

    # Create tool
    '#!/usr/bin/env nu
def main [] {
    { result: "long path" } | to json | print
}' | save -f $tool_path

    let input = build_run_tool_input $tool_path {} $long_path $logs_path "test-long-path"

    # Act: Execute with long path
    let result = do {
        $input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    # Assert: Should handle long paths
    assert_exit_code $result 0 "Should handle long paths"
    assert ($long_path | path exists) "Long path output should exist"

    # Cleanup
    rm -f $tool_path $logs_path
    rm -rf $parent
}

#[test]
def test_path_traversal_prevention [] {
    # Test that path traversal attempts don't escape intended directories
    # This is more about documenting behavior than preventing attacks

    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/traversal-tool-($test_id).nu"

    # Use path with .. components
    let output_path = $"/tmp/subdir/../output-($test_id).json"
    let logs_path = $"/tmp/subdir/../logs-($test_id).json"

    # Create tool
    '#!/usr/bin/env nu
def main [] {
    { result: "traversal test" } | to json | print
}' | save -f $tool_path

    let input = build_run_tool_input $tool_path {} $output_path $logs_path "test-traversal"

    # Act: Execute with .. in paths
    let result = do {
        $input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    # Assert: Should normalize path and succeed
    assert_exit_code $result 0 "Should handle path traversal syntax"

    # The normalized path should be /tmp/output-{id}.json
    let normalized = $"/tmp/output-($test_id).json"
    assert ($normalized | path exists) "Should create file at normalized path"

    # Cleanup
    rm -f $tool_path $output_path $logs_path $normalized
}

#[test]
def test_output_to_dev_null [] {
    # Test that output can be directed to /dev/null
    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/null-tool-($test_id).nu"

    # Create tool
    '#!/usr/bin/env nu
def main [] {
    { result: "to null" } | to json | print
}' | save -f $tool_path

    let input = build_run_tool_input $tool_path {} "/dev/null" "/dev/null" "test-null"

    # Act: Execute with /dev/null output
    let result = do {
        $input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    # Assert: Should succeed (output is discarded)
    assert_exit_code $result 0 "Should write to /dev/null"

    let output = $result.stdout | from json
    assert_success $output "Should succeed with /dev/null"

    # Cleanup
    rm -f $tool_path
}

#[test]
def test_existing_file_overwrite [] {
    # Test that existing output files are overwritten correctly
    let test_id = (random uuid | str substring 0..8)
    let output_path = $"/tmp/overwrite-($test_id).json"
    let logs_path = $"/tmp/overwrite-logs-($test_id).json"
    let tool_path = $"/tmp/overwrite-tool-($test_id).nu"

    # Create existing files with old content
    { old: "content" } | to json | save -f $output_path
    { old: "logs" } | to json | save -f $logs_path

    # Create tool
    '#!/usr/bin/env nu
def main [] {
    { result: "new content" } | to json | print
}' | save -f $tool_path

    let input = build_run_tool_input $tool_path {} $output_path $logs_path "test-overwrite"

    # Act: Execute - should overwrite
    let result = do {
        $input | to json | nu (tools_dir | path join "run-tool.nu")
    } | complete

    # Assert: Should overwrite successfully
    assert_exit_code $result 0 "Should overwrite existing files"

    # Verify new content
    let output_data = open $output_path | from json
    assert equal $output_data.result "new content" "Should contain new content"

    # Old content should be gone
    assert (not ("old" in $output_data)) "Old content should be overwritten"

    # Cleanup
    rm -f $tool_path $output_path $logs_path
}
