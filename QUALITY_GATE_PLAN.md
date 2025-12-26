# Quality Gate System: OODA Loop Architecture

## Vision

A **recursive, self-improving quality gate system** that leverages:
- Kestra orchestration for flow control
- DataContract CLI for schema validation
- Nushell for tool implementation
- OpenCode + Qwen Coder 3 30B3 @ 250 tok/s for AI generation
- OODA loop (Observe → Orient → Decide → Act) for iterative refinement

## The Problem

Current system has 8 quality gates but lacks:
1. **Coverage metrics** - Tests exist but no coverage measurement
2. **Linting** - No static analysis of generated code
3. **Mutation testing** - No testing of the tests themselves
4. **Hostile review** - No adversarial AI review of generated code
5. **Recursive depth** - Single feedback loop, not nested OODA

---

## OODA Loop Quality Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         OUTER OODA LOOP                             │
│  (Strategic: Did we solve the right problem?)                       │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    INNER OODA LOOP                          │   │
│  │  (Tactical: Does the code work correctly?)                  │   │
│  │                                                             │   │
│  │  ┌─────────────────────────────────────────────────────┐   │   │
│  │  │              MICRO OODA LOOP                        │   │   │
│  │  │  (Technical: Is the code well-formed?)              │   │   │
│  │  │                                                     │   │   │
│  │  │   OBSERVE: Parse code, run linter                   │   │   │
│  │  │   ORIENT: Categorize issues (syntax, style, smell)  │   │   │
│  │  │   DECIDE: Auto-fix or regenerate?                   │   │   │
│  │  │   ACT: Apply fix or feed back to generator          │   │   │
│  │  └─────────────────────────────────────────────────────┘   │   │
│  │                                                             │   │
│  │   OBSERVE: Run tests, measure coverage                      │   │
│  │   ORIENT: Identify gaps (uncovered paths, failures)         │   │
│  │   DECIDE: Add tests, fix code, or escalate?                 │   │
│  │   ACT: Generate tests, fix code, collect feedback           │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│   OBSERVE: Contract validation, hostile review                      │
│   ORIENT: Does output match intent? Security issues?                │
│   DECIDE: Accept, refine, or reject entirely?                       │
│   ACT: Ship, iterate, or redesign approach                          │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Quality Gate Stages (12 Gates)

### PHASE 1: GENERATION (Gates 1-3)

```
┌──────────────────────────────────────────────────────────────┐
│  GATE 1: CONTRACT PARSING                                    │
│  ─────────────────────────────────────────────────────────── │
│  Input: contract.yaml                                        │
│  Check: Valid YAML, valid DataContract schema                │
│  Tool: datacontract lint                                     │
│  Fail: Reject with schema errors                             │
└──────────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────┐
│  GATE 2: PROMPT CONSTRUCTION                                 │
│  ─────────────────────────────────────────────────────────── │
│  Input: contract + task + feedback                           │
│  Check: Prompt size limits, context window fit               │
│  Tool: prompt-builder.nu (new)                               │
│  Fail: Truncate feedback, summarize context                  │
└──────────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────┐
│  GATE 3: CODE GENERATION                                     │
│  ─────────────────────────────────────────────────────────── │
│  Input: prompt                                               │
│  Model: Qwen Coder 3 30B @ 250 tok/s                         │
│  Tool: opencode run -m local/qwen3-coder                     │
│  Fail: Timeout, empty output, model unavailable              │
└──────────────────────────────────────────────────────────────┘
```

### PHASE 2: STATIC ANALYSIS (Gates 4-6) - MICRO OODA

