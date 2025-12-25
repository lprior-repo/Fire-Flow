# Kestra Quick Reference Card

## bitter-truth Architecture

Kestra is the orchestrator (Law 4) that runs all bitter-truth workflows.

```
Human Intent → Contract → Kestra → AI → Nushell → Validation → Done
                           ↑
                     Everything flows through here
```

## 🚀 Quick Start

### Kestra Location
- **URL**: http://localhost:4200
- **Config**: `/home/lewis/kestra/config.yaml`
- **Credentials**: From environment (systemd service)

### Access API (Basic Auth)
```bash
# Get credentials from running process
KESTRA_USER=$(cat /proc/$(pgrep -f kestra.jar)/environ | tr '\0' '\n' | grep "^KESTRA_USERNAME=" | cut -d= -f2)
KESTRA_PASS=$(cat /proc/$(pgrep -f kestra.jar)/environ | tr '\0' '\n' | grep "^KESTRA_PASSWORD=" | cut -d= -f2)

# Use with curl
curl -u "$KESTRA_USER:$KESTRA_PASS" http://localhost:4200/api/v1/flows
```

---

## 📋 Deployed Workflows

| Workflow | Namespace | Purpose |
|----------|-----------|---------|
| `contract-loop` | `bitter` | Contract-driven AI generation with self-healing |

---

## 🔄 contract-loop Workflow

The core bitter-truth pattern:

```
Generate (AI) → Execute → Validate → Pass or Self-Heal → Escalate
```

### Trigger Execution

```bash
# Example: Generate an echo tool
curl -u "$KESTRA_USER:$KESTRA_PASS" \
  -X POST "http://localhost:4200/api/v1/executions/bitter/contract-loop" \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": {
      "contract": "/home/lewis/src/Fire-Flow/bitter-truth/contracts/tools/echo.yaml",
      "task": "Echo the input message back with its length",
      "input_json": "{\"message\": \"hello world\"}",
      "tools_dir": "/home/lewis/src/Fire-Flow/bitter-truth/tools"
    }
  }'
```

### Inputs

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `contract` | STRING | required | Path to DataContract YAML |
| `task` | STRING | required | Natural language intent |
| `input_json` | STRING | `{}` | JSON input for the tool |
| `max_attempts` | INT | `5` | Self-heal attempts before escalate |
| `tools_dir` | STRING | `./bitter-truth/tools` | Path to nushell tools |

---

## 🛠️ Deploy/Update Flows

```bash
# Deploy a flow
curl -u "$KESTRA_USER:$KESTRA_PASS" \
  -X POST "http://localhost:4200/api/v1/flows" \
  -H "Content-Type: application/x-yaml" \
  --data-binary @bitter-truth/kestra/flows/contract-loop.yml

# Update existing flow (same command, uses revision)
curl -u "$KESTRA_USER:$KESTRA_PASS" \
  -X POST "http://localhost:4200/api/v1/flows" \
  -H "Content-Type: application/x-yaml" \
  --data-binary @bitter-truth/kestra/flows/contract-loop.yml
```

---

## ⚡ Common API Commands

```bash
# List all flows
curl -u "$KESTRA_USER:$KESTRA_PASS" \
  "http://localhost:4200/api/v1/flows?namespace=bitter"

# Get flow details
curl -u "$KESTRA_USER:$KESTRA_PASS" \
  "http://localhost:4200/api/v1/flows/bitter/contract-loop"

# List executions
curl -u "$KESTRA_USER:$KESTRA_PASS" \
  "http://localhost:4200/api/v1/executions?namespace=bitter"

# Get execution status
curl -u "$KESTRA_USER:$KESTRA_PASS" \
  "http://localhost:4200/api/v1/executions/{execution-id}"

# Kill execution
curl -u "$KESTRA_USER:$KESTRA_PASS" \
  -X POST "http://localhost:4200/api/v1/executions/{execution-id}/kill"
```

---

## 📊 Monitor in UI

1. Open http://localhost:4200
2. Navigate to Flows → bitter namespace
3. Click on `contract-loop`
4. View Executions tab for history
5. Click execution to see:
   - Task logs (including AI generation)
   - Contract validation results
   - Self-heal feedback

---

## 🔧 Requirements

The Kestra host needs:
- `nu` (nushell) in PATH
- `datacontract` CLI installed
- `opencode` CLI for AI generation
- Access to bitter-truth tools directory

---

## 🆘 Troubleshooting

| Problem | Solution |
|---------|----------|
| Flow fails with "nu not found" | Ensure nushell is in PATH for Kestra process |
| Contract validation fails | Check contract has `servers.local` section |
| Can't access API | Check Kestra is running on 4200 |
| "PROCESS runner" issues | Ensure local files are accessible |

---

**Last Updated**: 2024-12-25
