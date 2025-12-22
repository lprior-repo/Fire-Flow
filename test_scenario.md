# Fire-Flow TCR Enforcer Test Scenario

## Problem Statement
A developer wants to implement a simple calculator function but must follow TDD principles with Fire-Flow.

## Steps to Reproduce
1. Create a new implementation file `calculator.go`
2. Try to write implementation code
3. Fire-Flow should block the write since there are no tests yet
4. Create a test file `calculator_test.go`
5. Run tests to verify implementation
6. Commit the changes

## Expected Behavior
- Writing implementation before tests should be blocked by TDD gate
- Writing tests should be allowed
- After tests pass, implementation should be allowed
- Successful commit should update state

## Commands to Run
```bash
# Create implementation file
echo 'package main

func Add(a, b int) int {
    return a + b
}' > calculator.go

# Try to write implementation (should be blocked)
fire-flow tdd-gate --file calculator.go

# Create test file (should be allowed)
echo 'package main

import "testing"

func TestAdd(t *testing.T) {
    result := Add(2, 3)
    if result != 5 {
        t.Errorf("Add(2, 3) = %d; want 5", result)
    }
}' > calculator_test.go

# Run tests (should pass)
fire-flow run-tests --json

# Check status
fire-flow status

# Commit changes
fire-flow commit --message "Add calculator implementation"
```