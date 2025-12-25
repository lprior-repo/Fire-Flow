#!/usr/bin/env nu
# Echo tool - bitter-truth proof of concept
#
# Contract: contracts/tools/echo.yaml
# Input: JSON from stdin (EchoInput)
# Output: JSON to stdout (EchoOutput wrapped in ToolResponse)
# Logs: JSON to stderr

# Read input from stdin
def main [] {
    let start = date now

    # Read and parse JSON input
    let input = $in | from json

    # Extract context
    let ctx = $input.context? | default {}
    let trace_id = $ctx.trace_id? | default ""
    let dry_run = $ctx.dry_run? | default false

    # Log start
    {
        level: "info"
        msg: "processing echo"
        trace_id: $trace_id
        message_len: ($input.message | str length)
        dry_run: $dry_run
        ts: (date now | format date "%s")
    } | to json -r | print -e

    # Validate input
    if ($input.message? | is-empty) {
        {
            success: false
            error: "message is required"
            trace_id: $trace_id
            duration_ms: ((date now) - $start | into int) / 1_000_000
        } | to json
        return
    }

    if $dry_run {
        { level: "info", msg: "dry-run mode", ts: (date now | format date "%s") } | to json -r | print -e
    }

    # Process
    let message = $input.message
    let output = {
        echo: $message
        reversed: ($message | split chars | reverse | str join)
        length: ($message | str length)
        was_dry_run: $dry_run
    }

    # Calculate duration
    let duration_ms = ((date now) - $start | into int) / 1_000_000

    # Log completion
    {
        level: "info"
        msg: "tool completed"
        trace_id: $trace_id
        duration_ms: $duration_ms
        ts: (date now | format date "%s")
    } | to json -r | print -e

    # Return wrapped response
    {
        success: true
        data: $output
        trace_id: $trace_id
        duration_ms: $duration_ms
    } | to json
}
