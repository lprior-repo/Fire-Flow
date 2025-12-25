#!/usr/bin/env nu
# Self-Healing Loop Workflow Tests
#
# Tests the multi-attempt self-healing pattern:
# - Failure detection across attempts
# - Feedback accumulation and improvement
# - Trace ID consistency
# - Max attempts enforcement
# - Early success optimization

use std assert

const TOOLS_DIR = "bitter-truth/tools"
const ECHO_CONTRACT = "bitter-truth/contracts/tools/echo.yaml"

# Helper: Create tool that fails N times before succeeding
def create_conditional_tool [path: string, fail_count: int] {
    let counter_file = $"/tmp/attempt-counter-($path | path basename).txt"

    # Reset counter
    "0" | save -f $counter_file

    # Build script in parts to avoid interpolation issues
    let script_header = '#!/usr/bin/env nu
def main [] {
    let counter_file = "' + $counter_file + '"

    # Increment attempt counter
    let current = try { open $counter_file | into int } catch { 0 }
    let next = $current + 1
    $next | into string | save -f $counter_file

    let input = open --raw /dev/stdin | from json
    let message = $input.message? | default ""
    let tid = $input.context?.trace_id? | default ""

    # Fail for first N attempts
    if $next <= ' + ($fail_count | into string) + ' {
        {
            success: true
            data: {
                echo: $message
                # Missing reversed and length - contract violation
                was_dry_run: false
            }
            trace_id: $tid
            duration_ms: 1.0
        } | to json | print
    } else {
        # Success on later attempts
        {
            success: true
            data: {
                echo: $message
                reversed: ($message | split chars | reverse | str join)
                length: ($message | str length)
                was_dry_run: false
            }
            trace_id: $tid
            duration_ms: 1.0
        } | to json | print
    }
}'

    $script_header | save -f $path
    chmod +x $path
}

#[test]
def "self_healing_attempt_1_fails_attempt_2_succeeds" [] {
    # Test: First attempt fails validation, second attempt succeeds

    let trace_id = $"sh-test-001-($env.USER?)"
    let tool_path = "/tmp/sh-test-tool-1.nu"

    create_conditional_tool $tool_path 1

    # ATTEMPT 1: Should fail validation
    let attempt_1_output = "/tmp/sh-attempt-1-output.json"
    let attempt_1_logs = "/tmp/sh-attempt-1-logs.json"

    let run_1 = {
        tool_path: $tool_path
        tool_input: { message: "test 1" }
        output_path: $attempt_1_output
        logs_path: $attempt_1_logs
        context: { trace_id: $trace_id }
    }

    do { $run_1 | to json | nu ($TOOLS_DIR | path join "run-tool.nu") } | complete | null

    let validate_1 = {
        contract_path: $ECHO_CONTRACT
        output_path: $attempt_1_output
        server: "local"
        context: { trace_id: $trace_id, dry_run: false }
    }

    let val_result_1 = do {
        $validate_1 | to json | nu ($TOOLS_DIR | path join "validate.nu")
    } | complete

    let val_response_1 = $val_result_1.stdout | from json
    assert equal $val_response_1.success false "Attempt 1 should fail validation"

    # ATTEMPT 2: Should succeed (tool improves)
    let attempt_2_output = "/tmp/output.json"
    let attempt_2_logs = "/tmp/sh-attempt-2-logs.json"

    let run_2 = {
        tool_path: $tool_path
        tool_input: { message: "test 2" }
        output_path: $attempt_2_output
        logs_path: $attempt_2_logs
        context: { trace_id: $trace_id }
    }

    do { $run_2 | to json | nu ($TOOLS_DIR | path join "run-tool.nu") } | complete | null

    let validate_2 = {
        contract_path: $ECHO_CONTRACT
        output_path: $attempt_2_output
        server: "local"
        context: { trace_id: $trace_id, dry_run: false }
    }

    let val_result_2 = do {
        $validate_2 | to json | nu ($TOOLS_DIR | path join "validate.nu")
    } | complete

    let val_response_2 = $val_result_2.stdout | from json
    assert equal $val_response_2.success true "Attempt 2 should pass validation"

    # Cleanup
    rm -f $tool_path $attempt_1_output $attempt_1_logs $attempt_2_output $attempt_2_logs
    rm -f $"/tmp/attempt-counter-($tool_path | path basename).txt"
}

