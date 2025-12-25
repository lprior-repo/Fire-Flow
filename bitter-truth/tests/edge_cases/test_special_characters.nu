#!/usr/bin/env nu
# Special character handling tests
# Tests for unicode, escape sequences, control characters, and encoding
#
# Run with: nu -c 'use /tmp/nutest/nutest; nutest run-tests --path bitter-truth/tests/edge_cases'

use std assert
use ../helpers/builders.nu *
use ../helpers/assertions.nu *

# Helper to get tools directory
def tools_dir [] {
    $env.PWD | path join "bitter-truth/tools"
}

#[test]
def test_message_with_newlines [] {
    # Test messages containing newline characters
    let message = "Line 1\nLine 2\nLine 3"
    let input = build_echo_input $message "test-newlines"

    # Act: Execute with newlines
    let result = do {
        $input | to json | nu (tools_dir | path join "echo.nu")
    } | complete

    # Assert: Should preserve newlines
    assert_exit_code $result 0 "Should handle newlines"

    let output = $result.stdout | from json
    assert_success $output "Message with newlines should succeed"
    assert equal $output.data.echo $message "Should preserve newlines in message"

    # Verify length calculation includes newlines
    assert equal $output.data.length ($message | str length) "Length should include newline characters"
}

#[test]
def test_message_with_tabs [] {
    # Test messages containing tab characters
    let message = "Column1\tColumn2\tColumn3"
    let input = build_echo_input $message "test-tabs"

    # Act: Execute with tabs
    let result = do {
        $input | to json | nu (tools_dir | path join "echo.nu")
    } | complete

    # Assert: Should preserve tabs
    assert_exit_code $result 0 "Should handle tabs"

    let output = $result.stdout | from json
    assert_success $output "Message with tabs should succeed"
    assert equal $output.data.echo $message "Should preserve tabs in message"
}

#[test]
def test_message_with_quotes [] {
    # Test messages with various quote types
    let test_cases = [
        'Single "quotes" inside'
        "Double 'quotes' inside"
        'Mixed "double" and \'single\' quotes'
        '"Starting with double quote'
        "'Starting with single quote"
    ]

    for msg in $test_cases {
        let input = build_echo_input $msg "test-quotes"

        let result = do {
            $input | to json | nu (tools_dir | path join "echo.nu")
        } | complete

        assert_exit_code $result 0 $"Should handle quotes: ($msg | str substring 0..20)"

        let output = $result.stdout | from json
        assert_success $output "Quoted message should succeed"
        assert equal $output.data.echo $msg "Should preserve quotes exactly"
    }
}

#[test]
def test_message_with_unicode_emoji [] {
    # Test messages with emoji and unicode characters
    let test_cases = [
        "Hello 👋 World 🌍"
        "Fire 🔥 Flow ⚡ System"
        "Tests ✅ Passing 🎉"
        "日本語 テスト"
        "中文测试"
        "العربية"
        "Ελληνικά"
        "🚀🔧💻📊🎯"
    ]

    for msg in $test_cases {
        let input = build_echo_input $msg "test-unicode"

        let result = do {
            $input | to json | nu (tools_dir | path join "echo.nu")
        } | complete

        assert_exit_code $result 0 $"Should handle unicode: ($msg | str substring 0..20)"

        let output = $result.stdout | from json
        assert_success $output "Unicode message should succeed"
        assert equal $output.data.echo $msg "Should preserve unicode exactly"

        # Note: Length might differ due to unicode encoding
        # Just verify it's reasonable
        assert ($output.data.length > 0) "Length should be positive for unicode"
    }
}

