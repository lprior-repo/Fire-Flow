#!/bin/bash

################################################################################
# Fire-Flow Startup Script
#
# Initializes all Fire-Flow components when a worktree is spun up
# Ensures Kestra, OpenCode, CLI, and all tools are properly configured
#
# Usage:
#   ./scripts/startup.sh                 # Full startup
#   ./scripts/startup.sh --verify-only   # Just verify tools
#   ./scripts/startup.sh --build-only    # Just build binaries
################################################################################

set -e  # Exit on first error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
STARTUP_LOG="${PROJECT_ROOT}/.opencode/startup.log"
STATE_DIR="${PROJECT_ROOT}/.opencode/tcr"
BIN_DIR="${PROJECT_ROOT}/bin"
KESTRA_PORT=${KESTRA_PORT:-8080}
VIBE_KANBAN_PORT=${VIBE_KANBAN_PORT:-34107}

# Initialize log file
mkdir -p "$(dirname "$STARTUP_LOG")" "$STATE_DIR"
{
    echo "================================"
    echo "Fire-Flow Startup Log"
    echo "Started: $(date)"
    echo "Working Directory: $(pwd)"
    echo "Project Root: $PROJECT_ROOT"
    echo "================================"
} > "$STARTUP_LOG"

################################################################################
# Utility Functions
################################################################################

log_info() {
    echo -e "${BLUE}[*]${NC} $1" | tee -a "$STARTUP_LOG"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$STARTUP_LOG"
}

log_error() {
    echo -e "${RED}[!]${NC} $1" | tee -a "$STARTUP_LOG"
    exit 1
}

log_warn() {
    echo -e "${YELLOW}[⚠]${NC} $1" | tee -a "$STARTUP_LOG"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        return 1
    fi
    return 0
}

check_port() {
    if lsof -Pi :"$1" -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # Port is in use
    fi
    return 1  # Port is free
}

################################################################################
# Phase 1: Verify Tools
################################################################################

verify_tools() {
    log_info "Phase 1: Verifying required tools..."

    local missing_tools=0

    # Core development tools
    if check_command "go"; then
        GO_VERSION=$(go version | awk '{print $3}')
        log_success "Go: $GO_VERSION"
    else
        log_error "Go is not installed. Install from https://golang.org/dl"
    fi

    if check_command "git"; then
        log_success "Git: $(git --version)"
    else
        log_error "Git is not installed"
    fi

    # Beads CLI
    if check_command "bd"; then
        log_success "Beads CLI: Available"
    else
        log_warn "Beads CLI (bd) not found. Install from https://github.com/kevinjqiu/beads"
        missing_tools=$((missing_tools + 1))
    fi

    # GitHub CLI
    if check_command "gh"; then
        log_success "GitHub CLI: $(gh --version | head -1)"
    else
        log_warn "GitHub CLI (gh) not found. Install from https://cli.github.com"
        missing_tools=$((missing_tools + 1))
    fi

    # Python (for scripts)
    if check_command "python3"; then
        PYTHON_VERSION=$(python3 --version)
        log_success "Python: $PYTHON_VERSION"
    else
        log_error "Python3 is not installed"
    fi

    # SQLite (for Vibe Kanban)
    if check_command "sqlite3"; then
        log_success "SQLite: Available"
    else
        log_warn "SQLite3 not found (needed for Vibe Kanban)"
        missing_tools=$((missing_tools + 1))
    fi

    # Optional: Kestra CLI
    if check_command "kestra"; then
        log_success "Kestra CLI: Available"
    else
        log_warn "Kestra CLI not installed (for workflow management)"
        missing_tools=$((missing_tools + 1))
    fi

    # Optional: Claude Code / vibe-kanban
    if check_command "npx"; then
        log_success "Node.js/npm: Available"
    else
        log_warn "Node.js/npm not found (needed for Vibe Kanban)"
        missing_tools=$((missing_tools + 1))
    fi

    if [ $missing_tools -gt 0 ]; then
        log_warn "$missing_tools optional tools missing (see above)"
    fi
}

