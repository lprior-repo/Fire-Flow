# Purity Tests

Comprehensive test suite verifying that Fire-Flow tools behave as pure functions with deterministic outputs and no side effects.

## Test Files

### 1. `test_determinism.nu` - Same Input → Same Output
Tests that tools produce identical outputs (excluding time-based fields) when run multiple times with identical inputs.

**Tests:**
- `test_echo_tool_deterministic` - Echo tool produces consistent outputs across 10 runs
- `test_run_tool_deterministic` - run-tool.nu produces consistent results
- `test_validate_deterministic` - validate.nu produces consistent validation results
- `test_error_messages_deterministic` - Error messages are identical across runs
- `test_trace_id_excluded_from_comparison` - Different trace IDs don't affect core output
- `test_duration_excluded_from_comparison` - Duration variance doesn't break determinism
- `test_timestamp_fields_excluded` - No timestamp fields leak into outputs
- `test_json_field_ordering_stable` - Field order is consistent across runs
- `test_multiple_runs_same_process_vs_separate` - Determinism across process boundaries
- `test_dry_run_deterministic` - Dry-run mode is deterministic
- `test_validation_errors_deterministic` - Validation errors are consistent

**Key Principles:**
- Excludes non-deterministic fields: `trace_id`, `duration_ms`
- Tests both success and failure cases
- Validates data content, not just structure
- Verifies cross-process consistency

### 2. `test_idempotency.nu` - Repeated Execution Safety
Tests that running tools multiple times with the same input doesn't cause side effects or state changes.

**Tests:**
- `test_run_tool_twice_same_input_same_result` - Running twice is safe
- `test_validate_twice_same_contract_same_result` - Validation can be repeated
- `test_generate_with_same_contract_same_feedback` - Generate is repeatable (dry-run)
- `test_file_overwrite_idempotent` - Overwriting output files is safe
- `test_temp_cleanup_idempotent` - Can cleanup and re-run safely
- `test_validation_multiple_times_safe` - Can validate 20+ times
- `test_echo_repeated_execution_safe` - Echo can run 50+ times
- `test_concurrent_file_writes_safe` - Rapid sequential writes are safe
- `test_dry_run_never_modifies_state` - Dry-run truly doesn't modify
- `test_error_state_idempotent` - Errors don't corrupt state
- `test_validate_idempotent_on_failure` - Failed validations are idempotent

**Key Principles:**
- Repeated execution is always safe
- No state accumulation across runs
- Files can be overwritten without corruption
- Failures don't corrupt state

### 3. `test_reproducibility.nu` - Cross-Run Consistency
Tests that outputs maintain stable formats, field ordering, and structure across different executions and time periods.

**Tests:**
- `test_output_format_stable` - ToolResponse format is consistent
- `test_json_serialization_stable` - JSON serialization is stable
- `test_error_format_stable` - Error responses have stable format
- `test_response_structure_stable` - Response structures don't change
- `test_field_ordering_stable` - Field order is consistent
- `test_type_stability` - Field types don't change across runs
- `test_validation_output_format_stable` - validate.nu format is stable
- `test_run_tool_output_format_stable` - run-tool.nu format is stable
- `test_error_types_stable` - Error types are consistent
- `test_nested_structure_stability` - Deep nesting is stable
- `test_boolean_representation_stable` - Booleans are consistently typed
- `test_numeric_representation_stable` - Numbers have stable types
- `test_empty_collections_stable` - Empty arrays/objects are consistent

**Key Principles:**
- Output schemas are stable
- Field types don't change
- Field ordering is preserved
- Empty values are consistently represented

### 4. `test_purity.nu` - No Side Effects
Tests that tools are pure functions: they don't modify inputs, don't leave temp files, and don't corrupt global state.

**Tests:**
- `test_read_only_contract_unchanged` - Contracts are never modified
- `test_read_only_fixtures_unchanged` - Fixture files are never modified
- `test_temp_files_cleaned_after` - Temp files can be cleaned safely
- `test_global_state_unchanged` - Environment is not modified
- `test_no_file_leaks` - No unexpected temp files created
- `test_input_data_unchanged` - Input data files are never modified
- `test_multiple_runs_no_accumulation` - No state accumulation
- `test_no_side_effects_on_failure` - Failures don't modify files
- `test_dry_run_truly_dry` - Dry-run creates no files
- `test_validation_no_write_to_contract` - Works with read-only files
- `test_concurrent_reads_safe` - Multiple reads don't interfere
- `test_no_global_file_modification` - Canary files remain untouched
- `test_tool_script_unchanged_after_execution` - Tools don't self-modify
- `test_no_persistent_cache_pollution` - No cache files created