```
┌──────────────────────────────────────────────────────────────┐
│  GATE 4: SYNTAX VALIDATION                                   │
│  ─────────────────────────────────────────────────────────── │
│  Input: generated.nu                                         │
│  Check: Valid Nushell syntax                                 │
│  Tool: nu --commands "source $file" (parse-only)             │
│  Fail: Syntax errors → regenerate with error context         │
└──────────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────┐
│  GATE 5: LINTING                                             │
│  ─────────────────────────────────────────────────────────── │
│  Input: generated.nu                                         │
│  Checks:                                                     │
│    - No hardcoded paths                                      │
│    - No shell injection vectors                              │
│    - Required patterns (def main, --help)                    │
│    - Style consistency                                       │
│  Tool: lint-nushell.nu (new)                                 │
│  Fail: Linting errors → regenerate with lint feedback        │
└──────────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────┐
│  GATE 6: SECURITY SCAN                                       │
│  ─────────────────────────────────────────────────────────── │
│  Input: generated.nu                                         │
│  Checks:                                                     │
│    - No credential patterns                                  │
│    - No dangerous commands (rm -rf, :>, etc.)                │
│    - No network calls without explicit contract permission   │
│    - No file writes outside allowed paths                    │
│  Tool: security-scan.nu (new)                                │
│  Fail: Security issue → regenerate with security feedback    │
└──────────────────────────────────────────────────────────────┘
```

### PHASE 3: DYNAMIC TESTING (Gates 7-9) - INNER OODA

```
┌──────────────────────────────────────────────────────────────┐
│  GATE 7: EXECUTION TEST                                      │
│  ─────────────────────────────────────────────────────────── │
│  Input: generated.nu + test_input.json                       │
│  Check: Tool executes without crash                          │
│  Tool: run-tool.nu (existing)                                │
│  Fail: Runtime error → regenerate with error + stack trace   │
└──────────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────┐
│  GATE 8: CONTRACT VALIDATION                                 │
│  ─────────────────────────────────────────────────────────── │
│  Input: output.json + contract.yaml                          │
│  Check: Output matches contract schema exactly               │
│  Tool: datacontract test (existing validate.nu)              │
│  Fail: Schema mismatch → regenerate with validation errors   │
└──────────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────┐
│  GATE 9: COVERAGE ANALYSIS                                   │
│  ─────────────────────────────────────────────────────────── │
│  Input: generated.nu execution traces                        │
│  Checks:                                                     │
│    - All branches exercised                                  │
│    - All error handlers reachable                            │
│    - Edge case inputs tested                                 │
│  Tool: coverage-check.nu (new)                               │
│  Fail: Low coverage → generate additional test cases         │
└──────────────────────────────────────────────────────────────┘
```

### PHASE 4: ADVERSARIAL REVIEW (Gates 10-12) - OUTER OODA

```
┌──────────────────────────────────────────────────────────────┐
│  GATE 10: MUTATION TESTING                                   │
│  ─────────────────────────────────────────────────────────── │
│  Input: generated.nu + test_cases                            │
│  Process:                                                    │
│    1. Generate mutants (change operators, constants, logic)  │
│    2. Run tests against mutants                              │
│    3. Count surviving mutants (test weakness indicator)      │
│  Tool: mutate-test.nu (new)                                  │
│  Fail: High mutant survival → generate stronger tests        │
└──────────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────┐
│  GATE 11: HOSTILE REVIEW                                     │
│  ─────────────────────────────────────────────────────────── │
│  Input: generated.nu + contract + task                       │
│  Reviewer: Second AI instance (skeptical persona)            │
│  Questions:                                                  │
│    - Does this actually solve the stated problem?            │
│    - What edge cases are missed?                             │
│    - What could go wrong in production?                      │
│    - Is this over-engineered or under-engineered?            │
│    - Any hidden assumptions?                                 │
│  Tool: hostile-review.nu (new)                               │
│  Output: Structured critique with severity levels            │
│  Fail: Critical issues → regenerate with critique            │
└──────────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────┐
│  GATE 12: SEMANTIC VALIDATION                                │
│  ─────────────────────────────────────────────────────────── │
│  Input: generated.nu + original task                         │
│  Check: Does the code actually do what was asked?            │
│  Method:                                                     │
│    1. AI summarizes what the code does                       │
│    2. Compare summary to original task                       │
│    3. Flag semantic drift                                    │
│  Tool: semantic-check.nu (new)                               │
│  Fail: Semantic mismatch → regenerate with clarification     │
└──────────────────────────────────────────────────────────────┘
```

