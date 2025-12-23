#!/bin/bash

# Test script to demonstrate OpenCode integration working
echo "Testing OpenCode integration with Fire-Flow..."

# First, make sure we're in the right directory
cd /home/lewis/src/Fire-Flow

# Initialize TCR environment if not already done
echo "Initializing TCR environment..."
./bin/fire-flow init

# Check current status
echo "Current TCR status:"
./bin/fire-flow status

# Test with a dummy file that should be allowed in RED state
echo "Testing TDD gate with a dummy file..."
./bin/fire-flow tdd-gate --file test_dummy.go

# Run tests to make sure they're working
echo "Running tests..."
./bin/fire-flow run-tests

# Show final status
echo "Final TCR status:"
./bin/fire-flow status

echo "OpenCode integration test completed successfully!"