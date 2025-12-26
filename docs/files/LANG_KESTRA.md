# AI Code Validator - Kestra Module

Kestra workflow-specific shortcuts, hallucinations, and validation rules. Load when reviewing Kestra YAML flows.

---

## Kestra-Specific Shortcuts

### KE001: Missing Error Handling [HIGH]

AI creates flows without error handling, retry, or timeout configuration.

```yaml
# Shortcut: No resilience
id: process_data
namespace: prod
tasks:
  - id: fetch
    type: io.kestra.plugin.core.http.Request
    uri: https://api.example.com/data
  - id: process
    type: io.kestra.plugin.scripts.python.Script
    script: |
      # process data

# Correct: With resilience
id: process_data
namespace: prod
tasks:
  - id: fetch
    type: io.kestra.plugin.core.http.Request
    uri: https://api.example.com/data
    retry:
      type: constant
      maxAttempt: 3
      interval: PT30S
    timeout: PT5M
  - id: process
    type: io.kestra.plugin.scripts.python.Script
    timeout: PT10M
    script: |
      # process data

errors:
  - id: alert_on_failure
    type: io.kestra.plugin.notifications.slack.SlackIncomingWebhook
    url: "{{ secret('SLACK_WEBHOOK') }}"
    payload: |
      {"text": "Flow {{ flow.id }} failed: {{ errorLogs() }}"}
```

Detection: Check for `retry`, `timeout`, and `errors` sections.

### KE002: Hardcoded Secrets [BLOCKING]

AI embeds credentials directly in flow YAML.

```yaml
# WRONG: Secrets in plain text
- id: connect_db
  type: io.kestra.plugin.jdbc.postgresql.Query
  url: jdbc:postgresql://db.example.com:5432/prod
  username: admin
  password: supersecret123  # NEVER DO THIS

# WRONG: Secrets in variables
variables:
  db_password: supersecret123

# Correct: Using secret() function
- id: connect_db
  type: io.kestra.plugin.jdbc.postgresql.Query
  url: "{{ secret('DB_URL') }}"
  username: "{{ secret('DB_USER') }}"
  password: "{{ secret('DB_PASSWORD') }}"
```

Detection: Search for `password:`, `token:`, `key:`, `secret:` with literal values.

### KE003: Missing Namespace Organization [MEDIUM]

AI uses flat namespace or hardcodes `dev`/`test` namespaces.

```yaml
# Weak: Flat namespace
id: my_flow
namespace: myflow

# Weak: Hardcoded environment
id: my_flow
namespace: dev.data

# Better: Hierarchical by domain
id: ingest_orders
namespace: company.data.orders

# With environment handled via deployment, not namespace
```

### KE004: Output Ignorance [HIGH]

AI doesn't capture or propagate task outputs.

```yaml
# Shortcut: Output lost
tasks:
  - id: query
    type: io.kestra.plugin.jdbc.postgresql.Query
    sql: SELECT * FROM users
    # No fetch/store
    
  - id: use_results
    type: io.kestra.plugin.scripts.python.Script
    script: |
      # Can't access query results!

# Correct: Capture outputs
tasks:
  - id: query
    type: io.kestra.plugin.jdbc.postgresql.Query
    sql: SELECT * FROM users
    fetch: true
    store: true
    
  - id: use_results
    type: io.kestra.plugin.scripts.python.Script
    inputFiles:
      data.json: "{{ outputs.query.uri }}"
    script: |
      import json
      with open('data.json') as f:
          users = json.load(f)
```

### KE005: Pebble Template Errors [HIGH]

AI uses incorrect Pebble template syntax.

```yaml
# Wrong: Jinja2 syntax
sql: SELECT * FROM {{ table_name }}  # Missing quotes for Pebble

# Wrong: Direct variable access
message: Hello {{ inputs.name }}!  # May work but fragile

# Correct: Proper Pebble expressions
sql: SELECT * FROM {{ inputs.table_name }}
message: "Hello {{ inputs.name | default('World') }}!"

# Wrong: Missing null handling
file: "{{ outputs.previous.uri }}"  # Crashes if previous failed

# Correct: With fallback
file: "{{ outputs.previous.uri | default('') }}"
```

