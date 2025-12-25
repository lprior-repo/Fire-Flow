#!/usr/bin/env nu
# Test for run-tool.nu
# Run with: nu test-run-tool.nu

def main [] {
    print "=== Testing run-tool.nu ==="

    # Create a simple test tool
    let test_tool_path = "/tmp/test-echo-tool.nu"
    let test_tool_content = '
def main [] {
    let input = open --raw /dev/stdin | from json
    let msg = $input.message? | default "no message"
    {
        success: true,
        data: {
            echo: $msg,
            reversed: ($msg | str reverse),
            length: ($msg | str length),
            was_dry_run: false
        }
    } | to json | print
}
'
    $test_tool_content | save -f $test_tool_path

    # Test 1: Run tool with valid input
    print "\n[Test 1] Run tool with valid input..."
    let run_input = {
        tool_path: $test_tool_path
        tool_input: { message: "Hello" }
        output_path: "/tmp/test-output.json"
        logs_path: "/tmp/test-logs.json"
        context: { trace_id: "test-run-001" }
    }

    let result = $run_input | to json | nu run-tool.nu | complete

    if $result.exit_code != 0 {
        print $"  FAIL: Exit code ($result.exit_code)"
        print $"  stderr: ($result.stderr)"
        print $"  stdout: ($result.stdout)"
        exit 1
    }

    let output = $result.stdout | from json
    if $output.success != true {
        print $"  FAIL: success != true"
        print $"  output: ($output)"
        exit 1
    }

    # Check the output file
    let tool_output = open /tmp/test-output.json
    if $tool_output.data.echo != "Hello" {
        print $"  FAIL: echo != Hello, got ($tool_output.data.echo)"
        exit 1
    }

    if $tool_output.data.reversed != "olleH" {
        print $"  FAIL: reversed != olleH"
        exit 1
    }

    print "  PASS: Tool executed successfully and output is correct"

    # Test 2: Dry run mode
    print "\n[Test 2] Dry run mode..."
    let dry_run_input = {
        tool_path: $test_tool_path
        tool_input: { message: "Test" }
        output_path: "/tmp/test-output.json"
        logs_path: "/tmp/test-logs.json"
        context: { trace_id: "test-run-002", dry_run: true }
    }

    let result2 = $dry_run_input | to json | nu run-tool.nu | complete

    if $result2.exit_code != 0 {
        print $"  FAIL: Exit code ($result2.exit_code)"
        exit 1
    }

    let output2 = $result2.stdout | from json
    if $output2.data.was_dry_run != true {
        print "  FAIL: was_dry_run != true"
        exit 1
    }

    print "  PASS: Dry run mode works"

    # Test 3: Missing tool_path
    print "\n[Test 3] Missing tool_path..."
    let missing_tool = {
        tool_input: { message: "Test" }
        context: { trace_id: "test-run-003" }
    }

    let result3 = $missing_tool | to json | nu run-tool.nu | complete

    if $result3.exit_code == 0 {
        print "  FAIL: Should have failed with missing tool_path"
        exit 1
    }

    print "  PASS: Correctly fails with missing tool_path"

    # Test 4: Non-existent tool
    print "\n[Test 4] Non-existent tool..."
    let bad_tool = {
        tool_path: "/nonexistent/tool.nu"
        tool_input: { message: "Test" }
        context: { trace_id: "test-run-004" }
    }

    let result4 = $bad_tool | to json | nu run-tool.nu | complete

    if $result4.exit_code == 0 {
        print "  FAIL: Should have failed with non-existent tool"
        exit 1
    }

    print "  PASS: Correctly fails with non-existent tool"

    # Clean up
    rm -f $test_tool_path
    rm -f /tmp/test-output.json
    rm -f /tmp/test-logs.json

    print "\n=== All run-tool.nu tests passed! ==="
}
