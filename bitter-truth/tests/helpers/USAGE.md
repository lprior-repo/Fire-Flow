# Quick Start Guide: Test Helpers

## Installation

No installation needed. All helpers are pure Nushell modules in this directory.

## Basic Usage

### 1. Import Helpers in Your Test File

```nushell
#!/usr/bin/env nu
use std assert
use bitter-truth/tests/helpers/constants.nu *
use bitter-truth/tests/helpers/fixtures.nu *
use bitter-truth/tests/helpers/builders.nu *
use bitter-truth/tests/helpers/assertions.nu *

#[test]
def "my_test" [] {
    # ... your test code ...
}
```

### 2. Standard Test Pattern

```nushell
#[test]
def "test_name_describes_behavior" [] {
    # Arrange - Setup test environment
    init_temp_tracker                              # Initialize temp file tracking
    let ctx = build_test_context                   # Get unique test context
    let input = build_echo_input "test" $ctx.trace_id  # Build input data

    # Act - Execute the code under test
    let result = $input | to json | nu (echo_tool) | complete

    # Assert - Verify behavior
    assert_completed_successfully $result
    let response = $result.stdout | from json
    assert_success $response
    assert_trace_id_propagated $response $ctx.trace_id

    # Cleanup - Remove temp files
    cleanup_temp_files
}
```

## Helper Functions Cheat Sheet

### Constants (constants.nu)

```nushell
use bitter-truth/tests/helpers/constants.nu *

print (tools_dir)           # /path/to/bitter-truth/tools
print (echo_tool)           # /path/to/bitter-truth/tools/echo.nu
print (echo_contract)       # /path/to/bitter-truth/contracts/tools/echo.yaml
print $DEFAULT_TIMEOUT_MS   # 30000
```

### Fixtures (fixtures.nu)

```nushell
use bitter-truth/tests/helpers/fixtures.nu *

# Get unique test ID
let id = get_test_id                                    # "a3f7b2c1"

# Create temp files (auto-tracked for cleanup)
let tool = create_temp_file "nu" "echo"                 # /tmp/echo-a3f7b2c1.nu
let json = create_temp_file "json"                      # /tmp/test-a3f7b2c1.json

# Load fixtures
let code = load_fixture "tools" "echo-correct"          # Load .nu file as string
let data = load_fixture "inputs" "echo-valid"           # Load JSON as record

# Helpers
let tool_path = create_temp_tool $code "my-tool"
let json_path = create_temp_json { msg: "test" } "data"

# Check if fixture exists
if (fixture_exists "tools" "my-tool") { ... }

# Cleanup (call at end of test)
init_temp_tracker       # At test start
cleanup_temp_files      # At test end
```

### Builders (builders.nu)

```nushell
use bitter-truth/tests/helpers/builders.nu *

# Build execution context
let ctx = build_context                                 # Auto-generated trace_id
let ctx = build_context "my-trace" true 30              # With trace_id, dry_run, timeout

# Build tool inputs
let input = build_echo_input "hello"
let input = build_echo_input "test" "trace-1" true      # with trace_id, dry_run

let input = build_run_tool_input $tool_path $data
let input = build_validate_input $contract
let input = build_generate_input $contract "task description"

# Build complete test context (all paths pre-generated)
let ctx = build_test_context
# Returns: { test_id, trace_id, tool_path, output_path, logs_path, generated_path, input_path }

# Build responses
let success = build_success_response { data: "value" } "trace-1" 42
let failure = build_error_response "error msg" "trace-1" 10
```

### Assertions (assertions.nu)

```nushell
use bitter-truth/tests/helpers/assertions.nu *
use std assert

# ToolResponse validation
assert_tool_response $response                          # Validates structure

# Contract validation (runs actual validate.nu)
assert_contract_valid "/tmp/output.json" $contract_path

# File operations
assert_files_exist ["/tmp/file1.json", "/tmp/file2.json"]
let data = assert_json_valid "/tmp/output.json"         # Parse and validate JSON

# Exit codes
assert_exit_code $result 0 "Should succeed"
assert_completed_successfully $result

# Trace ID
assert_trace_id_propagated $response "test-123"

# Success/Failure
assert_success $response "Should succeed"
assert_failure $response "Should fail"
assert_error_contains $response "error text"

# Data fields
assert_data_fields $response ["field1", "field2"]

# Duration
assert_duration_reasonable $response 5000               # Max 5 seconds

# Deep equality
assert_json_equals $actual $expected
```

## Common Patterns

### Test Echo Tool

```nushell
#[test]
def "test_echo_with_valid_input" [] {
    init_temp_tracker
    let ctx = build_test_context
    let input = build_echo_input "hello" $ctx.trace_id

    let result = $input | to json | nu (echo_tool) | complete

    assert_completed_successfully $result
    let response = $result.stdout | from json
    assert_success $response
    assert equal $response.data.echo "hello"

    cleanup_temp_files
}
```

### Test With Fixture

```nushell
#[test]
def "test_using_fixture_tool" [] {
    init_temp_tracker

    let tool_code = load_fixture "tools" "echo-correct"
    let tool_path = create_temp_tool $tool_code

    let input = build_echo_input "test"
    let result = $input | to json | nu $tool_path | complete

    assert_completed_successfully $result
    cleanup_temp_files
}
```