### KE006: Script Task Anti-patterns [HIGH]

#### Inline scripts that should be files
```yaml
# Bad: Long inline script
- id: process
  type: io.kestra.plugin.scripts.python.Script
  script: |
    import pandas as pd
    import json
    # ... 100 more lines ...

# Better: Namespace file reference
- id: process
  type: io.kestra.plugin.scripts.python.Script
  namespaceFiles:
    enabled: true
  script: "{{ read('scripts/process.py') }}"
```

#### Missing beforeCommands for dependencies
```yaml
# Wrong: Assumes packages exist
- id: analyze
  type: io.kestra.plugin.scripts.python.Script
  script: |
    import pandas as pd  # Not installed!
    import requests      # Not installed!

# Correct: Install dependencies
- id: analyze
  type: io.kestra.plugin.scripts.python.Script
  beforeCommands:
    - pip install pandas requests
  script: |
    import pandas as pd
    import requests
```

#### Not using containerImage for reproducibility
```yaml
# Fragile: Uses worker's Python
- id: ml_predict
  type: io.kestra.plugin.scripts.python.Script
  script: |
    import tensorflow as tf

# Robust: Containerized
- id: ml_predict
  type: io.kestra.plugin.scripts.python.Script
  taskRunner:
    type: io.kestra.plugin.scripts.runner.docker.Docker
  containerImage: tensorflow/tensorflow:2.15.0
  script: |
    import tensorflow as tf
```

### KE007: Trigger Misconfiguration [HIGH]

#### Schedule without timezone
```yaml
# Ambiguous: What timezone?
triggers:
  - id: daily
    type: io.kestra.plugin.core.trigger.Schedule
    cron: "0 9 * * *"

# Correct: Explicit timezone
triggers:
  - id: daily
    type: io.kestra.plugin.core.trigger.Schedule
    cron: "0 9 * * *"
    timezone: America/New_York
```

#### Event trigger without conditions
```yaml
# Dangerous: Triggers on ANY execution
triggers:
  - id: on_complete
    type: io.kestra.plugin.core.trigger.Flow
    
# Correct: Scoped trigger
triggers:
  - id: on_complete
    type: io.kestra.plugin.core.trigger.Flow
    conditions:
      - type: io.kestra.plugin.core.condition.ExecutionStatusCondition
        in:
          - SUCCESS
      - type: io.kestra.plugin.core.condition.ExecutionNamespaceCondition
        namespace: company.data
        comparison: PREFIX
```

### KE008: Flow Control Mistakes [HIGH]

#### Sequential when parallel possible
```yaml
# Slow: Sequential execution
tasks:
  - id: extract_a
    type: io.kestra.plugin.core.http.Request
    uri: https://api-a.example.com
  - id: extract_b
    type: io.kestra.plugin.core.http.Request
    uri: https://api-b.example.com
  - id: extract_c
    type: io.kestra.plugin.core.http.Request
    uri: https://api-c.example.com

# Fast: Parallel execution
tasks:
  - id: extract_all
    type: io.kestra.plugin.core.flow.Parallel
    tasks:
      - id: extract_a
        type: io.kestra.plugin.core.http.Request
        uri: https://api-a.example.com
      - id: extract_b
        type: io.kestra.plugin.core.http.Request
        uri: https://api-b.example.com
      - id: extract_c
        type: io.kestra.plugin.core.http.Request
        uri: https://api-c.example.com
```

#### Missing condition handling
```yaml
# Bug: No else branch
tasks:
  - id: check_data
    type: io.kestra.plugin.core.flow.If
    condition: "{{ outputs.validate.valid }}"
    then:
      - id: process
        type: ...
    # What if not valid?

# Correct: Handle both cases
tasks:
  - id: check_data
    type: io.kestra.plugin.core.flow.If
    condition: "{{ outputs.validate.valid }}"
    then:
      - id: process
        type: ...
    else:
      - id: handle_invalid
        type: ...
```