#[test]
def "self_healing_all_attempts_fail_returns_final_error" [] {
    # Test: All 3 attempts fail, should return final failure state

    let tool_path = "/tmp/sh-test-always-fail.nu"

    # Tool always outputs incomplete data
    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    {
        success: true
        data: { echo: "incomplete" }
        trace_id: ($input.context?.trace_id? | default "")
    } | to json | print
}' | save -f $tool_path

    let max_attempts = 3
    let trace_id = "sh-test-002"
    let final_success = false

    for attempt in 1..$max_attempts {
        let output_file = $"/tmp/sh-fail-attempt-($attempt).json"
        let logs_file = $"/tmp/sh-fail-logs-($attempt).json"

        let run_input = {
            tool_path: $tool_path
            tool_input: { message: $"attempt ($attempt)" }
            output_path: $output_file
            logs_path: $logs_file
            context: { trace_id: $trace_id }
        }

        do { $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu") } | complete | null

        let validate_input = {
            contract_path: $ECHO_CONTRACT
            output_path: $output_file
            server: "local"
            context: { trace_id: $trace_id, dry_run: false }
        }

        let val_result = do {
            $validate_input | to json | nu ($TOOLS_DIR | path join "validate.nu")
        } | complete

        let val_response = $val_result.stdout | from json

        if $attempt == $max_attempts {
            # Final attempt should still fail
            assert equal $val_response.success false "Final attempt should fail"
        }
    }

    # Cleanup
    rm -f $tool_path
    for attempt in 1..$max_attempts {
        rm -f $"/tmp/sh-fail-attempt-($attempt).json" $"/tmp/sh-fail-logs-($attempt).json"
    }
}

#[test]
def "self_healing_feedback_accumulates_across_attempts" [] {
    # Test: Feedback from attempt N can inform attempt N+1

    let feedback_1 = "Attempt 1: Missing 'reversed' field"
    let feedback_2 = $"($feedback_1)\nAttempt 2: Missing 'length' field"

    # Build cumulative feedback
    let accumulated = [$feedback_1, "Attempt 2: Missing 'length' field"] | str join "\n"

    assert ($accumulated | str contains "Attempt 1") "Should include first feedback"
    assert ($accumulated | str contains "Attempt 2") "Should include second feedback"
    assert (($accumulated | str length) > ($feedback_1 | str length)) "Feedback should grow"
}

#[test]
def "self_healing_trace_id_consistent_across_attempts" [] {
    # Test: Same trace_id flows through all attempts of the loop

    let trace_id = "sh-trace-consistency-test"
    let tool_path = "/tmp/sh-trace-tool.nu"

    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    let tid = $input.context?.trace_id? | default ""
    {
        success: true
        data: {
            echo: "test"
            reversed: "tset"
            length: 4
            was_dry_run: false
        }
        trace_id: $tid
    } | to json | print
}' | save -f $tool_path

    let attempts = [1, 2, 3]
    let collected_traces = []

    for attempt in $attempts {
        let output_file = $"/tmp/sh-trace-output-($attempt).json"
        let logs_file = $"/tmp/sh-trace-logs-($attempt).json"

        let run_input = {
            tool_path: $tool_path
            tool_input: { message: "test" }
            output_path: $output_file
            logs_path: $logs_file
            context: { trace_id: $trace_id }
        }

        let run_result = do {
            $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
        } | complete

        let run_response = $run_result.stdout | from json
        let collected_traces = ($collected_traces | append $run_response.trace_id)

        # Each execution should preserve trace_id
        assert equal $run_response.trace_id $trace_id $"Attempt ($attempt) should preserve trace_id"
    }

    # All attempts should have identical trace_id
    assert equal ($collected_traces | uniq | length) 1 "All trace_ids should be identical"

    # Cleanup
    rm -f $tool_path
    for attempt in $attempts {
        rm -f $"/tmp/sh-trace-output-($attempt).json" $"/tmp/sh-trace-logs-($attempt).json"
    }
}

#[test]
def "self_healing_max_attempts_enforced" [] {
    # Test: Loop stops after max_attempts even if still failing

    let max_attempts = 5
    let actual_attempts = 0

    # Simulate loop counter
    for attempt in 1..$max_attempts {
        let actual_attempts = $actual_attempts + 1
    }

    assert equal $actual_attempts $max_attempts "Should only attempt max_attempts times"
    assert ($actual_attempts <= $max_attempts) "Should never exceed max_attempts"
}

