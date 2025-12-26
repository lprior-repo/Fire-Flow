#!/usr/bin/env python3
"""Fire-Flow Hatchet Worker

Start the worker to process contract-loop workflows.

Usage:
    python worker.py

Or with poetry/uv:
    uv run python worker.py

Requires HATCHET_CLIENT_TOKEN environment variable.
"""

import os
import sys

# Add parent directory for imports
sys.path.insert(0, str(__file__).rsplit("/", 1)[0])

from hatchet_sdk import Hatchet

from workflows.contract_loop import ContractLoopWorkflow


def main():
    """Start the Hatchet worker."""
    # Verify token is set
    if not os.environ.get("HATCHET_CLIENT_TOKEN"):
        print("ERROR: HATCHET_CLIENT_TOKEN environment variable not set")
        print("Get your token from https://cloud.hatchet.run")
        sys.exit(1)

    print("Starting Fire-Flow worker...")
    print(f"Tools directory: {ContractLoopWorkflow}")

    hatchet = Hatchet()
    worker = hatchet.worker("fire-flow-worker")
    worker.register_workflow(ContractLoopWorkflow())

    print("Worker registered, starting...")
    worker.start()


if __name__ == "__main__":
    main()
