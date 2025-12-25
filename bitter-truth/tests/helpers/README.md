# Test Helpers Documentation

## Overview

This directory contains test infrastructure for Fire-Flow's bitter-truth system. All helpers follow these principles:

1. **UUID-based isolation** - Each test gets unique IDs to prevent conflicts
2. **Immutable fixtures** - Test data is read-only and loaded fresh each time
3. **Structured returns** - All functions return data, never print
4. **Thread-safe** - Designed for parallel test execution
5. **Error handling** - Clear error messages with context

## Files

### constants.nu

Shared constants across all tests. Import with:

```nushell
use helpers/constants.nu *
```

**Exports:**
- `TOOLS_DIR` - Path to bitter-truth/tools
- `CONTRACTS_DIR` - Path to bitter-truth/contracts
- `TESTS_DIR` - Path to bitter-truth/tests
- `FIXTURES_DIR` - Path to bitter-truth/tests/fixtures
- `COMMON_CONTRACT` - Path to common.yaml contract
- `ECHO_CONTRACT` - Path to echo.yaml contract
- `ECHO_TOOL`, `RUN_TOOL`, `GENERATE_TOOL`, `VALIDATE_TOOL` - Tool paths
- `DEFAULT_TIMEOUT_MS`, `TEST_TRACE_PREFIX`, `TMP_DIR` - Test defaults

### fixtures.nu

Fixture loading and temporary file management.

```nushell
use helpers/fixtures.nu *
```

**Key Functions:**

```nushell
# Generate unique test ID
let id = get_test_id  # "a3f7b2c1"

# Create temp files (auto-tracked for cleanup)
let tool = create_temp_file "nu" "echo"     # /tmp/echo-a3f7b2c1.nu
let json = create_temp_file "json"          # /tmp/test-a3f7b2c1.json

# Load fixtures from fixtures/ directory
let tool_code = load_fixture "tools" "echo-correct"  # loads fixtures/tools/echo-correct.*
let input_data = load_fixture "inputs" "echo-valid"  # loads fixtures/inputs/echo-valid.json

# Check fixture exists
if (fixture_exists "tools" "my-tool") { ... }

# Helpers for common patterns
let tool_path = create_temp_tool $code "my-tool"
let json_path = create_temp_json { message: "test" } "input"

# Cleanup (call at end of test)
cleanup_temp_files
```

**Fixture Directory Structure:**

```
fixtures/
├── tools/          # Tool scripts (.nu files)
├── inputs/         # Input JSON files
├── contracts/      # Contract YAML files
└── outputs/        # Expected output JSON files
```

### builders.nu

Build test data with sensible defaults.

```nushell
use helpers/builders.nu *
```

**Key Functions:**

```nushell
# Build execution context
let ctx = build_context "trace-1" false 30  # trace_id, dry_run, timeout
let ctx = build_context                      # auto-generates trace_id

# Build tool inputs
let input = build_echo_input "hello world"
let input = build_echo_input "test" "trace-1" true  # with trace_id and dry_run

let input = build_run_tool_input $tool_path $data
let input = build_run_tool_input $tool_path $data $out_path $logs_path "trace-1"

let input = build_generate_input $contract "create echo tool"
let input = build_validate_input $contract "local"

# Build complete test context (all paths pre-generated)
let ctx = build_test_context
# Returns:
# {
#   test_id: "a3f7b2c1"
#   trace_id: "test-a3f7b2c1"
#   tool_path: "/tmp/tool-a3f7b2c1.nu"
#   output_path: "/tmp/output-a3f7b2c1.json"
#   logs_path: "/tmp/logs-a3f7b2c1.json"
#   generated_path: "/tmp/generated-a3f7b2c1.nu"
#   input_path: "/tmp/input-a3f7b2c1.json"
# }

# Build ToolResponse wrappers
let success = build_success_response { echo: "hello" } "trace-1" 42
let failure = build_error_response "failed" "trace-1" 10
```

### assertions.nu

Specialized assertions for bitter-truth testing.

```nushell
use helpers/assertions.nu *
use std assert
```

**Key Assertions:**