### KE009: Input Validation Missing [MEDIUM]

```yaml
# Weak: No validation
inputs:
  - id: email
    type: STRING

# Better: With validation
inputs:
  - id: email
    type: STRING
    required: true
    defaults: null
    description: User email for notifications
    # Note: Kestra doesn't have regex validation built-in
    # Validate in first task if needed
```

### KE010: Subflow Misuse [MEDIUM]

#### Not using subflows for reusable logic
```yaml
# Copy-pasted across flows
tasks:
  - id: notify_slack
    type: io.kestra.plugin.notifications.slack.SlackIncomingWebhook
    url: "{{ secret('SLACK_WEBHOOK') }}"
    payload: |
      {"text": "..."}

# Better: Extract to subflow
# In shared/notifications.yml:
id: slack_notify
namespace: company.shared.notifications
inputs:
  - id: message
    type: STRING
tasks:
  - id: send
    type: io.kestra.plugin.notifications.slack.SlackIncomingWebhook
    url: "{{ secret('SLACK_WEBHOOK') }}"
    payload: |
      {"text": "{{ inputs.message }}"}

# In main flow:
tasks:
  - id: notify
    type: io.kestra.plugin.core.flow.Subflow
    namespace: company.shared.notifications
    flowId: slack_notify
    inputs:
      message: "Process complete"
```

---

## Kestra Hallucinations

### Hallucinated Task Types

| Hallucination | Reality |
|---------------|---------|
| `io.kestra.plugin.core.shell.Shell` | `io.kestra.plugin.scripts.shell.Commands` |
| `io.kestra.plugin.core.bash.Bash` | `io.kestra.plugin.scripts.shell.Commands` |
| `io.kestra.plugin.python.Execute` | `io.kestra.plugin.scripts.python.Script` |
| `io.kestra.plugin.core.sql.Query` | DB-specific: `io.kestra.plugin.jdbc.postgresql.Query` |
| `io.kestra.plugin.core.file.Copy` | `io.kestra.plugin.core.storage.Copy` |
| `io.kestra.plugin.http.Get` | `io.kestra.plugin.core.http.Request` |
| `io.kestra.plugin.core.sleep.Sleep` | `io.kestra.plugin.core.flow.Pause` |
| `io.kestra.plugin.core.condition.If` | It's a flow type: `io.kestra.plugin.core.flow.If` |

### Hallucinated Properties

| Hallucination | Reality |
|---------------|---------|
| `script.file` | Use `namespaceFiles` + `read()` |
| `http.method` | `method` (directly on Request) |
| `sql.connection` | `url`, `username`, `password` separately |
| `env` on tasks | `environmentVariables` |
| `workingDir` | `workingDirectory` |
| `output` | `outputs` (plural, automatic) |
| `depends_on` | Use `dependsOn` or task order |

### Hallucinated Pebble Filters

| Hallucination | Reality |
|---------------|---------|
| `{{ var \| json }}` | `{{ var \| json() }}` (function call) |
| `{{ var \| format_date }}` | `{{ var \| date("yyyy-MM-dd") }}` |
| `{{ list \| join(',') }}` | `{{ list \| join(', ') }}` |
| `{{ var \| env }}` | `{{ envs.VAR_NAME }}` |
| `{{ secret.NAME }}` | `{{ secret('NAME') }}` (function) |

### Confused with Airflow/Prefect