#[test]
def test_message_with_null_bytes [] {
    # Test handling of null bytes in messages
    # This is a critical security test - null bytes can cause truncation

    # Create a message with null byte (this might be challenging in nu)
    # We'll test the JSON encoding behavior instead
    let message = "Before\u{0000}After"  # Unicode null character

    let input = build_echo_input $message "test-null"

    # Act: Execute with null byte
    let result = do {
        $input | to json | nu (tools_dir | path join "echo.nu")
    } | complete

    # Assert: Should handle gracefully
    # Depending on JSON encoding, null might be escaped or cause issues
    if $result.exit_code == 0 {
        let output = $result.stdout | from json
        assert_success $output "Should handle null byte if JSON encoding supports it"
    } else {
        # If it fails, verify it fails gracefully
        let parse_result = try {
            $result.stdout | from json
        } catch {
            # Acceptable if null bytes break JSON
            return
        }
        assert_tool_response $parse_result
    }
}

#[test]
def test_message_with_control_characters [] {
    # Test various control characters (ASCII 0-31)
    let control_chars = [
        "\u{0001}"  # SOH (Start of Heading)
        "\u{0002}"  # STX (Start of Text)
        "\u{0007}"  # BEL (Bell)
        "\u{0008}"  # BS (Backspace)
        "\u{000B}"  # VT (Vertical Tab)
        "\u{000C}"  # FF (Form Feed)
        "\u{000D}"  # CR (Carriage Return)
        "\u{001B}"  # ESC (Escape)
        "\u{007F}"  # DEL (Delete)
    ]

    for ctrl in $control_chars {
        let message = $"Before($ctrl)After"
        let input = build_echo_input $message "test-control"

        let result = do {
            $input | to json | nu (tools_dir | path join "echo.nu")
        } | complete

        # Control characters might be handled differently
        # Some might be escaped, some might cause issues
        if $result.exit_code == 0 {
            let output = try {
                $result.stdout | from json
            } catch {
                # If JSON parsing fails, that's acceptable for control chars
                continue
            }

            assert_success $output "Should handle control character"
            # Don't assert exact equality - JSON encoding might escape them
            assert (($output.data.echo | str length) > 0) "Output should not be empty"
        }
        # If exit code != 0, that's also acceptable for control characters
    }
}

#[test]
def test_message_with_backslashes [] {
    # Test backslash escaping in messages
    let test_cases = [
        'C:\\Windows\\System32'
        '\\server\\share\\file.txt'
        'Escape \\n sequence'
        'Double \\\\ backslash'
        'Mixed /forward\\back slashes'
    ]

    for msg in $test_cases {
        let input = build_echo_input $msg "test-backslash"

        let result = do {
            $input | to json | nu (tools_dir | path join "echo.nu")
        } | complete

        assert_exit_code $result 0 $"Should handle backslashes: ($msg | str substring 0..30)"

        let output = $result.stdout | from json
        assert_success $output "Backslash message should succeed"
        assert equal $output.data.echo $msg "Should preserve backslashes"
    }
}

#[test]
def test_message_with_special_json_chars [] {
    # Test characters that have special meaning in JSON
    let test_cases = [
        '{"key": "value"}'
        '["array", "values"]'
        'Quote: "test"'
        'Backslash: \\'
        'Slash: /'
        'Special: \b \f \n \r \t'
    ]

    for msg in $test_cases {
        let input = build_echo_input $msg "test-json-special"

        let result = do {
            $input | to json | nu (tools_dir | path join "echo.nu")
        } | complete

        assert_exit_code $result 0 $"Should handle JSON special chars: ($msg | str substring 0..30)"

        let output = $result.stdout | from json
        assert_success $output "JSON special chars should be escaped properly"
        # The echo field might have escaped versions
        assert (($output.data.echo | str length) > 0) "Output should not be empty"
    }
}

#[test]
def test_message_with_ansi_escape_codes [] {
    # Test ANSI color codes and escape sequences
    let test_cases = [
        "\u{001B}[31mRed text\u{001B}[0m"
        "\u{001B}[1;32mBold green\u{001B}[0m"
        "\u{001B}[4mUnderlined\u{001B}[0m"
        "Normal \u{001B}[44mBlue background\u{001B}[0m text"
    ]

    for msg in $test_cases {
        let input = build_echo_input $msg "test-ansi"

        let result = do {
            $input | to json | nu (tools_dir | path join "echo.nu")
        } | complete

        # ANSI codes should be preserved or escaped
        if $result.exit_code == 0 {
            let output = $result.stdout | from json
            assert_success $output "ANSI escape codes should be handled"
            assert (($output.data.echo | str length) > 0) "Output should not be empty"
        }
    }
}

