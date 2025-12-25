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

    # Extract validation configuration
    let contract_path = $input.contract_path? | default ""
    let output_path = $input.output_path? | default ""
    let server = $input.server? | default "local"

    # Validate required fields
    if ($contract_path | is-empty) {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "error", msg: "contract_path is required", trace_id: $trace_id } | to json -r | print -e
        { success: false, error: "contract_path is required", trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 1
    }

    # Check dry_run BEFORE checking file existence (dry_run skips all real operations)
    if $dry_run {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "info", msg: "dry-run mode - skipping validation", trace_id: $trace_id } | to json -r | print -e
        let output = {
            valid: true
            errors: []
            was_dry_run: true
        }
        { success: true, data: $output, trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 0
    }

    if not ($contract_path | path exists) {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "error", msg: $"contract not found: ($contract_path)", trace_id: $trace_id } | to json -r | print -e
        { success: false, error: $"contract not found: ($contract_path)", trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 1
    }

    { level: "info", msg: "validating data", trace_id: $trace_id, contract: $contract_path, server: $server, dry_run: $dry_run } | to json -r | print -e

    # Extract the data file path from the contract's servers section
    let contract_content = try {
        open --raw $contract_path | from yaml
    } catch {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "error", msg: "failed to parse contract as YAML", trace_id: $trace_id } | to json -r | print -e
        { success: false, error: "Invalid contract YAML", trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 1
    }

    # Use output_path if provided, otherwise get from contract
    let data_file_path = if ($output_path | is-not-empty) {
        $output_path
    } else {
        try {
            $contract_content | get servers | get $server | get path
        } catch {
            let dur = (date now) - $start | into int | $in / 1000000
            { level: "error", msg: $"contract missing servers.($server).path and no output_path provided", trace_id: $trace_id } | to json -r | print -e
            { success: false, error: $"Contract does not define servers.($server).path", trace_id: $trace_id, duration_ms: $dur } | to json | print
            exit 1
        }
    }

    if not ($data_file_path | path exists) {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "error", msg: "data file does not exist", trace_id: $trace_id, data_file: $data_file_path, server: $server } | to json -r | print -e
        { success: false, error: $"Data file does not exist: ($data_file_path)", trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 1
    }

    { level: "debug", msg: "data file exists", data_file: $data_file_path } | to json -r | print -e

    # Get the expected path from the contract for datacontract CLI
    let contract_expected_path = try {
        $contract_content | get servers | get $server | get path
    } catch {
        ""
    }

    # If output_path differs from contract's path, copy the file temporarily
    let needs_copy = ($output_path | is-not-empty) and ($contract_expected_path | is-not-empty) and ($data_file_path != $contract_expected_path)
    if $needs_copy {
        { level: "debug", msg: "copying output to contract's expected location", from: $data_file_path, to: $contract_expected_path } | to json -r | print -e
        cp $data_file_path $contract_expected_path
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

    # Output Kestra format ONLY when running in Kestra (detected by KESTRA_EXECUTION_ID)
    # Format: ::{"outputs":{"key":"value"}}::
    if ($env.KESTRA_EXECUTION_ID? | default "" | str length) > 0 {
        let kestra_output = { outputs: { valid: $is_valid } } | to json -r
        print $"::($kestra_output)::"
    }

    # For self-healing pattern, ALWAYS exit 0 (so workflow continues)
    # Use success field to indicate validation result
    if $is_valid {
        { success: true, data: $output, trace_id: $trace_id, duration_ms: $duration_ms } | to json | print
    } else {
        { success: false, data: $output, error: "contract validation failed", trace_id: $trace_id, duration_ms: $duration_ms } | to json | print
    }
    exit 0
}
