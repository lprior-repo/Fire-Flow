#!/usr/bin/env nu
# Windmill Validation Tool
#
# Validates Windmill scripts, flows, and workspace configuration using wmill CLI.
# Integrates with Fire-Flow's bitter-truth validation pipeline.
#
# Usage:
#   nu tools/wmill-validate.nu                    # Validate all
#   nu tools/wmill-validate.nu --scripts-only     # Validate scripts only
#   nu tools/wmill-validate.nu --flows-only       # Validate flows only
#   nu tools/wmill-validate.nu --check            # Check without pushing
#   nu tools/wmill-validate.nu --ci               # CI mode (non-interactive)

def main [
    --scripts-only (-s)   # Only validate scripts (generate-metadata)
    --flows-only (-f)     # Only validate flows (generate-locks)
    --check (-c)          # Check mode - validate without pushing
    --ci                  # CI mode - non-interactive, fail fast
    --workspace (-w): string  # Target workspace
    --base-url (-u): string   # Windmill base URL
    --verbose (-v)        # Verbose output
] {
    let start = date now
    let windmill_dir = "windmill"
    
    # Check if windmill directory exists
    if not ($windmill_dir | path exists) {
        print -e $"(ansi red)Error: windmill/ directory not found(ansi reset)"
        print -e "Run from Fire-Flow root directory"
        exit 1
    }

    # Check if wmill CLI is installed
    let wmill_path = which wmill | get -o 0.path
    if ($wmill_path | is-empty) {
        print -e $"(ansi red)Error: wmill CLI not installed(ansi reset)"
        print -e "Install with: npm install -g windmill-cli"
        exit 1
    }

    print $"(ansi blue)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━(ansi reset)"
    print $"(ansi blue)  Windmill Validation Tool(ansi reset)"
    print $"(ansi blue)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━(ansi reset)"
    print ""

    # Initialize result tracking
    mut scripts_passed = 0
    mut scripts_failed = 0
    mut scripts_errors = []
    
    mut flows_passed = 0
    mut flows_failed = 0
    mut flows_errors = []
    
    mut sync_passed = 0
    mut sync_failed = 0
    mut sync_errors = []

    # === STEP 1: Validate Scripts (generate-metadata) ===
    if not $flows_only {
        print $"(ansi cyan)▶ Validating scripts via generate-metadata...(ansi reset)"
        
        # Use --yes flag in CI mode to auto-confirm
        let script_result = if $ci {
            do { ^wmill script generate-metadata } | complete
        } else {
            do { ^wmill script generate-metadata } | complete
        }

        if $script_result.exit_code == 0 {
            print $"  (ansi green)✓ Script metadata validation passed(ansi reset)"
            $scripts_passed = 1
        } else {
            print $"  (ansi red)✗ Script metadata validation failed(ansi reset)"
            if $verbose {
                print $"    stdout: ($script_result.stdout)"
                print $"    stderr: ($script_result.stderr)"
            }
            $scripts_failed = 1
            $scripts_errors = ($scripts_errors | append $script_result.stderr)
        }
        print ""
    }

    # === STEP 2: Validate Flows (generate-locks) ===
    if not $scripts_only {
        print $"(ansi cyan)▶ Validating flows via generate-locks...(ansi reset)"
        
        let flow_result = if $ci {
            do { ^wmill flow generate-locks } | complete
        } else {
            do { ^wmill flow generate-locks } | complete
        }

        if $flow_result.exit_code == 0 {
            print $"  (ansi green)✓ Flow lockfile validation passed(ansi reset)"
            $flows_passed = 1
        } else {
            print $"  (ansi red)✗ Flow lockfile validation failed(ansi reset)"
            if $verbose {
                print $"    stdout: ($flow_result.stdout)"
                print $"    stderr: ($flow_result.stderr)"
            }
            $flows_failed = 1
            $flows_errors = ($flows_errors | append $flow_result.stderr)
        }
        print ""
    }

    # === STEP 3: Sync Validation (push --show-diffs) ===
    if not $check {
        print $"(ansi cyan)▶ Validating sync (push --show-diffs)...(ansi reset)"
        
        # Build args as immutable
        let base_args = ["sync", "push", "--show-diffs"]
        let with_yes = if $ci { ($base_args | append "--yes") } else { $base_args }
        let with_workspace = if ($workspace | is-not-empty) { 
            ($with_yes | append ["--workspace", $workspace])
        } else { 
            $with_yes 
        }
        let final_args = if ($base_url | is-not-empty) { 
            ($with_workspace | append ["--base-url", $base_url])
        } else { 
            $with_workspace 
        }

        let sync_result = do {
            ^wmill ...$final_args
        } | complete

        if $sync_result.exit_code == 0 {
            print $"  (ansi green)✓ Sync validation passed(ansi reset)"
            $sync_passed = 1
        } else {
            print $"  (ansi red)✗ Sync validation failed(ansi reset)"
            if $verbose {
                print $"    stdout: ($sync_result.stdout)"
                print $"    stderr: ($sync_result.stderr)"
            }
            $sync_failed = 1
            $sync_errors = ($sync_errors | append $sync_result.stderr)
        }
        print ""
    } else {
        print $"(ansi cyan)▶ Sync validation...(ansi reset)"
        print $"  (ansi yellow)⚠ Check mode - skipping actual push(ansi reset)"
        $sync_passed = 1
        print ""
    }

    # === STEP 4: Check for uncommitted changes ===
    print $"(ansi cyan)▶ Checking for uncommitted changes...(ansi reset)"
    let git_status = do { ^git status --porcelain windmill/ } | complete
    let has_changes = ($git_status.stdout | str trim | str length) > 0

    if $has_changes {
        print $"  (ansi yellow)⚠ Uncommitted changes in windmill/(ansi reset)"
        if $verbose {
            print $"    ($git_status.stdout)"
        }
    } else {
        print $"  (ansi green)✓ No uncommitted changes(ansi reset)"
    }
    print ""

    # === SUMMARY ===
    let duration_ms = (date now) - $start | into int | $in / 1000000
    let total_passed = $scripts_passed + $flows_passed + $sync_passed
    let total_failed = $scripts_failed + $flows_failed + $sync_failed
    let all_passed = $total_failed == 0

    print $"(ansi blue)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━(ansi reset)"
    print $"(ansi blue)  Summary(ansi reset)"
    print $"(ansi blue)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━(ansi reset)"
    print ""
    
    if $all_passed {
        print $"  (ansi green)✓ All validations passed(ansi reset)"
    } else {
        print $"  (ansi red)✗ Some validations failed(ansi reset)"
    }
    
    print $"  Passed: ($total_passed)"
    print $"  Failed: ($total_failed)"
    print $"  Duration: ($duration_ms)ms"
    print ""

    # Output JSON for integration with other tools
    let output = {
        success: $all_passed
        results: {
            scripts: { passed: $scripts_passed, failed: $scripts_failed, errors: $scripts_errors }
            flows: { passed: $flows_passed, failed: $flows_failed, errors: $flows_errors }
            sync: { passed: $sync_passed, failed: $sync_failed, errors: $sync_errors }
        }
        duration_ms: $duration_ms
        has_uncommitted_changes: $has_changes
    }

    if $ci {
        # In CI mode, output JSON to stdout for machine parsing
        $output | to json | print
    }

    if not $all_passed {
        exit 1
    }
}

