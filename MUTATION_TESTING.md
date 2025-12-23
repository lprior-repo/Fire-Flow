# Mutation Testing in Fire-Flow

Mutation testing is a technique used to evaluate the quality of your test suite by introducing small changes (mutations) to your source code and checking if your tests can detect these changes.

## What is Mutation Testing?

Mutation testing involves:
1. Making small changes to the source code (mutants)
2. Running the test suite against these mutants
3. Determining if tests catch the mutations (mutants are "killed")
4. If a mutant survives, it indicates a gap in test coverage

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

To run mutation tests, you'll need to install a mutation testing tool. While we've configured the system to work with go-mutest, it may not be available in all environments. Alternative approaches include:

### Option 1: Using go-mutest (if available)
```bash
# Install go-mutest (may not be available)
go install github.com/zimmski/go-mutest@latest

# Run mutation tests with configuration
go-mutest -config=mutation-test-config.yaml ./...
```

### Option 2: Using the task system
```bash
# Run mutation tests with the task system
task mutation-test
```

### Option 3: Running with concurrency for faster execution
```bash
# Run with parallel execution
task mutation-test-concurrent
```

## Understanding Results

Mutation testing results will show:
- **Killed mutants**: Tests successfully detected the mutation
- **Survived mutants**: Tests failed to detect the mutation (potential test gap)
- **Timeout mutants**: Mutations that took too long to test
- **Error mutants**: Mutations that caused compilation errors

## Optimizing for Concurrency

The Fire-Flow system is designed to support concurrent execution of mutation tests. When running mutation tests, the system supports:

1. **Parallel package execution**: Tests can run on different packages simultaneously
2. **CPU core utilization**: Automatically adapts to available CPU cores
3. **Configurable concurrency levels**: The -p flag can be used to set parallelism levels

Example of running with concurrency:
```bash
# Run with 4 parallel workers
go-mutest -config=mutation-test-config.yaml -p=4 ./...
```

## Limitations

- Mutation testing can be time-consuming
- Not all mutations are meaningful (e.g., changing 1 to 2 in a constant)
- May not work well with complex dependencies or external libraries
- Some mutation testing tools may not be available in all environments