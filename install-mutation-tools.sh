#!/bin/bash

# Script to install mutation testing tools for Fire-Flow
# This script helps set up the environment for mutation testing

echo "=== Installing Mutation Testing Tools for Fire-Flow ==="

# Check if Go is installed
if ! command -v go &> /dev/null; then
    echo "Error: Go is not installed. Please install Go first."
    exit 1
fi

echo "Go version:"
go version

# Try to install go-mutest
echo "Installing go-mutest..."
if go install github.com/zimmski/go-mutest@latest; then
    echo "✅ go-mutest installed successfully!"
else
    echo "⚠️  Failed to install go-mutest via go install"
    echo "Trying alternative installation method..."
    
    # Try cloning and building manually
    if git clone https://github.com/zimmski/go-mutest.git /tmp/go-mutest && cd /tmp/go-mutest && go build -o go-mutest .; then
        echo "✅ go-mutest built successfully!"
        echo "You can now run: ./go-mutest -config=../mutation-test-config.yaml ./..."
        # Clean up
        cd -
        rm -rf /tmp/go-mutest
    else
        echo "❌ Failed to build go-mutest manually"
        echo "You'll need to install a compatible mutation testing tool manually"
    fi
fi

echo "=== Installation Complete ==="
echo "To run mutation tests, use:"
echo "  go run go-mutation-tester.go"
echo "Or if go-mutest is installed:"
echo "  go-mutest -config=mutation-test-config.yaml ./..."
echo "For concurrent execution:"
echo "  go-mutest -config=mutation-test-config.yaml -p=4 ./..."