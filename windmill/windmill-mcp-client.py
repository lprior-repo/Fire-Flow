#!/usr/bin/env python3
"""
Windmill MCP Client - Direct integration with Windmill MCP server
Usage: ./windmill-mcp-client.py <method> [args...]
"""

import sys
import json
import http.client
import urllib.parse
from typing import Any, Dict

WINDMILL_HOST = "localhost"
WINDMILL_PORT = 8200
WORKSPACE = "test"
TOKEN = "wElhroB23fQCcI38yY9EtQwmVgm7eE2D"

def send_mcp_request(method: str, params: Dict[str, Any] = None, request_id: int = 1) -> Dict:
    """Send JSON-RPC request to Windmill MCP endpoint"""

    url = f"/api/mcp/w/{WORKSPACE}/sse?token={TOKEN}"

    request_body = {
        "jsonrpc": "2.0",
        "method": method,
        "id": request_id
    }

    if params:
        request_body["params"] = params

    conn = http.client.HTTPConnection(WINDMILL_HOST, WINDMILL_PORT, timeout=30)

    try:
        conn.request(
            "POST",
            url,
            json.dumps(request_body),
            {
                "Content-Type": "application/json",
                "Accept": "application/json, text/event-stream"
            }
        )

        response = conn.getresponse()
        data = response.read().decode('utf-8')

        # Parse SSE response (starts with "data: ")
        if data.startswith("data: "):
            data = data[6:]  # Remove "data: " prefix

        result = json.loads(data)
        return result

    finally:
        conn.close()

def list_tools() -> None:
    """List all available Windmill tools/scripts/flows"""
    result = send_mcp_request("tools/list")
    tools = result.get("result", {}).get("tools", [])

    print(f"Found {len(tools)} tools:\n")
    for tool in tools:
        name = tool.get("name", "unknown")
        title = tool.get("title", "")
        desc = tool.get("description", "")[:60]
        print(f"  {name}")
        if title:
            print(f"    Title: {title}")
        if desc:
            print(f"    Desc: {desc}...")
        print()

def call_tool(tool_name: str, args: Dict[str, Any]) -> None:
    """Call a Windmill tool with arguments"""
    result = send_mcp_request(
        "tools/call",
        {
            "name": tool_name,
            "arguments": args
        }
    )

    if result.get("error"):
        print(f"Error: {result['error']}")
        return

    content = result.get("result", {}).get("content", [])
    for item in content:
        if item.get("type") == "text":
            print(item.get("text", ""))

def run_flow(flow_name: str, args: Dict[str, Any]) -> None:
    """Convenience function to run a Fire-Flow contract_loop"""
    if flow_name == "contract_loop":
        tool_name = "f-f_fire-flow_contract__loop"
    else:
        tool_name = flow_name

    call_tool(tool_name, args)

def main():
    if len(sys.argv) < 2:
        print("Usage:")
        print("  ./windmill-mcp-client.py list                    - List all tools")
        print("  ./windmill-mcp-client.py call <tool> <json_args> - Call a tool")
        print("  ./windmill-mcp-client.py flow contract_loop <json_args> - Run contract loop")
        sys.exit(1)

    command = sys.argv[1]

    if command == "list":
        list_tools()

    elif command == "call":
        if len(sys.argv) < 4:
            print("Usage: windmill-mcp-client.py call <tool_name> <json_args>")
            sys.exit(1)
        tool_name = sys.argv[2]
        args = json.loads(sys.argv[3])
        call_tool(tool_name, args)

    elif command == "flow":
        if len(sys.argv) < 4:
            print("Usage: windmill-mcp-client.py flow <flow_name> <json_args>")
            sys.exit(1)
        flow_name = sys.argv[2]
        args = json.loads(sys.argv[3])
        run_flow(flow_name, args)

    else:
        print(f"Unknown command: {command}")
        sys.exit(1)

if __name__ == "__main__":
    main()