---

## New Tools Required

### 1. lint-nushell.nu
```yaml
contract: contracts/tools/lint.yaml
input:
  file_path: string (required)
  rules: list<string> (optional, default: all)
output:
  passed: boolean
  issues: list<{line, column, rule, message, severity}>
  summary: {errors: int, warnings: int, info: int}
```

**Linting Rules**:
- `no-hardcoded-paths`: Flag `/home/`, `/tmp/` without variable
- `no-shell-injection`: Flag `^$"..."` with unvalidated input
- `require-main`: Entry point must be `def main`
- `require-help`: Must handle `--help` flag
- `no-global-mutation`: No `mut` at module scope
- `max-function-length`: Flag functions > 50 lines
- `require-error-handling`: `try` blocks for external calls

### 2. security-scan.nu
```yaml
contract: contracts/tools/security-scan.yaml
input:
  file_path: string (required)
  allowed_paths: list<string> (optional)
  allowed_network: boolean (default: false)
output:
  secure: boolean
  vulnerabilities: list<{type, line, description, severity}>
  risk_score: float (0.0 - 10.0)
```

**Security Checks**:
- Credential patterns (API keys, passwords, tokens)
- Dangerous commands (rm -rf, chmod 777, etc.)
- Network access without permission
- File operations outside sandbox
- Environment variable leakage
- Code injection vectors

### 3. coverage-check.nu
```yaml
contract: contracts/tools/coverage.yaml
input:
  tool_path: string (required)
  test_inputs: list<object> (required)
output:
  coverage_percent: float
  uncovered_lines: list<int>
  uncovered_branches: list<{line, branch}>
  suggested_inputs: list<object>
```

**Coverage Strategy**:
- Trace execution paths using Nushell's `debug` mode
- Identify untaken branches
- Generate synthetic inputs to improve coverage
- Target: 80% line coverage, 70% branch coverage

### 4. mutate-test.nu
```yaml
contract: contracts/tools/mutation.yaml
input:
  tool_path: string (required)
  test_inputs: list<object> (required)
  mutation_count: int (default: 10)
output:
  mutation_score: float (killed / total)
  surviving_mutants: list<{location, mutation, reason}>
  test_quality: string (weak | adequate | strong)
```

**Mutation Operators**:
- Arithmetic: `+` → `-`, `*` → `/`
- Comparison: `==` → `!=`, `<` → `<=`
- Logical: `and` → `or`, `not` removal
- Constant: Numbers ±1, strings empty
- Control flow: Remove branches, swap order

### 5. hostile-review.nu
```yaml
contract: contracts/tools/hostile-review.yaml
input:
  tool_path: string (required)
  contract_path: string (required)
  task: string (required)
output:
  approved: boolean
  critique: list<{aspect, issue, severity, suggestion}>
  questions: list<string>
  overall_assessment: string
```

**Review Dimensions**:
- **Correctness**: Does it solve the problem?
- **Completeness**: Are all edge cases handled?
- **Security**: Any vulnerabilities?
- **Performance**: Any obvious inefficiencies?
- **Maintainability**: Is it understandable?
- **Contract Alignment**: Does output match schema?

### 6. semantic-check.nu
```yaml
contract: contracts/tools/semantic-check.yaml
input:
  tool_path: string (required)
  original_task: string (required)
output:
  aligned: boolean
  code_summary: string
  task_interpretation: string
  drift_score: float (0.0 = perfect, 1.0 = completely wrong)
  misalignments: list<{aspect, expected, actual}>
```

---

## Kestra Flow Architecture

### Main Orchestrator: quality-gate-loop.yml

