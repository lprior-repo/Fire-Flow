#!/usr/bin/env nu

def main [] {
    # Read input from stdin
    let input = (try { 
        (open --raw -) 
    } catch {|e|
        print ({"error": $"Failed to read stdin: ($e.msg)"} | to json -r)
        exit 1
    })

    # Parse the input as JSON
    let parsed_input = try {
        ($input | from json)
    } catch {|e|
        print ({"error": $"Failed to parse JSON: ($e.msg)"} | to json -r)
        exit 1
    }

    # Extract the message field
    let message = ($parsed_input | get message)

    # Check if message is null or undefined
    if ($message == null) {
        print ({"error": "Missing 'message' field"} | to json -r)
        exit 1
    }

    # Reverse the string
    let reversed = ($message | str reverse)

    # Calculate length
    let length = ($message | str length)

    # Determine if dry run
    let was_dry_run = ($parsed_input | get dry_run | default false)

    # Create trace_id (using timestamp)
    let trace_id = (date now | format date "%Y-%m-%dT%H:%M:%S.%3fZ")

    # Create the response object
    let response = {
        success: true,
        data: {
            echo: $message,
            reversed: $reversed,
            length: $length,
            was_dry_run: $was_dry_run
        },
        trace_id: $trace_id,
        duration_ms: 0.0
    }

    # Print the response to stdout
    print ($response | to json -r)

    # Log to stderr
    print ({"level": "info", "message": "Echo tool executed successfully", "trace_id": $trace_id} | to json -r) >&2
}