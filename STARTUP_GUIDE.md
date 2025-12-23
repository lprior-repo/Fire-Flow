# Fire-Flow Startup Guide

## Overview

The **startup script** (`scripts/startup.sh`) is the unified entry point for initializing Fire-Flow when a worktree is spun up. It handles all necessary setup, verification, and configuration to ensure Fire-Flow components (CLI, Kestra, OpenCode, Beads) are ready for development.

---

## Quick Start

### Full Startup (Recommended)
```bash
./scripts/startup.sh
```

Performs 8 phases:
1. ✅ Verify tools (Go, Git, Python, SQLite, etc.)
2. ✅ Build Fire-Flow binaries
3. ✅ Initialize state and configuration
4. ✅ Configure environment variables
5. ✅ Verify service availability (Kestra, Vibe Kanban)
6. ✅ Sync with Beads issue tracker
7. ✅ Run health checks
8. ✅ Generate status report

### Verify-Only (Fast Check)
```bash
./scripts/startup.sh --verify-only
```

Checks if all required tools are available without building or initializing.

### Build-Only
```bash
./scripts/startup.sh --build-only
```

Builds Fire-Flow binaries and runs tests without full initialization.

---

## Startup Phases Explained

### Phase 1: Verify Tools

Checks availability of required and optional tools:

**Required:**
- `go` - Go compiler (v1.20+)
- `git` - Version control
- `python3` - Script execution
- `sqlite3` - Database access (Vibe Kanban)

**Recommended:**
- `bd` - Beads CLI (git-native issue tracking)
- `gh` - GitHub CLI (for PR creation)
- `kestra` - Kestra CLI (workflow management)
- `npm` - Node.js package manager (for Vibe Kanban)

**Output:**
```
[✓] Go: go1.25.5
[✓] Git: git version 2.52.0
[✓] Beads CLI: Available
[✓] GitHub CLI: gh version 2.83.2
[✓] Python: Python 3.12.12
```

### Phase 2: Build Binaries

Compiles Fire-Flow CLI and runs test suite:

**Actions:**
1. Compile `cmd/fire-flow/main.go` → `bin/fire-flow`
2. Run `go test ./...` to verify build
3. Mark binary as executable

**Output:**
```
[*] Building fire-flow CLI...
[✓] Built: ./bin/fire-flow
[*] Running unit tests...
[✓] All tests passed
```

### Phase 3: Initialize State & Configuration

Sets up directories and configuration files:

**Created:**
- `.opencode/tcr/` - TCR state directory
- `.opencode/config.json` - OpenCode configuration
- `.opencode/tcr/state.json` - TCR execution state

**config.json Format:**
```json
{
  "name": "Fire-Flow TCR Enforcer",
  "cli_binary": "./bin/fire-flow",
  "commands": {
    "init": "init",
    "status": "status",
    "tdd-gate": "tdd-gate",
    "run-tests": "run-tests",
    "commit": "commit",
    "revert": "revert"
  },
  "kestra": {
    "enabled": true,
    "port": 8080,
    "workflow": "fire.flow/tcr-enforcement-workflow"
  },
  "vibe-kanban": {
    "enabled": true,
    "port": 34107,
    "project_id": "522ec0f8-0cec-4533-8a2f-ac134da90b26"
  }
}
```

### Phase 4: Configure Environment

Sets critical environment variables:

```bash
export FIRE_FLOW_ROOT="/home/lewis/src/Fire-Flow"
export FIRE_FLOW_BIN="./bin/fire-flow"
export FIRE_FLOW_STATE="./.opencode/tcr"
export KESTRA_PORT="8080"
export VIBE_KANBAN_PORT="34107"
```

Creates `.env` file for convenience:
```bash
source .env  # Load in your shell
```

### Phase 5: Verify Services

Checks if external services are running:

**Checks:**
- Fire-Flow CLI is executable and status command works
- Kestra running on port 8080
- Vibe Kanban running on port 34107
- Git repository is valid

**Output:**
```
[✓] Fire-Flow CLI is executable
[✓] Fire-Flow status command works
[⚠] Kestra not running on port 8080 (optional)
[✓] Vibe Kanban is running on port 34107
[✓] Git repository is valid
[*] Current branch: main
```

