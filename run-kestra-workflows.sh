#!/bin/bash

# Script to run Kestra workflows for Fire-Flow project
# This script helps work around Java security manager issues

set -e

echo "=== Fire-Flow Kestra Workflows Runner ==="

# Function to get the Java path from mise
get_mise_java_path() {
    # Get the java path from mise environment
    local java_path=$(mise env | grep "JAVA_HOME" | cut -d'=' -f2 | tr -d '"')
    if [ -n "$java_path" ]; then
        echo "$java_path/bin"
    else
        # Fallback to standard path
        echo "/usr/lib/jvm/java-21-openjdk/bin"
    fi
}

# Function to check if Kestra is installed
check_kestra() {
    if [ ! -f "/home/lewis/.local/opt/kestra/kestra.jar" ]; then
        echo "Error: Kestra JAR file not found at /home/lewis/.local/opt/kestra/kestra.jar"
        exit 1
    fi
}

# Function to run a specific workflow
run_workflow() {
    local workflow_name=$1
    local workflow_file="kestra/flows/${workflow_name}.yml"
    
    if [ ! -f "$workflow_file" ]; then
        echo "Error: Workflow file not found: $workflow_file"
        exit 1
    fi
    
    echo "Running workflow: $workflow_name"
    
    # Get the correct Java path from mise
    local java_bin=$(get_mise_java_path)
    
    # Try running with specific Java options to bypass security manager issues
    # This is a workaround for the Java security manager problem
    "$java_bin/java" \
        -Djava.security.manager=allow \
        -Djava.security.policy=none \
        -jar /home/lewis/.local/opt/kestra/kestra.jar run "$workflow_file"
}

# Function to validate workflow files
validate_workflows() {
    echo "Validating workflow files..."
    
    local java_bin=$(get_mise_java_path)
    
    for workflow in kestra/flows/*.yml; do
        echo "Validating: $(basename $workflow)"
        "$java_bin/java" -jar /home/lewis/.local/opt/kestra/kestra.jar validate "$workflow" || echo "Validation failed for: $(basename $workflow)"
    done
}

# Main execution
case "${1:-help}" in
    "validate")
        validate_workflows
        ;;
    "hello")
        run_workflow "hello-flow"
        ;;
    "tcr")
        run_workflow "tcr-enforcement-workflow"
        ;;
    "build")
        run_workflow "build-and-test"
        ;;
    "all")
        echo "Running all workflows..."
        run_workflow "hello-flow"
        run_workflow "tcr-enforcement-workflow"
        run_workflow "build-and-test"
        ;;
    *)
        echo "Usage: $0 [validate|hello|tcr|build|all|help]"
        echo "  validate - Validate workflow files"
        echo "  hello    - Run hello-flow workflow"
        echo "  tcr      - Run tcr-enforcement-workflow"
        echo "  build    - Run build-and-test workflow"
        echo "  all      - Run all workflows"
        echo "  help     - Show this help"
        exit 1
        ;;
esac

echo "=== Workflow execution completed ==="