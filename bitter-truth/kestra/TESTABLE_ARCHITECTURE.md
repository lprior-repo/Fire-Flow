# Testable Kestra Workflow Architecture

## Overview

The rearchitected workflows prioritize **testability** by enabling:
- ✅ Input validation before execution
- ✅ Test mode with stub tools (no external dependencies)
- ✅ Explicit error paths that can be tested
- ✅ Structured outputs for assertion-based testing
- ✅ Early failure detection (fail fast)
- ✅ Mock execution for CI/CD pipelines
- ✅ Observability logging for debugging

## Key Changes from Original

### 1. Input Validation (New)
Every workflow validates inputs **before** executing critical operations:

```yaml
- id: validate_inputs
  type: io.kestra.plugin.scripts.shell.Commands
  commands:
    - |
      # Check contract exists, task is not empty, tools_dir exists
      # Exit 1 with error JSON if validation fails
      # Enables testing of error paths
```

**Benefits**:
- Catch configuration errors early
- No wasted execution on bad inputs
- Testable error path: pass invalid inputs, verify error response

### 2. Test Mode Support (New)
All testable workflows accept `test_mode: boolean` parameter:

```yaml
inputs:
  - id: test_mode
    type: BOOLEAN
    defaults: false
    description: If true, use stub tools instead of real execution
```

When `test_mode: true`:
- `generate-tool-testable` creates stub Nushell instead of calling opencode
- `execute-tool-testable` creates mock output instead of running tool
- `validate-tool-testable` uses mock validation logic instead of datacontract-cli

**Benefits**:
- Run workflows in CI/CD without opencode/datacontract-cli
- Fast testing (stub execution in milliseconds)
- No external dependencies for testing
- Deterministic results (no AI variance)

### 3. Step-by-Step Validation (New)
Each workflow breaks operations into distinct validation steps:

**generate-tool-testable**:
1. Validate inputs (contract exists, task not empty)
2. Generate code (real or stub)
3. Validate output (syntax check on generated tool)

**execute-tool-testable**:
1. Check tool exists
2. Validate input JSON is valid
3. Execute tool
4. Verify output files created

**validate-tool-testable**:
1. Validate inputs (contract, output file exist)
2. Validate output is valid JSON
3. Run validation (real or mock)

**Benefits**:
- Each step is independently testable
- Identify exactly where failures occur
- Test error paths in isolation

### 4. Structured Error Handling (New)
All errors return structured JSON with trace_id:

```json
{
  "success": false,
  "error": "Human-readable error message",
  "trace_id": "execution-id",
  "details": {...}  // Optional: error-specific context
}
```

**Benefits**:
- Consistent error format across all workflows
- Errors traceable via trace_id
- Can assert on error type/message in tests

### 5. Explicit Error Paths (New)
Workflows define `onFailure` handlers for recoverable failures:

```yaml
tasks:
  - id: generate_step
    type: io.kestra.plugin.core.flow.Subflow
    onFailure:
      - id: log_generate_error
        type: io.kestra.plugin.core.log.Log
        level: ERROR
        message: "Generation failed: {{ taskrun.stderr }}"
```

**Benefits**:
- Failed tasks log errors before workflow stops
- Test can trigger failures and verify error logging
- Human can see what went wrong in logs

### 6. Early Exit on Fatal Errors (New)
Pre-loop validation exits immediately on fatal errors:

```yaml
- id: check_contract_exists
  type: io.kestra.plugin.scripts.shell.Commands
  onFailure:
    - id: fail_no_contract
      type: io.kestra.plugin.core.execution.Exit
      state: FAILED
```

**Benefits**:
- Don't waste execution attempts on missing contract
- Fail fast principle
- Clear separation: setup errors vs. runtime errors

### 7. Observability Logging (Improved)
Structured JSON logging for inspection:

```yaml
{ level: "info", msg: "Generation complete", trace_id: "...", duration_ms: 123.4 }
```

Can parse logs to verify:
- What task ran
- Whether it succeeded
- Timing information
- Trace ID propagation

---

## Testing Strategies

### Strategy 1: Unit Test Individual Components (with test_mode)

**Test**: Generate component creates valid Nushell stub