### Phase 6: Sync with Beads

Synchronizes Beads issue tracker with git:

```bash
bd sync  # Pulls remote issues, exports local changes
```

This ensures all task metadata is consistent between Beads and git.

### Phase 7: Health Check

Validates that all essential components are ready:

**Checks (5 total):**
1. Go compiler available
2. Git repository valid
3. Binary built and executable
4. State directory initialized
5. Python available

**Output:**
```
Health Check: 5/5 passed
[✓] All health checks passed!
```

### Phase 8: Status Report

Generates comprehensive startup summary:

```
╔════════════════════════════════════════════════════════╗
║          Fire-Flow Startup Complete                    ║
╚════════════════════════════════════════════════════════╝

🚀 Ready to use Fire-Flow!

Quick Reference:
  Project Root:     /home/lewis/src/Fire-Flow
  Fire-Flow Binary: ./bin/fire-flow
  State Directory:  ./.opencode/tcr
  Startup Log:      ./.opencode/startup.log

Available Commands:
  ./bin/fire-flow init              # Initialize TCR state
  ./bin/fire-flow status            # Show TCR status
  ./bin/fire-flow tdd-gate          # Run TDD gate check
  ./bin/fire-flow run-tests         # Execute tests
  ./bin/fire-flow commit            # Commit changes
  ./bin/fire-flow revert            # Revert changes

Integration Tools:
  Kestra:       http://localhost:8080
  Vibe Kanban:  http://127.0.0.1:34107
  Beads:        bd list (git-native tracking)
```

---

## Using Fire-Flow After Startup

### Basic Commands

```bash
# Check TCR enforcement status
./bin/fire-flow status

# Run TDD gate check (test requirements)
./bin/fire-flow tdd-gate --file src/file.go

# Execute test suite
./bin/fire-flow run-tests

# Commit if tests pass
./bin/fire-flow commit --message "Feature: implement XYZ"

# Revert if tests fail
./bin/fire-flow revert

# Get help
./bin/fire-flow --help
```

### With Kestra Orchestration

```bash
# Trigger TCR enforcement workflow
kestra trigger \
  --namespace fire.flow \
  --name tcr-enforcement-workflow \
  --input file_path=/src/main.go
```

### With Vibe Kanban

```bash
# View board (opens browser)
http://127.0.0.1:34107/projects/522ec0f8-0cec-4533-8a2f-ac134da90b26/tasks

# Assign AI agent to task
# Create task from Beads issue
# Monitor progress in real-time
```

### With Beads Tracking

```bash
# See all open tasks
bd list

# See tasks ready for work
bd ready

# Mark task in progress
bd update --issue Fire-Flow-11f.1.1 --status in_progress

# Sync with git
bd sync
```

---

## Troubleshooting

### Issue: "Go is not installed"

**Solution:**
```bash
# Install Go from https://golang.org/dl
# Or use system package manager:
sudo apt-get install golang-go  # Debian/Ubuntu
brew install go                  # macOS
```

### Issue: "Tests failed - build is invalid"

**Solution:**
```bash
# Check test output
go test -v ./...

# Fix failing tests
# Then retry startup
./scripts/startup.sh
```

### Issue: "Beads CLI not found"

**Solution:**
```bash
# Install Beads from source
git clone https://github.com/kevinjqiu/beads.git
cd beads
go install ./cmd/bd

# Or download release binary
# https://github.com/kevinjqiu/beads/releases
```

### Issue: "Vibe Kanban not running"

**Solution:**
```bash
# Start Vibe Kanban in another terminal
PORT=34107 npx vibe-kanban

# Or check if port is in use
lsof -i :34107

# If process exists but not responding, kill and restart
pkill -f vibe-kanban
```

### Issue: "Kestra not running"

**Solution:**
```bash
# Kestra is optional but recommended
# Install from https://kestra.io

# Start locally:
kestra server standalone

# Or use Docker:
docker run -p 8080:8080 kestra:latest
```

### Issue: "Git repository is not valid"

