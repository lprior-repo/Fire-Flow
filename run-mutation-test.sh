#!/bin/bash

# Script to run mutation tests for Fire-Flow
# This script demonstrates how to perform mutation testing

echo "=== Fire-Flow Mutation Testing Script ==="

# Check if go-mutest is available
if ! command -v go-mutest &> /dev/null; then
    echo "go-mutest not found, installing..."
    go install github.com/zimmski/go-mutest@latest
fi

# Run mutation tests with the configuration
echo "Running mutation tests with configuration from mutation-test-config.yaml..."
go-mutest -config=mutation-test-config.yaml ./...

echo "Mutation testing completed."