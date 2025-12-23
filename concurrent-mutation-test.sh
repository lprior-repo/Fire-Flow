#!/bin/bash

# Concurrent mutation testing script for Fire-Flow
# This script runs mutation tests with better concurrency control

echo "=== Concurrent Fire-Flow Mutation Testing ==="

# Check if go-mutest is available
if ! command -v go-mutest &> /dev/null; then
    echo "go-mutest not found, installing..."
    go install github.com/zimmski/go-mutest@latest
fi

# Get number of CPU cores for parallelization
NUM_CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

echo "Using $NUM_CORES cores for concurrent execution"

# Run mutation tests with parallel execution
echo "Running mutation tests with -p=$NUM_CORES flag..."
go-mutest -config=mutation-test-config.yaml -p=$NUM_CORES ./...

echo "Concurrent mutation testing completed."