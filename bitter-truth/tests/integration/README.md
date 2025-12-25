# Fire-Flow Integration Tests

This directory contains comprehensive integration tests for the bitter-truth multi-component workflows. These tests validate component interaction and **REAL DataContract compliance** using actual tools, contracts, and validation.

## Test Files

### 1. test_contract_compliance.nu (11 tests)
**Real contract validation tests** - Uses actual DataContract CLI to validate outputs.

Tests:
- `test_echo_tool_output_validates_against_contract` - Valid output passes validation
- `test_missing_required_field_fails_validation` - Missing fields detected
- `test_wrong_type_fails_validation` - Type mismatches caught
- `test_extra_fields_pass_validation` - Additional fields allowed
- `test_nested_object_structure_validates` - Nested objects handled
- `test_array_field_validates` - Array fields validated
- `test_numeric_constraints_validate` - Min/max constraints enforced
- `test_string_constraints_validate` - String constraints (minLength, pattern)
- `test_validation_error_messages_accurate` - Error messages useful
- `test_boolean_field_type_enforcement` - Boolean type checking
- `test_optional_field_validation` - Optional fields can be omitted

### 2. test_generate_integration.nu (11 tests)
**AI generation integration** - Tests real AI code generation with opencode.

Tests:
- `test_generate_with_valid_contract_succeeds` - AI generates working tools
- `test_generate_with_feedback_incorporates_errors` - Feedback loop works
- `test_generate_timeout_kills_opencode_process` - Process cleanup on timeout
- `test_generate_preserves_trace_id` - Trace ID flows through generation
- `test_generate_prompt_includes_contract_schema` - Contract in prompt
- `test_generate_output_is_valid_nushell` - Generated code is parseable
- `test_generate_creates_executable_tool` - Output is runnable
- `test_generate_handles_missing_contract` - Error handling for bad inputs
- `test_generate_handles_empty_task` - Input validation
- `test_generate_dry_run_skips_ai_call` - Dry-run mode works
- `test_generate_uses_llm_cleaner` - Code extraction from AI response

### 3. test_run_execute_integrate.nu (14 tests)
**Tool execution integration** - Tests running real Nushell tools.

Tests:
- `test_execute_tool_with_valid_input_succeeds` - Basic execution
- `test_execute_tool_captures_stdout` - Output capture
- `test_execute_tool_captures_stderr` - Log capture
- `test_execute_tool_propagates_exit_code` - Exit code handling
- `test_execute_tool_with_large_input_succeeds` - Large data handling (1000 items)
- `test_execute_tool_with_special_chars_input` - Unicode, quotes, newlines
- `test_execute_tool_with_empty_input` - Empty input handling
- `test_execute_tool_with_nested_objects` - Nested JSON
- `test_execute_tool_preserves_trace_id` - Trace ID preservation
- `test_execute_missing_tool_fails` - Error handling
- `test_execute_malformed_json_input_fails` - JSON validation
- `test_execute_tool_dry_run_skips_execution` - Dry-run mode
- `test_execute_real_echo_tool` - Tests against real echo.nu
- `test_execute_tool_with_json_output_verification` - Complex JSON structures

### 4. test_generate_execute_validate_chain.nu (7 tests)
**Full chain integration** - The crown jewels! Complete end-to-end workflows.

Tests:
- `test_generate_then_execute_succeeds` - Generate → Execute chain
- `test_execute_output_validates_against_contract` - Execute → Validate chain
- `test_entire_generate_execute_validate_flow` - **COMPLETE FLOW**: Generate → Execute → Validate
- `test_chain_preserves_trace_id_end_to_end` - Trace ID through full chain
- `test_failed_validation_provides_feedback` - Validation errors for self-healing
- `test_self_healing_loop_simulation` - Simulates fail → feedback → fix → success
- `test_dry_run_propagates_through_chain` - Dry-run through full chain

## Running the Tests

### All Integration Tests
```bash
nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/integration'
```

### Single Test File
```bash
nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/integration/test_contract_compliance.nu'
```

