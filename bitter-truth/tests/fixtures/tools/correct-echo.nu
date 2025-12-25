#!/usr/bin/env nu
# Perfect implementation of echo tool
# Contract: fixtures/contracts/echo-complete.yaml
# Purpose: Reference implementation for testing validators

def main [] {
    let start = date now

    # Read and parse JSON input
    let raw = open --raw /dev/stdin
    let input = try {
        $raw | from json
    } catch {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "error", msg: "invalid JSON input" } | to json -r | print -e
        { success: false, error: "Invalid JSON input", trace_id: "", duration_ms: $dur } | to json | print
        exit 1
    }

    # Extract context
    let ctx = $input.context? | default {}
    let trace_id = $ctx.trace_id? | default ""
    let dry_run = $ctx.dry_run? | default false

    # Validate required field
    let message = $input.message? | default ""
    if ($message | is-empty) {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "error", msg: "message is required", trace_id: $trace_id } | to json -r | print -e
        { success: false, error: "message is required", trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 1
    }

    # Log processing
    { level: "info", msg: "processing", trace_id: $trace_id, len: ($message | str length), dry_run: $dry_run } | to json -r | print -e

    # Process message - CORRECT implementation
    let output = {
        echo: $message
        reversed: ($message | split chars | reverse | str join)
        length: ($message | str length)
        was_dry_run: $dry_run
    }

    let duration_ms = (date now) - $start | into int | $in / 1000000

    { level: "info", msg: "done", duration_ms: $duration_ms } | to json -r | print -e

    # Return proper ToolResponse
    { success: true, data: $output, trace_id: $trace_id, duration_ms: $duration_ms } | to json | print
}
