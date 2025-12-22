# OpenCode Integration with Fire-Flow

This document explains how to integrate Fire-Flow with OpenCode agents for a complete TCR (Test-Driven Code Review) workflow.

## Overview

Fire-Flow provides a complete solution for Test && Commit || Revert workflows through:
1. A CLI tool (`fire-flow`) that enforces TDD principles
2. Kestra orchestration workflows that manage the full workflow
3. Integration points for OpenCode agents

## Setup Instructions

### 1. Install and Configure Fire-Flow

First, ensure Fire-Flow is properly initialized:

```bash
# Initialize the Fire-Flow system
fire-flow init

# Check current state
fire-flow status
```

### 2. Configure Kestra Integration

Fire-Flow comes with Kestra workflows that orchestrate the TCR process. The main workflow is defined in:

`kestra/flows/tcr-enforcement-workflow.yml`

This workflow:
- Listens for file change events or manual triggers
- Executes `fire-flow tdd-gate` to enforce TDD
- Runs tests if the TDD gate allows
- Commits or reverts based on test results

### 3. Configure OpenCode Agent

To integrate with OpenCode, you'll need to set up a webhook that calls the Kestra workflow when code changes occur.

#### Webhook Configuration

1. Create a Kestra API token in your Kestra instance
2. Configure your OpenCode agent to call the Kestra workflow via webhook:

```bash
# Example curl command to trigger the workflow
curl -X POST \
  http://localhost:8080/api/v1/flows/fire.flow/tcr-enforcement-workflow/executions \
  -H 'Authorization: Bearer YOUR_API_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "inputs": {
      "file_path": "pkg/auth/login.go"
    }
  }'
```

### 4. Integration with OpenCode Agent Prompt

When integrating with OpenCode, include this context in your agent prompt:

```markdown
You are working with Fire-Flow, a TCR (Test-Driven Code Review) enforcement system.

Key rules:
1. Always run `fire-flow tdd-gate --file <file_path>` before modifying any implementation file
2. If TDD gate blocks, create a test file first
3. After implementing code, run `fire-flow run-tests`
4. If tests pass, run `fire-flow commit`
5. If tests fail, run `fire-flow revert`

This ensures proper TDD workflow enforcement.
```

## Example Usage

### Typical Development Workflow

1. **Write a test file**:
   ```bash
   touch pkg/auth/login_test.go
   ```

2. **Run TDD gate (will pass for test files)**:
   ```bash
   fire-flow tdd-gate --file pkg/auth/login_test.go
   ```

3. **Implement the code**:
   ```bash
   touch pkg/auth/login.go
   ```

4. **Run TDD gate (will block for implementation files in GREEN state)**:
   ```bash
   fire-flow tdd-gate --file pkg/auth/login.go
   ```

5. **Run tests to see if we're in RED state**:
   ```bash
   fire-flow run-tests
   ```

6. **Commit changes if tests pass**:
   ```bash
   fire-flow commit --message "Implement login functionality"
   ```

## State Management

Fire-Flow maintains state in `.opencode/tcr/state.json` with:
- `RevertStreak`: Number of consecutive reverts
- `FailingTests`: List of currently failing tests
- `LastCommitTime`: Timestamp of last commit
- `Mode`: Current operational mode

## Result Output

Kestra workflows output structured results in JSON format:
```json
{
  "action": "BLOCKED|ALLOWED|COMMITTED|REVERTED",
  "reason": "...",
  "streak": 0,
  "output": "..."
}
```

This result can be parsed by OpenCode agents to adjust their behavior.
```