### Individual Test
```bash
nu -c 'use bitter-truth/tests/integration/test_contract_compliance.nu; test_echo_tool_output_validates_against_contract'
```

## Prerequisites

### Required Tools
- `nu` (Nushell) - Script execution
- `datacontract` - Contract validation
- `nutest` - Test runner

### Required for AI Tests
- `opencode` - AI code generation
- `MODEL` environment variable - Set to your model (e.g., `local/qwen3-coder`)

### Optional for Full Chain Tests
- `llm-cleaner` - Code extraction from AI responses (built from tools/llm-cleaner)

## Test Philosophy

These integration tests follow Martin Fowler's principles:

1. **Tests describe behavior, not implementation**
   - Test names explain what should happen
   - Focus on contracts and outcomes

2. **Each test is independent and isolated**
   - Tests create their own fixtures
   - Clean up after themselves
   - Can run in any order

3. **Tests use REAL components**
   - No mocks or stubs
   - Real contract validation via datacontract-cli
   - Real tool execution
   - Real AI generation (where configured)

4. **Tests are as deterministic as possible**
   - AI tests skip if MODEL not set
   - Known-good tools used where determinism needed
   - Clear pass/fail criteria

5. **Tests verify actual contracts are satisfied**
   - Not just "does it run?"
   - But "does output match contract schema?"

## Key Differences from Unit Tests

| Aspect | Unit Tests | Integration Tests |
|--------|-----------|-------------------|
| Scope | Single function | Multiple components |
| Dependencies | Mocked/stubbed | Real tools |
| Validation | Assert outputs | Real contract validation |
| Speed | Fast (ms) | Slower (seconds) |
| AI Calls | Never | Optional (skipped if no MODEL) |
| Purpose | Verify logic | Verify interaction |

## Test Coverage

**Total Tests: 43 integration tests**

- Contract compliance: 11 tests
- AI generation: 11 tests
- Tool execution: 14 tests
- Full chain: 7 tests

## Environment Variables

```bash
# Required for AI generation tests
export MODEL="local/qwen3-coder"

# Optional: Custom paths
export OPENCODE_PATH="/path/to/opencode"
```

## Troubleshooting

### AI Tests Skipped
```
Skipping: MODEL env var not set
```
**Solution**: Set MODEL environment variable to your AI model.

### llm-cleaner Not Found
```
llm-cleaner not found in any standard location
```
**Solution**: Build llm-cleaner:
```bash
cargo build --release --manifest-path=tools/llm-cleaner/Cargo.toml
```

### Contract Validation Fails
Check that datacontract-cli is installed:
```bash
pip install datacontract-cli
```

### Tests Timing Out
AI generation tests have 60s timeout by default. Adjust in test if needed:
```nushell
timeout_seconds: 120  # Increase for slower models
```

## Contributing

When adding new integration tests:

1. Use REAL components (no mocks)
2. Test against actual contracts
3. Include cleanup (rm -f) in each test
4. Make tests independent
5. Add skip logic for optional dependencies (MODEL, etc.)
6. Follow naming convention: `test_component_behavior_scenario`

## Examples

### Running with AI
```bash
export MODEL="local/qwen3-coder"
nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/integration'
```

### Running without AI (contract & execution tests only)
```bash
unset MODEL
nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/integration'
```
AI tests will skip automatically.

### Debugging a Single Test
```bash
# Run with verbose output
nu bitter-truth/tests/integration/test_contract_compliance.nu
```

## Success Criteria

A successful integration test suite run should:

1. All contract compliance tests pass (validates DataContract integration)
2. All execution tests pass (validates tool running)
3. AI tests either pass or skip (depending on MODEL config)
4. Full chain tests demonstrate end-to-end flow
5. No orphaned processes left behind
6. All temp files cleaned up

## File Locations

- Test files: `/home/lewis/src/Fire-Flow/bitter-truth/tests/integration/`
- Real tools: `/home/lewis/src/Fire-Flow/bitter-truth/tools/`
- Real contracts: `/home/lewis/src/Fire-Flow/bitter-truth/contracts/`
- Test outputs: `/tmp/test-*.json` (cleaned up after each test)