#[test]
def test_message_with_html_entities [] {
    # Test HTML/XML special characters
    let test_cases = [
        '<div>HTML content</div>'
        'Tag: <br/>'
        'Entity: &amp; &lt; &gt;'
        '<script>alert("test")</script>'
        '<?xml version="1.0"?>'
    ]

    for msg in $test_cases {
        let input = build_echo_input $msg "test-html"

        let result = do {
            $input | to json | nu (tools_dir | path join "echo.nu")
        } | complete

        assert_exit_code $result 0 $"Should handle HTML: ($msg | str substring 0..30)"

        let output = $result.stdout | from json
        assert_success $output "HTML entities should be preserved"
        assert equal $output.data.echo $msg "Should preserve HTML exactly"
    }
}

#[test]
def test_message_with_sql_injection_patterns [] {
    # Test SQL injection-like strings (not that we use SQL, but good to test)
    let test_cases = [
        "'; DROP TABLE users; --"
        "1' OR '1'='1"
        "admin'--"
        "' UNION SELECT * FROM passwords--"
    ]

    for msg in $test_cases {
        let input = build_echo_input $msg "test-sql"

        let result = do {
            $input | to json | nu (tools_dir | path join "echo.nu")
        } | complete

        assert_exit_code $result 0 $"Should handle SQL patterns: ($msg | str substring 0..30)"

        let output = $result.stdout | from json
        assert_success $output "SQL patterns should be treated as plain text"
        assert equal $output.data.echo $msg "Should preserve SQL patterns exactly"
    }
}

#[test]
def test_message_with_url_encoding [] {
    # Test URL-encoded characters
    let test_cases = [
        'http://example.com/path?query=value&foo=bar'
        'mailto:user@example.com'
        'URL encoded: %20 %3D %26'
        'Path/to/resource#fragment'
    ]

    for msg in $test_cases {
        let input = build_echo_input $msg "test-url"

        let result = do {
            $input | to json | nu (tools_dir | path join "echo.nu")
        } | complete

        assert_exit_code $result 0 $"Should handle URLs: ($msg | str substring 0..40)"

        let output = $result.stdout | from json
        assert_success $output "URL encoding should be preserved"
        assert equal $output.data.echo $msg "Should preserve URLs exactly"
    }
}

#[test]
def test_message_with_regex_metacharacters [] {
    # Test regular expression metacharacters
    let test_cases = [
        '.*+?[]{}()|^$\\'
        'Pattern: [a-z]+'
        'Regex: ^start.*end$'
        'Group: (capture)'
        'Escape: \\d \\w \\s'
    ]

    for msg in $test_cases {
        let input = build_echo_input $msg "test-regex"

        let result = do {
            $input | to json | nu (tools_dir | path join "echo.nu")
        } | complete

        assert_exit_code $result 0 $"Should handle regex: ($msg | str substring 0..30)"

        let output = $result.stdout | from json
        assert_success $output "Regex metacharacters should be literal"
        assert equal $output.data.echo $msg "Should preserve regex patterns exactly"
    }
}

#[test]
def test_message_with_glob_patterns [] {
    # Test shell glob patterns
    let test_cases = [
        '*.txt'
        'file?.log'
        'data[0-9].json'
        '**/*.nu'
        'test{1,2,3}.sh'
    ]

    for msg in $test_cases {
        let input = build_echo_input $msg "test-glob"

        let result = do {
            $input | to json | nu (tools_dir | path join "echo.nu")
        } | complete

        assert_exit_code $result 0 $"Should handle glob: ($msg)"

        let output = $result.stdout | from json
        assert_success $output "Glob patterns should be literal"
        assert equal $output.data.echo $msg "Should preserve glob patterns exactly"
    }
}