| Airflow/Prefect | Kestra |
|-----------------|--------|
| `@dag` / `@flow` | YAML `id:` at root |
| `@task` | `tasks:` list with `type:` |
| `PythonOperator` | `io.kestra.plugin.scripts.python.Script` |
| `BashOperator` | `io.kestra.plugin.scripts.shell.Commands` |
| `>>` dependencies | Task order or `dependsOn:` |
| `xcom_push/pull` | `outputs.taskId.property` |
| `Variable.get()` | `{{ vars.name }}` |
| `Connection` | `secret()` + plugin properties |
| `catchup=False` | `lateMaximumDelay` on schedule |

---

## Kestra Edge Cases

### YAML Gotchas

```yaml
# Bug: Unquoted special values
enabled: yes    # Parsed as boolean true!
enabled: "yes"  # String "yes"

count: 1.0      # Float
count: "1.0"    # String

time: 12:30:00  # Parsed as seconds!
time: "12:30:00"  # String

# Bug: Multiline strings
description: This is
  a description  # Only "This is" captured

description: |
  This is
  a description  # Both lines captured

# Bug: Colon in values
message: Error: something failed  # Parse error
message: "Error: something failed"  # Correct
```

### Output Reference Timing

```yaml
# Bug: Reference before task runs
tasks:
  - id: second
    type: io.kestra.plugin.core.log.Log
    message: "{{ outputs.first.value }}"  # first hasn't run!
  - id: first
    type: io.kestra.plugin.scripts.python.Script
    ...

# Correct: Order matters for sequential
tasks:
  - id: first
    type: io.kestra.plugin.scripts.python.Script
    ...
  - id: second
    type: io.kestra.plugin.core.log.Log
    message: "{{ outputs.first.value }}"
```

### Namespace File Resolution

```yaml
# Bug: Wrong path
script: "{{ read('process.py') }}"  # File not found

# Correct: Ensure namespaceFiles enabled
namespaceFiles:
  enabled: true
script: "{{ read('scripts/process.py') }}"

# Or with explicit namespace
script: "{{ read(namespace='company.data', path='scripts/process.py') }}"
```

### Internal Storage URIs

```yaml
# Bug: Treating URI as file path
- id: process
  type: io.kestra.plugin.scripts.python.Script
  script: |
    with open("{{ outputs.fetch.uri }}") as f:  # Won't work!
      data = f.read()

# Correct: Use inputFiles mapping
- id: process
  type: io.kestra.plugin.scripts.python.Script
  inputFiles:
    data.json: "{{ outputs.fetch.uri }}"
  script: |
    with open("data.json") as f:  # Kestra maps the file
      data = f.read()
```

---

## Kestra Validation Checklist

### Flow Structure
- [ ] `id` and `namespace` are present and meaningful
- [ ] `description` explains purpose
- [ ] Tasks have descriptive `id` values
- [ ] Namespace follows hierarchical convention

### Error Handling
- [ ] `timeout` on long-running tasks
- [ ] `retry` on external calls (HTTP, DB, API)
- [ ] `errors` section for flow-level failure handling
- [ ] `allowFailure` only where explicitly acceptable

### Security
- [ ] No hardcoded secrets (use `secret()`)
- [ ] Sensitive values not in `variables` block
- [ ] Namespace-appropriate secret scoping

### Task Configuration
- [ ] `fetch: true` or `store: true` when output needed
- [ ] `beforeCommands` for script dependencies
- [ ] `containerImage` for reproducibility
- [ ] `inputFiles`/`outputFiles` for file passing

### Triggers
- [ ] Schedule triggers have `timezone`
- [ ] Flow triggers have `conditions`
- [ ] Polling triggers have reasonable `interval`
- [ ] Realtime triggers for low-latency needs

### Templates
- [ ] Pebble expressions quoted in YAML
- [ ] Default values for optional references
- [ ] Proper filter syntax (function calls)

### Performance
- [ ] `Parallel` for independent tasks
- [ ] `EachParallel` for collection processing
- [ ] Subflows for reusable logic
- [ ] `concurrency` limits where needed

### Inputs/Outputs
- [ ] Inputs have `type` and `description`
- [ ] Required inputs marked
- [ ] Default values where sensible
- [ ] Outputs documented
