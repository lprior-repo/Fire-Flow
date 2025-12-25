#!/usr/bin/env nu
# Validate - Test data against a DataContract
#
# Contract: contracts/tools/validate.yaml
# Input: JSON from stdin (ValidateInput)
# Output: JSON to stdout (ToolResponse wrapping ValidateOutput)
# Logs: JSON to stderr
#
# The contract must have a servers.local section pointing to the data file.

def main [] {
    let start = date now

    # Read JSON from stdin
    let raw = open --raw /dev/stdin
    let input = $raw | from json

    # Extract context
    let ctx = $input.context? | default {}
    let trace_id = $ctx.trace_id? | default ""
    let dry_run = $ctx.dry_run? | default false

    # Extract validation configuration
    let contract_path = $input.contract_path? | default ""
    let server = $input.server? | default "local"

    # Validate required fields
    if ($contract_path | is-empty) {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "error", msg: "contract_path is required", trace_id: $trace_id } | to json -r | print -e
        { success: false, error: "contract_path is required", trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 1
    }

    if not ($contract_path | path exists) {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "error", msg: $"contract not found: ($contract_path)", trace_id: $trace_id } | to json -r | print -e
        { success: false, error: $"contract not found: ($contract_path)", trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 1
    }

    { level: "info", msg: "validating data", trace_id: $trace_id, contract: $contract_path, server: $server, dry_run: $dry_run } | to json -r | print -e

    if $dry_run {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "info", msg: "dry-run mode - skipping validation" } | to json -r | print -e
        let output = {
            valid: true
            errors: []
            was_dry_run: true
        }
        { success: true, data: $output, trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 0
    }

    # Run datacontract test against the server
    let result = do {
        datacontract test --server $server $contract_path
    } | complete

    let duration_ms = (date now) - $start | into int | $in / 1000000

    let is_valid = $result.exit_code == 0

    { level: "info", msg: "validation complete", valid: $is_valid, duration_ms: $duration_ms } | to json -r | print -e

    # Parse errors from output if validation failed
    let errors = if $is_valid {
        []
    } else {
        $result.stdout | lines | where { |line| ($line | str length) > 0 }
    }

    let output = {
        valid: $is_valid
        errors: $errors
        stdout: $result.stdout
        stderr: $result.stderr
        was_dry_run: false
    }

    if $is_valid {
        { success: true, data: $output, trace_id: $trace_id, duration_ms: $duration_ms } | to json | print
    } else {
        { success: false, data: $output, error: "contract validation failed", trace_id: $trace_id, duration_ms: $duration_ms } | to json | print
        exit 1
    }
}