# Validate a single script
def "main script" [
    path: string  # Path to script file (e.g., f/fire-flow/validate/script.rs)
    --verbose (-v)
] {
    print $"(ansi cyan)▶ Validating script: ($path)(ansi reset)"
    
    let result = do {
        ^wmill script generate-metadata $path
    } | complete

    if $result.exit_code == 0 {
        print $"  (ansi green)✓ Script validation passed(ansi reset)"
    } else {
        print $"  (ansi red)✗ Script validation failed(ansi reset)"
        if $verbose {
            print $"    stderr: ($result.stderr)"
        }
        exit 1
    }
}

# Run a script with test data
def "main run" [
    path: string     # Remote path of script (e.g., f/fire-flow/validate)
    --data (-d): string  # JSON data or @filename
    --silent (-s)        # Only output result
] {
    print $"(ansi cyan)▶ Running script: ($path)(ansi reset)"
    
    let base_args = ["script", "run", $path]
    let with_data = if ($data | is-not-empty) { ($base_args | append ["-d", $data]) } else { $base_args }
    let final_args = if $silent { ($with_data | append "--silent") } else { $with_data }

    let result = do {
        ^wmill ...$final_args
    } | complete

    if not $silent {
        print $result.stdout
    }

    if $result.exit_code != 0 {
        print -e $"(ansi red)Script execution failed(ansi reset)"
        print -e $result.stderr
        exit 1
    }

    $result.stdout
}

# Run a flow with test data
def "main flow" [
    path: string     # Remote path of flow (e.g., f/fire-flow/contract_loop)
    --data (-d): string  # JSON data or @filename
    --silent (-s)        # Only output result
] {
    print $"(ansi cyan)▶ Running flow: ($path)(ansi reset)"
    
    let base_args = ["flow", "run", $path]
    let with_data = if ($data | is-not-empty) { ($base_args | append ["-d", $data]) } else { $base_args }
    let final_args = if $silent { ($with_data | append "--silent") } else { $with_data }

    let result = do {
        ^wmill ...$final_args
    } | complete

    if not $silent {
        print $result.stdout
    }

    if $result.exit_code != 0 {
        print -e $"(ansi red)Flow execution failed(ansi reset)"
        print -e $result.stderr
        exit 1
    }

    $result.stdout
}

# Show workspace info
def "main info" [] {
    print $"(ansi cyan)▶ Windmill Workspace Info(ansi reset)"
    print ""
    
    let whoami = do { ^wmill workspace whoami } | complete
    if $whoami.exit_code == 0 {
        print $"  ($whoami.stdout)"
    } else {
        print $"  (ansi yellow)Not logged in or no workspace selected(ansi reset)"
    }
    print ""

    print $"(ansi cyan)▶ Available Workspaces(ansi reset)"
    let workspaces = do { ^wmill workspace } | complete
    print $"  ($workspaces.stdout)"
}

# List all scripts in workspace
def "main list-scripts" [] {
    ^wmill script
}

# List all flows in workspace
def "main list-flows" [] {
    ^wmill flow
}
