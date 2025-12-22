# OpenCode Integration Setup

This document describes how to configure OpenCode to work with the Fire-Flow TCR enforcement system.

## Configuring opencode.json

To integrate with OpenCode, you'll need to configure your opencode.json file to call Kestra workflows when file changes occur.

### Example Configuration

```json
{
  "name": "fire-flow-integration",
  "version": "1.0.0",
  "integration": {
    "type": "webhook",
    "url": "http://localhost:8080/api/v1/flows/fire.flow/tcr-enforcement-workflow/executions",
    "headers": {
      "Authorization": "Bearer YOUR_API_TOKEN",
      "Content-Type": "application/json"
    },
    "payload": {
      "file_path": "{{ file.path }}"
    }
  }
}
```

## Passing Write Events to Kestra

When a file is changed, OpenCode should send a POST request to the Kestra webhook endpoint with:

1. The file path as input parameter
2. The appropriate authentication headers
3. A JSON payload containing the file path

## Parsing Results and Returning to Agent

The Kestra workflow returns a result.json that contains information about the action taken:

```json
{
  "action": "BLOCKED|ALLOWED|COMMITTED|REVERTED",
  "reason": "...",
  "streak": 0,
  "output": "..."
}
```

OpenCode should parse this result to determine:
- Whether the write was allowed or blocked
- The reason for the decision
- Any additional information needed for the agent to adjust behavior

## Agent Prompt Updates

Update your agent's prompt to include feedback from the TCR enforcement system:

```
When making code changes, please follow these rules:
1. If the TCR system blocks a write, you must first write a test for the functionality you're implementing
2. If the TCR system allows a write, proceed with implementing the feature
3. Pay attention to the feedback from the TCR system about the current state (GREEN/RED)
4. If changes are reverted, you must ensure that the new implementation passes all tests
```

## Testing the Integration

To test the integration:

1. Start Kestra and PostgreSQL services:
   ```bash
   docker-compose up -d
   ```

2. Ensure the Fire-Flow CLI is built and running:
   ```bash
   ./bin/fire-flow --help
   ```

3. Test the webhook manually:
   ```bash
   curl -X POST \
     http://localhost:8080/api/v1/flows/fire.flow/tcr-enforcement-workflow/executions \
     -H 'Authorization: Bearer YOUR_API_TOKEN' \
     -H 'Content-Type: application/json' \
     -d '{
       "inputs": {
         "file_path": "cmd/fire-flow/main.go"
       }
     }'
   ```