**Key Principles:**
- Input files are never modified
- Tools work with read-only files
- No unexpected files created
- Global state is preserved
- Failures are safe (no corruption)

## Running the Tests

### Run All Purity Tests
```bash
nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/purity'
```

### Run Individual Test Files
```bash
# Determinism tests
nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/purity/test_determinism.nu'

# Idempotency tests
nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/purity/test_idempotency.nu'

# Reproducibility tests
nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/purity/test_reproducibility.nu'

# Purity tests
nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/purity/test_purity.nu'
```

### Run Specific Test
```bash
nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/purity/test_determinism.nu --test test_echo_tool_deterministic'
```

## Test Coverage Summary

| Category | Tests | Lines | Focus |
|----------|-------|-------|-------|
| Determinism | 11 | 435 | Same input → same output |
| Idempotency | 11 | 507 | Repeated execution safety |
| Reproducibility | 13 | 551 | Format/structure stability |
| Purity | 14 | 574 | No side effects |
| **Total** | **49** | **2,067** | **Functional purity** |

## Key Concepts

### Determinism
A function is deterministic if it always produces the same output for the same input. Our tests verify this by:
- Running tools 10+ times with identical inputs
- Comparing outputs (excluding time-based fields)
- Checking both data values and structure
- Testing across process boundaries

### Idempotency
A function is idempotent if calling it multiple times has the same effect as calling it once. Our tests verify this by:
- Running tools repeatedly (up to 50 times)
- Checking for state accumulation
- Verifying file overwrites are safe
- Testing cleanup and re-run cycles

### Reproducibility
A system is reproducible if it produces consistent outputs over time. Our tests verify this by:
- Checking output schema stability
- Verifying field type consistency
- Testing field ordering preservation
- Validating error format stability

### Purity
A function is pure if it has no side effects. Our tests verify this by:
- Checking input files are never modified
- Verifying no unexpected files created
- Testing global state preservation
- Validating read-only file compatibility

## Non-Deterministic Fields

The following fields are **explicitly excluded** from determinism comparisons:

- `trace_id` - Varies per request (context propagation)
- `duration_ms` - Varies per execution (timing)
- `timestamp` - Not used in our tools (avoided by design)

All other fields must be deterministic.

## Design Principles

1. **Pure by Default** - Tools are designed as pure functions
2. **Read-Only Inputs** - Input files are never modified
3. **Explicit Outputs** - All outputs go to specified paths
4. **No Global State** - No environment modification
5. **Temp File Cleanup** - Tests clean up after themselves
6. **Dry-Run Safe** - Dry-run truly doesn't execute

## Integration with CI/CD

These tests are designed to:
- Run quickly (most complete in < 100ms)
- Be isolated (no shared state)
- Clean up resources (no test pollution)
- Provide clear failure messages
- Support parallel execution (future)

## Debugging Failures

### Determinism Failures
If outputs differ across runs:
1. Check for hidden timestamp fields
2. Look for random number generation
3. Verify file paths are absolute
4. Check for environment variable usage

### Idempotency Failures
If repeated runs fail:
1. Check for file locking issues
2. Look for state accumulation
3. Verify temp file cleanup
4. Check for race conditions

### Reproducibility Failures
If formats change:
1. Check for Nushell version differences
2. Verify JSON serialization settings
3. Look for schema evolution
4. Check dependency versions

### Purity Failures
If side effects detected:
1. Check for file modifications
2. Look for temp file leaks
3. Verify environment changes
4. Check for cache creation

## Future Enhancements

- [ ] Parallel execution tests (true concurrency)
- [ ] Property-based testing with random inputs
- [ ] Long-running stability tests (1000+ iterations)
- [ ] Memory leak detection
- [ ] Performance regression detection
- [ ] Cross-platform purity verification

## References

- [Functional Programming Principles](https://en.wikipedia.org/wiki/Functional_programming)
- [Pure Functions](https://en.wikipedia.org/wiki/Pure_function)
- [Idempotence](https://en.wikipedia.org/wiki/Idempotence)
- [Referential Transparency](https://en.wikipedia.org/wiki/Referential_transparency)
