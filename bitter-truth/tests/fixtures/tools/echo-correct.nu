#!/usr/bin/env nu
# Correct echo tool implementation - for testing
def main [] {
    let input = open --raw /dev/stdin | from json
    let ctx = $input.context? | default {}
    let trace_id = $ctx.trace_id? | default ""
    let message = $input.message

    let output = {
        echo: $message
        reversed: ($message | split chars | reverse | str join)
        length: ($message | str length)
        was_dry_run: false
    }

    {
        success: true
        data: $output
        trace_id: $trace_id
        duration_ms: 1
    } | to json | print
}
