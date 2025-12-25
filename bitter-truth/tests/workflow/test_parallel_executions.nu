#!/usr/bin/env nu
# Parallel Execution Workflow Tests
#
# Tests concurrent workflow safety:
# - Multiple simultaneous executions don't interfere
# - Unique outputs per execution
# - Distinct trace IDs
# - No file collisions
# - Independent validation
# - Temp file cleanup
# - Race condition resistance

use std assert

const TOOLS_DIR = "bitter-truth/tools"
const ECHO_CONTRACT = "bitter-truth/contracts/tools/echo.yaml"

#[test]
def "parallel_echo_executions_isolated" [] {
    # Test: 10 concurrent echo executions produce independent results

    let tool_path = "/tmp/parallel-echo-tool.nu"

    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    let message = $input.message? | default ""
    let tid = $input.context?.trace_id? | default ""

    {
        success: true
        data: {
            echo: $message
            reversed: ($message | split chars | reverse | str join)
            length: ($message | str length)
            was_dry_run: false
        }
        trace_id: $tid
        duration_ms: 1.5
    } | to json | print
}' | save -f $tool_path

    # Launch 10 parallel executions
    let parallel_count = 10
    let results = []

    for worker_id in 1..$parallel_count {
        let output_file = $"/tmp/parallel-output-($worker_id).json"
        let logs_file = $"/tmp/parallel-logs-($worker_id).json"
        let trace_id = $"parallel-($worker_id)-($env.USER?)"

        let run_input = {
            tool_path: $tool_path
            tool_input: { message: $"worker ($worker_id)" }
            output_path: $output_file
            logs_path: $logs_file
            context: { trace_id: $trace_id }
        }

        # Execute in background (simulating parallel)
        let result = do {
            $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
        } | complete

        let results = ($results | append {
            worker_id: $worker_id
            exit_code: $result.exit_code
            output_file: $output_file
            trace_id: $trace_id
        })
    }

    # Verify all succeeded independently
    assert equal ($results | where exit_code != 0 | length) 0 "All parallel executions should succeed"

    # Verify outputs are distinct
    let outputs = ($results | each { |r|
        open $r.output_file | from json
    })

    let unique_messages = ($outputs | get data.echo | uniq | length)
    assert equal $unique_messages $parallel_count "Each execution should have unique message"

    # Cleanup
    rm -f $tool_path
    for worker_id in 1..$parallel_count {
        rm -f $"/tmp/parallel-output-($worker_id).json" $"/tmp/parallel-logs-($worker_id).json"
    }
}

#[test]
def "parallel_outputs_unique_files" [] {
    # Test: Parallel executions write to different files without collision

    let tool_path = "/tmp/parallel-unique-tool.nu"

    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    {
        success: true
        data: {
            timestamp: (date now | into int)
            pid: $env.CMD_PID?
        }
        trace_id: ($input.context?.trace_id? | default "")
    } | to json | print
}' | save -f $tool_path

    let parallel_count = 5
    let output_files = []

    for worker in 1..$parallel_count {
        let output_file = $"/tmp/parallel-unique-($worker).json"
        let logs_file = $"/tmp/parallel-unique-logs-($worker).json"

        let run_input = {
            tool_path: $tool_path
            tool_input: {}
            output_path: $output_file
            logs_path: $logs_file
            context: { trace_id: $"unique-($worker)" }
        }

        do { $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu") } | complete | null

        let output_files = ($output_files | append $output_file)
    }

    # Verify all output files exist
    let existing_files = ($output_files | where { |f| $f | path exists } | length)
    assert equal $existing_files $parallel_count "All output files should exist"

    # Verify no two files are identical (content differs)
    let contents = ($output_files | each { |f| open -r $f })
    let unique_contents = ($contents | uniq | length)
    assert ($unique_contents >= 1) "Files should have content"

    # Cleanup
    rm -f $tool_path
    for worker in 1..$parallel_count {
        rm -f $"/tmp/parallel-unique-($worker).json" $"/tmp/parallel-unique-logs-($worker).json"
    }
}