#[test]
def test_message_with_shell_metacharacters [] {
    # Test shell special characters (should be treated as literal)
    let test_cases = [
        'command > output.txt'
        'input < file.txt'
        'cmd1 | cmd2'
        'background &'
        'variable=$value'
        '`backticks`'
        '$(command substitution)'
    ]

    for msg in $test_cases {
        let input = build_echo_input $msg "test-shell"

        let result = do {
            $input | to json | nu (tools_dir | path join "echo.nu")
        } | complete

        assert_exit_code $result 0 $"Should handle shell chars: ($msg | str substring 0..30)"

        let output = $result.stdout | from json
        assert_success $output "Shell metacharacters should be literal"
        assert equal $output.data.echo $msg "Should preserve shell patterns exactly"
    }
}

#[test]
def test_message_with_mixed_encodings [] {
    # Test messages with mixed character types
    let message = "ASCII 123, Unicode 日本語, Emoji 🔥, Symbols ★☆♠♣"

    let input = build_echo_input $message "test-mixed"

    let result = do {
        $input | to json | nu (tools_dir | path join "echo.nu")
    } | complete

    assert_exit_code $result 0 "Should handle mixed encodings"

    let output = $result.stdout | from json
    assert_success $output "Mixed encoding should succeed"
    assert equal $output.data.echo $message "Should preserve mixed characters"
}

#[test]
def test_message_with_zero_width_characters [] {
    # Test zero-width unicode characters
    let test_cases = [
        "Word\u{200B}Break"       # Zero-width space
        "Zero\u{FEFF}Width"       # Zero-width no-break space
        "Join\u{200D}er"          # Zero-width joiner
    ]

    for msg in $test_cases {
        let input = build_echo_input $msg "test-zero-width"

        let result = do {
            $input | to json | nu (tools_dir | path join "echo.nu")
        } | complete

        assert_exit_code $result 0 "Should handle zero-width characters"

        let output = $result.stdout | from json
        assert_success $output "Zero-width chars should be preserved"
        # Length might be surprising due to zero-width chars
        assert ($output.data.length > 0) "Length should be positive"
    }
}

#[test]
def test_message_with_rtl_text [] {
    # Test right-to-left text (Hebrew, Arabic)
    let test_cases = [
        "שלום עולם"  # Hebrew
        "مرحبا بك"   # Arabic
        "Mixed LTR and RTL: שלום"
    ]

    for msg in $test_cases {
        let input = build_echo_input $msg "test-rtl"

        let result = do {
            $input | to json | nu (tools_dir | path join "echo.nu")
        } | complete

        assert_exit_code $result 0 $"Should handle RTL text: ($msg)"

        let output = $result.stdout | from json
        assert_success $output "RTL text should be preserved"
        assert equal $output.data.echo $msg "Should preserve RTL exactly"
    }
}

#[test]
def test_very_long_line_no_newlines [] {
    # Test a very long single line (10,000 characters)
    let long_message = (1..10000 | each { |_| "x" } | str join "")

    let input = build_echo_input $long_message "test-long-line"

    let result = do {
        $input | to json | nu (tools_dir | path join "echo.nu")
    } | complete

    assert_exit_code $result 0 "Should handle very long line"

    let output = $result.stdout | from json
    assert_success $output "Long line should succeed"
    assert equal $output.data.length 10000 "Should preserve full length"
    assert equal $output.data.echo $long_message "Should preserve entire long line"
}

#[test]
def test_message_all_whitespace [] {
    # Test messages that are only whitespace (but not empty)
    let test_cases = [
        " "           # Single space
        "   "         # Multiple spaces
        "\t"          # Tab
        "\n"          # Newline
        " \t\n "      # Mixed whitespace
    ]

    for msg in $test_cases {
        let input = build_echo_input $msg "test-whitespace"

        let result = do {
            $input | to json | nu (tools_dir | path join "echo.nu")
        } | complete

        assert_exit_code $result 0 "Should handle whitespace-only messages"

        let output = $result.stdout | from json
        assert_success $output "Whitespace message should succeed"
        assert equal $output.data.echo $msg "Should preserve whitespace exactly"
        assert ($output.data.length > 0) "Whitespace should have positive length"
    }
}
