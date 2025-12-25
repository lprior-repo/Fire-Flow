# Unit Tests for Fire-Flow

This directory contains comprehensive unit tests for the Fire-Flow bitter-truth system components.

## Test Files

### 1. test_json_parsing.nu (12 tests)
Tests JSON input parsing robustness across all tools:

- `test_parse_valid_json_succeeds` - Valid JSON is parsed correctly
- `test_parse_empty_stdin_fails_gracefully` - Empty stdin returns proper error
- `test_parse_malformed_json_returns_error_response` - Malformed JSON handled gracefully
- `test_parse_incomplete_json_fails` - Incomplete JSON fails appropriately
- `test_parse_json_with_unicode_succeeds` - Unicode characters preserved
- `test_parse_nested_json_succeeds` - Deeply nested structures handled
- `test_parse_large_json_succeeds` - Large payloads (100k+ chars) work
- `test_parse_circular_reference_fails` - Circular references prevented
- `test_parse_special_characters_in_json` - Special chars escaped correctly
- `test_parse_json_with_null_values` - Null values handled properly
- `test_parse_json_with_arrays` - Array values preserved
- `test_parse_json_only_whitespace_fails` - Whitespace-only input fails

### 2. test_error_handling.nu (13 tests)
Tests error response format consistency:

- `test_error_response_has_required_fields` - Error responses include success, error, trace_id, duration_ms
- `test_error_preserves_trace_id` - trace_id preserved in errors
- `test_error_includes_duration_ms` - All errors include timing
- `test_error_logs_to_stderr` - Errors logged as JSON to stderr
- `test_error_exits_with_correct_code` - Exit code 1 on errors
- `test_error_response_is_valid_json` - Error output is valid JSON
- `test_multiple_errors_accumulated` - Multiple validation errors handled
- `test_error_message_is_descriptive` - Error messages are clear
- `test_error_with_empty_trace_id` - Empty trace_id handled
- `test_error_response_format_consistency` - All tools use same format
- `test_json_parse_error_has_empty_trace_id` - Parse errors have empty trace_id
- `test_error_duration_is_monotonic` - duration_ms is positive and reasonable
- `test_stderr_contains_trace_id` - Logs include trace_id

### 3. test_exit_codes.nu (13 tests)
Tests exit code correctness:

- `test_success_exits_zero` - Success returns exit 0
- `test_failure_exits_one` - Failures return exit 1
- `test_validation_pass_exits_zero` - Validation success exits 0
- `test_validation_fail_exits_one` - Validation failure exits 1
- `test_tool_execution_error_propagates` - Tool errors propagate
- `test_input_error_exits_one` - Input validation errors exit 1
- `test_dry_run_always_exits_zero` - dry_run always succeeds
- `test_json_parse_error_exits_one` - JSON parse errors exit 1
- `test_tool_success_propagates` - Tool success propagates
- `test_missing_dependency_exits_one` - Missing dependencies fail
- `test_exit_code_matches_success_field` - exit_code matches success field
- `test_zero_exit_only_on_true_success` - Exit 0 only on real success
- `test_nonzero_exit_prevents_success_true` - Failures never have success=true

### 4. test_trace_id_propagation.nu (13 tests)
Tests observability and trace_id flow:

- `test_trace_id_passes_through_generate` - generate.nu preserves trace_id
- `test_trace_id_passes_through_run_tool` - run-tool.nu preserves trace_id
- `test_trace_id_passes_through_validate` - validate.nu preserves trace_id
- `test_trace_id_in_error_responses` - Errors include trace_id
- `test_trace_id_consistent_across_pipeline` - Same trace_id through pipeline
- `test_trace_id_in_all_log_levels` - All log lines include trace_id
- `test_empty_trace_id_is_preserved` - Empty string preserved
- `test_missing_trace_id_defaults_to_empty` - Missing defaults to ""
- `test_trace_id_with_special_characters` - Special chars in trace_id work
- `test_trace_id_in_nested_tool_calls` - Nested calls preserve trace_id
- `test_trace_id_length_preserved` - Any length trace_id works
- `test_trace_id_in_concurrent_calls` - Concurrent calls keep separate trace_ids
- `test_trace_id_appears_in_every_stderr_line` - Every log has trace_id

## Total: 51 Unit Tests

## Running Tests

### Run All Unit Tests

```bash
nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/unit'
```

### Run Specific Test File

```bash
nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/unit/test_json_parsing.nu'
```

### Run Individual Test

```bash
nu -c 'source bitter-truth/tests/unit/test_json_parsing.nu; test_parse_valid_json_succeeds'
```

## Test Patterns

All tests follow the AAA (Arrange-Act-Assert) pattern:

```nushell
#[test]
def test_example [] {
    # Arrange: Set up test data
    let input = { ... }

    # Act: Execute the code under test
    let result = do {
        $input | to json | nu tools/some-tool.nu
    } | complete

    # Assert: Verify expectations
    assert equal $result.exit_code 0 "Should succeed"
    let output = $result.stdout | from json
    assert equal $output.success true "Should have success=true"
}
```

## Test Isolation

- Tests use UUID-based temporary files to avoid conflicts
- All tests clean up their temporary files
- Tests can run in parallel safely
- No shared state between tests

## Coverage

These unit tests validate:

1. **JSON Parsing**: Input validation and error handling
2. **Error Responses**: Consistent error format across all tools
3. **Exit Codes**: Correct exit codes for success/failure
4. **Observability**: trace_id propagation for distributed tracing

All four core tools are tested:
- `echo.nu` - Simple proof of concept
- `run-tool.nu` - Tool execution wrapper
- `validate.nu` - Contract validation
- `generate.nu` - AI code generation

## Design Principles

1. **Isolation**: Each test is independent
2. **Clarity**: Descriptive test names and failure messages
3. **Completeness**: Test both happy path and error cases
4. **Consistency**: All tests follow same patterns
5. **Cleanup**: All tests clean up resources
6. **Speed**: Tests use dry_run mode where possible

## Next Steps

After unit tests pass, run integration tests:
```bash
nu bitter-truth/tests/test_integration.nu
```

For full system testing with Kestra:
```bash
nu bitter-truth/tests/test_kestra_workflow_real.nu
```
