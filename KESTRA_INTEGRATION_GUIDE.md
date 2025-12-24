# Kestra Integration Guide

## Overview

Fire-Flow integrates with **Kestra** for TCR (Test-Commit-Revert) workflow orchestration. Kestra automates the enforcement of TDD principles through scheduled or event-driven workflows.

**Status**: Kestra running on `http://localhost:4200`

---

## 🚀 Quick Start

### Step 1: Deploy Workflows to Kestra

Choose one method:

#### Option A: Browser UI (Recommended for first-time setup)
1. Open http://localhost:4200 in your browser
2. Click the **"+"** button or **"Create new flow"** button
3. For each workflow file below, copy the YAML content and paste into Kestra:
   - `kestra/flows/hello-flow.yml` - Simple test workflow
   - `kestra/flows/build-and-test.yml` - Build and test pipeline
   - `kestra/flows/tcr-enforcement-workflow.yml` - TCR enforcement (main workflow)
4. Click **Save** for each workflow
5. Verify in Settings that workflows appear in the `fire.flow` namespace

#### Option B: API Deployment (requires authentication)
```bash
# 1. Create API token in Kestra UI:
#    - Open http://localhost:4200/settings
#    - Go to API Tokens section
#    - Create a new token and copy it

# 2. Deploy workflows via API:
export KESTRA_TOKEN='your-token-here'
bash /tmp/kestra-deploy.sh
```

### Step 2: Verify Workflows Are Loaded

```bash
# Check workflows in Kestra namespace
curl -H "Authorization: Bearer $KESTRA_TOKEN" \
  http://localhost:4200/api/v1/flows?namespace=fire.flow

# Or open Kestra UI and check the fire.flow namespace
```

### Step 3: Test a Workflow

```bash
# Trigger the hello-flow test
curl -X POST \
  -H "Authorization: Bearer $KESTRA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}' \
  http://localhost:4200/api/v1/flows/fire.flow/fire-flow-hello/executions
```

---

## 📋 Workflow Definitions

### 1. **hello-flow.yml** (Basic Test)
- **Purpose**: Simple verification workflow
- **Input**: None required
- **Tasks**:
  - Log "Hello from Fire-Flow"
  - Execute `go version`
  - Verify workflow execution
- **Use**: Test that Kestra can execute shell commands

### 2. **build-and-test.yml** (Build Pipeline)
- **Purpose**: Build and test the Fire-Flow application
- **Input**: `environment` (development/production, default: development)
- **Tasks**:
  1. Download Go dependencies
  2. Build binary: `go build -o bin/fire-flow ./cmd/fire-flow`
  3. Run tests: `go test -v ./...`
  4. Execute the built binary
- **Use**: Complete build-test-run cycle

### 3. **tcr-enforcement-workflow.yml** (Main TCR Workflow)
- **Purpose**: Orchestrate TCR enforcement for file changes
- **Input**: `file_path` (STRING) - Path to the changed file
- **Execution Flow**:
  ```
  Check TDD Gate
      ↓
  If PASS → Run Tests
      ↓
      ├─ If PASS → Commit changes
      └─ If FAIL → Revert changes
      ↓
  Write Result JSON
  ```
- **Tasks**:
  1. `status` - Log current TCR state
  2. `tdd-gate` - Run: `./bin/fire-flow tdd-gate --file <file_path>`
  3. `run-tests` - Run: `./bin/fire-flow run-tests`
  4. `commit` - Auto-commit if tests pass
  5. `revert` - Auto-revert if tests fail
  6. `write-result` - Output structured JSON result
- **Output**: Result JSON with action (COMMITTED/REVERTED/BLOCKED)

---

## 🔌 API Integration

### Triggering Workflows

All workflows are triggered via HTTP POST to Kestra API:

```bash
curl -X POST \
  -H "Authorization: Bearer $KESTRA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"inputs": {"file_path": "cmd/fire-flow/main.go"}}' \
  http://localhost:4200/api/v1/flows/{namespace}/{flow-id}/executions
```

### Workflow Endpoints

| Workflow | Endpoint | Input | Purpose |
|----------|----------|-------|---------|
| `hello-flow` | `.../fire-flow-hello/executions` | None | Test Kestra |
| `build-and-test` | `.../fire-flow-build-and-test/executions` | `environment` | Build pipeline |
| `tcr-enforcement-workflow` | `.../tcr-enforcement-workflow/executions` | `file_path` | TCR enforcement |

### Example: Trigger TCR Enforcement

```bash
KESTRA_TOKEN="your-token-here"
FILE_PATH="cmd/fire-flow/main.go"

curl -X POST \
  -H "Authorization: Bearer $KESTRA_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"inputs\": {\"file_path\": \"$FILE_PATH\"}}" \
  http://localhost:4200/api/v1/flows/fire.flow/tcr-enforcement-workflow/executions
```

