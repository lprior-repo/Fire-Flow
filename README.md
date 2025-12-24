# Fire-Flow

Fire-Flow is a TCR (Test && Commit || Revert) enforcement tool built with Go 1.25+ and Kestra workflow orchestration. It enforces TDD (Test-Driven Development) practices through filesystem-level protection using OverlayFS.

## Features

- **CLI Tool**: Complete command-line interface for TCR workflow enforcement
- **TDD Gate**: Blocks implementation changes until tests fail (RED state)
- **Test Execution**: Runs tests with timeout handling and JSON output parsing
- **Automatic Commit/Revert**: Commits changes if tests pass, reverts if they fail
- **Kestra Integration**: Workflow orchestration for CI/CD pipelines
- **OverlayFS Support**: Filesystem-level isolation for safe experimentation
- **OpenCode Integration**: Webhook-based integration with AI coding agents

## Prerequisites

- Go 1.25 or higher
- Linux with OverlayFS support (for `watch` command)
- Docker and Docker Compose (optional, for Kestra)
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
│   └── fire-flow/        # Main application entry point
├── internal/             # Private application code
│   ├── command/          # CLI commands (init, status, run-tests, commit, revert, watch)
│   ├── config/           # Configuration management
│   ├── logging/          # Standardized logging
│   ├── overlay/          # OverlayFS implementation for TDD enforcement
│   ├── patternmatcher/   # File pattern matching (glob patterns)
│   ├── state/            # State persistence
│   ├── tddgate/          # TDD gate logic
│   ├── teststate/        # Test result parsing
│   ├── utils/            # Utility functions
│   └── version/          # Version information
├── kestra/
│   └── flows/            # Kestra workflow definitions
├── Taskfile.yml          # Task automation
└── go.mod                # Go module definition
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

## Commands

Fire-Flow provides the following CLI commands:

| Command | Description |
|---------|-------------|
| `fire-flow init` | Initialize Fire-Flow configuration and state |
| `fire-flow status` | Show current TCR state (RED/GREEN) and statistics |
| `fire-flow tdd-gate` | Check TDD gate - blocks if in GREEN state |
| `fire-flow run-tests` | Execute test suite with timeout handling |
| `fire-flow commit` | Stage and commit changes with state update |
| `fire-flow revert` | Reset to HEAD and update state |
| `fire-flow watch` | Watch for file changes with OverlayFS protection |
| `fire-flow gate` | CI integration mode (stdin/stdout JSON) |

### Usage Examples

```bash
# Initialize Fire-Flow
fire-flow init

# Check current state
fire-flow status

# Run tests with default timeout
fire-flow run-tests

# Run tests with custom timeout
fire-flow run-tests --timeout 60

# Commit changes with message
fire-flow commit --message "feat: implement user authentication"

# Revert changes (hard reset)
fire-flow revert

# Watch mode with OverlayFS (requires root)
sudo fire-flow watch
```

## Configuration

Fire-Flow stores configuration in `.opencode/tcr/config.yml`:

```yaml
testCommand: "go test -json ./..."    # Command to run tests
testPatterns:                          # Glob patterns for test files
  - "*_test.go"
protectedPaths:                        # Paths that cannot be modified
  - "opencode.json"
  - ".opencode/tcr"
timeout: 30                            # Test execution timeout in seconds
autoCommitMsg: "WIP"                   # Default commit message
overlayWorkDir: "/tmp/fire-flow-overlay-work"
watchDebounce: 500                     # File watcher debounce in ms
watchIgnore:                           # Patterns to ignore in watch mode
  - ".git"
  - "node_modules"
  - ".opencode"
```

Configuration can be overridden with environment variables:
- `FIRE_FLOW_ROOT` - Override the root directory for state/config
- `TDD_TEST_COMMAND` - Override the test command
- `TDD_TIMEOUT` - Override the timeout
- `TDD_AUTO_COMMIT_MSG` - Override the auto-commit message

## State Management

Fire-Flow maintains state in `.opencode/tcr/state.json`:

```json
{
  "mode": "both",
  "revertStreak": 0,
  "failingTests": [],
  "lastCommitTime": "2025-12-23T00:00:00Z"
}
```

- **RED state**: Tests are failing (`failingTests` is not empty)
- **GREEN state**: All tests passing (`failingTests` is empty)

## Kestra Integration

Fire-Flow includes Kestra workflows for CI/CD orchestration. Workflows are defined in `kestra/flows/`:

- `tcr-enforcement-workflow.yml` - Main TCR workflow
- `hello-flow.yml` - Basic example workflow
- `build-and-test.yml` - Build and test workflow

### Webhook Configuration

See [kestra-webhook-configuration.md](kestra-webhook-configuration.md) for API integration details.

## OpenCode Integration

Fire-Flow supports AI coding agent integration through webhooks. See [OPENCODE_INTEGRATION.md](OPENCODE_INTEGRATION.md) for setup instructions.

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

# Run tests with verbose output
go test -v ./...
```

### Linting

```bash
task lint
```

## System Requirements

- **Go 1.25+**: Required for building
- **Linux with OverlayFS**: Required for `watch` command
- **sudo privileges**: Required for OverlayFS mounting

## License

See LICENSE file for details.