```nushell
# Validate ToolResponse structure
let response = $result.stdout | from json
assert_tool_response $response

# Contract validation (runs validate.nu)
assert_contract_valid "/tmp/output.json" "/path/contract.yaml"

# File existence
assert_files_exist ["/tmp/output.json", "/tmp/logs.json"]

# JSON validation
let data = assert_json_valid "/tmp/output.json"

# Exit codes
assert_exit_code $result 0 "Tool should succeed"
assert_completed_successfully $result

# Trace ID propagation
assert_trace_id_propagated $response "test-123"

# Success/failure
assert_success $response "Echo should succeed"
assert_failure $response "Invalid input should fail"
assert_error_contains $response "message is required"

# Data fields
assert_data_fields $response ["echo", "reversed", "length"]

# Duration checks
assert_duration_reasonable $response 5000  # max 5 seconds

# Deep equality
assert_json_equals $actual $expected
```

## Usage Patterns

### Basic Test Pattern

```nushell
#!/usr/bin/env nu
use std assert
use helpers/constants.nu *
use helpers/fixtures.nu *
use helpers/builders.nu *
use helpers/assertions.nu *

#[test]
def "test_echo_tool_with_valid_input" [] {
    # Arrange
    init_temp_tracker
    let ctx = build_test_context
    let input = build_echo_input "hello world" $ctx.trace_id

    # Act
    let result = $input | to json | nu $ECHO_TOOL | complete

    # Assert
    assert_completed_successfully $result
    let response = $result.stdout | from json
    assert_success $response
    assert_trace_id_propagated $response $ctx.trace_id
    assert_data_fields $response ["echo", "reversed", "length"]

    # Cleanup
    cleanup_temp_files
}
```

### Fixture-Based Test

```nushell
#[test]
def "test_with_fixture_tool" [] {
    # Arrange
    init_temp_tracker
    let tool_code = load_fixture "tools" "echo-correct"
    let tool_path = create_temp_tool $tool_code "echo"

    let input_data = load_fixture "inputs" "echo-valid"
    let ctx = build_test_context

    # Act
    let run_input = build_run_tool_input $tool_path $input_data $ctx.output_path $ctx.logs_path
    let result = $run_input | to json | nu $RUN_TOOL | complete

    # Assert
    assert_completed_successfully $result
    assert_files_exist [$ctx.output_path, $ctx.logs_path]

    let output = assert_json_valid $ctx.output_path
    assert_success $output

    # Cleanup
    cleanup_temp_files
}
```

### Contract Validation Test

```nushell
#[test]
def "test_output_conforms_to_contract" [] {
    # Arrange
    init_temp_tracker
    let ctx = build_test_context
    let expected_output = { success: true, data: { echo: "test" } }

    $expected_output | to json | save -f $ctx.output_path

    # Act & Assert - will fail if output doesn't match contract
    assert_contract_valid $ctx.output_path $ECHO_CONTRACT

    # Cleanup
    cleanup_temp_files
}
```

### Parallel Test Safety

All helpers use UUID-based isolation, so tests can run in parallel:

```nushell
#[test]
def "test_1" [] {
    let ctx = build_test_context  # unique ID: a3f7b2c1
    # ... test with ctx.output_path = /tmp/output-a3f7b2c1.json
}

#[test]
def "test_2" [] {
    let ctx = build_test_context  # unique ID: f9e4d8a2
    # ... test with ctx.output_path = /tmp/output-f9e4d8a2.json
}
```

## Design Principles

### 1. Immutable Fixtures

Fixtures are read-only and loaded fresh each time:

```nushell
# Good - loads fresh copy
let tool = load_fixture "tools" "echo"

# Bad - modifying shared state
$SHARED_TOOL_CODE = ...  # Don't do this
```

### 2. UUID-Based Isolation

Every test gets unique file paths:

```nushell
# Good - unique per test
let ctx = build_test_context
let output = $ctx.output_path  # /tmp/output-a3f7b2c1.json

# Bad - hardcoded paths (test conflicts)
let output = "/tmp/output.json"  # Don't do this
```

### 3. Structured Returns

All helpers return data, never print:

```nushell
# Good
export def get_test_id [] {
    random uuid | str substring 0..8
}

# Bad
export def get_test_id [] {
    let id = random uuid | str substring 0..8
    print $id  # Don't do this
}
```

### 4. Error Handling

Use `error make` with context:

```nushell
if not ($path | path exists) {
    error make {
        msg: $"File not found: ($path)"
        label: {
            text: "Path does not exist"
            span: (metadata $path).span
        }
    }
}
```

