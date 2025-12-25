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
    let auth = get-auth
    http get -H ["Authorization" $"Basic ($auth)"] "http://localhost:4200/api/v1/flows"
}

def "main flow" [namespace: string, id: string] {
    let auth = get-auth
    http get -H ["Authorization" $"Basic ($auth)"] $"http://localhost:4200/api/v1/flows/($namespace)/($id)"
}

def "main deploy" [file: path] {
    let auth = get-auth
    let content = open --raw $file
    # Extract namespace and id from the YAML
    let yaml = $content | from yaml
    let ns = $yaml.namespace
    let id = $yaml.id

    http put -H ["Authorization" $"Basic ($auth)" "Content-Type" "application/x-yaml"] $"http://localhost:4200/api/v1/flows/($ns)/($id)" $content
}

def "main run" [namespace: string, id: string, inputs: string] {
    let auth = get-auth
    let user = (^pass kestra/username | str trim)
    let pass = (^pass kestra/password | str trim)

    # Build form data from the inputs JSON using curl with -F flags
    let data = $inputs | from json

    # Build -F flags for each input
    let form_flags = $data | items { |k, v|
        let val = if ($v | describe) == "string" { $v } else { $v | to json -r }
        ["-F" $"($k)=($val)"]
    } | flatten

    # Use curl for multipart form data (nushell http doesn't support it well)
    # Note: endpoint is /api/v1/executions (not /api/v1/main/executions for OSS)
    ^curl -s -X POST ...$form_flags -u $"($user):($pass)" $"http://localhost:4200/api/v1/executions/($namespace)/($id)"
}

def "main status" [exec_id: string] {
    let auth = get-auth
    http get -H ["Authorization" $"Basic ($auth)"] $"http://localhost:4200/api/v1/executions/($exec_id)"
}

def "main logs" [exec_id: string] {
    let auth = get-auth
    http get -H ["Authorization" $"Basic ($auth)"] $"http://localhost:4200/api/v1/executions/($exec_id)/logs"
}

def get-auth [] {
    let user = (^pass kestra/username | str trim)
    let pass = (^pass kestra/password | str trim)
    [$user, $pass] | str join ":" | encode base64
}
