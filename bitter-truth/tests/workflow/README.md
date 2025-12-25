# Fire-Flow End-to-End Workflow Tests

Comprehensive end-to-end tests validating complete Fire-Flow workflow execution including self-healing, parallelization, and error recovery.

## Test Suites

### 1. Self-Healing Loop Tests (`test_self_healing_loop.nu`)

Tests the multi-attempt self-healing pattern that is central to Fire-Flow's contract-driven approach.

**Tests:**
- `self_healing_attempt_1_fails_attempt_2_succeeds` - Verify recovery after initial failure
- `self_healing_all_attempts_fail_returns_final_error` - Validate max attempts enforcement
- `self_healing_feedback_accumulates_across_attempts` - Confirm feedback builds context
- `self_healing_trace_id_consistent_across_attempts` - Ensure trace continuity
- `self_healing_max_attempts_enforced` - Verify loop termination
- `self_healing_early_success_stops_loop` - Confirm early exit optimization
- `self_healing_feedback_length_reasonable` - Prevent unbounded feedback growth
- `self_healing_each_attempt_improves_output` - Validate progressive improvement

**Key Validations:**
- Feedback loop functionality
- Progressive output improvement
- Trace ID consistency
- Proper termination conditions

### 2. Parallel Execution Tests (`test_parallel_executions.nu`)

Tests concurrent workflow safety to ensure Fire-Flow can handle multiple simultaneous executions.

**Tests:**
- `parallel_echo_executions_isolated` - 10 concurrent executions with unique outputs
- `parallel_outputs_unique_files` - Verify no file collisions
- `parallel_trace_ids_distinct` - Ensure unique trace IDs
- `parallel_no_file_collisions_under_load` - Stress test with 12 workers
- `parallel_validation_independent` - Validate concurrent contract checks
- `parallel_concurrent_temp_file_cleanup` - Test cleanup safety
- `parallel_race_condition_free` - Stress test for race conditions

**Key Validations:**
- Execution isolation
- File system safety
- Trace ID uniqueness
- Independent validation
- Race condition resistance

### 3. Full Workflow Tests (`test_full_workflow.nu`)

Tests complete happy path workflows from generation through validation.

**Tests:**
- `full_workflow_contract_loop_happy_path` - Complete Generate → Execute → Validate
- `full_workflow_pipeline_with_multiple_inputs` - Multiple input scenarios
- `full_workflow_output_correctness` - Data integrity verification
- `full_workflow_timing_reasonable` - Performance validation
- `full_workflow_logs_complete` - Log capture verification
- `full_workflow_end_to_end_with_validation_details` - Detailed validation inspection
- `full_workflow_handles_empty_input` - Edge case: empty input
- `full_workflow_large_message` - Stress test: large payloads

**Key Validations:**
- Complete pipeline functionality
- Output correctness
- Performance bounds
- Log completeness
- Edge case handling

### 4. Error Recovery Tests (`test_error_recovery.nu`)

Tests failure scenarios and graceful error handling.

**Tests:**
- `error_recovery_missing_contract_fails_gracefully` - Non-existent contract
- `error_recovery_missing_tool_fails_gracefully` - Non-existent tool
- `error_recovery_invalid_input_fails_gracefully` - Malformed JSON input
- `error_recovery_validation_failure_triggers_feedback` - Contract violations
- `error_recovery_network_timeout_handled` - Timeout scenarios
- `error_recovery_malformed_tool_output` - Non-JSON output
- `error_recovery_missing_data_file_in_contract` - Invalid contract config
- `error_recovery_tool_crash` - Tool exit with error
- `error_recovery_partial_output` - Incomplete output structure
- `error_recovery_contract_yaml_parse_error` - Invalid YAML syntax
- `error_recovery_empty_trace_id_handled` - Missing trace ID

**Key Validations:**
- Graceful failure handling
- Informative error messages
- Feedback generation for recovery
- No silent failures
- Trace ID preservation in errors

## Running the Tests

### Run All Workflow Tests

```bash
# From repository root
nu -c 'use nutest/nutest; nutest run-tests --path bitter-truth/tests/workflow/'
```

### Run Individual Test Suites

```bash
# Self-healing tests
nu -c 'use nutest/nutest; nutest run-tests --path bitter-truth/tests/workflow/test_self_healing_loop.nu'

# Parallel execution tests
nu -c 'use nutest/nutest; nutest run-tests --path bitter-truth/tests/workflow/test_parallel_executions.nu'

# Full workflow tests
nu -c 'use nutest/nutest; nutest run-tests --path bitter-truth/tests/workflow/test_full_workflow.nu'

# Error recovery tests
nu -c 'use nutest/nutest; nutest run-tests --path bitter-truth/tests/workflow/test_error_recovery.nu'
```

