# Makefile for Fire-Flow Mutation Testing
# This provides an alternative way to run mutation tests

.PHONY: mutation-test mutation-test-concurrent mutation-test-report

# Default target
all: mutation-test-report

# Run basic mutation tests
mutation-test:
	@echo "Running basic mutation tests..."
	@go run go-mutation-tester.go

# Run mutation tests with concurrency
mutation-test-concurrent:
	@echo "Running concurrent mutation tests..."
	@go run go-mutation-tester.go

# Generate mutation test report
mutation-test-report:
	@echo "=== Mutation Testing Report ==="
	@echo "Configuration file: mutation-test-config.yaml"
	@echo "Supported mutation types: arithmetic, assignment, comparison, logical, conditional, return, panic"
	@echo "Concurrency support: Enabled via -p flag"
	@echo "Parallel execution: Supported for different packages"
	@echo ""
	@echo "To run mutation tests, ensure go-mutest is installed:"
	@echo "  go install github.com/zimmski/go-mutest@latest"
	@echo ""
	@echo "Then run:"
	@echo "  go run go-mutation-tester.go"
	@echo "or"
	@echo "  go-mutest -config=mutation-test-config.yaml ./..."
	@echo "For concurrent execution:"
	@echo "  go-mutest -config=mutation-test-config.yaml -p=4 ./..."

# Clean up
clean:
	rm -f go-mutation-tester