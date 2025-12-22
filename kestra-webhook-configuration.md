# Kestra Webhook Configuration for OpenCode Integration

This document describes how to configure and use Kestra webhooks to integrate with OpenCode.

## Getting Kestra API Endpoint

Kestra provides an API endpoint for executing workflows via webhooks. The endpoint typically follows this pattern:

```
POST /api/v1/flows/{namespace}/{id}/executions
```

Where:
- `{namespace}` is the namespace of your workflow (e.g., `fire.flow`)
- `{id}` is the workflow ID (e.g., `tcr-enforcement-workflow`)

## Creating an API Token

1. Log into your Kestra UI
2. Navigate to Settings > API Tokens
3. Create a new API token with appropriate permissions
4. Copy the token for use in your OpenCode configuration

## Calling the Flow via Webhook

Once you have your API token, you can call the workflow using curl or any HTTP client:

```bash
curl -X POST \
  http://localhost:8080/api/v1/flows/fire.flow/tcr-enforcement-workflow/executions \
  -H 'Authorization: Bearer YOUR_API_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "inputs": {
      "file_path": "pkg/auth/login.go"
    }
  }'
```

## Input Parameters

The workflow accepts the following input parameters:

- `file_path` (STRING): Path to the file being changed

## Response Format

The webhook returns a JSON response with execution details:

```json
{
  "id": "execution-id",
  "namespace": "fire.flow",
  "flowId": "tcr-enforcement-workflow",
  "state": {
    "current": "SUCCESS"
  },
  "inputs": {
    "file_path": "pkg/auth/login.go"
  }
}
```

## Integration with OpenCode

To integrate with OpenCode, configure your opencode.json file to send file change events to this webhook endpoint with the appropriate file path as input.