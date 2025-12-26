# Fire-Flow Project Instructions

## ═══════════════════════════════════════════════════════════════════════════════
## 🔥 KESTRA API - HOW TO CALL IT (OSS Edition)
## ═══════════════════════════════════════════════════════════════════════════════

**BASE URL**: `http://localhost:4200`
**TENANT**: `main` (OSS always uses `main` as tenant)
**AUTH**: Basic Auth via `~/.netrc` or `-u user:pass`

### 🎯 CORE ENDPOINTS

```bash
# List/Search Flows
GET  /api/v1/main/flows/search?namespace={namespace}
GET  /api/v1/main/flows/{namespace}/{id}

# Deploy Flow
PUT  /api/v1/main/flows/{namespace}/{id}
     Content-Type: application/x-yaml
     Body: <flow YAML>

# Trigger Execution
POST /api/v1/main/executions/{namespace}/{flowId}
     -F input1=value1 -F input2=value2

# Get Execution Status
GET  /api/v1/main/executions/{executionId}

# Get Execution Logs
GET  /api/v1/main/executions/{executionId}/logs
```

### 💡 EXAMPLES

```bash
# Setup auth (run once)
echo "machine localhost
  login $(pass kestra/username)
  password $(pass kestra/password)" > ~/.netrc
chmod 600 ~/.netrc

# Search flows in 'bitter' namespace
curl --netrc 'http://localhost:4200/api/v1/main/flows/search?namespace=bitter'

# Deploy a flow
curl -X PUT --netrc -H "Content-Type: application/x-yaml" \
  --data-binary '@flow.yml' \
  'http://localhost:4200/api/v1/main/flows/bitter/contract-loop-modular'

# Trigger execution
curl -X POST --netrc \
  -F contract="/path/to/contract.yaml" \
  -F task="Create echo tool" \
  -F input_json="{}" \
  'http://localhost:4200/api/v1/main/executions/bitter/contract-loop-modular'
```

