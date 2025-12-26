# Fire-Flow: Hatchet Orchestration

Contract-driven AI code generation with self-healing loops.

## Quick Start

### 1. Install Dependencies

```bash
cd fire-flow
pip install -e .
# or with uv:
uv pip install -e .
```

### 2. Get Hatchet Cloud Token

1. Sign up at [hatchet.run](https://cloud.hatchet.run)
2. Create a tenant
3. Go to Settings → API Keys → Create API Key
4. Copy the token

### 3. Set Environment Variable

```bash
export HATCHET_CLIENT_TOKEN="your-token-here"
# or create .env file:
echo "HATCHET_CLIENT_TOKEN=your-token-here" > .env
```

### 4. Start the Worker

```bash
python worker.py
```

### 5. Trigger a Workflow

```python
from workflows.client import run_contract_loop

result = run_contract_loop(
    contract="../bitter-truth/contracts/tools/echo.yaml",
    task="Generate an echo tool that returns the input",
)
print(result)
```

Or from CLI:

```bash
python -m workflows.client ../bitter-truth/contracts/tools/echo.yaml "Generate echo tool"
```

## Architecture

```
fire-flow/
├── workflows/
│   ├── __init__.py
│   ├── contract_loop.py  # Main workflow (ported from Kestra)
│   └── client.py         # Client for triggering workflows
├── worker.py             # Worker entrypoint
├── pyproject.toml        # Python package config
└── .env.example          # Environment template
```

## Workflow Steps

1. **init** - Create workspace, set trace ID
2. **generate** - Call `generate.nu` to create Nushell tool
3. **execute** - Call `run-tool.nu` to run the tool
4. **validate** - Call `validate.nu` to check contract
5. **decide** - Success, retry, or escalate
6. **collect_feedback** - Build feedback for AI retry
7. **retry_or_complete** - Spawn retry or return result

## Migration from Kestra

| Kestra | Hatchet |
|--------|---------|
| `contract-loop.yml` | `contract_loop.py` |
| ForEach loop | `spawn_workflow()` recursive |
| YAML tasks | `@hatchet.step()` decorators |
| Kestra UI (port 4201) | Hatchet Cloud dashboard |
