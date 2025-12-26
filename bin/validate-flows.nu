#!/usr/bin/env nu
# Validate all Kestra flows using Kestra CLI
# Usage: nu bin/validate-flows.nu

def main [] {
  let kestra_plugins = "/home/lewis/kestra/plugins"
  let flows_dir = "bitter-truth/kestra/flows"

  print "🔍 Validating Kestra flows in ($flows_dir)..."
  print ""

  let flows = (glob ($flows_dir + "/*.yml"))
  mut results = []

  for flow in $flows {
    let flowname = ($flow | path basename)
    print -n $"  [($results | length | $in + 1)] ($flowname) ... "

    let validation = (
      ^kestra flow validate -p $kestra_plugins --local $flow
      | complete
    )

    # Check if validation passed
    # Exit code 0 = valid (ignore internal Kestra warnings about "flowwithsources")
    # Our flows are valid if exit code is 0
    if $validation.exit_code == 0 {
      print "✅ valid"
      $results = ($results | append {flow: $flowname, status: "valid"})
    } else {
      print "❌ FAILED"
      print ""
      print "    Error details:"
      $validation.stderr | lines | each {|line| print $"    ($line)"}
      print ""
      $results = ($results | append {flow: $flowname, status: "failed"})
    }
  }

  let valid_count = ($results | where status == "valid" | length)
  let total_count = ($results | length)
  let failed_count = $total_count - $valid_count

  print ""
  print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  print $"Results: ($valid_count)/($total_count) flows valid"

  if $failed_count > 0 {
    print $"❌ ($failed_count) flow\(s\) failed validation"
    exit 1
  } else {
    print "✅ All flows validated successfully!"
    exit 0
  }
}