### 📚 Reference
- [Kestra OSS API Docs](https://kestra.io/docs/api-reference/open-source)
- [API Guide](https://kestra.io/docs/how-to-guides/api)

## ═══════════════════════════════════════════════════════════════════════════════

## RULE 1: NEVER PLAINTEXT CREDENTIALS

**CRITICAL**: Never echo, print, or display credentials in plaintext. Always use secure methods:

### Credential Access Patterns

```bash
# Kestra credentials are in pass
# Username: pass kestra/username
# Password: pass kestra/password

# ALWAYS use netrc or credential helpers - NEVER inline creds in commands
```

### Secure Kestra API Access

Create `~/.netrc` with proper permissions for Kestra access:
```
machine localhost
  login <email>
  password <password>
```

Or use a nushell helper that reads from pass:

```nu
# In ~/.config/nushell/scripts/kestra.nu
def kestra-api [endpoint: string, --method: string = "GET", --data: string = ""] {
    let user = (pass kestra/username | str trim)
    let pass = (pass kestra/password | str trim)
    let auth = [$user, $pass] | str join ":"
    let base64_auth = ($auth | encode base64)

    if $data == "" {
        http get -H ["Authorization" $"Basic ($base64_auth)"] $"http://localhost:4200($endpoint)"
    } else {
        http post -H ["Authorization" $"Basic ($base64_auth)" "Content-Type" "application/json"] $"http://localhost:4200($endpoint)" $data
    }
}
```

## Kestra Configuration

- **URL**: http://localhost:4200
- **Namespace**: `bitter`
- **Main Flow**: `contract-loop-modular`
- **Credentials**: Stored in `pass` at:
  - `kestra/username` - email address
  - `kestra/password` - password

## bitter-truth System

This is a contract-driven AI code generation system with self-healing:

### The 4 Laws

1. **No-Human Zone**: AI writes all Nushell, humans write contracts
2. **Contract is Law**: Validation is draconian, self-heal on failure
3. **We Set the Standard**: Human defines target, AI hits it
4. **Orchestrator Runs Everything**: Kestra owns execution

### Flow Pattern

```
Generate -> Gate -> Pass or Self-Heal -> Escalate after N failures
```

### Key Components

- `bitter-truth/tools/generate.nu` - AI generates Nushell from contract
- `bitter-truth/tools/run-tool.nu` - Execute generated tools
- `bitter-truth/tools/validate.nu` - Contract validation via datacontract-cli
- `bitter-truth/tools/echo.nu` - Proof of concept echo tool
- `bitter-truth/contracts/` - DataContract definitions
- `bitter-truth/kestra/flows/` - Kestra orchestration flows

### Prerequisites

- `nu` (Nushell) - script execution
- `opencode` - AI code generation
- `datacontract` - contract validation
- Kestra (running on :4200) - orchestration

### Running the Flow

```bash
# Deploy flow
kestra-api "/api/v1/flows" --method PUT --data "$(cat bitter-truth/kestra/flows/contract-loop-modular.yml)"

# Trigger execution
kestra-api "/api/v1/executions/bitter/contract-loop-modular" --method POST --data '{
  "contract": "/path/to/contract.yaml",
  "task": "description of what to generate",
  "input_json": "{}",
  "max_attempts": 5,
  "tools_dir": "/path/to/bitter-truth/tools"
}'
```

## Monitoring

- Kestra UI: http://localhost:4200
- Execution logs visible in task outputs
- All tools log structured JSON to stderr
- Use `tools/kestra-ws` Rust CLI for AI-friendly log streaming

## Kestra API Reference

**OpenAPI Spec**: `docs/kestra-openapi.yaml` (161 endpoints)
**API Docs**: `docs/kestra-api.md` (progressive disclosure)

### Quick Reference

| Operation | Method | Endpoint |
|-----------|--------|----------|
| Trigger Flow | POST | `/api/v1/executions/{ns}/{flowId}` |
| Get Execution | GET | `/api/v1/executions/{execId}` |
| Get Logs | GET | `/api/v1/logs/{execId}` |
| Stream Logs (SSE) | GET | `/api/v1/logs/{execId}/follow` |
| Deploy Flow | PUT | `/api/v1/flows/{ns}/{id}` |
| Webhook Trigger | POST | `/api/v1/executions/webhook/{ns}/{flowId}/{key}` |

### Key Endpoints

- **Flows**: `/api/v1/{tenant}/flows` - CRUD, validate, graph, dependencies
- **Executions**: `/api/v1/{tenant}/executions` - trigger, pause, resume, kill, restart
- **Logs**: `/api/v1/{tenant}/logs` - search, download, follow (SSE)
- **Namespaces**: `/api/v1/{tenant}/namespaces` - files, KV store
- **Plugins**: `/api/v1/plugins` - schemas, icons, documentation

### Execution States

| State | Terminal | Description |
|-------|----------|-------------|
| CREATED | No | Just created |
| RUNNING | No | In progress |
| SUCCESS | Yes | Completed successfully |
| FAILED | Yes | One or more tasks failed |
| KILLED | Yes | Manually stopped |

## Development

- Edit flows in `bitter-truth/kestra/flows/`
- Redeploy with PUT to `/api/v1/flows/{namespace}/{id}`
- All shell tasks use `taskRunner.type: io.kestra.plugin.core.runner.Process` (no Docker)

## Tooling

### Nushell Helper (`tools/kestra.nu`)
```bash
nu tools/kestra.nu flow bitter contract-loop-modular      # Get flow
nu tools/kestra.nu run bitter contract-loop-modular '{}'  # Trigger
nu tools/kestra.nu status {exec-id}                       # Status
```

### Rust CLI (`tools/kestra-ws`)
```bash
kestra-ws poll --execution-id {id} --format json  # JSON output for AI
kestra-ws watch --namespace bitter                 # Watch executions
```

Build: `cargo build --release --manifest-path=tools/kestra-ws/Cargo.toml`
