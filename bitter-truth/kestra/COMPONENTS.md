# Modular Workflow Components - Quick Reference

## The Four Components

| Component | Purpose | Input | Output | Composition Pattern |
|-----------|---------|-------|--------|---------------------|
| `generate-tool.yml` | AI generates Nushell from contract | contract_path, task, feedback, attempt | tool_path | Source |
| `execute-tool.yml` | Run generated tool with input | tool_path, tool_input | output_path, logs_path | Sequential |
| `validate-tool.yml` | Validate output against contract | contract_path, output_path | validation_result | Gating |
| `collect-feedback.yml` | Build feedback for AI retry | output_path, logs_path, validation_errors | feedback | Transformation |

## Data Flow Diagram

```
[Human Contract]
      ↓
[generate-tool] → /tmp/tool.nu
      ↓
[Human Input JSON]
      ↓
[execute-tool] → /tmp/output.json + /tmp/logs.json
      ↓
[validate-tool] → { success, valid, errors }
      ↓
    [IF VALID] → SUCCESS EXIT
    [IF INVALID] ↓
[collect-feedback] → feedback text
      ↓
[SetVariables: update feedback]
      ↓
[RETRY with next attempt]
```

## Usage Patterns

### Pattern 1: Sequential Chaining (in contract-loop-modular.yml)

```yaml
- id: generate_step
  type: io.kestra.plugin.core.flow.Subflow
  flowId: generate-tool

- id: execute_step
  type: io.kestra.plugin.core.flow.Subflow
  flowId: execute-tool
  inputs:
    tool_path: "{{ outputs.generate_step.tool_path }}"

- id: validate_step
  type: io.kestra.plugin.core.flow.Subflow
  flowId: validate-tool
  inputs:
    output_path: "{{ outputs.execute_step.output_file }}"
```

### Pattern 2: Error Handling (Self-Healing)

```yaml
- id: check_pass
  type: io.kestra.plugin.core.flow.If
  condition: "{{ outputs.validate_step.success }}"
  then:
    - id: exit_success
      type: io.kestra.plugin.core.execution.Exit
      state: SUCCESS

# If not passing, continue to feedback collection (implicit)

- id: feedback_step
  type: io.kestra.plugin.core.flow.Subflow
  flowId: collect-feedback
  inputs:
    validation_errors: "{{ outputs.validate_step.validation_result }}"
```

### Pattern 3: Loop with Retry

```yaml
- id: attempt_loop
  type: io.kestra.plugin.core.flow.ForEach
  values: "{{ range(1, max_attempts + 1) }}"
  tasks:
    # [generate → execute → validate → feedback → update] loop

- id: update_feedback
  type: io.kestra.plugin.core.execution.SetVariables
  variables:
    feedback: "{{ outputs.feedback_step.feedback }}"
    # Next iteration uses updated feedback variable
```

## Testing Components

Run tests:
```bash
# All modular tests
nutest run-tests --path bitter-truth/tests/test_modular_workflows.nu

# Specific test
nutest run-tests --path bitter-truth/tests/test_modular_workflows.nu --filter "modular_execute_is_pure"
```

Test Categories:
- **Module Tests** (1 component): `modular_generate_*`, `modular_execute_*`, `modular_validate_*`, `modular_collect_*`
- **Composition Tests** (2+ components): `modular_chain_*`, `modular_full_*`
- **Purity Tests** (determinism): `modular_*_is_pure`

## Component Files

| File | Type | Lines | Purpose |
|------|------|-------|---------|
| `generate-tool.yml` | Subflow | 80 | AI code generation with opencode |
| `execute-tool.yml` | Subflow | 70 | Tool execution with stdin/stdout |
| `validate-tool.yml` | Subflow | 65 | DataContract validation |
| `collect-feedback.yml` | Subflow | 65 | Feedback generation for retry |
| `contract-loop-modular.yml` | Orchestrator | 180 | Composes all 4 components in loop |
| `contract-loop.yml` | Monolithic | 210 | Original (still available for reference) |

## Key Design Decisions

1. **Subflows, Not Shared State**: Each component is a Kestra Subflow (reusable, testable)
2. **JSON I/O, Not Direct Composition**: Components communicate via JSON files (`/tmp/output.json`, etc.)
3. **Always Exit 0**: Tools exit 0 for orchestration control (self-healing pattern)
4. **Trace ID Propagation**: Every component receives and logs trace_id for observability
5. **No Docker**: Process runner only (per requirement: "Minus the docker no fucking docker")
6. **Feedback Loop**: Failed attempts feed back into generate step (not escalation)

## Migration Path

**Old**: Single `contract-loop.yml` flow
```
tasks:
  - id: loop
    tasks:
      - id: generate (inline)
      - id: execute (inline)
      - id: validate (inline)
      - id: self_heal (inline)
```

**New**: Modular `contract-loop-modular.yml` using Subflows
```
tasks:
  - id: attempt_loop
    tasks:
      - id: generate_step
        type: io.kestra.plugin.core.flow.Subflow
        flowId: generate-tool
      - id: execute_step
        type: io.kestra.plugin.core.flow.Subflow
        flowId: execute-tool
      # ... etc
```

Both versions coexist - original available for reference/debugging.

## Debugging a Component

### Generate Tool Failed
```bash
# Check if tool was created
test -f /tmp/tool.nu && cat /tmp/tool.nu || echo "Not created"

# Check AI output
kestra-api "/api/v1/logs/{exec-id}" | grep "opencode"
```

### Execution Failed
```bash
# Check output and logs
cat /tmp/output.json
cat /tmp/logs.json
```

### Validation Failed
```bash
# Run validate manually
echo '{ contract_path: "...", output_path: "/tmp/output.json", server: "local" }' | \
  to json | nu bitter-truth/tools/validate.nu
```

### Feedback Loop Stuck
```bash
# Check feedback content
cat /tmp/feedback.txt

# Check if variables were updated
kestra-api "/api/v1/executions/{exec-id}" | jq .variables.feedback
```

## When to Use Each Pattern

| Scenario | Pattern | Component(s) |
|----------|---------|--------------|
| Test AI generation only | Unit | generate-tool |
| Test tool execution | Unit | execute-tool |
| Test validation | Unit | validate-tool |
| Test self-healing loop | Integration | all 4 |
| Manually trigger workflow | CLI | contract-loop-modular |
| One-off validation | Direct tool | validate.nu |

