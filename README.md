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
├── pkg/                 # Public library code
├── kestra/
│   ├── flows/          # Kestra workflow definitions
│   └── config/         # Kestra configuration files
├── docker-compose.yml  # Kestra orchestrator setup
├── Taskfile.yml        # Task automation
└── go.mod              # Go module definition
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
```

### Linting

```bash
task lint
```

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