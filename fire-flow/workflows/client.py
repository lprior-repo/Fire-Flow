"""Fire-Flow Client - Trigger Hatchet workflows.

Usage:
    from fire_flow.workflows.client import run_contract_loop

    result = run_contract_loop(
        contract="contracts/echo.yaml",
        task="Generate an echo tool",
        input_json='{}'
    )
"""

import asyncio
from typing import Any

from hatchet_sdk import Hatchet

hatchet = Hatchet()


async def run_contract_loop_async(
    contract: str,
    task: str,
    input_json: str = "{}",
    max_attempts: int = 5,
) -> dict[str, Any]:
    """Run contract loop workflow asynchronously.

    Args:
        contract: Path to DataContract YAML file
        task: Natural language description of what to generate
        input_json: JSON input for the generated tool
        max_attempts: Maximum retry attempts before escalation

    Returns:
        Workflow result with status, output_path, attempts, etc.
    """
    workflow_run = await hatchet.admin.aio.run_workflow(
        "ContractLoopWorkflow",
        {
            "contract": contract,
            "task": task,
            "input_json": input_json,
            "max_attempts": max_attempts,
        },
    )

    # Wait for completion
    result = await workflow_run.result()
    return result


def run_contract_loop(
    contract: str,
    task: str,
    input_json: str = "{}",
    max_attempts: int = 5,
) -> dict[str, Any]:
    """Run contract loop workflow synchronously.

    Args:
        contract: Path to DataContract YAML file
        task: Natural language description of what to generate
        input_json: JSON input for the generated tool
        max_attempts: Maximum retry attempts before escalation

    Returns:
        Workflow result with status, output_path, attempts, etc.
    """
    return asyncio.run(
        run_contract_loop_async(contract, task, input_json, max_attempts)
    )


def trigger_contract_loop(
    contract: str,
    task: str,
    input_json: str = "{}",
    max_attempts: int = 5,
) -> str:
    """Trigger contract loop workflow (fire-and-forget).

    Returns the workflow run ID for later status checking.
    """
    workflow_run = hatchet.admin.run_workflow(
        "ContractLoopWorkflow",
        {
            "contract": contract,
            "task": task,
            "input_json": input_json,
            "max_attempts": max_attempts,
        },
    )
    return workflow_run.workflow_run_id


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 3:
        print("Usage: python -m workflows.client <contract_path> <task>")
        sys.exit(1)

    contract = sys.argv[1]
    task = sys.argv[2]
    input_json = sys.argv[3] if len(sys.argv) > 3 else "{}"

    print(f"Running contract loop for: {contract}")
    print(f"Task: {task}")

    result = run_contract_loop(contract, task, input_json)
    print(f"Result: {result}")