### Response

```json
{
  "id": "execution-id-123",
  "namespace": "fire.flow",
  "flowId": "tcr-enforcement-workflow",
  "state": {
    "current": "RUNNING"
  },
  "inputs": {
    "file_path": "cmd/fire-flow/main.go"
  }
}
```

---

## 🔐 Authentication

### Creating an API Token

1. Open http://localhost:4200
2. Click the **gear icon** (Settings) in top right
3. Navigate to **API Tokens** or **Developer Settings**
4. Click **Create New Token**
5. Set an expiration (or make it permanent)
6. Copy the token value

### Using the Token

```bash
# Set as environment variable
export KESTRA_TOKEN='your-token-here'

# Use in curl requests
curl -H "Authorization: Bearer $KESTRA_TOKEN" http://localhost:4200/api/v1/flows

# Or add to ~/.bashrc or ~/.profile for persistent access
echo 'export KESTRA_TOKEN="your-token-here"' >> ~/.bashrc
source ~/.bashrc
```

---

## 📊 Monitoring Executions

### View Execution Status

```bash
# Get specific execution status
curl -H "Authorization: Bearer $KESTRA_TOKEN" \
  http://localhost:4200/api/v1/flows/fire.flow/tcr-enforcement-workflow/executions/{execution-id}

# List all executions
curl -H "Authorization: Bearer $KESTRA_TOKEN" \
  http://localhost:4200/api/v1/executions?namespace=fire.flow
```

### Kestra UI

1. Open http://localhost:4200
2. Click on a workflow in the `fire.flow` namespace
3. View **Executions** tab to see:
   - Execution status (RUNNING, SUCCESS, FAILED)
   - Task logs and outputs
   - Execution duration
   - Error messages

---

## 🛠️ Troubleshooting

### Workflows Not Showing Up

**Problem**: Workflows don't appear in Kestra UI after deployment

**Solutions**:
1. Refresh the browser (Ctrl+F5 or Cmd+Shift+R)
2. Check that workflows were saved in `fire.flow` namespace
3. Verify YAML syntax is valid (check for indentation errors)
4. Look for deployment errors in browser console or Kestra logs

### API Token Issues

**Problem**: `401 Unauthorized` error

**Solutions**:
```bash
# Verify token is set
echo $KESTRA_TOKEN

# Re-create token in Kestra UI:
# Settings → API Tokens → Create New

# Ensure token is in Authorization header
curl -H "Authorization: Bearer $KESTRA_TOKEN" \
  http://localhost:4200/api/v1/flows
```

### Workflow Execution Fails

**Problem**: Workflow runs but tasks fail

**Solutions**:
1. Check task logs in Kestra UI (click execution → view logs)
2. Verify Fire-Flow binary exists: `ls -la /home/lewis/src/Fire-Flow/bin/fire-flow`
3. Test command manually:
   ```bash
   cd /home/lewis/src/Fire-Flow
   ./bin/fire-flow tdd-gate --file test.go
   ```
4. Check file paths in workflow YAML match your system

### Fire-Flow Binary Not Found

**Problem**: Workflow logs show "fire-flow: command not found"

**Solution**: Rebuild the binary
```bash
cd /home/lewis/src/Fire-Flow
make build
# Or: go build -o bin/fire-flow ./cmd/fire-flow
```

---

## 📚 Files Reference

| File | Purpose |
|------|---------|
| `kestra/flows/hello-flow.yml` | Simple test workflow |
| `kestra/flows/build-and-test.yml` | Build and test pipeline |
| `kestra/flows/tcr-enforcement-workflow.yml` | Main TCR enforcement workflow |
| `/tmp/kestra-deploy.sh` | API deployment script |
| This file | Integration guide |

---

## ✅ Verification Checklist

- [ ] Kestra running at http://localhost:4200
- [ ] Can access Kestra UI in browser
- [ ] API token created and stored in `KESTRA_TOKEN` env var
- [ ] All 3 workflows deployed to `fire.flow` namespace
- [ ] Test execution of `hello-flow` succeeds
- [ ] Build-and-test workflow completes
- [ ] TCR enforcement workflow responds to file_path input

---

## 🔗 Related Documentation

- Kestra Official: https://kestra.io
- Kestra API Docs: http://localhost:4200/docs
- Fire-Flow Commands: See `cmd/fire-flow/main.go`
- TCR Workflow Logic: See `kestra/flows/tcr-enforcement-workflow.yml`

---

## Next Steps

1. **Deploy workflows** using Method A (UI) or Method B (API)
2. **Test with hello-flow** - Simplest verification
3. **Monitor executions** in Kestra UI
4. **Integrate with OpenCode** - Use TCR workflow for automated code changes
5. **Set up webhooks** for event-driven workflow triggers (optional)

---

Generated: 2025-12-24