```bash
# Trigger workflow via API
kestra-api "/api/v1/executions/bitter/generate-tool-testable" --method POST --data '{
  "contract_path": "bitter-truth/contracts/tools/echo.yaml",
  "task": "Create echo tool",
  "attempt": "1/5",
  "test_mode": true,
  "trace_id": "test-001"
}'

# Get execution status
kestra-api "/api/v1/executions/{exec-id}"

# Get logs
kestra-api "/api/v1/logs/{exec-id}"

# Assertions:
# - exit_code == 0
# - /tmp/tool.nu exists
# - tool is valid Nushell syntax
```

### Strategy 2: Test Error Paths

**Test**: Generate fails with missing contract

```bash
kestra-api "/api/v1/executions/bitter/generate-tool-testable" --method POST --data '{
  "contract_path": "/nonexistent/contract.yaml",
  "task": "Create tool",
  "test_mode": true
}'

# Assertions:
# - exit_code == 1
# - stderr contains error message
# - validated: false in output
```

### Strategy 3: Integration Test (Full Loop, Test Mode)

**Test**: Full workflow with stub tools (no AI/validation)

```bash
kestra-api "/api/v1/executions/bitter/contract-loop-testable" --method POST --data '{
  "contract": "bitter-truth/contracts/tools/echo.yaml",
  "task": "Create echo tool",
  "input_json": "{}",
  "max_attempts": 3,
  "test_mode": true,
  "timeout_seconds": 300
}'

# Assertions:
# - succeeds or fails predictably
# - completes in <10 seconds
# - outputs: success, output_file, trace_id
```

### Strategy 4: Smoke Test (Real Execution, No opencode)

**Test**: Full workflow with real tools but mock AI (test_mode=true)

```bash
kestra-api "/api/v1/executions/bitter/contract-loop-testable" --method POST --data '{
  "contract": "bitter-truth/contracts/tools/echo.yaml",
  "task": "Create echo tool",
  "input_json": "{\"message\": \"hello\"}",
  "max_attempts": 2,
  "test_mode": true
}'

# Assertions:
# - execution_status == SUCCESS
# - /tmp/tool.nu created
# - /tmp/output.json created
# - output.json is valid JSON
```

---

## Test Mode Behavior

### generate-tool-testable (test_mode=true)

Creates stub tool instead of calling opencode:

```nushell
# Generated stub tool
#!/usr/bin/env nu
def main [] {
  { success: true, data: { message: "stub" } } | to json | print
}
```

Output: `{ success: true, generated: true, was_test_mode: true, output_path: "/tmp/tool.nu" }`

### execute-tool-testable (test_mode=true)

Creates mock execution output instead of running tool:

```json
{
  "success": true,
  "data": { "message": "mock execution" },
  "trace_id": "...",
  "duration_ms": 1.0,
  "was_mock": true
}
```

### validate-tool-testable (test_mode=true)

Uses mock validation logic (just checks if `data` field exists):

```json
{
  "success": true,
  "data": { "valid": true, "was_mock": true },
  "trace_id": "..."
}
```

### contract-loop-testable (test_mode=true)

Full workflow runs with all stub components:
- Generates stub tool in < 1 second
- Executes stub in < 1 second
- Validates with mock logic in < 1 second
- **Total execution: ~3 seconds** (vs. minutes with real AI)

---

## File Structure

```
bitter-truth/kestra/
├── config/
│   └── defaults.yml              # Centralized configuration
│
├── flows/
│   ├── [Original]
│   ├── contract-loop.yml         # Original monolithic flow
│   ├── generate-tool.yml         # Original component
│   ├── execute-tool.yml          # Original component
│   ├── validate-tool.yml         # Original component
│   ├── collect-feedback.yml      # Original component
│   │
│   ├── [Testable Versions]
│   ├── contract-loop-testable.yml
│   ├── generate-tool-testable.yml
│   ├── execute-tool-testable.yml
│   ├── validate-tool-testable.yml
│   │
│   └── contract-loop-modular.yml # Current production (uses originals)
│
├── fixtures/                      # Test data (coming soon)
│   ├── contracts/
│   │   └── echo.yaml
│   ├── inputs/
│   │   └── echo-test-input.json
│   └── outputs/
│       └── echo-valid-output.json
│
├── MODULAR_ARCHITECTURE.md       # Pure functional design
├── COMPONENTS.md                 # Quick reference
└── TESTABLE_ARCHITECTURE.md      # This file
```

