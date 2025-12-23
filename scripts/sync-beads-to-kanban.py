#!/usr/bin/env python3
"""
Sync Beads issues to Vibe Kanban board
Reads from bd list output and creates tasks in Vibe Kanban via API
"""

import json
import subprocess
import requests
import sys
from typing import List, Dict, Any
from datetime import datetime

# Configuration
KANBAN_BASE_URL = "http://127.0.0.1:34107/api"
PROJECT_ID = "522ec0f8-0cec-4533-8a2f-ac134da90b26"
KANBAN_PROJECT_URL = f"{KANBAN_BASE_URL}/projects/{PROJECT_ID}"

# Status mapping: Beads → Vibe Kanban
STATUS_MAP = {
    "open": "todo",
    "in_progress": "in_progress",
    "in_review": "in_review",
    "closed": "done",
}

# Priority mapping
PRIORITY_MAP = {
    "P0": 5,  # Critical
    "P1": 4,  # High
    "P2": 3,  # Medium
    "P3": 2,  # Low
    "P4": 1,  # Backlog
}


def get_beads_issues() -> List[Dict[str, Any]]:
    """Fetch all Beads issues"""
    print("[*] Fetching Beads issues...")
    try:
        result = subprocess.run(
            ["bd", "list", "--format", "json"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if result.returncode != 0:
            print(f"[!] Error running bd list: {result.stderr}")
            return []

        # Parse each line as JSON (JSONL format)
        issues = []
        for line in result.stdout.strip().split('\n'):
            if not line.strip():
                continue
            try:
                issue = json.loads(line)
                issues.append(issue)
            except json.JSONDecodeError:
                # Fallback: parse from text format
                # Format: "Fire-Flow-4ik.4 [P2] [task] open - Update fire-flow watch command..."
                parts = line.split(' - ', 1)
                if len(parts) == 2:
                    meta = parts[0].strip()
                    title = parts[1].strip()

                    # Extract ID, priority, type, status
                    meta_parts = meta.split()
                    issue_id = meta_parts[0] if meta_parts else "unknown"
                    priority = meta_parts[1] if len(meta_parts) > 1 else "[P2]"
                    issue_type = meta_parts[2] if len(meta_parts) > 2 else "[task]"
                    status = meta_parts[3] if len(meta_parts) > 3 else "open"

                    issues.append({
                        "id": issue_id,
                        "title": title,
                        "priority": priority.strip("[]"),
                        "type": issue_type.strip("[]"),
                        "status": status,
                    })

        print(f"[+] Found {len(issues)} Beads issues")
        return issues
    except Exception as e:
        print(f"[!] Exception fetching Beads issues: {e}")
        return []


def create_kanban_task(issue: Dict[str, Any]) -> bool:
    """Create a task in Vibe Kanban"""

    # Extract fields from Beads issue
    task_title = issue.get("title", "")
    task_description = issue.get("description", "") or f"Beads Issue: {issue.get('id', '')}"
    beads_status = issue.get("status", "open")
    priority = issue.get("priority", "P2")
    issue_type = issue.get("type", "task")

    # Map to Kanban status
    kanban_status = STATUS_MAP.get(beads_status, "todo")

    # Build task payload
    payload = {
        "title": task_title,
        "description": task_description,
        "status": kanban_status,
        "priority": PRIORITY_MAP.get(priority, 3),
        "tags": [issue_type, priority],
        "metadata": {
            "beads_id": issue.get("id", ""),
            "beads_status": beads_status,
            "synced_at": datetime.now().isoformat(),
        }
    }

    try:
        response = requests.post(
            f"{KANBAN_PROJECT_URL}/tasks",
            json=payload,
            timeout=10,
        )

        if response.status_code in [200, 201]:
            task_data = response.json()
            print(f"[✓] Created: {issue.get('id', 'unknown'):20} -> {task_title[:50]}")
            return True
        else:
            print(f"[!] Failed to create {issue.get('id', 'unknown')}: {response.status_code}")
            print(f"    Response: {response.text[:200]}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"[!] Exception creating task for {issue.get('id', 'unknown')}: {e}")
        return False


def check_kanban_health() -> bool:
    """Verify Vibe Kanban is accessible"""
    try:
        response = requests.get(f"{KANBAN_PROJECT_URL}", timeout=5)
        if response.status_code == 200:
            project = response.json()
            print(f"[+] Connected to Vibe Kanban project: {project.get('data', {}).get('name', 'Unknown')}")
            return True
        else:
            print(f"[!] Vibe Kanban returned status {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"[!] Cannot connect to Vibe Kanban: {e}")
        return False


def main():
    print("\n" + "="*60)
    print("  Beads → Vibe Kanban Sync")
    print("="*60 + "\n")

    # Check Kanban health
    if not check_kanban_health():
        print("\n[!] Vibe Kanban is not accessible")
        print(f"    URL: {KANBAN_PROJECT_URL}")
        return 1

    # Fetch Beads issues
    issues = get_beads_issues()
    if not issues:
        print("[!] No Beads issues found")
        return 1

    # Create tasks in Kanban
    print(f"\n[*] Creating {len(issues)} tasks in Vibe Kanban...\n")
    created = 0
    failed = 0

    for issue in issues:
        if create_kanban_task(issue):
            created += 1
        else:
            failed += 1

    # Summary
    print(f"\n" + "="*60)
    print(f"  Sync Complete")
    print("="*60)
    print(f"  Created: {created} tasks")
    print(f"  Failed:  {failed} tasks")
    print(f"  Total:   {len(issues)} issues")
    print("="*60 + "\n")

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