### 5. Thread Safety

No global mutable state - use environment variables for tracking:

```nushell
# Good - environment scoped
$env.TEMP_FILES = []

# Bad - global mutable
mut TEMP_FILES = []  # Shared across all tests
```

## Adding New Fixtures

1. Create fixture file in appropriate subdirectory:
   ```bash
   echo $'...' | save fixtures/tools/my-tool.nu
   echo '{"message": "test"}' | save fixtures/inputs/my-input.json
   ```

2. Load in tests:
   ```nushell
   let tool = load_fixture "tools" "my-tool"
   let input = load_fixture "inputs" "my-input"
   ```

## Adding New Assertions

Follow the pattern:

```nushell
export def assert_my_thing [
    data: record
    expected: string
] {
    # Validate input
    assert ("field" in $data) "data must have field"

    # Perform assertion
    assert equal $data.field $expected $"Custom message with ($data.field)"
}
```

## Common Patterns

### Test Template

```nushell
#!/usr/bin/env nu
use std assert
use helpers/constants.nu *
use helpers/fixtures.nu *
use helpers/builders.nu *
use helpers/assertions.nu *

#[test]
def "behavior_under_test" [] {
    # Arrange
    init_temp_tracker
    let ctx = build_test_context
    # ... setup

    # Act
    # ... execute

    # Assert
    # ... verify

    # Cleanup
    cleanup_temp_files
}
```

### Error Testing

```nushell
#[test]
def "test_handles_error_gracefully" [] {
    init_temp_tracker
    let input = build_echo_input ""  # empty message

    let result = $input | to json | nu $ECHO_TOOL | complete

    assert_exit_code $result 1  # expect failure
    let response = $result.stdout | from json
    assert_failure $response
    assert_error_contains $response "message is required"

    cleanup_temp_files
}
```

### Integration Testing

```nushell
#[test]
def "test_full_pipeline" [] {
    init_temp_tracker
    let ctx = build_test_context

    # Generate
    let gen_input = build_generate_input $ECHO_CONTRACT "create echo tool" $ctx.generated_path
    let gen_result = $gen_input | to json | nu $GENERATE_TOOL | complete
    assert_completed_successfully $gen_result

    # Execute
    let run_input = build_run_tool_input $ctx.generated_path { message: "test" }
    let run_result = $run_input | to json | nu $RUN_TOOL | complete
    assert_completed_successfully $run_result

    # Validate
    assert_contract_valid $run_result.data.output_path $ECHO_CONTRACT

    cleanup_temp_files
}
```

## Troubleshooting

### Tests Interfering With Each Other

**Symptom:** Tests pass individually but fail when run together.

**Solution:** Ensure using `build_test_context` or `create_temp_file` for all paths:

```nushell
# Bad - hardcoded paths
let output = "/tmp/output.json"

# Good - unique paths
let ctx = build_test_context
let output = $ctx.output_path
```

### Fixture Not Found

**Symptom:** `error: Fixture not found: tools/my-tool`

**Solution:** Check fixture exists with correct extension:

```nushell
ls fixtures/tools/  # verify file exists
fixture_exists "tools" "my-tool"  # returns true/false
```

### Temp Files Not Cleaned Up

**Symptom:** `/tmp` fills up with test files

**Solution:** Always call `cleanup_temp_files`:

```nushell
#[test]
def "my_test" [] {
    init_temp_tracker
    # ... test code ...
    cleanup_temp_files  # Always cleanup
}
```

### Type Errors in Assertions

**Symptom:** `error: type mismatch`

**Solution:** Use `describe` to check types:

```nushell
print ($data | describe)  # check actual type
assert equal ($data | describe) "record"
```

## Best Practices

1. **Always use helpers** - Don't hardcode paths or IDs
2. **Init temp tracker** - Call `init_temp_tracker` at test start
3. **Always cleanup** - Call `cleanup_temp_files` at test end
4. **Use fixtures for reuse** - Put shared test data in fixtures/
5. **Build with builders** - Use `build_*` functions for inputs
6. **Assert with assertions** - Use specialized assertions
7. **Test one thing** - Each test should verify one behavior
8. **Name tests clearly** - Use descriptive names that explain behavior
9. **Arrange-Act-Assert** - Follow AAA pattern
10. **Document edge cases** - Add comments for non-obvious tests
