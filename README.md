# Fire-Flow

Fire-Flow is a workflow orchestration service built with Go 1.24+ and Kestra.

## Prerequisites

- Go 1.24 or higher
- Docker and Docker Compose
- Task (go-task) - Install from https://taskfile.dev/
  ```bash
  # macOS
  brew install go-task

  # Linux
  sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin

  # Or using Go
  go install github.com/go-task/task/v3/cmd/task@latest
  ```

## Project Structure

```
Fire-Flow/
├── cmd/
│   └── fire-flow/       # Main application entry point
├── internal/            # Private application code
│   ├── config/         # Configuration management
│   ├── overlay/        # OverlayFS implementation for TDD enforcement
│   ├── state/          # State persistence
│   └── version/        # Version information
├── kestra/
│   ├── flows/          # Kestra workflow definitions
│   └── config/         # Kestra configuration files
├── Taskfile.yml        # Task automation
├── go.mod              # Go module definition
├── kestra-webhook-configuration.md  # Documentation for Kestra webhook setup
└── opencode-integration-setup.md    # Documentation for OpenCode integration
```

## Quick Start

### 1. Build and Run the Go Application

```bash
# Show available tasks
task

# Install development tools (optional)
task install-tools

# Build the application
task build

# Run the application
task run
```

### 2. Start Kestra Orchestrator

```bash
# Start Kestra and PostgreSQL
docker-compose up -d

# View logs
docker-compose logs -f kestra

# Access Kestra UI
# Open http://localhost:8080 in your browser
```

### 3. Execute Workflows

Once Kestra is running, you can:
- Access the Kestra UI at http://localhost:8080
- View and execute workflows defined in `kestra/flows/`
- Create new workflows using the Kestra UI or YAML files

## Available Tasks

Run `task` or `task --list` to see all available tasks:

- `task build` - Build the application
- `task run` - Run the application
- `task test` - Run tests
- `task test-coverage` - Run tests with coverage report
- `task lint` - Run code linters
- `task tidy` - Tidy and verify Go modules
- `task clean` - Clean build artifacts
- `task deps` - Download dependencies
- `task check` - Run all checks (tidy, lint, test)

## Development

### Building

```bash
task build
```

The binary will be created in `./bin/fire-flow`

### Testing

```bash
# Run all tests
task test

# Run tests with coverage
task test-coverage

# Run mutation tests (requires go-mutest)
task mutation-test
```

### Linting

```bash
task lint
```

## TCR (Test && Commit || Revert) Enforcer

Fire-Flow includes a TDD enforcement tool that implements the Test && Commit || Revert workflow using an overlay filesystem. This provides filesystem-level enforcement of TDD practices:

1. **OverlayFS-based enforcement** - All changes are written to an upper layer (tmpfs), not the real filesystem
2. **Automatic commit/discard** - Based on test results
3. **Zero pollution** - No temporary data in project directory
4. **Filesystem-level protection** - Cannot bypass TDD rules

### Commands

- `fire-flow init` - Initialize Fire-Flow configuration and state
- `fire-flow status` - Show current TCR state (RED/GREEN) and statistics
- `fire-flow watch` - Watch for file changes and automatically run tests
- `fire-flow gate` - Read from stdin and write to stdout for CI integration

### Configuration

Fire-Flow uses Viper for configuration management. Configuration is stored in `.fire-flow/config.yaml`:

```yaml
testCommand: "go test -json ./..."        # Command to run tests
testPatterns:                              # Patterns for identifying test files
  - "_test\\.go$"
protectedPaths:                            # Paths that cannot be modified
  - "opencode.json"
  - ".fire-flow"
timeout: 30                                # Test execution timeout in seconds
autoCommitMsg: "WIP"                       # Default commit message
```

Viper supports multiple configuration sources including:
- YAML config file
- Environment variables
- Command-line flags

## OpenCode Integration

This project supports integration with OpenCode through Kestra workflows. See the following documentation files for setup instructions:

- [Kestra Webhook Configuration](kestra-webhook-configuration.md)
- [OpenCode Integration Setup](opencode-integration-setup.md)

## Kestra Workflows

Example workflows are provided in `kestra/flows/`:

- `hello-flow.yml` - Basic hello world workflow
- `build-and-test.yml` - Build and test the Go application

### Creating New Workflows

Create YAML files in `kestra/flows/` following the Kestra workflow syntax:

```yaml
id: my-workflow
namespace: fire.flow

tasks:
  - id: my-task
    type: io.kestra.core.tasks.log.Log
    message: "Hello from my workflow!"
```

## Stopping Services

```bash
# Stop Kestra and PostgreSQL
docker-compose down

# Stop and remove volumes (clean slate)
docker-compose down -v
```

## License

See LICENSE file for details.