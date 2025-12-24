# Kestra Quick Reference Card

## 🚀 Get Started in 5 Minutes

### 1. Deploy Workflows (Choose One Method)

**Easy Method (UI):**
```
1. Open http://localhost:4200
2. Click "+" or "Create new flow"
3. Copy-paste one of these files:
   - kestra/flows/hello-flow.yml
   - kestra/flows/build-and-test.yml
   - kestra/flows/tcr-enforcement-workflow.yml
4. Click Save
```

**Advanced Method (API):**
```bash
# 1. Create API token: Settings → API Tokens → New Token
# 2. Deploy all workflows:
export KESTRA_TOKEN='your-token-here'
bash /tmp/kestra-deploy.sh
```

### 2. Test It Works

```bash
# Create API token in Kestra UI first, then:
export KESTRA_TOKEN='your-token-here'
bash scripts/kestra-test.sh
```

### 3. Trigger a Workflow

```bash
# Test workflow (simple)
curl -X POST \
  -H "Authorization: Bearer $KESTRA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}' \
  http://localhost:4200/api/v1/flows/fire.flow/fire-flow-hello/executions

# TCR enforcement (with file path)
curl -X POST \
  -H "Authorization: Bearer $KESTRA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"inputs": {"file_path": "cmd/fire-flow/main.go"}}' \
  http://localhost:4200/api/v1/flows/fire.flow/tcr-enforcement-workflow/executions
```

---

## 📋 Workflows Summary

| Workflow | ID | Purpose | Input |
|----------|----|---------| ------|
| Hello Flow | `fire-flow-hello` | Test Kestra | None |
| Build & Test | `fire-flow-build-and-test` | Build pipeline | `environment` |
| TCR Enforcement | `tcr-enforcement-workflow` | TCR rules | `file_path` |

---

## 🔑 API Token Setup

### Create Token
1. Open http://localhost:4200
2. Click gear icon → Settings
3. Find "API Tokens" section
4. Click "Create New Token"
5. Copy the token value

### Use Token
```bash
# Method 1: Environment variable
export KESTRA_TOKEN='your-token-here'

# Method 2: Direct in curl
curl -H "Authorization: Bearer your-token-here" ...

# Method 3: Save to file
echo 'export KESTRA_TOKEN="your-token-here"' >> ~/.bashrc
source ~/.bashrc
```

---

## 🔗 Useful Links

- **Kestra UI**: http://localhost:4200
- **API Docs**: http://localhost:4200/docs
- **Full Guide**: See `KESTRA_INTEGRATION_GUIDE.md`
- **Test Script**: `bash scripts/kestra-test.sh`

---

## ⚡ Common Commands

```bash
# List all workflows
curl -H "Authorization: Bearer $KESTRA_TOKEN" \
  http://localhost:4200/api/v1/flows?namespace=fire.flow

# Get workflow details
curl -H "Authorization: Bearer $KESTRA_TOKEN" \
  http://localhost:4200/api/v1/flows/fire.flow/{workflow-id}

# List executions
curl -H "Authorization: Bearer $KESTRA_TOKEN" \
  http://localhost:4200/api/v1/executions?namespace=fire.flow

# Get execution status
curl -H "Authorization: Bearer $KESTRA_TOKEN" \
  http://localhost:4200/api/v1/executions/{execution-id}
```

---

## 🆘 Troubleshooting

| Problem | Solution |
|---------|----------|
| Can't access Kestra | Check http://localhost:4200 is running |
| Workflows don't show | Refresh browser, check namespace is `fire.flow` |
| API returns 401 | Create API token and set `KESTRA_TOKEN` env var |
| Workflow fails | Check logs in Kestra UI, verify Fire-Flow binary exists |
| "command not found" | Rebuild: `go build -o bin/fire-flow ./cmd/fire-flow` |

---

## 📊 Monitor Execution

**In Kestra UI:**
1. Click workflow name
2. Click "Executions" tab
3. Click execution ID to see:
   - Task logs
   - Output
   - Duration
   - Errors

**Via API:**
```bash
curl -H "Authorization: Bearer $KESTRA_TOKEN" \
  http://localhost:4200/api/v1/executions/{execution-id}
```

---

**Last Updated**: 2025-12-24
