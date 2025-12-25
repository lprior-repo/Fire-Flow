#!/usr/bin/env nu
# Fire-Flow Workflow Test Runner
#
# Convenience script for running workflow tests with various options.
#
# Usage:
#   ./run-workflow-tests.nu                    # Run all workflow tests
#   ./run-workflow-tests.nu --suite healing    # Run self-healing tests only
#   ./run-workflow-tests.nu --verbose          # Run with verbose output
#   ./run-workflow-tests.nu --test "test_name" # Run specific test

def main [
    --suite: string              # Test suite: healing, parallel, full, error, all
    --test: string               # Specific test name to run
    --verbose                    # Verbose output
    --list                       # List all available tests
    --summary                    # Show summary statistics only
] {
    let repo_root = "/home/lewis/src/Fire-Flow"
    let workflow_dir = $"($repo_root)/bitter-truth/tests/workflow"

    # Change to repo root for consistent paths
    cd $repo_root

    if $list {
        print "Available Workflow Tests:\n"

        print "Self-Healing Loop Tests (test_self_healing_loop.nu):"
        print "  - self_healing_attempt_1_fails_attempt_2_succeeds"
        print "  - self_healing_all_attempts_fail_returns_final_error"
        print "  - self_healing_feedback_accumulates_across_attempts"
        print "  - self_healing_trace_id_consistent_across_attempts"
        print "  - self_healing_max_attempts_enforced"
        print "  - self_healing_early_success_stops_loop"
        print "  - self_healing_feedback_length_reasonable"
        print "  - self_healing_each_attempt_improves_output\n"

        print "Parallel Execution Tests (test_parallel_executions.nu):"
        print "  - parallel_echo_executions_isolated"
        print "  - parallel_outputs_unique_files"
        print "  - parallel_trace_ids_distinct"
        print "  - parallel_no_file_collisions_under_load"
        print "  - parallel_validation_independent"
        print "  - parallel_concurrent_temp_file_cleanup"
        print "  - parallel_race_condition_free\n"

        print "Full Workflow Tests (test_full_workflow.nu):"
        print "  - full_workflow_contract_loop_happy_path"
        print "  - full_workflow_pipeline_with_multiple_inputs"
        print "  - full_workflow_output_correctness"
        print "  - full_workflow_timing_reasonable"
        print "  - full_workflow_logs_complete"
        print "  - full_workflow_end_to_end_with_validation_details"
        print "  - full_workflow_handles_empty_input"
        print "  - full_workflow_large_message\n"

        print "Error Recovery Tests (test_error_recovery.nu):"
        print "  - error_recovery_missing_contract_fails_gracefully"
        print "  - error_recovery_missing_tool_fails_gracefully"
        print "  - error_recovery_invalid_input_fails_gracefully"
        print "  - error_recovery_validation_failure_triggers_feedback"
        print "  - error_recovery_network_timeout_handled"
        print "  - error_recovery_malformed_tool_output"
        print "  - error_recovery_missing_data_file_in_contract"
        print "  - error_recovery_tool_crash"
        print "  - error_recovery_partial_output"
        print "  - error_recovery_contract_yaml_parse_error"
        print "  - error_recovery_empty_trace_id_handled\n"

        return
    }

    # Determine which test file(s) to run
    let test_files = if ($suite != null) {
        match $suite {
            "healing" | "self-healing" => ["test_self_healing_loop.nu"]
            "parallel" | "concurrent" => ["test_parallel_executions.nu"]
            "full" | "workflow" => ["test_full_workflow.nu"]
            "error" | "recovery" => ["test_error_recovery.nu"]
            "all" => [
                "test_self_healing_loop.nu"
                "test_parallel_executions.nu"
                "test_full_workflow.nu"
                "test_error_recovery.nu"
            ]
            _ => {
                print $"Error: Unknown suite '($suite)'"
                print "Valid suites: healing, parallel, full, error, all"
                return
            }
        }
    } else {
        # Default: run all
        [
            "test_self_healing_loop.nu"
            "test_parallel_executions.nu"
            "test_full_workflow.nu"
            "test_error_recovery.nu"
        ]
    }

    print "\nFire-Flow Workflow Tests\n"
    print "========================\n"

    let start_time = date now

    for file in $test_files {
        let test_path = $"($workflow_dir)/($file)"

        print $"Running: ($file)"

        if ($test != null) {
            # Run specific test
            let result = do {
                nu -c $'use nutest/nutest; nutest run-tests --path ($test_path) --test-name ($test)'
            } | complete

            if $verbose {
                print $result.stdout
            }

            if $result.exit_code == 0 {
                print $"✓ Test '($test)' passed\n"
            } else {
                print $"✗ Test '($test)' failed\n"
                print $result.stdout
                print $result.stderr
            }
        } else {
            # Run all tests in file
            let result = do {
                nu -c $'use nutest/nutest; nutest run-tests --path ($test_path)'
            } | complete

            if $verbose {
                print $result.stdout
            }

            if $result.exit_code == 0 {
                print $"✓ All tests passed in ($file)\n"
            } else {
                print $"✗ Some tests failed in ($file)\n"
                print $result.stdout
                print $result.stderr
            }
        }
    }

    let end_time = date now
    let duration_sec = (($end_time - $start_time) | into int) / 1_000_000_000

    print "\n========================"
    print $"Total Duration: ($duration_sec) seconds"

    if $summary {
        print "\nTest Summary:"
        print $"- Self-Healing Tests: 8"
        print $"- Parallel Execution Tests: 7"
        print $"- Full Workflow Tests: 8"
        print $"- Error Recovery Tests: 11"
        print $"- Total: 34 workflow tests"
    }
}
