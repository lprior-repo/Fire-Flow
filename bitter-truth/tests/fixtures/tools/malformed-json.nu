#!/usr/bin/env nu
# MALFORMED OUTPUT: Outputs invalid JSON
# Bug: Prints raw text instead of valid JSON
# Purpose: Test that validators catch JSON parsing errors

def main [] {
    let start = date now

    let raw = open --raw /dev/stdin
    let input = try {
        $raw | from json
    } catch {
        # At least handle input parsing correctly
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

    # BUG: Print invalid JSON instead of proper JSON output
    print "This is not JSON at all!"
    print $"Message was: ($message)"
    print "Expected JSON but got plain text"
}
