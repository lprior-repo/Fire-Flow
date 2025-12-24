#!/bin/bash

# Kestra Testing and Validation Script
set -e

KESTRA_URL="${KESTRA_URL:-http://localhost:4200}"
KESTRA_TOKEN="${KESTRA_TOKEN:-}"
NAMESPACE="fire.flow"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 Kestra Workflow Testing Script"
echo "=================================="
echo ""

# Check connectivity
echo "[1/5] Testing Kestra connectivity..."
if curl -s -o /dev/null -w "%{http_code}" "$KESTRA_URL/api/v1/settings" | grep -q "401\|200"; then
    echo -e "${GREEN}✓${NC} Kestra is accessible at $KESTRA_URL"
else
    echo -e "${RED}✗${NC} Cannot reach Kestra at $KESTRA_URL"
    exit 1
fi

echo ""
echo "[2/5] Checking API authentication..."
if [ -z "$KESTRA_TOKEN" ]; then
    echo -e "${YELLOW}⚠${NC}  KESTRA_TOKEN not set. Some tests will be skipped."
    echo "    Set token: export KESTRA_TOKEN='your-token-here'"
    NO_TOKEN=true
else
    echo -e "${GREEN}✓${NC} API token is set"
    NO_TOKEN=false
fi

echo ""
echo "[3/5] Checking Fire-Flow binary..."
if [ -f "/home/lewis/src/Fire-Flow/bin/fire-flow" ]; then
    echo -e "${GREEN}✓${NC} Fire-Flow binary found"
else
    echo -e "${YELLOW}⚠${NC}  Fire-Flow binary not found. Rebuilding..."
    cd /home/lewis/src/Fire-Flow
    go build -o bin/fire-flow ./cmd/fire-flow
    echo -e "${GREEN}✓${NC} Binary rebuilt"
fi

echo ""
echo "[4/5] Testing workflow deployment..."

if [ "$NO_TOKEN" = false ]; then
    echo "Listing workflows in '$NAMESPACE' namespace:"
    curl -s -H "Authorization: Bearer $KESTRA_TOKEN" \
        "$KESTRA_URL/api/v1/flows?namespace=$NAMESPACE" \
        | python3 -m json.tool | head -30
else
    echo -e "${YELLOW}⚠${NC}  Skipping workflow listing (no token)"
fi

echo ""
echo "[5/5] Testing workflow execution..."

if [ "$NO_TOKEN" = false ]; then
    echo "Triggering hello-flow test..."
    RESPONSE=$(curl -s -X POST \
        -H "Authorization: Bearer $KESTRA_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{}' \
        "$KESTRA_URL/api/v1/flows/fire.flow/fire-flow-hello/executions")
    
    if echo "$RESPONSE" | grep -q "execution"; then
        EXEC_ID=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('id', 'unknown'))")
        echo -e "${GREEN}✓${NC} Workflow triggered successfully"
        echo "  Execution ID: $EXEC_ID"
        echo "  View in UI: $KESTRA_URL/flows/fire.flow/fire-flow-hello?executionId=$EXEC_ID"
    else
        echo -e "${RED}✗${NC} Failed to trigger workflow"
        echo "Response: $RESPONSE"
    fi
else
    echo -e "${YELLOW}⚠${NC}  Skipping execution test (no token)"
fi

echo ""
echo "=================================="
echo "Testing complete!"
echo ""
echo "Next steps:"
echo "1. If workflows don't appear, deploy them via Kestra UI:"
echo "   - Open http://localhost:4200"
echo "   - Create new flows from YAML files in kestra/flows/"
echo "2. Generate API token in Kestra UI Settings"
echo "3. Run this script with token:"
echo "   export KESTRA_TOKEN='your-token'"
echo "   bash scripts/kestra-test.sh"