```yaml
id: quality-gate-loop
namespace: bitter
description: 12-gate quality system with nested OODA loops

inputs:
  - id: contract
    type: STRING
  - id: task
    type: STRING
  - id: input_json
    type: STRING
    defaults: "{}"
  - id: max_attempts
    type: INT
    defaults: 5
  - id: coverage_threshold
    type: FLOAT
    defaults: 0.8
  - id: mutation_threshold
    type: FLOAT
    defaults: 0.6
  - id: enable_hostile_review
    type: BOOLEAN
    defaults: true

variables:
  tools_dir: "{{ projectDir }}/bitter-truth/tools"
  trace_id: "{{ execution.id }}"
  feedback: ""
  gate_results: {}

tasks:
  # PHASE 1: GENERATION
  - id: gate_1_contract_parse
    type: io.kestra.plugin.core.flow.Subflow
    flowId: gate-contract-parse
    namespace: bitter
    inputs:
      contract_path: "{{ inputs.contract }}"
      trace_id: "{{ vars.trace_id }}"

  - id: gate_2_prompt_build
    type: io.kestra.plugin.core.flow.Subflow
    flowId: gate-prompt-build
    namespace: bitter
    inputs:
      contract_path: "{{ inputs.contract }}"
      task: "{{ inputs.task }}"
      feedback: "{{ vars.feedback }}"
      trace_id: "{{ vars.trace_id }}"

  - id: gate_3_generate
    type: io.kestra.plugin.core.flow.Subflow
    flowId: generate-tool-testable
    namespace: bitter
    inputs:
      contract_path: "{{ inputs.contract }}"
      task: "{{ inputs.task }}"
      feedback: "{{ vars.feedback }}"
      attempt: "{{ taskrun.iteration }}/{{ inputs.max_attempts }}"
      trace_id: "{{ vars.trace_id }}"

  # PHASE 2: STATIC ANALYSIS (Micro OODA)
  - id: micro_ooda_loop
    type: io.kestra.plugin.core.flow.Subflow
    flowId: micro-ooda-static-analysis
    namespace: bitter
    inputs:
      tool_path: "{{ outputs.gate_3_generate.outputs.tool_path }}"
      trace_id: "{{ vars.trace_id }}"

  # PHASE 3: DYNAMIC TESTING (Inner OODA)
  - id: inner_ooda_loop
    type: io.kestra.plugin.core.flow.Subflow
    flowId: inner-ooda-dynamic-testing
    namespace: bitter
    inputs:
      tool_path: "{{ outputs.gate_3_generate.outputs.tool_path }}"
      contract_path: "{{ inputs.contract }}"
      input_json: "{{ inputs.input_json }}"
      coverage_threshold: "{{ inputs.coverage_threshold }}"
      trace_id: "{{ vars.trace_id }}"

  # PHASE 4: ADVERSARIAL REVIEW (Outer OODA)
  - id: outer_ooda_loop
    type: io.kestra.plugin.core.flow.Subflow
    flowId: outer-ooda-adversarial-review
    namespace: bitter
    inputs:
      tool_path: "{{ outputs.gate_3_generate.outputs.tool_path }}"
      contract_path: "{{ inputs.contract }}"
      task: "{{ inputs.task }}"
      mutation_threshold: "{{ inputs.mutation_threshold }}"
      enable_hostile_review: "{{ inputs.enable_hostile_review }}"
      trace_id: "{{ vars.trace_id }}"

  # DECISION: Pass or Loop
  - id: check_all_gates
    type: io.kestra.plugin.core.flow.If
    condition: "{{ all gates passed }}"
    then:
      - id: success
        type: io.kestra.plugin.core.log.Log
        message: "All 12 gates passed!"
    else:
      - id: collect_feedback
        type: io.kestra.plugin.core.flow.Subflow
        flowId: collect-comprehensive-feedback
        namespace: bitter
      - id: loop_back
        type: io.kestra.plugin.core.flow.Subflow
        flowId: quality-gate-loop  # Recursive!
        inputs:
          # ... with accumulated feedback
```

### Subflow: micro-ooda-static-analysis.yml

