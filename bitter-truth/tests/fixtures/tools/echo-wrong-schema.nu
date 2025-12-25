#!/usr/bin/env nu
# Tool with wrong output schema - for testing validation
def main [] {
    let input = open --raw /dev/stdin | from json

    # Wrong schema - missing required ToolResponse fields
    { wrong_field: "data", message: $input.message } | to json | print
}