---

## Migration Path

### Current (Production)
```
contract-loop-modular.yml
  ├─ generate-tool.yml
  ├─ execute-tool.yml
  ├─ validate-tool.yml
  └─ collect-feedback.yml
```

### With Testing
```
contract-loop-testable.yml          # Use for testing
  ├─ generate-tool-testable.yml
  ├─ execute-tool-testable.yml
  ├─ validate-tool-testable.yml
  └─ collect-feedback.yml (unchanged)

contract-loop-modular.yml          # Use for production
  ├─ generate-tool.yml
  ├─ execute-tool.yml
  ├─ validate-tool.yml
  └─ collect-feedback.yml
```

### Both Versions Coexist
- **Testing**: Use `-testable` versions with `test_mode: true`
- **Development**: Use `-testable` versions with `test_mode: false` for real execution
- **Production**: Use regular versions for optimal performance

---

## Testing Patterns

### Pattern 1: Pre-Execution Validation

Test that invalid inputs are caught **before** expensive operations:

```
Trigger workflow with:
  - contract_path: "/nonexistent/file"
  - task: ""
  - input_json: "invalid json"

Verify:
  - Fails at validate_inputs step
  - No tool generated
  - No tool executed
  - Error logs contain specific reason
```

### Pattern 2: Step-by-Step Validation

Test each step independently:

```
1. Trigger generate-tool-testable → verify tool created
2. Trigger execute-tool-testable with tool → verify output created
3. Trigger validate-tool-testable with output → verify result
```

### Pattern 3: Error Path Testing

Test that failures don't break downstream steps:

```
1. Trigger workflow with broken tool
2. Verify: tool executes, produces error output
3. Verify: validation detects error
4. Verify: feedback collected
5. Verify: next attempt can proceed
```

### Pattern 4: Fast Iteration (Test Mode)

Use test mode for rapid development:

```
# Iterate quickly with stubs
test_mode: true → runs in seconds

# Final validation with real tools
test_mode: false → runs full execution
```

---

## Debugging a Failed Workflow

### Step 1: Get Execution ID
```bash
kestra-api "/api/v1/executions/bitter/contract-loop-testable" --method POST --data '...'
# Returns: { id: "abc123xyz", ... }
```

### Step 2: Check Logs
```bash
kestra-api "/api/v1/logs/abc123xyz" | jq '.'

# Look for:
# - Validation errors (early step failures)
# - Task execution errors
# - Error messages with trace_id
```

### Step 3: Inspect Outputs
```bash
# Get task outputs
kestra-api "/api/v1/executions/abc123xyz" | jq '.taskRunList[] | {id, state, outputs}'

# Check intermediate files
ls -la /tmp/tool.nu /tmp/output.json /tmp/logs.json /tmp/feedback.txt
cat /tmp/output.json | jq '.'
```

### Step 4: Re-run with test_mode=true
If using real execution, re-run with test stubs:
```bash
# Faster debugging (no AI, no contracts, just stubs)
test_mode: true
```

---

## Best Practices

1. **Always Start with test_mode=true**
   - Verify configuration works
   - Fast feedback loop
   - No external dependencies

2. **Test Each Component Independently**
   - Don't assume orchestration works if components don't
   - Use Subflow triggers directly for unit testing

3. **Use Fixtures for Test Data**
   - Store sample contracts, inputs, outputs in `fixtures/`
   - Reuse same test data across test runs
   - Version control fixtures

4. **Monitor Test Execution Times**
   - test_mode=true: < 10 seconds
   - test_mode=false: minutes (acceptable for CI/CD)
   - If test execution slow: investigate blocker

5. **Log Everything**
   - Use structured JSON logging
   - Include trace_id in all logs
   - Correlate logs via trace_id

6. **Fail Fast**
   - Validate inputs before loop
   - Exit immediately on fatal errors
   - Log reason for failure

---

## Future Enhancements

1. **Fixture Library** - Pre-built test data in `fixtures/`
2. **Assertion Helpers** - Nushell functions to assert outputs
3. **Mock Kestra API** - Test without real Kestra instance
4. **Performance Baselines** - Track execution time trends
5. **Contract Validation Tests** - Validate fixtures against contracts