################################################################################
# Phase 2: Build Binaries
################################################################################

build_binaries() {
    log_info "Phase 2: Building Fire-Flow binaries..."

    cd "$PROJECT_ROOT"

    # Create bin directory
    mkdir -p "$BIN_DIR"

    # Build fire-flow CLI
    if [ -f "cmd/fire-flow/main.go" ]; then
        log_info "Building fire-flow CLI..."
        if go build -o "$BIN_DIR/fire-flow" ./cmd/fire-flow/; then
            log_success "Built: $BIN_DIR/fire-flow"
            chmod +x "$BIN_DIR/fire-flow"
        else
            log_error "Failed to build fire-flow CLI"
        fi
    fi

    # Run tests to ensure build is valid
    log_info "Running unit tests..."
    if go test -v ./... -timeout 30s 2>&1 | tee -a "$STARTUP_LOG"; then
        log_success "All tests passed"
    else
        log_error "Tests failed - build is invalid"
    fi
}

################################################################################
# Phase 3: Initialize State & Configuration
################################################################################

init_state() {
    log_info "Phase 3: Initializing state and configuration..."

    # Create state directory structure
    mkdir -p "$STATE_DIR"/{config,status,results}

    # Initialize configuration file
    CONFIG_FILE="$PROJECT_ROOT/.opencode/config.json"
    if [ ! -f "$CONFIG_FILE" ]; then
        log_info "Creating OpenCode configuration..."
        cat > "$CONFIG_FILE" << 'EOF'
{
  "name": "Fire-Flow TCR Enforcer",
  "version": "1.0.0",
  "description": "Test-Driven Code Review enforcement system",
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
  },
  "features": {
    "tdd-enforcement": true,
    "overlay-fs": true,
    "git-integration": true,
    "opencode-integration": true,
    "kestra-orchestration": true
  }
}
EOF
        log_success "Created OpenCode configuration"
    else
        log_success "OpenCode configuration exists"
    fi

    # Initialize TCR state file
    STATE_FILE="$STATE_DIR/state.json"
    if [ ! -f "$STATE_FILE" ]; then
        log_info "Creating TCR state file..."
        cat > "$STATE_FILE" << 'EOF'
{
  "initialized": true,
  "version": "1.0",
  "created_at": "2025-12-23T00:00:00Z",
  "last_run": null,
  "status": "ready",
  "tdd_enforced": true,
  "test_coverage": 0.0,
  "commits_since_startup": 0,
  "streak": 0
}
EOF
        log_success "Created TCR state file"
    else
        log_success "TCR state file exists"
    fi
}

################################################################################
# Phase 4: Configure Environment
################################################################################

configure_environment() {
    log_info "Phase 4: Configuring environment..."

    # Set required environment variables
    export FIRE_FLOW_ROOT="$PROJECT_ROOT"
    export FIRE_FLOW_BIN="$BIN_DIR/fire-flow"
    export FIRE_FLOW_STATE="$STATE_DIR"
    export KESTRA_PORT="$KESTRA_PORT"
    export VIBE_KANBAN_PORT="$VIBE_KANBAN_PORT"

    log_success "Environment variables set:"
    log_info "  FIRE_FLOW_ROOT: $FIRE_FLOW_ROOT"
    log_info "  FIRE_FLOW_BIN: $FIRE_FLOW_BIN"
    log_info "  FIRE_FLOW_STATE: $FIRE_FLOW_STATE"
    log_info "  KESTRA_PORT: $KESTRA_PORT"
    log_info "  VIBE_KANBAN_PORT: $VIBE_KANBAN_PORT"

    # Create .env file for convenience
    ENV_FILE="$PROJECT_ROOT/.env"
    cat > "$ENV_FILE" << EOF
# Fire-Flow Environment Configuration
# Generated: $(date)

export FIRE_FLOW_ROOT="$PROJECT_ROOT"
export FIRE_FLOW_BIN="$BIN_DIR/fire-flow"
export FIRE_FLOW_STATE="$STATE_DIR"
export KESTRA_PORT="$KESTRA_PORT"
export VIBE_KANBAN_PORT="$VIBE_KANBAN_PORT"
EOF
    log_success "Created .env file at $ENV_FILE"
}

