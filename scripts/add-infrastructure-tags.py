#!/usr/bin/env python3
"""
Add infrastructure and tool tags to Vibe Kanban tasks
Identifies which tools/services are involved in each task
"""

import sqlite3
import json
from pathlib import Path
from typing import List, Dict, Any
import re

DB_PATH = Path.home() / ".local/share/vibe-kanban/db.sqlite"
PROJECT_ID = "522ec0f8-0cec-4533-8a2f-ac134da90b26"

# Tool/Infrastructure pattern mapping
TOOL_PATTERNS = {
    "tool:cli": ["CLI", "command", "init", "status", "tdd-gate", "run-tests", "commit", "revert"],
    "tool:kestra": ["Kestra", "workflow", "orchestration"],
    "tool:opencode": ["OpenCode", "integration", "webhook"],
    "tool:overlay": ["OverlayFS", "Mounter", "mount", "overlay"],
    "tool:git": ["git", "commit", "revert", "merge"],
    "tool:beads": ["Beads", "issue", "tracking"],
    "tool:kanban": ["Kanban", "board", "task"],
    "tool:python": ["Python", "script", "automation"],
    "tool:docker": ["Docker", "container", "image"],
    "tool:sqlite": ["SQLite", "database"],
}

# Workflow tags
WORKFLOW_PATTERNS = {
    "workflow:tdd": ["test", "TDD", "testing", "unit test"],
    "workflow:ci-cd": ["CI", "CD", "pipeline", "workflow"],
    "workflow:integration": ["integration", "webhook", "OpenCode"],
    "workflow:deployment": ["deploy", "production", "release"],
}

# Feature/Capability tags
FEATURE_PATTERNS = {
    "feature:automation": ["automate", "automatic", "autonomous"],
    "feature:monitoring": ["monitor", "status", "dashboard"],
    "feature:sync": ["sync", "synchronization", "export", "import"],
    "feature:safety": ["isolation", "worktree", "safe"],
}

def uuid_to_blob(uuid_str: str) -> bytes:
    """Convert UUID string to binary blob"""
    import uuid
    return uuid.UUID(uuid_str).bytes

def extract_existing_tags(desc_str: str) -> List[str]:
    """Extract existing tags from description (JSON format)"""
    match = re.search(r'\[Tags: ([^\]]+)\]', desc_str)
    if match:
        tags_str = match.group(1)
        return [t.strip() for t in tags_str.split(',')]
    return []

def analyze_task(title: str, description: str = "") -> List[str]:
    """Analyze task and determine infrastructure/tool tags"""
    tags = set()
    full_text = f"{title} {description}".lower()

    # Check tool patterns
    for tool_tag, patterns in TOOL_PATTERNS.items():
        for pattern in patterns:
            if pattern.lower() in full_text:
                tags.add(tool_tag)
                break

    # Check workflow patterns
    for workflow_tag, patterns in WORKFLOW_PATTERNS.items():
        for pattern in patterns:
            if pattern.lower() in full_text:
                tags.add(workflow_tag)
                break

    # Check feature patterns
    for feature_tag, patterns in FEATURE_PATTERNS.items():
        for pattern in patterns:
            if pattern.lower() in full_text:
                tags.add(feature_tag)
                break

    # Special infrastructure detection
    if "test" in full_text and "state" in full_text:
        tags.add("infrastructure:state-management")
    if "environment" in full_text or "config" in full_text:
        tags.add("infrastructure:configuration")
    if "error" in full_text or "logging" in full_text:
        tags.add("infrastructure:observability")
    if "security" in full_text or "permission" in full_text:
        tags.add("infrastructure:security")

    return sorted(list(tags))

def merge_tags(existing: List[str], new: List[str]) -> List[str]:
    """Merge existing and new tags without duplication"""
    combined = set(existing + new)
    return sorted(list(combined))

def update_task_tags(db_path: str, project_id: str):
    """Update all tasks with infrastructure and tool tags"""
    print("\n" + "="*70)
    print("  Adding Infrastructure & Tool Tags to Vibe Kanban Tasks")
    print("="*70 + "\n")

    if not Path(db_path).exists():
        print(f"[!] Database not found: {db_path}")
        return 1

    try:
        conn = sqlite3.connect(db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()

        project_id_blob = uuid_to_blob(project_id)

        # Get all tasks for this project
        cursor.execute("""
            SELECT id, title, description FROM tasks
            WHERE project_id = ?
            ORDER BY created_at
        """, (project_id_blob,))

        tasks = cursor.fetchall()
        print(f"[*] Found {len(tasks)} tasks to enhance\n")

        updated = 0
        total_tags_added = 0

        for task in tasks:
            task_id = task['id']
            title = task['title']
            description = task['description'] or ""

            # Extract Beads ID
            beads_id = "unknown"
            if "Beads Issue:" in description:
                beads_id = description.replace("Beads Issue:", "").strip()

            # Extract existing tags
            existing_tags = extract_existing_tags(description)

            # Analyze and get new tags
            new_tags = analyze_task(title, description)

            # Merge all tags
            all_tags = merge_tags(existing_tags, new_tags)
            tags_added = len(all_tags) - len(existing_tags)
            total_tags_added += tags_added

            # Update description with merged tags
            new_desc = description.split('[Tags:')[0].rstrip() if '[Tags:' in description else description
            new_desc = f"{new_desc}\n\n[Tags: {', '.join(all_tags)}]"

            try:
                cursor.execute("""
                    UPDATE tasks SET description = ? WHERE id = ?
                """, (new_desc, task_id))

                tag_display = " | ".join(all_tags[:4])  # Show first 4
                if len(all_tags) > 4:
                    tag_display += f" | +{len(all_tags) - 4}"

                print(f"[✓] {beads_id:20} → {tag_display}")
                updated += 1

            except Exception as e:
                print(f"[!] {beads_id:20} - Error: {e}")

        conn.commit()
        conn.close()

        # Print summary
        print(f"\n" + "="*70)
        print(f"  Enhancement Summary")
        print("="*70)
        print(f"  Tasks Updated:    {updated}")
        print(f"  Tags Added:       {total_tags_added}")
        print(f"  Avg Tags/Task:    {total_tags_added/updated:.1f}" if updated > 0 else "")
        print(f"\n  Infrastructure Tags Added:")
        print(f"    • tool:* - Specific tools (cli, kestra, opencode, overlay, git, etc.)")
        print(f"    • workflow:* - Workflow type (tdd, ci-cd, integration, deployment)")
        print(f"    • feature:* - Feature capability (automation, monitoring, sync, safety)")
        print(f"    • infrastructure:* - Infrastructure concern (config, observability, security)")
        print("="*70 + "\n")

        return 0

    except Exception as e:
        print(f"[!] Error: {e}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    import sys
    sys.exit(update_task_tags(str(DB_PATH), PROJECT_ID))
