"""Contract Loop Workflow - Hatchet Port of bitter-truth/kestra/flows/contract-loop.yml

THE 4 LAWS:
1. No-Human Zone: AI writes all Nushell, humans write contracts
2. Contract is Law: Validation is draconian, self-heal on failure
3. We Set the Standard: Human defines target, AI hits it
4. Orchestrator Runs Everything: Hatchet owns execution

PATTERN: Generate -> Execute -> Validate -> (Pass=Exit | Fail=Feedback->Retry)
"""

import json
import subprocess
import tempfile
import uuid
from pathlib import Path
from typing import Any

from hatchet_sdk import Context, Hatchet

hatchet = Hatchet()

# Path to bitter-truth tools (relative to repo root)
TOOLS_DIR = Path(__file__).parent.parent.parent / "bitter-truth" / "tools"


def run_nu_script(script_path: Path, input_data: dict) -> dict:
    """Run a Nushell script with JSON input, return parsed output."""
    result = subprocess.run(
        ["nu", str(script_path)],
        input=json.dumps(input_data),
        capture_output=True,
        text=True,
        timeout=300,  # 5 min timeout
    )

    if result.returncode != 0:
        return {
            "success": False,
            "error": result.stderr or f"Exit code: {result.returncode}",
            "stdout": result.stdout,
        }

    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return {
            "success": True,
            "raw_output": result.stdout,
        }