```yaml
id: micro-ooda-static-analysis
namespace: bitter
description: Gates 4-6 with internal retry loop

inputs:
  - id: tool_path
    type: STRING
  - id: trace_id
    type: STRING
  - id: max_micro_attempts
    type: INT
    defaults: 3

tasks:
  - id: micro_loop
    type: io.kestra.plugin.core.flow.ForEach
    values: "{{ range(1, inputs.max_micro_attempts + 1) }}"
    tasks:
      - id: gate_4_syntax
        type: io.kestra.plugin.scripts.shell.Commands
        commands:
          - nu --commands "source {{ inputs.tool_path }}" 2>&1 || true

      - id: gate_5_lint
        type: io.kestra.plugin.core.flow.Subflow
        flowId: gate-lint
        namespace: bitter
        inputs:
          tool_path: "{{ inputs.tool_path }}"

      - id: gate_6_security
        type: io.kestra.plugin.core.flow.Subflow
        flowId: gate-security-scan
        namespace: bitter
        inputs:
          tool_path: "{{ inputs.tool_path }}"

      - id: micro_check
        type: io.kestra.plugin.core.flow.If
        condition: "{{ all micro gates pass }}"
        then:
          - id: micro_success
            type: io.kestra.plugin.core.flow.Break
        else:
          - id: micro_fix
            type: io.kestra.plugin.core.flow.Subflow
            flowId: auto-fix-issues
            namespace: bitter
```

---

## OODA Loop Decision Matrix

### Micro OODA (Static Analysis) Decisions

| Observation | Orientation | Decision | Action |
|-------------|-------------|----------|--------|
| Syntax error | Parse failure | Auto-fix possible? | Regenerate with error context |
| Lint warning | Style issue | Severity check | Ignore INFO, fix WARN/ERROR |
| Lint error | Code smell | Pattern match | Regenerate with lint feedback |
| Security vuln | Risk assessment | Severity ≥ HIGH? | Block and regenerate |
| Security warn | Low risk | Acceptable? | Log and continue |

### Inner OODA (Dynamic Testing) Decisions

| Observation | Orientation | Decision | Action |
|-------------|-------------|----------|--------|
| Test pass | Happy path works | Coverage check | Continue or add tests |
| Test fail | Logic error | Fixable? | Regenerate with failure |
| Low coverage | Untested paths | Gap analysis | Generate test cases |
| Contract fail | Schema mismatch | Field analysis | Regenerate with schema errors |
| Timeout | Performance issue | Optimize? | Add timeout handling |

### Outer OODA (Adversarial Review) Decisions

| Observation | Orientation | Decision | Action |
|-------------|-------------|----------|--------|
| High mutant survival | Weak tests | Add tests? | Generate mutation-killing tests |
| Hostile critique | Design flaw | Severity? | Regenerate or accept |
| Semantic drift | Wrong solution | Alignment? | Clarify task, regenerate |
| All gates pass | Quality achieved | Ship it | Output final tool |

---

## Feedback Accumulation Strategy

### Feedback Structure

```yaml
feedback:
  attempt: 3
  history:
    - attempt: 1
      gates_failed: [5, 8, 11]
      issues:
        - gate: 5
          type: lint
          message: "Function too long (72 lines)"
        - gate: 8
          type: contract
          message: "Missing required field: trace_id"
        - gate: 11
          type: hostile_review
          message: "No error handling for empty input"
    - attempt: 2
      gates_failed: [8]
      issues:
        - gate: 8
          type: contract
          message: "trace_id must be string, got null"

  patterns_detected:
    - "Repeated trace_id issues - emphasize in prompt"
    - "Error handling frequently missing"

  successful_elements:
    - "Main logic correct"
    - "Output structure improved"
    - "Lint issues resolved"
```

### Progressive Prompt Enhancement

```
Attempt 1: Base prompt + contract + task
Attempt 2: + Previous errors + what worked
Attempt 3: + Pattern analysis + explicit constraints
Attempt 4: + Concrete examples + anti-patterns
Attempt 5: + Simplified task + fallback strategy
```

---

## Metrics & Observability

### Quality Metrics

