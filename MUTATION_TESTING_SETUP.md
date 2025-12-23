# Setting Up Mutation Testing for Fire-Flow

This document provides instructions for setting up and running mutation testing in the Fire-Flow project.

## Prerequisites

- Go 1.24 or higher
- Git
- Basic understanding of Go modules and testing

## Installing Mutation Testing Tools

While the Fire-Flow project is configured to work with go-mutest, we'll need to ensure the tool is available in your environment.

### Option 1: Using go install (if available)

```bash
go install github.com/zimmski/go-mutest@latest
```

### Option 2: Manual Installation (if go install fails)

If the go install command fails, you can manually clone and build the tool:

```bash
git clone https://github.com/zimmski/go-mutest.git
cd go-mutest
go build -o go-mutest .
# Move the binary to your PATH or use it directly
```

## Configuration

The mutation testing configuration is defined in `mutation-test-config.yaml`:

```yaml
# Mutation Testing Configuration for Fire-Flow
# This file defines settings for mutation testing using standard Go tools

# Enable mutation testing
enabled: true

# Test command to run before mutations
testCommand: "go test -v ./..."

# Timeout for test execution
timeout: 30

# Mutators to enable
mutators:
  - "arithmetic"
  - "assignment"
  - "comparison"
  - "logical"
  - "conditional"
  - "return"
  - "panic"

# Coverage thresholds
coverage:
  # Minimum coverage percentage
  min: 80
  # Maximum coverage percentage (for performance)
  max: 100

# Files to exclude from mutation testing
exclude:
  - "main.go" # Main file might not be suitable for mutation testing
  - "version.go" # Version file is typically stable
  - "*_test.go" # Test files
```

## Running Mutation Tests

The Fire-Flow project provides several ways to run mutation tests:

### Using the Go-based tester (Recommended)

```bash
# Run the Go-based mutation tester
go run go-mutation-tester.go
```

### Using Taskfile (if available)

```bash
# Run standard mutation tests
task mutation-test

# Run with concurrency
task mutation-test-concurrent
```

### Using Makefile

```bash
# Generate report
make mutation-test-report

# Run tests
make mutation-test
```

### Direct go-mutest execution

```bash
# Run with basic configuration
go-mutest -config=mutation-test-config.yaml ./...

# Run with concurrency (4 parallel workers)
go-mutest -config=mutation-test-config.yaml -p=4 ./...
```

## Understanding Results

Mutation testing results will include:

- **Killed mutants**: Tests successfully detected the mutation
- **Survived mutants**: Tests failed to detect the mutation (potential test gap)
- **Timeout mutants**: Mutations that took too long to test
- **Error mutants**: Mutations that caused compilation errors

## Performance Optimization

### Concurrency Settings

The Fire-Flow system supports concurrent execution:

1. **Parallel Package Execution**: Different packages can be tested simultaneously
2. **CPU Core Utilization**: Automatically adapts to available CPU cores
3. **Configurable Concurrency**: Use the `-p` flag to set parallelism levels

Example of running with different concurrency levels:
```bash
# Run with 2 parallel workers
go-mutest -config=mutation-test-config.yaml -p=2 ./...

# Run with 8 parallel workers (if you have 8 cores)
go-mutest -config=mutation-test-config.yaml -p=8 ./...
```

## Troubleshooting

### If go-mutest installation fails

If you encounter issues installing go-mutest, you can:

1. Check your Go environment:
   ```bash
   go version
   go env GOPATH
   ```

2. Try installing with a specific version:
   ```bash
   go install github.com/zimmski/go-mutest@v0.0.0-20210101000000-000000000000
   ```

3. Use alternative mutation testing tools if needed

### If tests are failing

Some tests might be designed to fail intentionally for demonstration purposes:
- `TestMain` in main_test.go always fails
- `TestExample` in example_test.go is a failing test

These are normal and expected in the test suite.

## Best Practices

1. **Run on Stable Code**: Only run mutation tests on code that's in a stable state
2. **Monitor Resource Usage**: Mutation testing can be resource-intensive
3. **Use Incremental Testing**: Run mutation tests on specific packages when needed
4. **Combine with Coverage**: Use mutation testing alongside code coverage analysis
5. **Set Appropriate Thresholds**: Define acceptable mutation survival rates for your project

## Integration with CI/CD

The Fire-Flow mutation testing framework is designed to integrate well with CI/CD pipelines:

1. Add mutation testing to your build process
2. Set appropriate time limits for mutation tests
3. Configure alerts for high mutation survival rates
4. Use parallel execution to reduce CI time

## Limitations

- Mutation testing can be time-consuming
- Not all mutations are meaningful for test quality assessment
- May not work well with complex dependencies or external libraries
- Some environments might not have access to mutation testing tools

## Next Steps

After setting up mutation testing:

1. Run a full mutation test suite
2. Analyze results to identify test gaps
3. Improve test coverage based on mutation test findings
4. Set up regular mutation testing in your development workflow