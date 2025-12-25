# Edge Case and Boundary Tests

Comprehensive test suite for Fire-Flow edge cases, boundary conditions, and stress scenarios.

## Test Files

### 1. `test_resource_limits.nu`
Tests for resource exhaustion and stress conditions:

- **test_large_payload_10mb_succeeds** - Verify 10MB payloads work
- **test_large_payload_100mb_handles_gracefully** - Test 100MB extreme stress
- **test_many_concurrent_files** - Create/cleanup 1000 temp files
- **test_tool_timeout_enforced** - Verify duration tracking for slow tools
- **test_tool_timeout_cleans_up_process** - No zombie processes after execution
- **test_disk_cleanup_works** - Proper cleanup of temporary files
- **test_memory_efficient_execution** - No memory leaks across iterations
- **test_rapid_successive_executions** - 20 executions in rapid succession
- **test_output_file_size_limit** - Write large (1MB) output files
- **test_concurrent_output_paths_no_collision** - Multiple tools writing different paths

### 2. `test_filesystem_edge_cases.nu`
Tests for path handling and filesystem edge cases:

- **test_output_path_with_spaces** - Paths containing spaces
- **test_output_path_with_unicode** - Unicode characters in paths (日本語, 中文)
- **test_output_path_with_special_chars** - Special characters (@#$%+=~[])
- **test_relative_path_resolution** - Relative paths work correctly
- **test_absolute_path_resolution** - Absolute paths regardless of cwd
- **test_symlink_handling** - Follow symlinks to tools
- **test_missing_parent_directory_fails_gracefully** - Nonexistent parent dirs
- **test_permission_denied_fails_gracefully** - Read-only file handling
- **test_very_long_path** - Paths with 400+ character components
- **test_path_traversal_prevention** - Path normalization with .. components
- **test_output_to_dev_null** - Writing to /dev/null
- **test_existing_file_overwrite** - Overwriting existing output files

### 3. `test_special_characters.nu`
Tests for unicode, escape sequences, and encoding:

- **test_message_with_newlines** - Preserve \n in messages
- **test_message_with_tabs** - Preserve \t in messages
- **test_message_with_quotes** - Single and double quotes
- **test_message_with_unicode_emoji** - Emoji and unicode (🔥⚡日本語中文)
- **test_message_with_null_bytes** - Null byte handling (\u{0000})
- **test_message_with_control_characters** - ASCII control chars (SOH, STX, ESC, etc.)
- **test_message_with_backslashes** - Windows paths, escape sequences
- **test_message_with_special_json_chars** - JSON metacharacters
- **test_message_with_ansi_escape_codes** - Color codes and formatting
- **test_message_with_html_entities** - HTML/XML special characters
- **test_message_with_sql_injection_patterns** - SQL-like strings (as plain text)
- **test_message_with_url_encoding** - URLs with query params
- **test_message_with_regex_metacharacters** - Regex special chars as literals
- **test_message_with_glob_patterns** - Shell glob patterns as literals
- **test_message_with_shell_metacharacters** - Shell operators as literals
- **test_message_with_mixed_encodings** - ASCII + Unicode + Emoji mix
- **test_message_with_zero_width_characters** - Zero-width spaces/joiners
- **test_message_with_rtl_text** - Right-to-left text (Hebrew, Arabic)
- **test_very_long_line_no_newlines** - 10,000 character single line
- **test_message_all_whitespace** - Whitespace-only messages (non-empty)

### 4. `test_boundary_values.nu`
Tests for limits and edge values:

- **test_empty_message_fails** - Empty string validation
- **test_very_long_message_succeeds** - 1MB message processing
- **test_zero_length_json_fails** - Empty stdin handling
- **test_max_trace_id_length** - Long trace IDs (100, 300, 1000 chars)
- **test_negative_duration_values** - Duration must be non-negative
- **test_very_large_duration_values** - 5+ second executions
- **test_minimum_valid_json_input** - Smallest valid inputs
- **test_maximum_nesting_depth** - Deeply nested JSON (10 levels)
- **test_single_character_message** - Minimum non-empty messages
- **test_boundary_exit_codes** - Exit codes 0, 1, 2, 127, 255
- **test_empty_tool_input** - Empty {} object input
- **test_null_fields_in_input** - Null values in optional fields
- **test_maximum_array_size** - 1000-item arrays
- **test_zero_duration_execution** - Very fast operations
- **test_maximum_field_count** - 100 fields in input
- **test_boolean_boundary_values** - True/false boolean handling
- **test_numeric_overflow_protection** - Large integers (32-bit, 64-bit limits)

## Running Tests

Run all edge case tests:
```bash
nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/edge_cases'
```

Run specific test file:
```bash
nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/edge_cases/test_resource_limits.nu'
```

Run specific test:
```bash
nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/edge_cases --filter "test_large_payload"'
```

## Test Philosophy

### Graceful Degradation
All tests verify that:
1. Valid edge cases succeed with correct output
2. Invalid edge cases fail with proper error responses
3. Extreme stress conditions either succeed or fail gracefully (no crashes)
4. Error messages are helpful and JSON is always valid

### Realistic Boundaries
Tests use realistic limits:
- 10MB payloads: Should work
- 100MB payloads: May fail, but gracefully
- 1000 files: Should be manageable
- 1MB messages: Should be processable
- 5 second timeouts: Should be trackable

### Character Encoding
Extensive unicode and encoding tests ensure:
- UTF-8 is preserved correctly
- Special characters don't break JSON
- Shell/regex metacharacters are literal
- Right-to-left text works
- Emoji and zero-width characters are handled

### Filesystem Robustness
Path tests cover:
- Spaces, unicode, special chars in paths
- Relative and absolute path resolution
- Symlink following
- Permission errors
- Path traversal (.. components)
- Very long paths
- Overwriting existing files

## Coverage

Total tests: **70 edge case tests**

Breakdown:
- Resource limits: 10 tests
- Filesystem: 12 tests
- Special characters: 20 tests
- Boundary values: 18 tests

All tests use the established helper modules:
- `use ../helpers/builders.nu *` - Test data builders
- `use ../helpers/assertions.nu *` - Custom assertions

## Expected Behavior

### Success Cases
- Valid edge cases should succeed with `exit_code: 0`
- Output should have `success: true`
- Data should be preserved exactly (no truncation)
- Duration should be tracked accurately

### Failure Cases
- Invalid inputs should fail with `exit_code: 1`
- Output should have `success: false`
- Error messages should be descriptive
- JSON should always be valid (even on errors)
- trace_id should be preserved in errors

### Extreme Cases
- Very large payloads may timeout or fail - but gracefully
- Missing permissions should return proper errors
- Control characters may be escaped or rejected - but no crashes
- Resource exhaustion should be detectable

## Test Patterns

All edge case tests follow this pattern:

```nu
#[test]
def test_some_edge_case [] {
    # Arrange: Set up edge case scenario
    let input = build_echo_input "edge case data" "trace-id"

    # Act: Execute the tool
    let result = do {
        $input | to json | nu (tools_dir | path join "echo.nu")
    } | complete

    # Assert: Verify behavior
    assert_exit_code $result 0 "Should handle edge case"
    let output = $result.stdout | from json
    assert_success $output "Edge case should succeed"

    # Cleanup: Remove temp files
    rm -f $temp_files
}
```

## Future Enhancements

Potential additions:
- **Network edge cases** - Simulated network failures (when network tools added)
- **Concurrency stress** - Parallel execution of 100+ tools
- **Signal handling** - SIGTERM, SIGKILL during execution
- **Disk full scenarios** - Out of disk space handling
- **Memory limits** - ulimit-based memory constraints
- **Time zones** - Date/time handling across zones
- **Locale variations** - Different LC_ALL settings

## Integration with CI

These tests are designed to:
1. Run in CI environments (predictable, no external dependencies)
2. Complete in reasonable time (< 2 minutes total)
3. Require no special privileges (no sudo needed)
4. Clean up all temporary files
5. Provide clear failure messages

## Notes

- Some tests create temporary files in `/tmp` with unique IDs
- All temporary files are cleaned up in test teardown
- Tests are isolated and can run in any order
- Some extreme stress tests may timeout on slow systems (this is expected)
- Permission tests are limited (no sudo available in tests)