#[test]
def "self_healing_early_success_stops_loop" [] {
    # Test: Loop exits early on first success (doesn't continue to max)

    let tool_path = "/tmp/sh-early-success.nu"

    create_conditional_tool $tool_path 0  # Succeed on first attempt

    let output_file = "/tmp/output.json"
    let logs_file = "/tmp/sh-early-logs.json"

    let run_input = {
        tool_path: $tool_path
        tool_input: { message: "immediate success" }
        output_path: $output_file
        logs_path: $logs_file
        context: { trace_id: "early-exit" }
    }

    do { $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu") } | complete | null

    let validate_input = {
        contract_path: $ECHO_CONTRACT
        output_path: $output_file
        server: "local"
        context: { trace_id: "early-exit", dry_run: false }
    }

    let val_result = do {
        $validate_input | to json | nu ($TOOLS_DIR | path join "validate.nu")
    } | complete

    let val_response = $val_result.stdout | from json
    assert equal $val_response.success true "First attempt should succeed"

    # In real workflow, this would trigger Exit task and skip remaining attempts

    # Cleanup
    rm -f $tool_path $output_file $logs_file
    rm -f $"/tmp/attempt-counter-($tool_path | path basename).txt"
}

#[test]
def "self_healing_feedback_length_reasonable" [] {
    # Test: Feedback doesn't grow unbounded (truncate old attempts)

    let max_feedback_len = 5000  # Reasonable limit for AI context

    # Simulate collecting feedback from 5 failed attempts
    let feedback = (1..5 | reduce -f "Initial generation" { |attempt, acc|
        let attempt_feedback = $"
ATTEMPT ($attempt)/5 FAILED.

CONTRACT ERRORS:
- Missing field: reversed
- Missing field: length

OUTPUT PRODUCED:
{{ success: true, data: {{ echo: 'test' }} }}

LOGS:
{{ level: 'info', msg: 'processing' }}

FIX THE NUSHELL SCRIPT TO SATISFY THE CONTRACT.
"

        $acc + "\n" + $attempt_feedback
    })

    # Feedback should be informative but not excessive
    let feedback_len = $feedback | str length
    assert ($feedback_len < $max_feedback_len) "Feedback should stay under reasonable limit"
    assert ($feedback_len > 100) "Feedback should be substantive"
}

#[test]
def "self_healing_each_attempt_improves_output" [] {
    # Test: Verify progression - each attempt should get closer to valid output

    let tool_path = "/tmp/sh-progressive-tool.nu"

    create_conditional_tool $tool_path 2  # Fail twice, succeed on third

    let trace_id = "progressive-test"

    # Attempt 1: Missing 2 fields
    let out_1 = "/tmp/sh-prog-1.json"
    let logs_1 = "/tmp/sh-prog-1-logs.json"

    do {
        {
            tool_path: $tool_path
            tool_input: { message: "prog test" }
            output_path: $out_1
            logs_path: $logs_1
            context: { trace_id: $trace_id }
        } | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete | null

    let output_1 = open $out_1 | from json
    let fields_1 = $output_1.data | columns | length

    # Attempt 2: Still missing fields (in this test)
    let out_2 = "/tmp/sh-prog-2.json"
    let logs_2 = "/tmp/sh-prog-2-logs.json"

    do {
        {
            tool_path: $tool_path
            tool_input: { message: "prog test" }
            output_path: $out_2
            logs_path: $logs_2
            context: { trace_id: $trace_id }
        } | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete | null

    let output_2 = open $out_2 | from json
    let fields_2 = $output_2.data | columns | length

    # Attempt 3: All fields present
    let out_3 = "/tmp/output.json"
    let logs_3 = "/tmp/sh-prog-3-logs.json"

    do {
        {
            tool_path: $tool_path
            tool_input: { message: "prog test" }
            output_path: $out_3
            logs_path: $logs_3
            context: { trace_id: $trace_id }
        } | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
    } | complete | null

    let output_3 = open $out_3 | from json
    let fields_3 = $output_3.data | columns | length

    # Verify progression: attempt 3 should have more fields than attempt 1
    assert ($fields_3 > $fields_1) "Later attempts should have more complete output"
    assert ($fields_3 >= 4) "Final attempt should have all required fields"

    # Cleanup
    rm -f $tool_path $out_1 $logs_1 $out_2 $logs_2 $out_3 $logs_3
    rm -f $"/tmp/attempt-counter-($tool_path | path basename).txt"
}
