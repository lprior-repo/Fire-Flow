# Fire-Flow TCR Enforcement Workflow

This Kestra workflow orchestrates the TCR (Test-Driven Code Review) enforcement process for Fire-Flow. It integrates with the TCR enforcer CLI to enforce TDD principles.

## Workflow Details

### Inputs
- `file_path` (STRING): Path to the file being changed

### Tasks

1. **status** (Log): 
   - Logs the start of TCR state checking for the given file path

2. **tdd-gate** (Shell Commands):
   - Runs the TDD gate check
   - Command: `cd /home/lewis/src/Fire-Flow && ./bin/fire-flow tdd-gate --file {{ inputs.file_path }}`

3. **run-tests** (Shell Commands):
   - Runs tests if TDD gate allows
   - Command: `cd /home/lewis/src/Fire-Flow && ./bin/fire-flow run-tests`
   - Condition: `{{ outputs.tdd-gate.exitCode == 0 }}`

4. **commit** (Shell Commands):
   - Commits changes if tests pass
   - Command: `cd /home/lewis/src/Fire-Flow && ./bin/fire-flow commit --message "TCR: Auto-commit from workflow"`
   - Condition: `{{ outputs.run-tests.exitCode == 0 }}`

5. **revert** (Shell Commands):
   - Reverts changes if tests fail
   - Command: `cd /home/lewis/src/Fire-Flow && ./bin/fire-flow revert`
   - Condition: `{{ outputs.run-tests.exitCode != 0 }}`

6. **write-result** (WriteFile):
   - Writes structured result for OpenCode integration
   - Contains detailed action information, file path, timestamps, and success status

## Result Format

The workflow produces a detailed JSON result in `{{ workingDir }}/result.json` with the following fields:
- `action`: "COMMITTED", "REVERTED", or "BLOCKED"
- `reason`: Description of workflow completion
- `streak`: Test streak count (1 for commit, 0 for revert/block)
- `output`: Detailed execution information
- `file_path`: Path to the file being processed
- `timestamp`: Workflow execution timestamp
- `success`: Boolean indicating overall workflow success

## Decision Branching Logic

The workflow implements robust decision branching:
1. If TDD gate blocks (exit code != 0): Block the workflow and don't run tests
2. If TDD gate allows (exit code == 0) and tests pass (exit code == 0): Commit changes
3. If TDD gate allows (exit code == 0) and tests fail (exit code != 0): Revert changes

This ensures that only properly tested code gets committed, with the workflow providing clear feedback on the outcome.