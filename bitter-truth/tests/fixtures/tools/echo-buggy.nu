#!/usr/bin/env nu
# Buggy echo tool - common mistake (str rev instead of str reverse)
def main [] {
    let input = open --raw /dev/stdin | from json
    let message = $input.message

    # BUG: str rev does not exist in Nushell
    let reversed = ($message | str rev)

    { echo: $message, reversed: $reversed } | to json | print
}
