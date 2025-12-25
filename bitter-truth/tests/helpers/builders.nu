#!/usr/bin/env nu
# Test data builders - Construct test inputs with sensible defaults
#
# Usage:
#   use bitter-truth/tests/helpers/builders.nu *
#   let input = build_echo_input "hello" "my-trace"

# Internal: Generate unique test ID
def get_test_id [] {
    random uuid | str substring 0..8
}

# Build ExecutionContext with sensible defaults
#
# Args:
#   trace_id: string - trace ID (optional, generates UUID if empty)
#   dry_run: bool - dry run mode (default: false)
#   timeout_seconds: int - timeout in seconds (optional)
#
# Returns: record - ExecutionContext
#
# Example:
#   let ctx = build_context "my-trace" false 30
#   let ctx = build_context  # auto-generated trace_id, dry_run=false
export def build_context [
    trace_id?: string
    dry_run?: bool
    timeout_seconds?: int
] {
    let tid = if ($trace_id | is-empty) {
        $"test-(get_test_id)"
    } else {
        $trace_id
    }

    let dr = $dry_run | default false

    let ctx = {
        trace_id: $tid
        dry_run: $dr
    }

    if ($timeout_seconds | is-empty) {
        $ctx
    } else {
        $ctx | merge { timeout_seconds: $timeout_seconds }
    }
}

# Build echo tool input
#
# Args:
#   message: string - message to echo
#   trace_id: string - trace ID (optional)
#   dry_run: bool - dry run mode (optional, default false)
#
# Returns: record - EchoInput with context
#
# Example:
#   let input = build_echo_input "hello world"
#   let input = build_echo_input "test" "my-trace" true
export def build_echo_input [
    message: string
    trace_id?: string
    dry_run?: bool
] {
    {
        message: $message
        context: (build_context $trace_id $dry_run)
    }
}

# Build run-tool input
#
# Args:
#   tool_path: string - absolute path to tool script
#   tool_input: record - input data to pass to tool
#   output_path: string - path for tool output (optional, auto-generated)
#   logs_path: string - path for tool logs (optional, auto-generated)
#   trace_id: string - trace ID (optional)
#   dry_run: bool - dry run mode (optional, default false)
#
# Returns: record - RunToolInput with context
#
# Example:
#   let input = build_run_tool_input "/tmp/echo.nu" { message: "hello" }
#   let input = build_run_tool_input $tool_path $data "/tmp/out.json" "/tmp/logs.json" "trace-1"
export def build_run_tool_input [
    tool_path: string
    tool_input: record
    output_path?: string
    logs_path?: string
    trace_id?: string
    dry_run?: bool
] {
    let test_id = get_test_id

    let out_path = if ($output_path | is-empty) {
        $"/tmp/output-($test_id).json"
    } else {
        $output_path
    }

    let log_path = if ($logs_path | is-empty) {
        $"/tmp/logs-($test_id).json"
    } else {
        $logs_path
    }

    {
        tool_path: $tool_path
        tool_input: $tool_input
        output_path: $out_path
        logs_path: $log_path
        context: (build_context $trace_id $dry_run)
    }
}

# Build generate tool input
#
# Args:
#   contract_path: string - path to data contract
#   task: string - task description for code generation
#   output_path: string - where to save generated code (optional)
#   trace_id: string - trace ID (optional)
#   dry_run: bool - dry run mode (optional, default false)
#
# Returns: record - GenerateInput with context
#
# Example:
#   let input = build_generate_input "/path/contract.yaml" "create echo tool"
export def build_generate_input [
    contract_path: string
    task: string
    output_path?: string
    trace_id?: string
    dry_run?: bool
] {
    let test_id = get_test_id

    let out_path = if ($output_path | is-empty) {
        $"/tmp/generated-($test_id).nu"
    } else {
        $output_path
    }

    {
        contract_path: $contract_path
        task: $task
        output_path: $out_path
        context: (build_context $trace_id $dry_run)
    }
}

# Build validate tool input
#
# Args:
#   contract_path: string - path to data contract
#   server: string - server type (local/remote, default: local)
#   trace_id: string - trace ID (optional)
#   dry_run: bool - dry run mode (optional, default false)
#
# Returns: record - ValidateInput with context
#
# Example:
#   let input = build_validate_input "/path/contract.yaml"
#   let input = build_validate_input $contract "remote" "trace-1"
export def build_validate_input [
    contract_path: string
    server?: string
    trace_id?: string
    dry_run?: bool
] {
    let srv = $server | default "local"

    {
        contract_path: $contract_path
        server: $srv
        context: (build_context $trace_id $dry_run)
    }
}

# Build common test context with all paths
#
# Creates a complete test context with all necessary temp file paths
# pre-generated with unique IDs for test isolation
#
# Returns: record - test context with paths and IDs
#
# Example:
#   let ctx = build_test_context
#   print $ctx.trace_id
#   print $ctx.output_path
export def build_test_context [] {
    let test_id = get_test_id
    let trace_id = $"test-($test_id)"

    {
        test_id: $test_id
        trace_id: $trace_id
        tool_path: $"/tmp/tool-($test_id).nu"
        output_path: $"/tmp/output-($test_id).json"
        logs_path: $"/tmp/logs-($test_id).json"
        generated_path: $"/tmp/generated-($test_id).nu"
        input_path: $"/tmp/input-($test_id).json"
    }
}

# Build ToolResponse success wrapper
#
# Args:
#   data: record - the tool-specific output data
#   trace_id: string - trace ID (optional)
#   duration_ms: int - execution duration (optional)
#
# Returns: record - ToolResponse with success=true
#
# Example:
#   let response = build_success_response { echo: "hello" } "trace-1" 42
export def build_success_response [
    data: record
    trace_id?: string
    duration_ms?: int
] {
    let response = {
        success: true
        data: $data
    }

    let with_trace = if ($trace_id | is-empty) {
        $response
    } else {
        $response | merge { trace_id: $trace_id }
    }

    if ($duration_ms | is-empty) {
        $with_trace
    } else {
        $with_trace | merge { duration_ms: $duration_ms }
    }
}

# Build ToolResponse error wrapper
#
# Args:
#   error: string - error message
#   trace_id: string - trace ID (optional)
#   duration_ms: int - execution duration (optional)
#   data: record - partial data (optional)
#
# Returns: record - ToolResponse with success=false
#
# Example:
#   let response = build_error_response "tool failed" "trace-1" 10
export def build_error_response [
    error: string
    trace_id?: string
    duration_ms?: int
    data?: record
] {
    let response = {
        success: false
        error: $error
    }

    let with_trace = if ($trace_id | is-empty) {
        $response
    } else {
        $response | merge { trace_id: $trace_id }
    }

    let with_duration = if ($duration_ms | is-empty) {
        $with_trace
    } else {
        $with_trace | merge { duration_ms: $duration_ms }
    }

    if ($data | is-empty) {
        $with_duration
    } else {
        $with_duration | merge { data: $data }
    }
}