### Run Specific Test

```bash
nu -c 'use nutest/nutest; nutest run-tests --path bitter-truth/tests/workflow/test_self_healing_loop.nu --test-name self_healing_attempt_1_fails_attempt_2_succeeds'
```

## Test Statistics

- **Total Tests:** 39 comprehensive workflow tests
- **Total Lines:** ~2,000 lines of test code
- **Coverage Areas:**
  - Self-healing loops (8 tests)
  - Parallel execution (7 tests)
  - Full workflows (8 tests)
  - Error recovery (11 tests)
  - Edge cases (5 tests)

## Architecture Patterns Tested

### 1. Contract-Driven Development
All tests verify that DataContracts act as the source of truth:
- Contract validation is draconian
- Failures trigger feedback loops
- No silent contract violations

### 2. Self-Healing Pattern
Tests verify the core Generate → Execute → Validate → Feedback loop:
- AI receives actionable feedback
- Feedback accumulates context
- Progressive improvement across attempts
- Graceful termination on max attempts

### 3. Trace ID Flow
All tests verify trace_id propagation:
- Consistent across all pipeline steps
- Preserved in error conditions
- Unique per execution in parallel scenarios

### 4. Tool Response Format
Tests validate the standard ToolResponse structure:
```nushell
{
    success: bool
    data: <contract-specific>
    error?: string
    trace_id: string
    duration_ms: float
}
```

## Test Design Principles

1. **Realistic Scenarios** - Tests simulate actual workflow usage
2. **Self-Healing Verification** - Core to Fire-Flow, heavily tested
3. **Parallelization Safety** - Concurrent executions don't interfere
4. **Complete Output Validation** - Not just success/failure, but data correctness
5. **Side Effect Verification** - Confirm no unintended file/state pollution
6. **Graceful Degradation** - Errors produce useful feedback, not crashes

## Temporary Files

Tests use `/tmp/` for temporary files with prefixes:
- `sh-*` - Self-healing tests
- `parallel-*` - Parallel execution tests
- `full-*` - Full workflow tests
- `error-*` - Error recovery tests
- `output.json` - Standard output file

All tests clean up their temporary files in the test body.

## Performance Expectations

- **Single tool execution:** < 1 second
- **Full pipeline (Generate → Execute → Validate):** < 5 seconds
- **Parallel execution (10 concurrent):** < 10 seconds
- **Self-healing loop (5 attempts):** < 30 seconds

## Contract Dependencies

Tests rely on:
- `/home/lewis/src/Fire-Flow/bitter-truth/contracts/tools/echo.yaml`
- `/home/lewis/src/Fire-Flow/bitter-truth/tools/run-tool.nu`
- `/home/lewis/src/Fire-Flow/bitter-truth/tools/validate.nu`
- `/home/lewis/src/Fire-Flow/bitter-truth/tools/generate.nu` (simulated in tests)

## Adding New Tests

When adding workflow tests:

1. **Use descriptive test names** following pattern: `category_scenario_expected_behavior`
2. **Create unique temp files** to avoid parallel test conflicts
3. **Clean up temp files** in the test body (use `rm -f`)
4. **Verify trace_id flow** where applicable
5. **Test both success and failure paths**
6. **Add assertions for data correctness**, not just exit codes

Example test template:

```nushell
#[test]
def "category_scenario_behavior" [] {
    # Test: Description of what this test validates

    let trace_id = "unique-test-id"
    let output_file = "/tmp/unique-output.json"
    let logs_file = "/tmp/unique-logs.json"

    # Test implementation
    # ...

    # Assertions
    assert condition "descriptive message"

    # Cleanup
    rm -f $output_file $logs_file
}
```

## Debugging Failed Tests

1. **Check temp files** - Failed tests may leave files in `/tmp/`
2. **Examine logs** - Look at `*-logs.json` files for tool stderr
3. **Verify contracts** - Ensure contract files haven't changed
4. **Run individually** - Isolate the failing test
5. **Check trace IDs** - Verify trace_id propagation

## CI Integration

These tests are designed to run in CI environments:
- No external dependencies (beyond nutest, nu, datacontract-cli)
- Deterministic (no network calls, no random data)
- Fast execution (< 2 minutes total)
- Clear pass/fail signals
- Cleanup temp files on success or failure

## Future Enhancements

Planned additions:
- [ ] Metrics collection tests (timing, memory, etc.)
- [ ] Long-running workflow tests (30+ minute executions)
- [ ] Multi-contract validation tests
- [ ] Complex dependency chain tests
- [ ] Workflow restart/resume tests
- [ ] Distributed execution tests
