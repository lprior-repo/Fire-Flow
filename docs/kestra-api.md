# Kestra API Reference

> Progressive disclosure: Start simple, reveal complexity as needed

## Quick Start (30 seconds)

```bash
# Trigger a flow
curl -X POST -F "input1=value1" \
  -u "user:pass" \
  "http://localhost:4200/api/v1/executions/{namespace}/{flowId}"

# Get execution status
curl -u "user:pass" \
  "http://localhost:4200/api/v1/executions/{executionId}"
```

---

## Common Operations

<details>
<summary><strong>Flows</strong> - Deploy and manage workflow definitions</summary>

### List Flows
```http
GET /api/v1/flows/{namespace}
```

### Get Flow
```http
GET /api/v1/flows/{namespace}/{id}
```

### Create/Update Flow
```http
PUT /api/v1/flows/{namespace}/{id}
Content-Type: application/x-yaml

# Flow YAML content in body
```

### Delete Flow
```http
DELETE /api/v1/flows/{namespace}/{id}
```

</details>

<details>
<summary><strong>Executions</strong> - Trigger and monitor workflow runs</summary>

### Trigger Execution
```http
POST /api/v1/executions/{namespace}/{flowId}
Content-Type: multipart/form-data

# Inputs as form fields: -F "input1=value1" -F "input2=value2"
```

**Response:**
```json
{
  "id": "execution-id",
  "namespace": "bitter",
  "flowId": "contract-loop",
  "state": { "current": "CREATED" },
  "url": "/ui/main/executions/..."
}
```

### Get Execution Status
```http
GET /api/v1/executions/{executionId}
```

**Execution States:**
| State | Description |
|-------|-------------|
| CREATED | Just created |
| RUNNING | In progress |
| SUCCESS | Completed successfully |
| FAILED | Failed with error |
| KILLED | Manually stopped |
| WARNING | Completed with warnings |

### List Executions
```http
GET /api/v1/executions?namespace={ns}&flowId={id}&state={state}
```

### Cancel Execution
```http
DELETE /api/v1/executions/{executionId}/kill
```

</details>

<details>
<summary><strong>Logs</strong> - Retrieve execution logs</summary>

### Get Execution Logs
```http
GET /api/v1/logs/{executionId}
```

**Response:**
```json
[
  {
    "executionId": "abc123",
    "namespace": "bitter",
    "flowId": "contract-loop",
    "taskId": "generate",
    "message": "Starting generation",
    "level": "INFO",
    "timestamp": "2024-12-25T00:00:00Z"
  }
]
```

### Stream Logs (SSE)
```http
GET /api/v1/logs/{executionId}/follow
Accept: text/event-stream
```

</details>

<details>
<summary><strong>Webhooks</strong> - Trigger flows via HTTP</summary>

### Webhook URL Format
```
POST /api/v1/executions/webhook/{namespace}/{flowId}/{key}
```

The `key` is defined in your flow's webhook trigger configuration.

### Example Flow with Webhook
```yaml
triggers:
  - id: webhook
    type: io.kestra.plugin.core.trigger.Webhook
    key: my-secret-key
```

Then trigger with:
```bash
curl -X POST "http://localhost:4200/api/v1/executions/webhook/bitter/my-flow/my-secret-key"
```

</details>

---

## Authentication

<details>
<summary><strong>Basic Auth</strong> (OSS)</summary>

```bash
curl -u "username:password" http://localhost:4200/api/v1/...
```

Or with header:
```bash
curl -H "Authorization: Basic $(echo -n 'user:pass' | base64)" ...
```

</details>

<details>
<summary><strong>API Tokens</strong> (Enterprise)</summary>

```bash
curl -H "Authorization: Bearer YOUR_API_TOKEN" ...
```

Create tokens in: **Administration → API Tokens**

</details>

---

## Advanced Operations

<details>
<summary><strong>Namespace Files</strong></summary>

### Upload File
```http
POST /api/v1/namespaces/{namespace}/files?path=/path/to/file.txt
Content-Type: text/plain

# File content in body
```

### Download File
```http
GET /api/v1/namespaces/{namespace}/files?path=/path/to/file.txt
```

### List Files
```http
GET /api/v1/namespaces/{namespace}/files
```

</details>

<details>
<summary><strong>KV Store</strong></summary>

### Set Value
```http
PUT /api/v1/namespaces/{namespace}/kv/{key}
Content-Type: application/json

"your-value"
```

### Get Value
```http
GET /api/v1/namespaces/{namespace}/kv/{key}
```

### Delete Value
```http
DELETE /api/v1/namespaces/{namespace}/kv/{key}
```

</details>

<details>
<summary><strong>Task Run Operations</strong></summary>

### Get Task Run Outputs
```http
GET /api/v1/executions/{executionId}/taskruns/{taskRunId}/outputs
```

### Restart from Task
```http
POST /api/v1/executions/{executionId}/restart?taskRunId={taskRunId}
```

</details>

---

## Nushell Helper

For secure credential handling, use `tools/kestra.nu`:

```bash
# Get flow details
nu tools/kestra.nu flow bitter contract-loop

# Trigger execution
nu tools/kestra.nu run bitter contract-loop '{"contract":"/path/to/contract.yaml"}'

# Check status
nu tools/kestra.nu status {execution-id}
```

## Rust CLI

For AI-friendly log streaming:

```bash
# Poll execution with JSON output
kestra-ws poll --execution-id {id} --format json

# Watch namespace for new executions
kestra-ws watch --namespace bitter
```

---

## Error Codes

| Code | Meaning |
|------|---------|
| 401 | Unauthorized - check credentials |
| 404 | Not found - check namespace/flow/execution ID |
| 422 | Validation error - check request format |
| 500 | Server error - check Kestra logs |

## Rate Limits

OSS Kestra has no built-in rate limits. For production, consider:
- Reverse proxy rate limiting (nginx, Caddy)
- Custom middleware

---

## References

- [Kestra API Guide](https://kestra.io/docs/how-to-guides/api)
- [Webhook Triggers](https://kestra.io/docs/workflow-components/triggers/webhook-trigger)
- [Execution States](https://kestra.io/docs/workflow-components/states)
