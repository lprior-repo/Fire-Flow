#!/usr/bin/env nu
# Tests for run-tool.nu
#
# Run with: nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests'

use std assert

# Helper to create a test tool that echoes input
def create_echo_tool [path: string] {
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    { echo: $input.message } | to json | print
}' | save -f $path
}

# Helper to create a tool that fails
def create_failing_tool [path: string] {
    '#!/usr/bin/env nu
def main [] {
    print -e "Tool error: something went wrong"
    exit 1
}' | save -f $path
}

# Helper to run run-tool.nu with given input
def run_tool_with [input: record] {
    let tools_dir = $env.PWD | path join "bitter-truth/tools"
    $input | to json | nu ($tools_dir | path join "run-tool.nu") | complete
}

#[test]
def test_run_tool_requires_tool_path [] {
    let result = run_tool_with { context: { trace_id: "test" } }

    assert equal $result.exit_code 1
    let output = $result.stdout | from json
    assert equal $output.success false
    assert ($output.error | str contains "tool_path is required")
}

#[test]
def test_run_tool_requires_existing_file [] {
    let result = run_tool_with {
        tool_path: "/nonexistent/tool.nu"
        context: { trace_id: "test" }
    }

    assert equal $result.exit_code 1
    let output = $result.stdout | from json
    assert equal $output.success false
    assert ($output.error | str contains "not found")
}

#[test]
def test_run_tool_executes_tool [] {
    # Use unique file paths to avoid parallel test conflicts
    let test_id = (random uuid | str substring 0..8)
    let tool_path = $"/tmp/test-echo-($test_id).nu"
    let output_path = $"/tmp/test-output-($test_id).json"
    let logs_path = $"/tmp/test-logs-($test_id).json"

    create_echo_tool $tool_path

    let result = run_tool_with {
        tool_path: $tool_path
        tool_input: { message: "hello world" }
        output_path: $output_path
        logs_path: $logs_path
        context: { trace_id: "test-exec" }
    }

    assert equal $result.exit_code 0
    let output = $result.stdout | from json
    assert equal $output.success true
    assert equal $output.data.exit_code 0

    # Check output file was created (open auto-parses .json files)
    let tool_output = open $output_path
    assert equal $tool_output.echo "hello world"

    # Cleanup
    rm -f $tool_path $output_path $logs_path
}

#[test]
def test_run_tool_captures_failure [] {
    let tool_path = "/tmp/test-failing-tool.nu"
    create_failing_tool $tool_path

    let result = run_tool_with {
        tool_path: $tool_path
        tool_input: {}
        output_path: "/tmp/test-output.json"
        logs_path: "/tmp/test-logs.json"
        context: { trace_id: "test-fail" }
    }

    # Should exit 0 (not fail the flow) but report failure
    assert equal $result.exit_code 0
    let output = $result.stdout | from json
    assert equal $output.success false
    assert equal $output.data.exit_code 1
    assert ($output.error | str contains "error")

    # Cleanup
    rm -f $tool_path /tmp/test-output.json /tmp/test-logs.json
}

#[test]
def test_run_tool_dry_run [] {
    # Create a dummy tool for dry-run (it won't be executed)
    let tool_path = "/tmp/test-dry-tool.nu"
    "# dummy" | save -f $tool_path

    let result = run_tool_with {
        tool_path: $tool_path
        tool_input: {}
        context: { trace_id: "test-dry", dry_run: true }
    }

    assert equal $result.exit_code 0
    let output = $result.stdout | from json
    assert equal $output.success true
    assert equal $output.data.was_dry_run true

    # Cleanup
    rm -f $tool_path
}
