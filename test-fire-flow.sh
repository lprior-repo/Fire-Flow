#!/bin/bash

# Test script for Fire-Flow implementation

echo "=== Testing Fire-Flow Implementation ==="

# Change to project directory
cd /home/lewis/src/Fire-Flow

# Initialize Fire-Flow
echo "1. Initializing Fire-Flow..."
./bin/fire-flow init
echo "   ✓ Initialization complete"

# Check status
echo "2. Checking initial status..."
./bin/fire-flow status
echo "   ✓ Status check complete"

# Run tests to set up proper state
echo "3. Running tests to set up state..."
./bin/fire-flow run-tests
echo "   ✓ Test execution complete"

# Check status after running tests
echo "4. Checking status after test run..."
./bin/fire-flow status
echo "   ✓ Status check complete"

# Test TDD gate with a non-test file (should be blocked in GREEN state)
echo "5. Testing TDD gate with implementation file (should be blocked)..."
./bin/fire-flow tdd-gate --file main.go
echo "   ✓ TDD gate check complete"

# Test TDD gate with a test file (should be allowed)
echo "6. Testing TDD gate with test file (should be allowed)..."
./bin/fire-flow tdd-gate --file main_test.go
echo "   ✓ TDD gate check complete"

# Test commit and revert
echo "7. Testing commit functionality..."
./bin/fire-flow commit --message "Test commit"
echo "   ✓ Commit complete"

# Test revert functionality
echo "8. Testing revert functionality..."
./bin/fire-flow revert
echo "   ✓ Revert complete"

echo "=== All Fire-Flow tests completed successfully ==="