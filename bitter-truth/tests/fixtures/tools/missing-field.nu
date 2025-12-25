#!/usr/bin/env nu
# CONTRACT VIOLATION: Missing required output field
# Bug: Does not include 'length' field in output
# Purpose: Test contract validation catches missing required fields

def main [] {
    let start = date now

    let raw = open --raw /dev/stdin
    let input = try {
        $raw | from json
    } catch {
        let dur = (date now) - $start | into int | $in / 1000000
        { success: false, error: "Invalid JSON input", trace_id: "", duration_ms: $dur } | to json | print
        exit 1
    }

    let ctx = $input.context? | default {}
    let trace_id = $ctx.trace_id? | default ""
    let dry_run = $ctx.dry_run? | default false

    let message = $input.message? | default ""
    if ($message | is-empty) {
        let dur = (date now) - $start | into int | $in / 1000000
        { success: false, error: "message is required", trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 1
    }

    # CONTRACT VIOLATION: Missing 'length' field required by EchoOutput
    let output = {
        echo: $message
        reversed: ($message | split chars | reverse | str join)
        # length: ($message | str length)  # MISSING!
        was_dry_run: $dry_run
    }

    let duration_ms = (date now) - $start | into int | $in / 1000000

    { success: true, data: $output, trace_id: $trace_id, duration_ms: $duration_ms } | to json | print
}
