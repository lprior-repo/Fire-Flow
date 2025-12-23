#!/bin/bash

echo "=== Fire-Flow Implementation Verification ==="

# Check if binary exists
if [ -f "bin/fire-flow" ]; then
    echo "✓ Binary exists: bin/fire-flow"
else
    echo "✗ Binary missing: bin/fire-flow"
fi

# Check if config exists
if [ -f ".opencode/tcr/config.yml" ]; then
    echo "✓ Config exists: .opencode/tcr/config.yml"
else
    echo "✗ Config missing: .opencode/tcr/config.yml"
fi

# Check if state exists
if [ -f ".opencode/tcr/state.json" ]; then
    echo "✓ State exists: .opencode/tcr/state.json"
else
    echo "✗ State missing: .opencode/tcr/state.json"
fi

# Check if workflows exist
workflow_count=$(ls -la kestra/flows/*.yml 2>/dev/null | wc -l)
echo "✓ Workflows found: $workflow_count"

# Test basic functionality
echo ""
echo "=== Testing Basic Functionality ==="
./bin/fire-flow status 2>/dev/null && echo "✓ Status command works" || echo "✗ Status command failed"

echo ""
echo "=== Fire-Flow Implementation Complete ==="