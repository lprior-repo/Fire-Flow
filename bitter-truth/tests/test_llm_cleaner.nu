#!/usr/bin/env nu
# Tests for llm-cleaner Rust tool
#
# Run with: nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests'

use std assert

const llm_cleaner = "/home/lewis/src/Fire-Flow/tools/llm-cleaner/target/release/llm-cleaner"

# Helper to run llm-cleaner with nushell lang
def run_cleaner_nushell [input: string] {
    $input | do { ^$llm_cleaner --lang nushell } | complete
}

# Helper to run llm-cleaner with json validation
def run_cleaner_json [input: string] {
    $input | do { ^$llm_cleaner --lang json --validate-json } | complete
}

# Helper to run llm-cleaner with debug
def run_cleaner_debug [input: string] {
    $input | do { ^$llm_cleaner --lang nushell --debug } | complete
}

# Helper to run llm-cleaner with no args
def run_cleaner_default [input: string] {
    $input | do { ^$llm_cleaner } | complete
}

#[test]
def test_cleaner_extracts_nushell_block [] {
    let input = 'Here is the code:

```nushell
#!/usr/bin/env nu
def main [] {
    print "hello"
}
```

Hope this helps!'

    let result = run_cleaner_nushell $input

    assert equal $result.exit_code 0
    assert ($result.stdout | str contains "def main")
    assert ($result.stdout | str contains 'print "hello"')
    # Should NOT contain the markdown
    assert (not ($result.stdout | str contains "```"))
    assert (not ($result.stdout | str contains "Hope this helps"))
}

#[test]
def test_cleaner_extracts_json_block [] {
    let input = 'The response is:

```json
{"success": true, "data": {"value": 42}}
```
'

    let result = run_cleaner_json $input

    assert equal $result.exit_code 0
    let parsed = $result.stdout | from json
    assert equal $parsed.success true
    assert equal $parsed.data.value 42
}

#[test]
def test_cleaner_handles_raw_code [] {
    let input = '#!/usr/bin/env nu
def main [] {
    print "direct code"
}'

    let result = run_cleaner_default $input

    assert equal $result.exit_code 0
    assert ($result.stdout | str contains "def main")
}

#[test]
def test_cleaner_fails_on_no_code [] {
    let input = 'This is just a conversational response with no code at all.
I am happy to help you with your question.'

    let result = run_cleaner_nushell $input

    assert equal $result.exit_code 1
    assert ($result.stderr | str contains "No code block found")
}

#[test]
def test_cleaner_extracts_code_after_llm_prefix [] {
    let input = "Here is the script you requested:

#!/usr/bin/env nu
def main [] {
    let x = 1
    print \$x
}"

    let result = run_cleaner_default $input

    assert equal $result.exit_code 0
    assert ($result.stdout | str contains "def main")
}

#[test]
def test_cleaner_handles_nushell_specific_patterns [] {
    let input = 'export def my_command [] {
    print "exported"
}'

    let result = run_cleaner_default $input

    assert equal $result.exit_code 0
    assert ($result.stdout | str contains "export def")
}

#[test]
def test_cleaner_json_validation_fails_on_invalid [] {
    let input = '```json
{invalid json here}
```'

    let result = run_cleaner_json $input

    assert equal $result.exit_code 1
}

#[test]
def test_cleaner_debug_mode [] {
    let input = '```nushell
def main [] { }
```'

    let result = run_cleaner_debug $input

    assert equal $result.exit_code 0
    # Debug info goes to stderr
    assert ($result.stderr | str contains "llm-cleaner")
}

#[test]
def test_cleaner_handles_str_reverse_not_str_rev [] {
    # This tests the exact issue we hit - LLM generated str rev instead of str reverse
    let bad_code = '```nushell
#!/usr/bin/env nu
def main [] {
    let msg = "hello"
    let reversed = ($msg | str rev)  # WRONG - should be str reverse
    print $reversed
}
```'

    let result = run_cleaner_nushell $bad_code

    # llm-cleaner should extract this, but it's the tool execution that would fail
    assert equal $result.exit_code 0
    assert ($result.stdout | str contains "str rev")
}
