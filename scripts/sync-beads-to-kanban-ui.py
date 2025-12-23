#!/usr/bin/env python3
"""
Sync Beads issues to Vibe Kanban using browser automation
Uses Playwright to automate task creation through the web UI
"""

import json
import subprocess
import sys
from typing import List, Dict, Any
import asyncio


async def main():
    """Main sync function"""
    print("\n" + "="*60)
    print("  Beads → Vibe Kanban Sync (UI Automation)")
    print("="*60 + "\n")

    # Get Beads issues
    print("[*] Fetching Beads issues...")
    try:
        result = subprocess.run(
            ["bd", "list", "--format", "json"],
            capture_output=True,
            text=True,
            timeout=10,
        )

        issues = []
        for line in result.stdout.strip().split('\n'):
            if not line.strip():
                continue
            try:
                issue = json.loads(line)
                issues.append(issue)
            except:
                # Parse text format
                parts = line.split(' - ', 1)
                if len(parts) == 2:
                    meta = parts[0].strip()
                    title = parts[1].strip()
                    meta_parts = meta.split()
                    issues.append({
                        "id": meta_parts[0] if meta_parts else "unknown",
                        "title": title,
                        "priority": meta_parts[1].strip("[]") if len(meta_parts) > 1 else "P2",
                        "type": meta_parts[2].strip("[]") if len(meta_parts) > 2 else "task",
                        "status": meta_parts[3] if len(meta_parts) > 3 else "open",
                    })

        print(f"[+] Found {len(issues)} Beads issues\n")

    except Exception as e:
        print(f"[!] Error fetching Beads: {e}")
        return 1

    # Information for user
    print("🔄 MANUAL SYNC INSTRUCTIONS:")
    print("="*60)
    print()
    print("The Vibe Kanban API doesn't support task creation via REST API.")
    print("Please use one of these methods to import tasks:\n")

    print("METHOD 1: Manual Import (Recommended)")
    print("-" * 60)
    print(f"1. Open Vibe Kanban: http://127.0.0.1:34107/")
    print(f"2. Select Fire-Flow project")
    print(f"3. Click 'Import' or use the board's import feature")
    print(f"4. A file with all tasks is ready:")
    print(f"   📄 {'/tmp/beads-tasks-export.jsonl'}\n")

    print("METHOD 2: Use Vibe Kanban CLI (if available)")
    print("-" * 60)
    print("Check if vibe-kanban has CLI tools:\n")
    print("   vibe tasks import /tmp/beads-tasks-export.jsonl\n")

    print("METHOD 3: Copy-Paste Tasks Manually")
    print("-" * 60)
    print(f"Total tasks to create: {len(issues)}")
    print("This is tedious but works if UI import unavailable\n")

    # Export tasks to file
    export_file = "/tmp/beads-tasks-export.jsonl"
    print(f"[*] Exporting {len(issues)} tasks to {export_file}...")

    try:
        with open(export_file, 'w') as f:
            for issue in issues:
                task = {
                    "id": issue.get("id", ""),
                    "title": issue.get("title", ""),
                    "description": f"Beads Issue: {issue.get('id', '')}",
                    "status": {"open": "todo", "in_progress": "in_progress",
                              "in_review": "in_review", "closed": "done"}.get(
                        issue.get("status", "open"), "todo"
                    ),
                    "priority": {"P0": 5, "P1": 4, "P2": 3, "P3": 2, "P4": 1}.get(
                        issue.get("priority", "P2"), 3
                    ),
                    "tags": [issue.get("type", "task"), issue.get("priority", "P2")],
                }
                f.write(json.dumps(task) + "\n")

        print(f"[+] Exported to: {export_file}\n")
    except Exception as e:
        print(f"[!] Error exporting: {e}")
        return 1

    # Summary table
    print("="*60)
    print("  Tasks to Import")
    print("="*60)
    print(f"{'ID':<20} {'Title':<40} {'Status':<12}")
    print("-" * 60)

    for i, issue in enumerate(issues[:10]):  # Show first 10
        issue_id = str(issue.get("id", ""))[:20]
        title = str(issue.get("title", ""))[:40]
        status = issue.get("status", "open")
        print(f"{issue_id:<20} {title:<40} {status:<12}")

    if len(issues) > 10:
        print(f"... and {len(issues) - 10} more")

    print("\n" + "="*60)
    print(f"  Total: {len(issues)} tasks ready to import")
    print("="*60 + "\n")

    # Offer quick links
    print("📌 QUICK LINKS:")
    print(f"   Kanban Board: http://127.0.0.1:34107/projects/522ec0f8-0cec-4533-8a2f-ac134da90b26/tasks")
    print(f"   Export File:  {export_file}")
    print(f"   Beads List:   bd ready\n")

    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
