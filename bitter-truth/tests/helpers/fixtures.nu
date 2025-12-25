#!/usr/bin/env nu
# Test fixtures - Immutable test data loader and temp file management
#
# Usage:
#   use bitter-truth/tests/helpers/fixtures.nu *
#   let data = load_fixture "tools" "echo-valid"
#   let tmp = create_temp_file "json"
#   cleanup_temp_files

use std assert

# Generate unique test ID using UUID (8 char prefix for readability)
#
# Returns: string - unique test ID
#
# Example:
#   let id = get_test_id  # "a3f7b2c1"
export def get_test_id [] {
    random uuid | str substring 0..8
}

# Create temporary file with unique UUID-based name
#
# Args:
#   extension: string - file extension (without dot)
#   prefix: string - optional prefix for file name
#
# Returns: string - absolute path to temp file
#
# Example:
#   let tmp = create_temp_file "json"  # /tmp/test-a3f7b2c1.json
#   let tmp = create_temp_file "nu" "tool"  # /tmp/tool-a3f7b2c1.nu
export def create_temp_file [
    extension: string
    prefix?: string
] {
    let id = get_test_id
    let filename = if ($prefix | is-empty) {
        $"test-($id).($extension)"
    } else {
        $"($prefix)-($id).($extension)"
    }

    let path = $"/tmp/($filename)"

    # Track for cleanup
    $env.TEMP_FILES = ($env.TEMP_FILES | append $path)

    $path
}

# Cleanup all tracked temporary files
#
# This is safe to call multiple times - ignores missing files
#
# Example:
#   cleanup_temp_files
export def cleanup_temp_files [] {
    $env.TEMP_FILES | each { |file|
        if ($file | path exists) {
            rm -f $file
        }
    }
    $env.TEMP_FILES = []
}

# Load fixture from fixtures directory
#
# Args:
#   category: string - subdirectory under fixtures/
#   name: string - fixture name (without extension)
#
# Returns: any - parsed fixture data (JSON/YAML) or string content
#
# Fixtures are read-only and immutable. They are loaded fresh each time.
#
# Example:
#   let tool = load_fixture "tools" "echo-correct"
#   let input = load_fixture "inputs" "echo-valid"
export def load_fixture [
    category: string
    name: string
] {
    let fixtures_dir = $env.PWD | path join "bitter-truth/tests/fixtures"

    # Try common extensions in order: .json, .yaml, .yml, .nu, .txt
    let extensions = [".json", ".yaml", ".yml", ".nu", ".txt"]

    let fixture_path = $extensions | each { |ext|
        let path = $fixtures_dir | path join $category $"($name)($ext)"
        if ($path | path exists) {
            $path
        } else {
            null
        }
    } | compact | first

    if ($fixture_path | is-empty) {
        error make {
            msg: $"Fixture not found: ($category)/($name)"
            label: {
                text: "No fixture file with supported extensions"
                span: (metadata $name).span
            }
        }
    }

    # Parse based on extension
    let ext = $fixture_path | path parse | get extension

    if $ext == "json" {
        open $fixture_path
    } else if $ext in ["yaml", "yml"] {
        open $fixture_path
    } else {
        # Raw text for .nu, .txt, or other files
        open --raw $fixture_path
    }
}

# Check if fixture exists
#
# Args:
#   category: string - subdirectory under fixtures/
#   name: string - fixture name (without extension)
#
# Returns: bool - true if fixture exists
#
# Example:
#   if (fixture_exists "tools" "echo-correct") { ... }
export def fixture_exists [
    category: string
    name: string
] {
    let fixtures_dir = $env.PWD | path join "bitter-truth/tests/fixtures"
    let extensions = [".json", ".yaml", ".yml", ".nu", ".txt"]

    $extensions | any { |ext|
        let path = $fixtures_dir | path join $category $"($name)($ext)"
        $path | path exists
    }
}

# Create temporary tool file with content
#
# Args:
#   content: string - tool script content
#   name: string - optional tool name prefix
#
# Returns: string - absolute path to tool file
#
# The file is automatically tracked for cleanup
#
# Example:
#   let tool_path = create_temp_tool $tool_code "echo"
#   # ... use tool
#   cleanup_temp_files
export def create_temp_tool [
    content: string
    name?: string
] {
    let prefix = if ($name | is-empty) { "tool" } else { $name }
    let path = create_temp_file "nu" $prefix
    $content | save -f $path
    $path
}

# Create temporary JSON file with data
#
# Args:
#   data: record - data to serialize as JSON
#   name: string - optional file name prefix
#
# Returns: string - absolute path to JSON file
#
# Example:
#   let input_path = create_temp_json { message: "hello" } "input"
export def create_temp_json [
    data: record
    name?: string
] {
    let prefix = if ($name | is-empty) { "data" } else { $name }
    let path = create_temp_file "json" $prefix
    $data | to json | save -f $path
    $path
}

# Initialize temp files tracker (call at test start)
#
# Example:
#   init_temp_tracker
#   # ... run test ...
#   cleanup_temp_files
export def init_temp_tracker [] {
    $env.TEMP_FILES = []
}