**Solution:**
```bash
# Check git status
git status

# If not a git repo:
git init

# If issues with worktree:
git status --porcelain
git reset --hard HEAD
```

---

## Environment Files

### `.env` (Generated)

Auto-generated environment configuration:

```bash
export FIRE_FLOW_ROOT="/home/lewis/src/Fire-Flow"
export FIRE_FLOW_BIN="./bin/fire-flow"
export FIRE_FLOW_STATE="./.opencode/tcr"
export KESTRA_PORT="8080"
export VIBE_KANBAN_PORT="34107"
```

**Use:**
```bash
source .env
echo $FIRE_FLOW_ROOT
```

### `.opencode/config.json` (Generated)

Central configuration for all Fire-Flow tools:

- CLI binary location
- Available commands
- Kestra integration settings
- Vibe Kanban project ID
- Feature flags

### `.opencode/tcr/state.json` (Generated)

Execution state tracking:

```json
{
  "initialized": true,
  "version": "1.0",
  "created_at": "2025-12-23T00:00:00Z",
  "status": "ready",
  "tdd_enforced": true,
  "test_coverage": 0.0,
  "commits_since_startup": 0,
  "streak": 0
}
```

---

## Integration with Vibe Kanban

When Vibe Kanban spins up a worktree to execute a task:

1. **Worktree Created:** `git worktree add /tmp/worktree-XYZ`
2. **Startup Script Runs:** `./scripts/startup.sh`
3. **Binary Built:** Fire-Flow CLI compiled fresh
4. **State Initialized:** Configuration and state files created
5. **Environment Ready:** All env vars set, services verified
6. **Agent Executes Task:** `./bin/fire-flow <command>`
7. **Results Captured:** Output written to `.opencode/tcr/results/`
8. **Worktree Cleaned:** Isolated execution, then removed

**Advantages:**
- ✅ Fresh builds (no stale state)
- ✅ Isolated execution (no interference)
- ✅ Reproducible environments
- ✅ Safe experimentation

---

## Monitoring Startup

### Real-time Log

Monitor startup progress live:

```bash
tail -f .opencode/startup.log
```

### Full Log After Completion

View complete startup log:

```bash
cat .opencode/startup.log
```

### Latest Startup

Find last startup.log:

```bash
ls -lrt .opencode/startup.log*
```

---

## Best Practices

### 1. Run Startup After Pulling Changes

```bash
git pull
./scripts/startup.sh
```

This ensures:
- Binaries are built from latest code
- Dependencies are initialized
- Configuration is current

### 2. Use Startup in CI/CD

```yaml
# .github/workflows/ci.yml
- name: Fire-Flow Startup
  run: ./scripts/startup.sh --build-only

- name: Run TCR Checks
  run: ./bin/fire-flow tdd-gate
```

### 3. Monitor Startup Log

```bash
# After startup, check for warnings
grep "\[⚠\]" .opencode/startup.log

# Or errors
grep "\[!\]" .opencode/startup.log
```

### 4. Keep Environment Fresh

Re-run startup periodically:

```bash
# Daily
0 9 * * * cd /home/lewis/src/Fire-Flow && ./scripts/startup.sh

# Or on demand
./scripts/startup.sh --verify-only
```

---

## Related Documentation

- **[SDLC_VIBE_KANBAN_SETUP.md](./SDLC_VIBE_KANBAN_SETUP.md)** - SDLC practices and Vibe Kanban setup
- **[QWEN.md](./QWEN.md)** - Agent instructions and project conventions
- **[NEXT_STAGES_FROM_MEM0.md](./NEXT_STAGES_FROM_MEM0.md)** - Implementation roadmap
- **[README.md](./README.md)** - Project overview

---

## Support

For issues or questions:

1. Check troubleshooting section above
2. Review startup log: `.opencode/startup.log`
3. Run with verbose: `set -x ./scripts/startup.sh`
4. Check Beads issues: `bd list`
5. Review tool documentation

---

**Last Updated:** 2025-12-23
**Startup Script Version:** 1.0
**Tested On:** Go 1.25.5, Git 2.52.0, Python 3.12.12
