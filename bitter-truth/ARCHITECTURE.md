# bitter-truth Architecture: Kestra Orchestrates, Nushell Executes

## THE SEPARATION OF CONCERNS

```
┌─────────────────────────────────────────────────────────────┐
│                    KESTRA (Orchestrator)                     │
│  Owns: Loops, Retries, Decisions, State, Workflow Control  │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ calls
                              ▼
┌─────────────────────────────────────────────────────────────┐
│               NUSHELL TOOLS (Stateless Workers)              │
│    Owns: Business Logic, Execution, Return JSON Response    │
│    - generate.nu: Calls LLM, returns code                   │
│    - run-tool.nu: Executes code, returns output             │
│    - validate.nu: Validates, returns pass/fail              │
└─────────────────────────────────────────────────────────────┘
```

## ARCHITECTURE RULES

### ✅ KESTRA RESPONSIBILITIES (Orchestration Layer)

1. **Loop Control** - ForEach over attempts (1 to max_attempts)
2. **Decision Making** - If validation passes → exit, else → retry
3. **State Management** - Track attempt number, feedback, execution context
4. **Error Handling** - Catch failures, escalate after max attempts
5. **Workflow Sequencing** - Generate → Execute → Validate → Check
6. **Retry Logic** - Loop back with feedback on validation failure

**WHERE**: `bitter-truth/kestra/flows/contract-loop-modular.yml`

```yaml
tasks:
  - id: attempt_loop
    type: io.kestra.plugin.core.flow.ForEach  # ← Kestra owns the loop
    values: "{{ range(1, inputs.max_attempts + 1) }}"
    tasks:
      - id: generate_step
        type: io.kestra.plugin.core.flow.Subflow
        # Kestra calls generate.nu via shell task

      - id: validate_step
        type: io.kestra.plugin.core.flow.Subflow
        # Kestra calls validate.nu via shell task

      - id: check_pass
        type: io.kestra.plugin.core.flow.If  # ← Kestra owns decisions
        condition: "{{ validation.success }}"
        then:
          - id: success_exit  # ← Kestra decides to exit
        else:
          - id: collect_feedback  # ← Kestra decides to retry
```

### ✅ NUSHELL RESPONSIBILITIES (Execution Layer)

1. **Accept JSON Input** - Read from stdin
2. **Execute Business Logic** - Generate code, run code, validate code
3. **Return JSON Output** - ToolResponse format with success/error/data
4. **Log Structured JSON** - Emit logs to stderr
5. **NO State** - Stateless functions, no memory between calls
6. **NO Orchestration** - No loops, no retries, no decisions about what to do next

**WHERE**: `bitter-truth/tools/*.nu`

```nu
# generate.nu - WORKER FUNCTION
def main [] {
    let input = open --raw /dev/stdin | from json  # ← Input from Kestra

    # Business logic: Call LLM, generate code
    let result = call_ai_to_generate_code($input)

    # Return success/failure - Kestra decides what to do next
    {
        success: $result.success
        data: { generated_path: "/tmp/tool.nu" }
        trace_id: $input.context.trace_id
    } | to json | print
}
# NO LOOPS, NO RETRIES, NO DECISIONS - Just execute and return
```

## THE 4 LAWS MAPPED TO ARCHITECTURE

| Law | Kestra's Role | Nushell's Role |
|-----|---------------|----------------|
| **1. No-Human Zone** | Calls generate.nu | Executes LLM call, writes code |
| **2. Contract is Law** | Enforces validation gate, loops on failure | Executes validation check |
| **3. We Set the Standard** | Passes contract to tools | Uses contract to generate/validate |
| **4. Orchestrator Runs Everything** | **OWNS THE WORKFLOW** | **EXECUTES THE TASKS** |

## ANTI-PATTERNS (VIOLATIONS)

### ❌ BAD: Nushell doing orchestration

```nu
# DON'T DO THIS IN NUSHELL
def main [] {
    for attempt in 1..5 {  # ← NO! Kestra owns loops
        let result = generate_code()
        if $result.valid {
            break  # ← NO! Kestra owns decisions
        }
    }
}
```

### ✅ GOOD: Kestra orchestrating, Nushell executing

```yaml
# Kestra Flow
- id: loop
  type: ForEach  # ← Kestra owns loop
  values: "{{ range(1, 6) }}"
  tasks:
    - id: gen
      type: Shell
      commands: ["nu generate.nu"]  # ← Calls Nushell worker
```

```nu
# generate.nu
def main [] {
    # Just generate and return - NO loops, NO decisions
    let code = call_ai()
    { success: true, data: $code } | to json | print
}
```

## AUDIT CHECKLIST

- [ ] Nushell tools contain NO ForEach/loop/while
- [ ] Nushell tools contain NO retry logic
- [ ] Nushell tools contain NO if/then workflow decisions
- [ ] Nushell tools are stateless (no global state)
- [ ] Nushell tools accept JSON stdin, return JSON stdout
- [ ] Kestra flow contains ALL loop logic
- [ ] Kestra flow contains ALL retry logic
- [ ] Kestra flow contains ALL workflow decisions
- [ ] Kestra flow manages attempt count
- [ ] Kestra flow manages feedback accumulation

## COMMUNICATION PROTOCOL

**Kestra → Nushell**: JSON via stdin
```json
{
  "contract_path": "/path/to/contract.yaml",
  "task": "Generate echo tool",
  "attempt": "3/5",
  "feedback": "Previous error: missing field 'reversed'",
  "context": {
    "trace_id": "exec-123",
    "dry_run": false
  }
}
```

**Nushell → Kestra**: JSON via stdout
```json
{
  "success": true,
  "data": {
    "generated_path": "/tmp/tool.nu"
  },
  "trace_id": "exec-123",
  "duration_ms": 1234
}
```

**Logs**: JSON via stderr (not seen by Kestra workflow, only logs)
```json
{"level":"info","msg":"generating tool","trace_id":"exec-123"}
```

## SUMMARY

**Kestra is God. Nushell is the angels executing Her will.**

- **Kestra**: Decides WHAT to do, WHEN to do it, HOW MANY TIMES
- **Nushell**: Executes THE TASK and reports back (success/failure/data)
- **The Contract**: Source of truth that both respect
- **The Flow**: Kestra's orchestration pattern (Generate → Execute → Validate → Loop)
- **The Tools**: Nushell's stateless worker functions

This is Lambda-style serverless architecture: Kestra is the orchestrator, Nushell functions are the lambdas.
