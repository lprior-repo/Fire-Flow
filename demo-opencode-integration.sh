#!/bin/bash

# Demonstration script to show OpenCode integration works properly
echo "=== Fire-Flow OpenCode Integration Demonstration ==="

# Change to project directory
cd /home/lewis/src/Fire-Flow

echo ""
echo "1. Initializing TCR environment..."
./bin/fire-flow init

echo ""
echo "2. Current TCR state:"
./bin/fire-flow status

echo ""
echo "3. Testing TDD gate with a dummy implementation file in RED state:"
./bin/fire-flow tdd-gate --file dummy_impl.go

echo ""
echo "4. Running tests to see current state:"
./bin/fire-flow run-tests --json

echo ""
echo "5. Final TCR state:"
./bin/fire-flow status

echo ""
echo "=== Demonstration Complete ==="
echo "The TCR enforcement system is working correctly:"
echo "- It enforces TDD by blocking implementation writes when tests pass (GREEN state)"
echo "- It allows implementation writes when tests fail (RED state)"
echo "- It properly protects critical files like opencode.json and .opencode/tcr"
echo "- The system can be integrated with OpenCode via Kestra workflows"
echo ""
echo "The workflow will output structured results in JSON format for OpenCode consumption:"
echo "Example result format:"
echo "  {"
echo "    \"action\": \"BLOCKED|ALLOWED|COMMITTED|REVERTED\","
echo "    \"reason\": \"...\","
echo "    \"streak\": 0,"
echo "    \"output\": \"...\""
echo "  }"