@hatchet.workflow(on_events=["contract:run"])
class ContractLoopWorkflow:
    """Self-healing contract-driven code generation loop.

    Inputs:
        contract: Path to DataContract YAML file
        task: Natural language description of what to generate
        input_json: JSON input for the generated tool (optional)
        max_attempts: Maximum retry attempts before escalation (default: 5)
    """

    @hatchet.step()
    def init(self, ctx: Context) -> dict:
        """Initialize workflow with trace ID and workspace."""
        trace_id = ctx.workflow_run_id()
        work_dir = Path(tempfile.mkdtemp(prefix=f"fire-flow-{trace_id[:8]}-"))

        ctx.log(f"Starting contract-loop (trace: {trace_id})")
        ctx.log(f"Contract: {ctx.workflow_input().get('contract')}")
        ctx.log(f"Task: {ctx.workflow_input().get('task')}")

        return {
            "trace_id": trace_id,
            "work_dir": str(work_dir),
            "attempt": 0,
            "max_attempts": ctx.workflow_input().get("max_attempts", 5),
            "feedback": "Initial generation",
        }

    @hatchet.step(parents=["init"])
    def generate(self, ctx: Context) -> dict:
        """Generate Nushell tool from contract + task + feedback."""
        init_data = ctx.step_output("init")
        workflow_input = ctx.workflow_input()

        attempt = init_data["attempt"] + 1
        ctx.log(f"Generate attempt {attempt}/{init_data['max_attempts']}")

        tool_path = Path(init_data["work_dir"]) / "tool.nu"

        generate_input = {
            "contract_path": workflow_input["contract"],
            "task": workflow_input["task"],
            "feedback": init_data["feedback"],
            "attempt": f"{attempt}/{init_data['max_attempts']}",
            "output_path": str(tool_path),
            "context": {"trace_id": init_data["trace_id"]},
        }

        result = run_nu_script(TOOLS_DIR / "generate.nu", generate_input)

        if not result.get("success", False):
            raise Exception(f"Generation failed: {result.get('error', 'Unknown error')}")

        return {
            "tool_path": str(tool_path),
            "attempt": attempt,
            **result,
        }

    @hatchet.step(parents=["generate"])
    def execute(self, ctx: Context) -> dict:
        """Execute the generated tool with input."""
        init_data = ctx.step_output("init")
        gen_data = ctx.step_output("generate")
        workflow_input = ctx.workflow_input()

        output_path = Path(init_data["work_dir"]) / "output.json"
        logs_path = Path(init_data["work_dir"]) / "logs.json"

        execute_input = {
            "tool_path": gen_data["tool_path"],
            "tool_input": json.loads(workflow_input.get("input_json", "{}")),
            "output_path": str(output_path),
            "logs_path": str(logs_path),
            "context": {"trace_id": init_data["trace_id"]},
        }

        result = run_nu_script(TOOLS_DIR / "run-tool.nu", execute_input)

        return {
            "output_path": str(output_path),
            "logs_path": str(logs_path),
            "execution_result": result,
        }

    @hatchet.step(parents=["execute"])
    def validate(self, ctx: Context) -> dict:
        """Validate tool output against DataContract."""
        init_data = ctx.step_output("init")
        exec_data = ctx.step_output("execute")
        workflow_input = ctx.workflow_input()

        validate_input = {
            "contract_path": workflow_input["contract"],
            "output_path": exec_data["output_path"],
            "server": "local",
            "context": {"trace_id": init_data["trace_id"]},
        }

        result = run_nu_script(TOOLS_DIR / "validate.nu", validate_input)

        is_valid = result.get("data", {}).get("valid", False)

        return {
            "valid": is_valid,
            "validation_result": result,
        }

    @hatchet.step(parents=["validate"])
    def decide(self, ctx: Context) -> dict:
        """Decide: success, retry, or escalate."""
        init_data = ctx.step_output("init")
        gen_data = ctx.step_output("generate")
        val_data = ctx.step_output("validate")

        if val_data["valid"]:
            ctx.log("Contract satisfied!")
            return {
                "decision": "success",
                "attempts_made": gen_data["attempt"],
            }

        if gen_data["attempt"] >= init_data["max_attempts"]:
            ctx.log(f"Max attempts ({init_data['max_attempts']}) reached - escalating")
            return {
                "decision": "escalate",
                "attempts_made": gen_data["attempt"],
                "last_error": val_data["validation_result"],
            }

        ctx.log(f"Validation failed, will retry (attempt {gen_data['attempt']})")
        return {
            "decision": "retry",
            "attempt": gen_data["attempt"],
        }

    @hatchet.step(parents=["decide"])
    def collect_feedback(self, ctx: Context) -> dict:
        """Collect feedback for self-healing retry."""
        decide_data = ctx.step_output("decide")

        if decide_data["decision"] != "retry":
            return {"feedback": None}

        init_data = ctx.step_output("init")
        exec_data = ctx.step_output("execute")
        val_data = ctx.step_output("validate")
        gen_data = ctx.step_output("generate")

        # Build feedback message for AI
        feedback_parts = [
            f"ATTEMPT {gen_data['attempt']}/{init_data['max_attempts']} FAILED.",
            "",
            "CONTRACT ERRORS:",
            json.dumps(val_data["validation_result"], indent=2),
            "",
            "FIX THE NUSHELL SCRIPT TO SATISFY THE CONTRACT.",
        ]

        # Try to include output if available
        try:
            with open(exec_data["output_path"]) as f:
                output_content = f.read()
            feedback_parts.insert(4, f"OUTPUT PRODUCED:\n{output_content}")
        except Exception:
            pass

        return {
            "feedback": "\n".join(feedback_parts),
        }

    @hatchet.step(parents=["collect_feedback"])
    def retry_or_complete(self, ctx: Context) -> dict:
        """Spawn retry workflow or complete."""
        decide_data = ctx.step_output("decide")

        if decide_data["decision"] == "success":
            exec_data = ctx.step_output("execute")
            gen_data = ctx.step_output("generate")
            return {
                "status": "success",
                "output_path": exec_data["output_path"],
                "tool_path": gen_data["tool_path"],
                "attempts": decide_data["attempts_made"],
            }

        if decide_data["decision"] == "escalate":
            return {
                "status": "escalated",
                "message": "AI failed to satisfy contract after max attempts. FIX THE PROMPT OR CONTRACT, NOT THE NUSHELL.",
                "attempts": decide_data["attempts_made"],
                "last_error": decide_data.get("last_error"),
            }

        # Retry: spawn new workflow run with updated feedback
        feedback_data = ctx.step_output("collect_feedback")
        init_data = ctx.step_output("init")
        gen_data = ctx.step_output("generate")
        workflow_input = ctx.workflow_input()

        # Spawn child workflow for retry
        ctx.spawn_workflow(
            "ContractLoopWorkflow",
            {
                **workflow_input,
                "_retry_state": {
                    "attempt": gen_data["attempt"],
                    "feedback": feedback_data["feedback"],
                    "trace_id": init_data["trace_id"],
                    "work_dir": init_data["work_dir"],
                },
            },
        )

        return {
            "status": "retrying",
            "attempt": gen_data["attempt"],
        }


# Worker entrypoint
def main():
    """Start the Hatchet worker."""
    worker = hatchet.worker("fire-flow-worker")
    worker.register_workflow(ContractLoopWorkflow())
    worker.start()


if __name__ == "__main__":
    main()
