#!/usr/bin/env nu
# Test constants - shared across all test files
#
# Usage:
#   use bitter-truth/tests/helpers/constants.nu *
#   print (tools_dir)

# Base directories (functions since we can't use runtime values in const)
export def tools_dir [] {
    $env.PWD | path join "bitter-truth/tools"
}

export def contracts_dir [] {
    $env.PWD | path join "bitter-truth/contracts"
}

export def tests_dir [] {
    $env.PWD | path join "bitter-truth/tests"
}

export def fixtures_dir [] {
    $env.PWD | path join "bitter-truth/tests/fixtures"
}

# Specific contract paths
export def common_contract [] {
    $env.PWD | path join "bitter-truth/contracts/common.yaml"
}

export def echo_contract [] {
    $env.PWD | path join "bitter-truth/contracts/tools/echo.yaml"
}

# Tool paths
export def echo_tool [] {
    $env.PWD | path join "bitter-truth/tools/echo.nu"
}

export def run_tool [] {
    $env.PWD | path join "bitter-truth/tools/run-tool.nu"
}

export def generate_tool [] {
    $env.PWD | path join "bitter-truth/tools/generate.nu"
}

export def validate_tool [] {
    $env.PWD | path join "bitter-truth/tools/validate.nu"
}

# Test execution defaults (these can be constants)
export const DEFAULT_TIMEOUT_MS = 30000
export const TEST_TRACE_PREFIX = "test"
export const TMP_DIR = "/tmp"
