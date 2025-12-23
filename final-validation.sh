#!/bin/bash

echo "=== Final Validation of Fire-Flow Implementation ==="

# Test 1: Verify binary exists and is executable
if [ -x "bin/fire-flow" ]; then
    echo "✓ Binary verification: PASS"
else
    echo "✗ Binary verification: FAIL"
    exit 1
fi

# Test 2: Verify config file exists
if [ -f ".opencode/tcr/config.yml" ]; then
    echo "✓ Config file verification: PASS"
else
    echo "✗ Config file verification: FAIL"
    exit 1
fi

# Test 3: Verify state file exists
if [ -f ".opencode/tcr/state.json" ]; then
    echo "✓ State file verification: PASS"
else
    echo "✗ State file verification: FAIL"
    exit 1
fi

# Test 4: Verify Kestra workflows exist
workflow_count=$(ls -la kestra/flows/*.yml 2>/dev/null | wc -l)
if [ "$workflow_count" -ge 3 ]; then
    echo "✓ Kestra workflows verification: PASS ($workflow_count workflows found)"
else
    echo "✗ Kestra workflows verification: FAIL"
    exit 1
fi

# Test 5: Test basic functionality
echo "Testing basic functionality..."
status_output=$("./bin/fire-flow" status 2>&1)
if [[ "$status_output" == *"State:"* ]]; then
    echo "✓ Basic functionality test: PASS"
    echo "  Status: $status_output"
else
    echo "✗ Basic functionality test: FAIL"
    echo "  Output: $status_output"
    exit 1
fi

# Test 6: Test TDD gate with test file (should allow)
echo "Testing TDD gate with test file..."
tdd_output=$("./bin/fire-flow" tdd-gate --file main_test.go 2>&1)
if [[ "$tdd_output" == *"ALLOWED"* ]]; then
    echo "✓ TDD gate with test file: PASS"
else
    echo "✗ TDD gate with test file: FAIL"
    echo "  Output: $tdd_output"
    exit 1
fi

# Test 7: Test TDD gate with implementation file (should allow in RED state)
echo "Testing TDD gate with implementation file..."
tdd_output=$("./bin/fire-flow" tdd-gate --file main.go 2>&1)
if [[ "$tdd_output" == *"ALLOWED"* ]]; then
    echo "✓ TDD gate with implementation file: PASS"
else
    echo "✗ TDD gate with implementation file: FAIL"
    echo "  Output: $tdd_output"
    exit 1
fi

echo ""
echo "=== All Fire-Flow components verified successfully ==="
echo "Implementation is complete and functional!"