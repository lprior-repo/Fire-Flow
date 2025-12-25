# Modular Kestra Workflow Architecture

## Philosophy: Pure Functional Composition

Kestra workflows are now decomposed into small, testable, chainable components following pure functional principles:

- **Single Responsibility**: Each component does one thing well
- **Pure Functions**: Same input → Same output (deterministic)
- **Composable**: Components can be chained via Subflows
- **Independently Testable**: Each component tested in isolation
- **No Side Effects**: Only file I/O (output_path, logs_path)

This mirrors how Nushell and Rust handle modular code - small, composable functions with clear inputs/outputs.

## Components

### 1. `generate-tool.yml` - AI Code Generation

**Purpose**: AI generates Nushell tool from DataContract + task description

**Inputs**:
```yaml
contract_path: string    # Path to DataContract YAML
task: string             # Natural language intent
feedback: string         # Feedback from previous attempt (for self-healing)
attempt: string          # Current attempt (e.g., "2/5")
tools_dir: string        # Directory containing tools
timeout_seconds: int     # Timeout for AI generation
trace_id: string         # Trace ID for observability
```

**Outputs**:
```yaml
tool_path: string        # Path to generated Nushell tool (/tmp/tool.nu)
```

**Laws Enforced**:
- Law 1: No-Human Zone - AI is exclusive author of Nushell
- Law 4: Orchestrator Runs Everything - Via Kestra

**Error Handling**:
- Missing contract → JSON error response with trace_id
- Invalid task → JSON error response with trace_id
- Timeout (exit 124) → JSON error response
- OpenCode failure → JSON error response

---

### 2. `execute-tool.yml` - Tool Execution

**Purpose**: Execute generated Nushell tool with JSON input

**Inputs**:
```yaml
tool_path: string        # Path to generated tool
tool_input: string       # JSON input for tool (as string)
output_path: string      # Where to save tool output
logs_path: string        # Where to save tool logs
tools_dir: string        # Directory containing tools
trace_id: string         # Trace ID for observability
```

**Outputs**:
```yaml
output_file: string      # Path to output (/tmp/output.json)
logs_file: string        # Path to logs (/tmp/logs.json)
```

**Pure Function Pattern**:
```
tool + input → output + logs
```

**Error Handling**:
- Malformed JSON input → Graceful error, exit 0 (self-healing)
- Tool crash → Exit 0, error in output_file
- Missing tool → Error response with trace_id

---

### 3. `validate-tool.yml` - Contract Validation

**Purpose**: Validate tool output against DataContract

**Inputs**:
```yaml
contract_path: string    # Path to DataContract YAML
output_path: string      # Path to tool output to validate
tools_dir: string        # Directory containing tools
trace_id: string         # Trace ID for observability
dry_run: boolean         # Skip validation, return success
```

**Outputs**:
```yaml
validation_result: string # JSON response with success/valid fields
output_file: string        # Path to output file
```

**Laws Enforced**:
- Law 2: Contract is Law - Draconian validation
- Law 3: We Set the Standard - Contract defines correctness

**Behavior**:
- Valid output → `{"success": true, "data": {"valid": true}}`
- Invalid output → `{"success": false, "data": {"valid": false, "errors": [...]}}`
- **Always exits 0** (self-healing pattern)

---

### 4. `collect-feedback.yml` - Self-Healing Feedback

**Purpose**: Collect feedback from failed attempt for AI retry

**Inputs**:
```yaml
output_file: string      # Tool output from failed attempt
logs_file: string        # Tool logs from failed attempt
validation_errors: string # Errors from contract validation
attempt_number: string   # Current attempt (e.g., "2/5")
```

**Outputs**:
```yaml
feedback: string         # AI-readable feedback for next attempt
```

**Output Format**:
```
ATTEMPT 2/5 FAILED.

CONTRACT ERRORS:
Missing required field: 'reversed'

OUTPUT PRODUCED:
{ "success": true, "data": { "echo": "test" } }

LOGS:
[error logs from tool execution]

FIX THE NUSHELL SCRIPT TO SATISFY THE CONTRACT.
```

**Behavior**:
- Transforms failure signals into structured AI prompts
- No AI hallucination - just objective facts (errors, output, logs)
- Guides AI toward solution ("FIX THE NUSHELL SCRIPT")

---

## Composition: The Self-Healing Loop

### Sequential Chaining (Single Attempt)

```
generate-tool
    ↓ (tool_path)
execute-tool
    ↓ (output_file)
validate-tool
    ↓ (validation_result)
[IF valid]
    → SUCCESS (exit)
[IF invalid]
    → collect-feedback
        ↓ (feedback)
    → [update feedback variable]
    → [retry with next attempt]
```

### The Loop (Multiple Attempts)

```nushell
foreach attempt in [1..max_attempts]:
    result = generate-tool(contract, task, feedback, attempt)
    output = execute-tool(result.tool_path, input)
    validation = validate-tool(contract, output.output_file)

    if validation.valid:
        return SUCCESS
    else:
        feedback = collect-feedback(output, validation.errors, attempt)
        # continue to next iteration
```

---

## Orchestration: `contract-loop-modular.yml`

The modular orchestrator composes components via Kestra Subflows:

```yaml
tasks:
  - id: attempt_loop
    type: io.kestra.plugin.core.flow.ForEach
    values: "{{ range(1, max_attempts + 1) }}"
    tasks:
      - id: generate_step
        type: io.kestra.plugin.core.flow.Subflow
        flowId: generate-tool
        inputs: [contract, task, feedback, attempt, ...]

      - id: execute_step
        type: io.kestra.plugin.core.flow.Subflow
        flowId: execute-tool
        inputs: [tool_path from generate_step, input, ...]

      - id: validate_step
        type: io.kestra.plugin.core.flow.Subflow
        flowId: validate-tool
        inputs: [contract, output_path from execute_step, ...]

      - id: check_pass
        type: io.kestra.plugin.core.flow.If
        condition: "{{ validate_step output is valid }}"
        then: [exit SUCCESS]

      - id: feedback_step
        type: io.kestra.plugin.core.flow.Subflow
        flowId: collect-feedback
        inputs: [output, validation errors, attempt, ...]

      - id: update_feedback
        type: io.kestra.plugin.core.execution.SetVariables
        variables:
          feedback: "{{ feedback_step output }}"

  - id: escalate
    type: io.kestra.plugin.core.log.Log
    message: "Max attempts exceeded - escalate to human"
```

---

## The 4 Laws (Enforced by Architecture)

### Law 1: No-Human Zone (Humans write contracts, AI writes Nushell)

**Enforcement**:
- `generate-tool` is the **only** place Nushell is authored
- Contract is written in YAML (human domain)
- All tool editing done through contract evolution + feedback loop

### Law 2: Contract is Law (Validation is draconian, self-heal on failure)

**Enforcement**:
- `validate-tool` uses DataContract CLI (external, authoritative)
- Validation failures trigger `collect-feedback` (not error escalation)
- No partial success - either full compliance or retry

### Law 3: We Set the Standard (Human defines target, AI hits it)

**Enforcement**:
- Contract (human-written) defines all requirements
- AI adjusts based on validation feedback
- Final validation gate ensures compliance

### Law 4: Orchestrator Runs Everything (Kestra owns execution)

**Enforcement**:
- All tools run inside Kestra tasks
- Execution context (trace_id, attempt) provided by Kestra
- Feedback loop controlled by ForEach + SetVariables in Kestra

---

## Testing Strategy

### Unit Tests (Per-Component)
Each component tested independently in `test_modular_workflows.nu`:

- `modular_generate_creates_nushell_tool` - Generate produces valid code
- `modular_execute_runs_tool_with_input` - Execute runs tool correctly
- `modular_validate_accepts_correct_output` - Validate detects compliance
- `modular_validate_rejects_invalid_output` - Validate detects violations
- `modular_collect_feedback_builds_message` - Feedback is AI-readable

### Integration Tests (Chaining)
Components chained together:

- `modular_chain_generate_to_execute` - Generate → Execute
- `modular_chain_execute_to_validate` - Execute → Validate
- `modular_full_pipeline_success` - Generate → Execute → Validate (pass)
- `modular_pipeline_with_feedback_loop` - Attempt 1 fails, Attempt 2 succeeds

### Purity Tests
Verify components are pure (deterministic):

- `modular_execute_is_pure` - Same input → Same output
- `modular_validate_is_pure` - Validation result consistent

---

## Usage

### Deploy a Component

```bash
# Deploy generate-tool
kestra-api "/api/v1/flows/bitter/generate-tool" \
  --method PUT \
  --data "$(cat bitter-truth/kestra/flows/generate-tool.yml)"

# Deploy all components
for f in bitter-truth/kestra/flows/*.yml; do
  kestra-api "/api/v1/flows/bitter/$(basename $f .yml)" \
    --method PUT \
    --data "$(cat $f)"
done
```

### Trigger Full Workflow

```bash
kestra-api "/api/v1/executions/bitter/contract-loop-modular" \
  --method POST \
  --data '{
    "contract": "bitter-truth/contracts/tools/echo.yaml",
    "task": "Create an echo tool",
    "input_json": "{\"message\": \"Hello\"}",
    "max_attempts": 5,
    "tools_dir": "./bitter-truth/tools"
  }'
```

### Trigger Single Component

```bash
kestra-api "/api/v1/executions/bitter/generate-tool" \
  --method POST \
  --data '{
    "contract_path": "bitter-truth/contracts/tools/echo.yaml",
    "task": "Create echo tool",
    "feedback": "Initial generation",
    "attempt": "1/5",
    "tools_dir": "./bitter-truth/tools",
    "timeout_seconds": 300,
    "trace_id": "manual-001"
  }'
```

---

## Evolution

Components can be:
1. **Optimized independently** - Change generate logic without affecting execute
2. **Replaced** - Swap validate.nu for different validator without changing orchestration
3. **Extended** - Add new components (pre-execute hooks, post-validate logging)
4. **Tested** - Each component has isolated test suite
5. **Monitored** - Trace ID flows through all components for observability

---

## Principles Reflected

**Pure Functional Programming**:
- Functions (components) have clear inputs/outputs
- No hidden state (all context via variables)
- Composition builds complex behavior from simple pieces
- Referential transparency (same input = same output)

**UNIX Philosophy**:
- Do one thing and do it well
- Compose simple pieces to build complex workflows
- Text-based interfaces (JSON input/output)

**Nushell/Rust Style**:
- Small, focused functions
- Pipeable data (JSON)
- Error handling via structured responses
- Type safety via contracts

