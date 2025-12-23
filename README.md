# Fire-Flow

A minimalist Test-Driven Development (TDD) workflow tool built with Go.

## What It Does

Fire-Flow helps enforce TDD practices by tracking your test state and managing your development workflow.

## Prerequisites

- Go 1.24 or higher

## Quick Start

```bash
# Build the application
go build -o fire-flow ./cmd/fire-flow/

# Initialize Fire-Flow in your project
./fire-flow init

# Check current status
./fire-flow status
```

## Commands

- `fire-flow init` - Initialize Fire-Flow state and configuration
- `fire-flow status` - Show current TDD state (GREEN/RED)

## How It Works

Fire-Flow maintains state in `.fire-flow/` directory:
- `config.yaml` - Configuration for test commands and patterns
- `state.json` - Current TDD state (mode, failing tests, etc.)

## Configuration

Default configuration (`.fire-flow/config.yaml`):
```yaml
testCommand: "go test -json ./..."
testPatterns:
  - "_test\\.go$"
protectedPaths:
  - "opencode.json"
  - ".opencode/tcr"
timeout: 30
autoCommitMsg: "WIP"
```

You can override settings via environment variables:
- `TDD_TEST_COMMAND` - Override test command
- `TDD_TIMEOUT` - Override test timeout (seconds)
- `TDD_AUTO_COMMIT_MSG` - Override auto-commit message

## Development

```bash
# Build
go build ./cmd/fire-flow/

# Run tests
go test ./...

# Run with coverage
go test -cover ./...
```

## Project Structure

```
Fire-Flow/
├── cmd/
│   └── fire-flow/       # Main application
├── internal/
│   ├── command/         # Command implementations
│   ├── config/          # Configuration management
│   ├── state/           # State persistence
│   └── version/         # Version information
├── go.mod
└── README.md
```

## License

See LICENSE file for details.