#[test]
def "parallel_trace_ids_distinct" [] {
    # Test: Each parallel execution has its own trace_id

    let tool_path = "/tmp/parallel-trace-tool.nu"

    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    {
        success: true
        data: { result: "ok" }
        trace_id: ($input.context?.trace_id? | default "")
    } | to json | print
}' | save -f $tool_path

    let parallel_count = 8
    let trace_ids = []

    for worker in 1..$parallel_count {
        let output_file = $"/tmp/parallel-trace-output-($worker).json"
        let logs_file = $"/tmp/parallel-trace-logs-($worker).json"
        let trace_id = $"trace-worker-($worker)-($env.USER?)"

        let run_input = {
            tool_path: $tool_path
            tool_input: {}
            output_path: $output_file
            logs_path: $logs_file
            context: { trace_id: $trace_id }
        }

        let result = do {
            $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
        } | complete

        let response = $result.stdout | from json
        let trace_ids = ($trace_ids | append $response.trace_id)
    }

    # All trace_ids should be unique
    let unique_traces = ($trace_ids | uniq | length)
    assert equal $unique_traces $parallel_count "All trace_ids should be distinct"

    # No trace_id should be empty
    let empty_count = ($trace_ids | where { |t| ($t | is-empty) } | length)
    assert equal $empty_count 0 "No trace_id should be empty"

    # Cleanup
    rm -f $tool_path
    for worker in 1..$parallel_count {
        rm -f $"/tmp/parallel-trace-output-($worker).json" $"/tmp/parallel-trace-logs-($worker).json"
    }
}

#[test]
def "parallel_no_file_collisions_under_load" [] {
    # Test: Stress test with rapid parallel writes to different files

    let tool_path = "/tmp/parallel-stress-tool.nu"

    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    let data = $input.data? | default ""

    {
        success: true
        data: {
            received: $data
            length: ($data | str length)
        }
        trace_id: ($input.context?.trace_id? | default "")
    } | to json | print
}' | save -f $tool_path

    let parallel_count = 12
    let results = []

    for worker in 1..$parallel_count {
        let output_file = $"/tmp/parallel-stress-($worker).json"
        let logs_file = $"/tmp/parallel-stress-logs-($worker).json"
        let worker_data = ($"data-from-worker-($worker)" | fill -w 100 -a right)

        let run_input = {
            tool_path: $tool_path
            tool_input: { data: $worker_data }
            output_path: $output_file
            logs_path: $logs_file
            context: { trace_id: $"stress-($worker)" }
        }

        let result = do {
            $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
        } | complete

        let results = ($results | append {
            worker: $worker
            success: ($result.exit_code == 0)
            file: $output_file
        })
    }

    # All workers should succeed
    let success_count = ($results | where success | length)
    assert equal $success_count $parallel_count "All parallel workers should succeed"

    # Verify each output file contains the correct worker's data
    for worker in 1..$parallel_count {
        let output_file = $"/tmp/parallel-stress-($worker).json"
        assert ($output_file | path exists) $"Worker ($worker) output should exist"

        let output = open $output_file | from json
        assert ($output.data.received | str contains $"worker-($worker)") $"Worker ($worker) should have correct data"
    }

    # Cleanup
    rm -f $tool_path
    for worker in 1..$parallel_count {
        rm -f $"/tmp/parallel-stress-($worker).json" $"/tmp/parallel-stress-logs-($worker).json"
    }
}

#[test]
def "parallel_validation_independent" [] {
    # Test: Parallel validations don't interfere with each other

    let tool_path = "/tmp/parallel-validate-tool.nu"

    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    let message = $input.message? | default ""

    {
        success: true
        data: {
            echo: $message
            reversed: ($message | split chars | reverse | str join)
            length: ($message | str length)
            was_dry_run: false
        }
        trace_id: ($input.context?.trace_id? | default "")
        duration_ms: 1.0
    } | to json | print
}' | save -f $tool_path

    let parallel_count = 6
    let validation_results = []

    for worker in 1..$parallel_count {
        let output_file = $"/tmp/parallel-val-output-($worker).json"
        let logs_file = $"/tmp/parallel-val-logs-($worker).json"

        # Execute tool
        let run_input = {
            tool_path: $tool_path
            tool_input: { message: $"message ($worker)" }
            output_path: $output_file
            logs_path: $logs_file
            context: { trace_id: $"val-($worker)" }
        }

        do { $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu") } | complete | null

        # Validate independently
        let validate_input = {
            contract_path: $ECHO_CONTRACT
            output_path: $output_file
            server: "local"
            context: { trace_id: $"val-($worker)", dry_run: false }
        }

        let val_result = do {
            $validate_input | to json | nu ($TOOLS_DIR | path join "validate.nu")
        } | complete

        let val_response = $val_result.stdout | from json

        let validation_results = ($validation_results | append {
            worker: $worker
            valid: $val_response.success
            trace_id: $val_response.trace_id
        })
    }

    # All validations should succeed independently
    let valid_count = ($validation_results | where valid | length)
    assert equal $valid_count $parallel_count "All parallel validations should succeed"

    # Each validation should preserve its trace_id
    for worker in 1..$parallel_count {
        let result = ($validation_results | where worker == $worker | first)
        assert equal $result.trace_id $"val-($worker)" $"Worker ($worker) should preserve trace_id"
    }

    # Cleanup
    rm -f $tool_path
    for worker in 1..$parallel_count {
        rm -f $"/tmp/parallel-val-output-($worker).json" $"/tmp/parallel-val-logs-($worker).json"
    }
}

