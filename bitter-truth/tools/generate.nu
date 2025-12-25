#!/usr/bin/env nu
# Generate - AI generates Nushell tool from contract
#
# Contract: contracts/tools/generate.yaml
# Input: JSON from stdin (GenerateInput)
# Output: JSON to stdout (ToolResponse wrapping GenerateOutput)
# Logs: JSON to stderr
#
# CRITICAL: This tool handles process cleanup to prevent orphaned AI processes
# when Kestra kills the parent task.

def main [] {
    let start = date now

    # Read JSON from stdin
    let raw = open --raw /dev/stdin
    let input = $raw | from json

    # Extract context
    let ctx = $input.context? | default {}
    let trace_id = $ctx.trace_id? | default ""
    let dry_run = $ctx.dry_run? | default false
    let timeout_seconds = $ctx.timeout_seconds? | default 600

    # Extract generation parameters
    let contract_path = $input.contract_path? | default ""
    let task = $input.task? | default ""
    let feedback = $input.feedback? | default "Initial generation"
    let attempt = $input.attempt? | default "1/5"
    let output_path = $input.output_path? | default "/tmp/tool.nu"

    # Validate required fields
    if ($contract_path | is-empty) {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "error", msg: "contract_path is required", trace_id: $trace_id } | to json -r | print -e
        { success: false, error: "contract_path is required", trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 1
    }

    if ($task | is-empty) {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "error", msg: "task is required", trace_id: $trace_id } | to json -r | print -e
        { success: false, error: "task is required", trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 1
    }

    if not ($contract_path | path exists) {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "error", msg: $"contract not found: ($contract_path)", trace_id: $trace_id } | to json -r | print -e
        { success: false, error: $"contract not found: ($contract_path)", trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 1
    }

    { level: "info", msg: "generating tool", trace_id: $trace_id, contract: $contract_path, task: $task, attempt: $attempt, dry_run: $dry_run } | to json -r | print -e

    if $dry_run {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "info", msg: "dry-run mode - skipping generation" } | to json -r | print -e

        # Write a stub tool for dry-run
        "# Dry-run stub\ndef main [] { print 'dry-run' }" | save -f $output_path

        let output = {
            generated: true
            output_path: $output_path
            was_dry_run: true
        }
        { success: true, data: $output, trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 0
    }

    # Build the prompt
    let contract_content = open $contract_path | to yaml
    let prompt = [
        $"TASK: ($task)"
        ""
        "CONTRACT - this is the schema to match:"
        $contract_content
        ""
        $"PREVIOUS FEEDBACK: ($feedback)"
        ""
        $"ATTEMPT: ($attempt)"
        ""
        "Generate a Nushell script that:"
        "1. Reads JSON from stdin"
        "2. Produces output matching the contract EXACTLY"
        "3. Logs to stderr as JSON"
        "4. Returns exit 0 on success, exit 1 on failure"
        ""
        "Output ONLY the Nushell script, no explanation."
    ] | str join "\n"

    { level: "info", msg: "calling opencode", prompt_length: ($prompt | str length) } | to json -r | print -e

    # Save prompt to temp file to avoid pipe (pipes cause orphaned processes)
    let prompt_file = $"/tmp/prompt-($trace_id)-($attempt | str replace '/' '-').txt"
    $prompt | save -f $prompt_file

    # Run opencode with timeout
    # --foreground: don't create new process group, signals propagate properly
    # --kill-after=5: send SIGKILL 5s after SIGTERM if still running
    let result = do {
        timeout --foreground --kill-after=5 $"($timeout_seconds)s" opencode -p (open --raw $prompt_file)
    } | complete

    # Cleanup prompt file
    rm -f $prompt_file

    let duration_ms = (date now) - $start | into int | $in / 1000000

    if $result.exit_code == 124 {
        # Timeout
        { level: "error", msg: "opencode timed out", timeout_seconds: $timeout_seconds } | to json -r | print -e
        { success: false, error: "AI generation timed out", trace_id: $trace_id, duration_ms: $duration_ms } | to json | print
        exit 1
    }

    if $result.exit_code != 0 {
        { level: "error", msg: "opencode failed", exit_code: $result.exit_code, stderr: $result.stderr } | to json -r | print -e
        { success: false, error: $"opencode failed with exit ($result.exit_code)", trace_id: $trace_id, duration_ms: $duration_ms } | to json | print
        exit 1
    }

    # Save the generated script
    $result.stdout | save -f $output_path

    { level: "info", msg: "generation complete", output_path: $output_path, duration_ms: $duration_ms } | to json -r | print -e

    let output = {
        generated: true
        output_path: $output_path
        was_dry_run: false
    }

    { success: true, data: $output, trace_id: $trace_id, duration_ms: $duration_ms } | to json | print
}
