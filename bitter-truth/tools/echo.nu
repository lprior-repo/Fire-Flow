#!/usr/bin/env nu
# Echo tool - bitter-truth proof of concept
#
# Contract: contracts/tools/echo.yaml
# Input: JSON from stdin (EchoInput)
# Output: JSON to stdout (EchoOutput wrapped in ToolResponse)
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

    # Log start
    let log_start = {
        level: "info"
        msg: "processing echo"
        trace_id: $trace_id
        message_len: ($input.message | str length)
        dry_run: $dry_run
        ts: (date now | format date "%s")
    }
    $log_start | to json -r | print -e

    # Validate input
    if ($input.message? | is-empty) {
        let dur = (date now) - $start | into int | $in / 1000000
        {
            success: false
            error: "message is required"
            trace_id: $trace_id
            duration_ms: $dur
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
    let duration_ms = (date now) - $start | into int | $in / 1000000

    # Log completion
    let log_end = {
        level: "info"
        msg: "tool completed"
        trace_id: $trace_id
        duration_ms: $duration_ms
        ts: (date now | format date "%s")
    }
    $log_end | to json -r | print -e

    # Return wrapped response
    {
        success: true
        data: $output
        trace_id: $trace_id
        duration_ms: $duration_ms
    } | to json
}