### Test Error Handling

```nushell
#[test]
def "test_handles_empty_message" [] {
    init_temp_tracker

    let input = build_echo_input ""  # Invalid input
    let result = $input | to json | nu (echo_tool) | complete

    assert_exit_code $result 1
    let response = $result.stdout | from json
    assert_failure $response
    assert_error_contains $response "message is required"

    cleanup_temp_files
}
```

### Test Integration Flow

```nushell
#[test]
def "test_generate_execute_validate" [] {
    init_temp_tracker
    let ctx = build_test_context

    # 1. Generate (or load fixture)
    let tool_code = load_fixture "tools" "echo-correct"
    let tool_path = create_temp_tool $tool_code

    # 2. Execute
    let input = load_fixture "inputs" "echo-valid"
    let run_input = build_run_tool_input $tool_path $input $ctx.output_path $ctx.logs_path
    let result = $run_input | to json | nu (run_tool) | complete

    assert_completed_successfully $result

    # 3. Validate
    let output = assert_json_valid $ctx.output_path
    assert_success $output

    cleanup_temp_files
}
```

## Available Fixtures

Located in `bitter-truth/tests/fixtures/`:

### Tools (`fixtures/tools/`)
- `echo-correct.nu` - Correct echo implementation
- `echo-buggy.nu` - Buggy implementation (str rev error)
- `echo-wrong-schema.nu` - Wrong output schema

### Inputs (`fixtures/inputs/`)
- `echo-valid.json` - Valid echo input
- `echo-empty-message.json` - Empty message (should fail)

### Outputs (`fixtures/outputs/`)
- `echo-expected.json` - Expected echo output

## Tips

1. **Always use `build_test_context`** - Gets you unique file paths automatically
2. **Always init and cleanup** - Call `init_temp_tracker` at start, `cleanup_temp_files` at end
3. **Use fixtures for reuse** - Put common test data in fixtures/
4. **Use builders for inputs** - Don't manually construct input records
5. **Use specialized assertions** - They give better error messages
6. **One test, one behavior** - Each test should verify one thing
7. **Name tests clearly** - Use descriptive names that explain the behavior

## File Structure

```
bitter-truth/tests/
├── helpers/
│   ├── mod.nu              # Module exports
│   ├── constants.nu        # Path constants (as functions)
│   ├── fixtures.nu         # Fixture loading & temp files
│   ├── builders.nu         # Test data builders
│   ├── assertions.nu       # Specialized assertions
│   ├── README.md           # Detailed documentation
│   └── USAGE.md            # This quick start guide
├── fixtures/
│   ├── tools/              # Tool script fixtures (.nu)
│   ├── inputs/             # Input data fixtures (.json)
│   ├── contracts/          # Contract fixtures (.yaml)
│   └── outputs/            # Expected output fixtures (.json)
└── test_*.nu               # Your test files
```

## Running Tests

```bash
# From project root
nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests'

# Run specific test file
nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/test_helpers_example.nu'

# Run single test
nu bitter-truth/tests/test_helpers_example.nu
```

## Troubleshooting

**Problem:** Module not found errors

**Solution:** Ensure you're using the full path from project root:
```nushell
use bitter-truth/tests/helpers/builders.nu *  # ✓ Correct
use helpers/builders.nu *                      # ✗ Won't work
```

**Problem:** Tests interfere with each other

**Solution:** Use `build_test_context` for unique file paths:
```nushell
let ctx = build_test_context       # ✓ Unique paths
let out = "/tmp/output.json"       # ✗ Shared path
```

**Problem:** Fixture not found

**Solution:** Check the file exists with correct extension:
```bash
ls bitter-truth/tests/fixtures/tools/
# Ensure file has .nu, .json, .yaml, or .txt extension
```

## Complete Example

```nushell
#!/usr/bin/env nu
use std assert
use bitter-truth/tests/helpers/constants.nu *
use bitter-truth/tests/helpers/fixtures.nu *
use bitter-truth/tests/helpers/builders.nu *
use bitter-truth/tests/helpers/assertions.nu *

#[test]
def "echo_tool_reverses_message_correctly" [] {
    # Arrange
    init_temp_tracker
    let ctx = build_test_context
    let message = "hello world"
    let input = build_echo_input $message $ctx.trace_id

    # Act
    let result = $input | to json | nu (echo_tool) | complete

    # Assert
    assert_completed_successfully $result

    let response = $result.stdout | from json
    assert_tool_response $response
    assert_success $response
    assert_trace_id_propagated $response $ctx.trace_id
    assert_data_fields $response ["echo", "reversed", "length", "was_dry_run"]
    assert_duration_reasonable $response

    # Verify actual values
    assert equal $response.data.echo "hello world"
    assert equal $response.data.reversed "dlrow olleh"
    assert equal $response.data.length 11
    assert equal $response.data.was_dry_run false

    # Cleanup
    cleanup_temp_files
}
```

For more details, see [README.md](README.md).
