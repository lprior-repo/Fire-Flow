#!/usr/bin/env nu
# Kestra API helper - secure credential handling via pass

def main [] {
    print "Usage: kestra.nu <command> [args]"
    print "Commands:"
    print "  flows                    - List all flows"
    print "  flow <ns> <id>          - Get flow details"
    print "  deploy <file>           - Deploy flow from YAML file"
    print "  run <ns> <id> <json>    - Trigger execution"
    print "  status <exec-id>        - Get execution status"
    print "  logs <exec-id>          - Get execution logs"
}

def "main flows" [] {
    # Auth via ~/.netrc
    ^curl -s --netrc "http://localhost:4201/api/v1/main/flows"
}

def "main flow" [namespace: string, id: string] {
    # Auth via ~/.netrc
    ^curl -s --netrc $"http://localhost:4201/api/v1/main/flows/($namespace)/($id)"
}

def "main deploy" [file: path] {
    let content = open --raw $file
    # Extract namespace and id from the YAML
    let yaml = $content | from yaml
    let ns = $yaml.namespace
    let id = $yaml.id

    # Auth via ~/.netrc
    ^curl -s -X PUT --netrc -H "Content-Type: application/x-yaml" --data-binary $"@($file)" $"http://localhost:4201/api/v1/main/flows/($ns)/($id)"
}

def "main run" [namespace: string, id: string, inputs: string] {
    # Build form data from the inputs JSON using curl with -F flags
    let data = $inputs | from json

    # Build -F flags for each input
    let form_flags = $data | items { |k, v|
        let val = if ($v | describe) == "string" { $v } else { $v | to json -r }
        ["-F" $"($k)=($val)"]
    } | flatten

    # Use curl for multipart form data (nushell http doesn't support it well)
    # Note: endpoint is /api/v1/executions (not /api/v1/main/executions for OSS)
    # Auth via ~/.netrc (machine localhost, login <email>, password <pass>)
    let curl_args = ["-s" "-X" "POST" "--netrc" ...$form_flags $"http://localhost:4201/api/v1/main/executions/($namespace)/($id)"]
    ^curl ...$curl_args
}

def "main status" [exec_id: string] {
    # Auth via ~/.netrc
    ^curl -s --netrc $"http://localhost:4201/api/v1/main/executions/($exec_id)"
}

def "main logs" [exec_id: string] {
    # Auth via ~/.netrc
    ^curl -s --netrc $"http://localhost:4201/api/v1/main/logs/($exec_id)"
}