################################################################################
# Phase 5: Verify Services
################################################################################

verify_services() {
    log_info "Phase 5: Verifying service availability..."

    # Check if fire-flow CLI is executable
    if [ -x "$BIN_DIR/fire-flow" ]; then
        log_success "Fire-Flow CLI is executable"

        # Try to run status command
        if "$BIN_DIR/fire-flow" status &>/dev/null; then
            log_success "Fire-Flow status command works"
        else
            log_warn "Fire-Flow status command returned error"
        fi
    else
        log_error "Fire-Flow CLI is not executable"
    fi

    # Check Kestra
    if check_port "$KESTRA_PORT"; then
        log_success "Kestra is running on port $KESTRA_PORT"
    else
        log_warn "Kestra not running on port $KESTRA_PORT (optional)"
    fi

    # Check Vibe Kanban
    if check_port "$VIBE_KANBAN_PORT"; then
        log_success "Vibe Kanban is running on port $VIBE_KANBAN_PORT"
    else
        log_warn "Vibe Kanban not running on port $VIBE_KANBAN_PORT (optional)"
    fi

    # Check git
    if cd "$PROJECT_ROOT" && git status &>/dev/null; then
        log_success "Git repository is valid"

        # Get current branch
        BRANCH=$(git rev-parse --abbrev-ref HEAD)
        log_info "Current branch: $BRANCH"
    else
        log_error "Git repository is not valid"
    fi
}

################################################################################
# Phase 6: Sync with Beads
################################################################################

sync_beads() {
    log_info "Phase 6: Syncing with Beads issue tracker..."

    if ! check_command "bd"; then
        log_warn "Beads CLI not available, skipping sync"
        return
    fi

    cd "$PROJECT_ROOT"

    if bd sync &>>$STARTUP_LOG; then
        log_success "Beads sync completed"
    else
        log_warn "Beads sync had issues (may not affect functionality)"
    fi
}

################################################################################
# Phase 7: Health Check
################################################################################

health_check() {
    log_info "Phase 7: Running health checks..."

    local checks_passed=0
    local checks_total=0

    # Check 1: Go version
    checks_total=$((checks_total + 1))
    if check_command "go"; then
        checks_passed=$((checks_passed + 1))
    fi

    # Check 2: Git repository
    checks_total=$((checks_total + 1))
    if cd "$PROJECT_ROOT" && git status &>/dev/null; then
        checks_passed=$((checks_passed + 1))
    fi

    # Check 3: Binary exists and is executable
    checks_total=$((checks_total + 1))
    if [ -x "$BIN_DIR/fire-flow" ]; then
        checks_passed=$((checks_passed + 1))
    fi

    # Check 4: State directory initialized
    checks_total=$((checks_total + 1))
    if [ -d "$STATE_DIR" ] && [ -f "$STATE_DIR/state.json" ]; then
        checks_passed=$((checks_passed + 1))
    fi

    # Check 5: Python available
    checks_total=$((checks_total + 1))
    if check_command "python3"; then
        checks_passed=$((checks_passed + 1))
    fi

    log_info "Health Check: $checks_passed/$checks_total passed"

    if [ "$checks_passed" -eq "$checks_total" ]; then
        log_success "All health checks passed!"
        return 0
    else
        log_warn "Some health checks failed (see above)"
        return 1
    fi
}

################################################################################
# Phase 8: Status Report
################################################################################

