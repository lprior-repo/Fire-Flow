#!/bin/bash

# Test script to verify OpenCode integration works correctly

echo "Testing OpenCode integration..."

# Create test directory
mkdir -p test_integration
cd test_integration

# Create .opencode/tcr directory
mkdir -p .opencode/tcr

# Create a basic config file
cat > .opencode/tcr/config.yml << EOF
testCommand: "go test -json ./..."
testPatterns:
  - "_test\\.go$"
protectedPaths:
  - "opencode.json"
  - ".opencode/tcr"
timeout: 30
autoCommitMsg: "WIP"
EOF

# Create a basic state file (GREEN state)
cat > .opencode/tcr/state.json << EOF
{
  "mode": "both",
  "revertStreak": 0,
  "failingTests": [],
  "lastCommitTime": "2024-12-22T15:30:00Z"
}
EOF

# Create a test file to simulate an implementation file
mkdir -p testdir
cat > testdir/main.go << EOF
package main

func main() {
    println("Hello, world!")
}
EOF

# Test with an implementation file in GREEN state (should be blocked)
echo "Testing with implementation file in GREEN state (should be blocked)..."
cd ..
./bin/fire-flow tdd-gate --file test_integration/testdir/main.go

# Test with a test file (should be allowed)
echo "Testing with test file (should be allowed)..."
./bin/fire-flow tdd-gate --file test_integration/testdir/main_test.go

# Clean up
rm -rf test_integration
echo "Integration test completed."