```yaml
execution_metrics:
  trace_id: "abc123"
  total_duration_ms: 45000
  gates:
    - id: 1
      name: "contract_parse"
      status: pass
      duration_ms: 100
    - id: 5
      name: "lint"
      status: fail
      duration_ms: 500
      issues_found: 3
    # ...

  attempts: 3
  final_status: success

  quality_scores:
    coverage: 0.87
    mutation_score: 0.72
    hostile_review_score: 0.85
    security_score: 1.0

  feedback_effectiveness:
    issues_per_attempt: [5, 2, 0]
    convergence_rate: 0.6
```

### Dashboard Metrics

- **Gate Pass Rate**: % of executions passing each gate
- **Attempt Distribution**: Histogram of attempts needed
- **Common Failure Modes**: Top issues by gate
- **AI Efficiency**: Tokens spent vs. quality achieved
- **Time to Quality**: Duration from task to passing all gates

---

## Implementation Phases

### Phase 1: Foundation (Current + Enhancements)
- [ ] Add syntax validation gate (Gate 4)
- [ ] Create lint-nushell.nu tool (Gate 5)
- [ ] Create security-scan.nu tool (Gate 6)
- [ ] Deploy micro-ooda-static-analysis.yml flow

### Phase 2: Dynamic Testing
- [ ] Create coverage-check.nu tool (Gate 9)
- [ ] Implement test case generation
- [ ] Deploy inner-ooda-dynamic-testing.yml flow
- [ ] Add coverage threshold enforcement

### Phase 3: Adversarial Review
- [ ] Create mutate-test.nu tool (Gate 10)
- [ ] Create hostile-review.nu tool (Gate 11)
- [ ] Create semantic-check.nu tool (Gate 12)
- [ ] Deploy outer-ooda-adversarial-review.yml flow

### Phase 4: Integration
- [ ] Deploy quality-gate-loop.yml orchestrator
- [ ] Implement feedback accumulation
- [ ] Add metrics collection
- [ ] Create dashboard

### Phase 5: Optimization
- [ ] Tune thresholds based on data
- [ ] Optimize AI prompt templates
- [ ] Add caching for repeated patterns
- [ ] Implement parallel gate execution where possible

---

## Key Design Decisions

### 1. Recursive vs. Iterative

**Chosen: Hybrid**
- Micro OODA: Iterative (3 attempts, fast fixes)
- Inner OODA: Iterative (5 attempts, test improvements)
- Outer OODA: Recursive (can restart from generation)

### 2. Fail Fast vs. Collect All

**Chosen: Collect All per Phase, Fail Fast between Phases**
- Within a phase: Run all gates, collect all issues
- Between phases: Don't proceed if phase fails
- Reason: More feedback = better regeneration

### 3. AI Review: Same Model vs. Different Model

**Chosen: Same Model, Different Persona**
- Use Qwen Coder 3 for both generation and review
- Hostile reviewer uses skeptical system prompt
- Reason: Speed (250 tok/s), cost efficiency

### 4. Test Generation: AI vs. Property-Based

**Chosen: AI with Property-Based Fallback**
- Primary: AI generates test cases from contract
- Fallback: Property-based testing for edge cases
- Reason: AI understands intent, properties catch edges

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Infinite loops | Max attempts at each OODA level |
| Token explosion | Feedback summarization, context window management |
| False positives | Severity thresholds, human escape hatch |
| AI hallucination | Schema validation as ground truth |
| Performance | Parallel gates, caching, fast model |
| Circular feedback | Pattern detection, feedback deduplication |

---

## Success Criteria

1. **Correctness**: 95% of generated tools pass all 12 gates within 5 attempts
2. **Coverage**: 80% line coverage minimum on generated code
3. **Mutation Score**: 60% minimum (tests kill 60% of mutants)
4. **Security**: 0 high-severity vulnerabilities in shipped code
5. **Semantic Alignment**: <0.2 drift score between task and implementation
6. **Efficiency**: Average 2.5 attempts to pass all gates