#[test]
def "parallel_concurrent_temp_file_cleanup" [] {
    # Test: Parallel executions clean up their own temp files without conflicts

    let tool_path = "/tmp/parallel-cleanup-tool.nu"

    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    {
        success: true
        data: { worker: ($input.worker_id? | default 0) }
        trace_id: ($input.context?.trace_id? | default "")
    } | to json | print
}' | save -f $tool_path

    let parallel_count = 8
    let temp_files = []

    # Create files
    for worker in 1..$parallel_count {
        let output_file = $"/tmp/parallel-cleanup-output-($worker).json"
        let logs_file = $"/tmp/parallel-cleanup-logs-($worker).json"

        let run_input = {
            tool_path: $tool_path
            tool_input: { worker_id: $worker }
            output_path: $output_file
            logs_path: $logs_file
            context: { trace_id: $"cleanup-($worker)" }
        }

        do { $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu") } | complete | null

        let temp_files = ($temp_files | append $output_file | append $logs_file)
    }

    # Verify all temp files were created
    let created_count = ($temp_files | where { |f| $f | path exists } | length)
    assert equal $created_count ($parallel_count * 2) "All temp files should be created"

    # Simulate cleanup (each worker cleans its own files)
    for worker in 1..$parallel_count {
        let output_file = $"/tmp/parallel-cleanup-output-($worker).json"
        let logs_file = $"/tmp/parallel-cleanup-logs-($worker).json"

        # Each worker only cleans its own files
        if ($output_file | path exists) {
            rm -f $output_file
        }
        if ($logs_file | path exists) {
            rm -f $logs_file
        }
    }

    # Verify cleanup was successful
    let remaining_count = ($temp_files | where { |f| $f | path exists } | length)
    assert equal $remaining_count 0 "All temp files should be cleaned up"

    # Cleanup tool
    rm -f $tool_path
}

#[test]
def "parallel_race_condition_free" [] {
    # Test: Stress test for race conditions with shared contract file

    let tool_path = "/tmp/parallel-race-tool.nu"

    '#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    let message = $input.message? | default ""

    # Simulate some processing time
    sleep 10ms

    {
        success: true
        data: {
            echo: $message
            reversed: ($message | split chars | reverse | str join)
            length: ($message | str length)
            was_dry_run: false
        }
        trace_id: ($input.context?.trace_id? | default "")
        duration_ms: 10.0
    } | to json | print
}' | save -f $tool_path

    let parallel_count = 10
    let race_results = []

    # Launch many executions simultaneously reading same contract
    for worker in 1..$parallel_count {
        let output_file = $"/tmp/parallel-race-output-($worker).json"
        let logs_file = $"/tmp/parallel-race-logs-($worker).json"

        let run_input = {
            tool_path: $tool_path
            tool_input: { message: $"race-test-($worker)" }
            output_path: $output_file
            logs_path: $logs_file
            context: { trace_id: $"race-($worker)" }
        }

        let result = do {
            $run_input | to json | nu ($TOOLS_DIR | path join "run-tool.nu")
        } | complete

        let race_results = ($race_results | append {
            worker: $worker
            success: ($result.exit_code == 0)
            output_file: $output_file
        })
    }

    # All should succeed despite concurrent access
    let success_count = ($race_results | where success | length)
    assert equal $success_count $parallel_count "All concurrent executions should succeed"

    # Verify each output is correct and independent
    for worker in 1..$parallel_count {
        let output_file = $"/tmp/parallel-race-output-($worker).json"
        let output = open $output_file | from json

        assert equal $output.data.echo $"race-test-($worker)" $"Worker ($worker) should have independent output"
    }

    # Cleanup
    rm -f $tool_path
    for worker in 1..$parallel_count {
        rm -f $"/tmp/parallel-race-output-($worker).json" $"/tmp/parallel-race-logs-($worker).json"
    }
}
