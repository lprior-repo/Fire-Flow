#!/bin/bash

# Test script to verify TDD gate functionality

echo "Testing TDD Gate functionality..."

# Create a test directory
mkdir -p test_dir
cd test_dir

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

# Test with a test file (should be allowed)
echo "Testing with test file (should be allowed)..."
cd ..
./bin/fire-flow tdd-gate --file test_dir/main_test.go

# Test with an implementation file in GREEN state (should be blocked)
echo "Testing with implementation file in GREEN state (should be blocked)..."
./bin/fire-flow tdd-gate --file test_dir/main.go

# Clean up
rm -rf test_dir
echo "Test completed."