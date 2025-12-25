#!/usr/bin/env nu
# Generate - AI generates Nushell tool from contract
#
# Contract: contracts/tools/generate.yaml
# Input: JSON from stdin (GenerateInput)
# Output: JSON to stdout (ToolResponse wrapping GenerateOutput)
# Logs: JSON to stderr
#
# CRITICAL: This tool handles process cleanup to prevent orphaned AI processes
# when Kestra kills the parent task.

def main [] {
    let start = date now

    # Read JSON from stdin
    let raw = open --raw /dev/stdin
    let input = $raw | from json

    # Extract context
    let ctx = $input.context? | default {}
    let trace_id = $ctx.trace_id? | default ""
    let dry_run = $ctx.dry_run? | default false
    let timeout_seconds = $ctx.timeout_seconds? | default 600

    # Extract generation parameters
    let contract_path = $input.contract_path? | default ""
    let task = $input.task? | default ""
    let feedback = $input.feedback? | default "Initial generation"
    let attempt = $input.attempt? | default "1/5"
    let output_path = $input.output_path? | default "/tmp/tool.nu"

    # Validate required fields
    if ($contract_path | is-empty) {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "error", msg: "contract_path is required", trace_id: $trace_id } | to json -r | print -e
        { success: false, error: "contract_path is required", trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 1
    }

    if ($task | is-empty) {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "error", msg: "task is required", trace_id: $trace_id } | to json -r | print -e
        { success: false, error: "task is required", trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 1
    }

    if not ($contract_path | path exists) {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "error", msg: $"contract not found: ($contract_path)", trace_id: $trace_id } | to json -r | print -e
        { success: false, error: $"contract not found: ($contract_path)", trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 1
    }

    { level: "info", msg: "generating tool", trace_id: $trace_id, contract: $contract_path, task: $task, attempt: $attempt, dry_run: $dry_run } | to json -r | print -e

    if $dry_run {
        let dur = (date now) - $start | into int | $in / 1000000
        { level: "info", msg: "dry-run mode - skipping generation" } | to json -r | print -e

        # Write a stub tool for dry-run
        "# Dry-run stub\ndef main [] { print 'dry-run' }" | save -f $output_path

        let output = {
            generated: true
            output_path: $output_path
            was_dry_run: true
        }
        { success: true, data: $output, trace_id: $trace_id, duration_ms: $dur } | to json | print
        exit 0
    }

    # Build the prompt - provide complete working code pattern
    # NOTE: Local models work better with explicit examples and output priming
    let contract_content = open $contract_path | to yaml
    let prompt = $"You are a Nushell code generator. You output ONLY valid Nushell code, never explanations.

TASK: ($task)

CONTRACT \(your output must produce JSON matching this schema\):
($contract_content)

FEEDBACK FROM PREVIOUS ATTEMPT: ($feedback)
ATTEMPT: ($attempt)

REQUIREMENTS:
- Read JSON from stdin: let input = open --raw /dev/stdin | from json
- Output JSON to stdout matching the contract schema
- Exit 0 on success, exit 1 on failure

EXAMPLE OUTPUT FORMAT \(you must follow this exact pattern\):
```nushell
#!/usr/bin/env nu
def main [] {
    let input = open --raw /dev/stdin | from json
    # ... your implementation here ...
    { success: true, data: $result } | to json | print
}
```

Now generate the complete Nushell script for the task above.
OUTPUT ONLY THE CODE INSIDE A ```nushell CODE BLOCK:"

    { level: "info", msg: "calling opencode", prompt_length: ($prompt | str length), timeout_seconds: $timeout_seconds } | to json -r | print -e

    # Save prompt to temp file to avoid pipe (pipes cause orphaned processes)
    let prompt_file = $"/tmp/prompt-($trace_id)-($attempt | str replace '/' '-').txt"
    $prompt | save -f $prompt_file
    { level: "debug", msg: "saved prompt to file", prompt_file: $prompt_file } | to json -r | print -e

    # Build the opencode command - explicitly use local/qwen3-coder model
    let model = "local/qwen3-coder"
    let opencode_cmd = $"timeout --foreground --kill-after=5 ($timeout_seconds)s opencode run -m ($model)"
    { level: "debug", msg: "opencode command", cmd: $opencode_cmd, model: $model, prompt_file: $prompt_file } | to json -r | print -e

    # Run opencode with timeout using 'run' subcommand for headless execution
    # --foreground: don't create new process group, signals propagate properly
    # --kill-after=5: send SIGKILL 5s after SIGTERM if still running
    let opencode_start = date now
    { level: "info", msg: "starting opencode process", model: $model } | to json -r | print -e

    let result = do {
        timeout --foreground --kill-after=5 $"($timeout_seconds)s" opencode run -m $model (open --raw $prompt_file)
    } | complete

    let opencode_duration = (date now) - $opencode_start | into int | $in / 1000000
    { level: "info", msg: "opencode process completed", exit_code: $result.exit_code, duration_ms: $opencode_duration, stdout_len: ($result.stdout | str length), stderr_len: ($result.stderr | str length) } | to json -r | print -e

    # Log stderr from opencode (contains --print-logs output)
    if ($result.stderr | str length) > 0 {
        { level: "debug", msg: "opencode stderr (truncated)", stderr_preview: ($result.stderr | str substring 0..500) } | to json -r | print -e
    }

    # Cleanup prompt file
    rm -f $prompt_file

    let duration_ms = (date now) - $start | into int | $in / 1000000

    if $result.exit_code == 124 {
        # Timeout
        { level: "error", msg: "opencode timed out", timeout_seconds: $timeout_seconds } | to json -r | print -e
        { success: false, error: "AI generation timed out", trace_id: $trace_id, duration_ms: $duration_ms } | to json | print
        exit 1
    }

    if $result.exit_code != 0 {
        { level: "error", msg: "opencode failed", exit_code: $result.exit_code, stderr: ($result.stderr | str substring 0..500) } | to json -r | print -e
        { success: false, error: $"opencode failed with exit ($result.exit_code)", trace_id: $trace_id, duration_ms: $duration_ms } | to json | print
        exit 1
    }

    # Default format outputs directly to stdout
    let raw_output = $result.stdout
    { level: "info", msg: "received output from opencode", raw_length: ($raw_output | str length), preview: ($raw_output | str substring 0..200) } | to json -r | print -e

    if ($raw_output | str length) == 0 {
        { level: "error", msg: "no output from opencode - empty" } | to json -r | print -e
        { success: false, error: "No output from AI", trace_id: $trace_id, duration_ms: $duration_ms } | to json | print
        exit 1
    }

    # Use llm-cleaner to extract nushell code from potentially chatty output
    let llm_cleaner = "/home/lewis/src/Fire-Flow/tools/llm-cleaner/target/release/llm-cleaner"
    { level: "debug", msg: "cleaning LLM output with llm-cleaner" } | to json -r | print -e

    let clean_result = $raw_output | do { ^$llm_cleaner --lang nushell --debug } | complete

    if $clean_result.exit_code != 0 {
        { level: "warn", msg: "llm-cleaner failed - trying raw output", error: $clean_result.stderr } | to json -r | print -e
        # Fallback: use raw output if cleaner fails
        $raw_output | save -f $output_path
    } else {
        let generated_code = $clean_result.stdout
        { level: "info", msg: "llm-cleaner extracted code", code_length: ($generated_code | str length), cleaner_stderr: $clean_result.stderr } | to json -r | print -e
        $generated_code | save -f $output_path
    }

    { level: "info", msg: "generation complete", output_path: $output_path, duration_ms: $duration_ms } | to json -r | print -e

    let output = {
        generated: true
        output_path: $output_path
        was_dry_run: false
    }

    { success: true, data: $output, trace_id: $trace_id, duration_ms: $duration_ms } | to json | print
}