status_report() {
    log_info "Phase 8: Generating status report..."

    echo "" | tee -a "$STARTUP_LOG"
    echo "╔════════════════════════════════════════════════════════╗" | tee -a "$STARTUP_LOG"
    echo "║          Fire-Flow Startup Complete                    ║" | tee -a "$STARTUP_LOG"
    echo "╚════════════════════════════════════════════════════════╝" | tee -a "$STARTUP_LOG"
    echo "" | tee -a "$STARTUP_LOG"
    echo "🚀 Ready to use Fire-Flow!" | tee -a "$STARTUP_LOG"
    echo "" | tee -a "$STARTUP_LOG"
    echo "Quick Reference:" | tee -a "$STARTUP_LOG"
    echo "  Project Root:     $PROJECT_ROOT" | tee -a "$STARTUP_LOG"
    echo "  Fire-Flow Binary: $BIN_DIR/fire-flow" | tee -a "$STARTUP_LOG"
    echo "  State Directory:  $STATE_DIR" | tee -a "$STARTUP_LOG"
    echo "  Startup Log:      $STARTUP_LOG" | tee -a "$STARTUP_LOG"
    echo "" | tee -a "$STARTUP_LOG"
    echo "Available Commands:" | tee -a "$STARTUP_LOG"
    echo "  $BIN_DIR/fire-flow init              # Initialize TCR state" | tee -a "$STARTUP_LOG"
    echo "  $BIN_DIR/fire-flow status            # Show TCR status" | tee -a "$STARTUP_LOG"
    echo "  $BIN_DIR/fire-flow tdd-gate          # Run TDD gate check" | tee -a "$STARTUP_LOG"
    echo "  $BIN_DIR/fire-flow run-tests         # Execute tests" | tee -a "$STARTUP_LOG"
    echo "  $BIN_DIR/fire-flow commit             # Commit changes" | tee -a "$STARTUP_LOG"
    echo "  $BIN_DIR/fire-flow revert             # Revert changes" | tee -a "$STARTUP_LOG"
    echo "" | tee -a "$STARTUP_LOG"
    echo "Integration Tools:" | tee -a "$STARTUP_LOG"
    echo "  Kestra:         http://localhost:$KESTRA_PORT" | tee -a "$STARTUP_LOG"
    echo "  Vibe Kanban:    http://127.0.0.1:$VIBE_KANBAN_PORT" | tee -a "$STARTUP_LOG"
    echo "  Beads:          bd list (git-native tracking)" | tee -a "$STARTUP_LOG"
    echo "" | tee -a "$STARTUP_LOG"
    echo "Source Files:" | tee -a "$STARTUP_LOG"
    echo "  Documentation:  $PROJECT_ROOT/SDLC_VIBE_KANBAN_SETUP.md" | tee -a "$STARTUP_LOG"
    echo "  Config:         $PROJECT_ROOT/.opencode/config.json" | tee -a "$STARTUP_LOG"
    echo "  QWEN Guide:     $PROJECT_ROOT/QWEN.md" | tee -a "$STARTUP_LOG"
    echo "  Next Stages:    $PROJECT_ROOT/NEXT_STAGES_FROM_MEM0.md" | tee -a "$STARTUP_LOG"
    echo "" | tee -a "$STARTUP_LOG"
    echo "For detailed help:" | tee -a "$STARTUP_LOG"
    echo "  $BIN_DIR/fire-flow --help" | tee -a "$STARTUP_LOG"
    echo "" | tee -a "$STARTUP_LOG"
}

################################################################################
# Main Execution
################################################################################

main() {
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Fire-Flow Startup Sequence                           ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Parse arguments
    VERIFY_ONLY=false
    BUILD_ONLY=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --verify-only)
                VERIFY_ONLY=true
                shift
                ;;
            --build-only)
                BUILD_ONLY=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                echo "Usage: $0 [--verify-only] [--build-only]"
                exit 1
                ;;
        esac
    done

    # Execute phases
    verify_tools

    if [ "$VERIFY_ONLY" = true ]; then
        log_success "Tool verification complete"
        exit 0
    fi

    build_binaries

    if [ "$BUILD_ONLY" = true ]; then
        log_success "Build complete"
        exit 0
    fi

    init_state
    configure_environment
    verify_services
    sync_beads
    health_check
    status_report

    log_success "Startup sequence completed successfully!"
    echo ""
    echo "Startup log saved to: $STARTUP_LOG"
    echo ""
}

# Run main function
main "$@"
