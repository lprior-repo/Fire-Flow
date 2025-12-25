#!/usr/bin/env nu
# Run Tool - Execute a nushell tool with contract pattern
#
# Contract: contracts/tools/run-tool.yaml
# Input: JSON from stdin (RunToolInput)
# Output: JSON to stdout (ToolResponse wrapping RunToolOutput)
# Logs: JSON to stderr

def main [] {
    let start = date now

    # Read JSON from stdin
    let raw = open --raw /dev/stdin
    let input = $raw | from json

    # Extract context
    let ctx = $input.context? | default {}
    let trace_id = $ctx.trace_id? | default ""
    let dry_run = $ctx.dry_run? | default false

    # Extract tool configuration
    let tool_path = $input.tool_path? | default ""
    let tool_input = $input.tool_input? | default {}
    let output_path = $input.output_path? | default "/tmp/output.json"
    let logs_path = $input.logs_path? | default "/tmp/logs.json"

    # Validate required fields
    if ($tool_path | is-empty) {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "error", msg: "tool_path is required", trace_id: $trace_id } | to json -r | print -e
        { success: false, error: "tool_path is required", trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 1
    }

    if not ($tool_path | path exists) {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "error", msg: $"tool not found: ($tool_path)", trace_id: $trace_id } | to json -r | print -e
        { success: false, error: $"tool not found: ($tool_path)", trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 1
    }

    { level: "info", msg: "running tool", trace_id: $trace_id, tool: $tool_path, dry_run: $dry_run } | to json -r | print -e

    if $dry_run {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "info", msg: "dry-run mode - skipping execution" } | to json -r | print -e
        let output = {
            exit_code: 0
            output_path: $output_path
            logs_path: $logs_path
            was_dry_run: true
        }
        { success: true, data: $output, trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 0
    }

    # Run the tool, capturing stdout and stderr separately
    let tool_input_json = $tool_input | to json -r

    # Execute and capture result
    let result = do {
        $tool_input_json | nu $tool_path
    } | complete

    # Save outputs
    $result.stdout | save -f $output_path
    $result.stderr | save -f $logs_path

    let duration_ms = (date now) - $start | into int | $in / 1000000

    { level: "info", msg: "tool complete", exit_code: $result.exit_code, duration_ms: $duration_ms } | to json -r | print -e

    let output = {
        exit_code: $result.exit_code
        output_path: $output_path
        logs_path: $logs_path
        was_dry_run: false
    }

    if $result.exit_code == 0 {
        { success: true, data: $output, trace_id: $trace_id, duration_ms: $duration_ms } | to json | print
    } else {
        { success: false, data: $output, error: "tool exited with non-zero code", trace_id: $trace_id, duration_ms: $duration_ms } | to json | print
        exit 1
    }
}
