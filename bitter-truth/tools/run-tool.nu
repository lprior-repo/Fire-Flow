#!/usr/bin/env nu
# Run Tool - Execute a nushell tool with contract pattern
#
# Contract: contracts/tools/run-tool.yaml
# Input: JSON from stdin (RunToolInput)
# Output: JSON to stdout (ToolResponse wrapping RunToolOutput)
# Logs: JSON to stderr

def main [] {
    let start = date now

    # Read JSON from stdin with error handling
    let raw = open --raw /dev/stdin
    let input = try {
        $raw | from json
    } catch {
        # JSON parsing failed - return proper error response
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "error", msg: "invalid JSON input" } | to json -r | print -e
        { success: false, error: "Invalid JSON input", trace_id: "", duration_ms: $dur } | to json | print
        exit 1
    }

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

    # Validate tool_input is serializable to JSON before piping
    let tool_input_json = try {
        $tool_input | to json -r
    } catch {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "error", msg: "tool_input is not serializable to JSON", trace_id: $trace_id, tool_input: $tool_input } | to json -r | print -e
        { success: false, error: "tool_input is not valid JSON-serializable data", trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 1
    }

    # Validate the JSON is parseable (roundtrip test)
    let validation_check = try {
        $tool_input_json | from json
        true
    } catch {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "error", msg: "serialized tool_input is not valid JSON", trace_id: $trace_id, json_preview: ($tool_input_json | str substring 0..200) } | to json -r | print -e
        { success: false, error: "tool_input serialization produced invalid JSON", trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 1
    }

    { level: "debug", msg: "tool_input validated successfully", json_length: ($tool_input_json | str length) } | to json -r | print -e

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
        exit 0
    } else {
        # Capture tool's stderr as the error message for debugging
        let tool_error = if ($result.stderr | str length) > 0 { $result.stderr } else { "tool exited with non-zero code" }
        { level: "warn", msg: "tool failed", exit_code: $result.exit_code, error: $tool_error } | to json -r | print -e
        { success: false, data: $output, error: $tool_error, trace_id: $trace_id, duration_ms: $duration_ms } | to json | print
        exit 1
    }
}
