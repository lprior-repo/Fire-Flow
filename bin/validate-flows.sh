#!/usr/bin/env bash
# Standalone script to validate all Kestra flows
# Usage: ./bin/validate-flows.sh

set -e

KESTRA_BIN="kestra"
KESTRA_PLUGINS="/home/lewis/kestra/plugins"
FLOWS_DIR="bitter-truth/kestra/flows"

echo "🔍 Validating Kestra flows in $FLOWS_DIR..."
echo ""

failed=0
total=0

for flow in "$FLOWS_DIR"/*.yml; do
  total=$((total + 1))
  flowname=$(basename "$flow")

  echo -n "  [$total] $flowname ... "

  if $KESTRA_BIN flow validate -p "$KESTRA_PLUGINS" --local "$flow" > /dev/null 2>&1; then
    echo "✅ valid"
  else
    echo "❌ FAILED"
    echo ""
    echo "    Error details:"
    $KESTRA_BIN flow validate -p "$KESTRA_PLUGINS" --local "$flow" 2>&1 | sed 's/^/    /'
    echo ""
    failed=$((failed + 1))
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Results: $((total - failed))/$total flows valid"

if [ $failed -gt 0 ]; then
  echo "❌ $failed flow(s) failed validation"
  exit 1
else
  echo "✅ All flows validated successfully!"
  exit 0
fi
