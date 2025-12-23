#!/usr/bin/env python3
"""
Add comprehensive tags to Vibe Kanban tasks for better organization
Tags include: type, priority, component, epic, status
"""

import sqlite3
import json
from pathlib import Path
from typing import List, Dict, Any
import re

DB_PATH = Path.home() / ".local/share/vibe-kanban/db.sqlite"
PROJECT_ID = "522ec0f8-0cec-4533-8a2f-ac134da90b26"

# Tag mappings based on task title patterns
COMPONENT_PATTERNS = {
    "overlay": ["overlay", "OverlayFS", "Mounter", "mount"],
    "cli": ["CLI", "command", "init", "status", "tcr-enforcer"],
    "tdd-gate": ["tdd-gate", "gate", "test state", "pattern matcher"],
    "orchestration": ["Kestra", "workflow", "orchestration"],
    "git": ["git", "commit", "revert"],
    "testing": ["unit", "test", "Test", "concurrent"],
    "integration": ["OpenCode", "integration", "webhook"],
    "docs": ["Document", "README", "Summary"],
}

EPIC_MAPPING = {
    "11f": "tcr-enforcer-epic",
    "4ik": "overlayfs-epic",
    "5zs": "implementation-complete",
    "8so": "tcr-complete",
    "9dx": "tcr-enforcer-epic",
}

def uuid_to_blob(uuid_str: str) -> bytes:
    """Convert UUID string to binary blob"""
    import uuid
    return uuid.UUID(uuid_str).bytes

def get_components(title: str, description: str = "") -> List[str]:
    """Extract component tags from title and description"""
    full_text = f"{title} {description}".lower()
    components = set()

    for component, patterns in COMPONENT_PATTERNS.items():
        for pattern in patterns:
            if pattern.lower() in full_text:
                components.add(component)
                break

    return sorted(list(components))

def get_epic(beads_id: str) -> str:
    """Determine epic from Beads ID"""
    # Extract prefix (Fire-Flow-XXX part)
    match = re.match(r"Fire-Flow-([a-z0-9]+)", beads_id)
    if match:
        prefix = match.group(1)
        # Check if it's a sub-task (has a dot)
        base_id = prefix.split('.')[0]
        return EPIC_MAPPING.get(base_id, "general")
    return "general"

def get_type_and_status(title: str) -> tuple:
    """Infer task type and status from title"""
    title_lower = title.lower()

    # Determine type
    if "bug" in title_lower or "fix" in title_lower:
        task_type = "bug"
    elif "implement" in title_lower or "add" in title_lower:
        task_type = "feature"
    elif "document" in title_lower or "readme" in title_lower:
        task_type = "docs"
    elif "test" in title_lower or "testing" in title_lower:
        task_type = "testing"
    elif "improve" in title_lower or "refactor" in title_lower or "consolidate" in title_lower:
        task_type = "enhancement"
    else:
        task_type = "task"

    # Determine status (default: backlog)
    status = "backlog"
    if "complete" in title_lower or "done" in title_lower:
        status = "done"
    elif "test" in title_lower or "unit" in title_lower:
        status = "testing"

    return task_type, status

def generate_tags(beads_id: str, title: str, description: str = "") -> List[str]:
    """Generate comprehensive tags for a task"""
    tags = set()

    # 1. Epic tag
    epic = get_epic(beads_id)
    if epic and epic != "general":
        tags.add(f"epic:{epic}")

    # 2. Type tag
    task_type, status = get_type_and_status(title)
    tags.add(f"type:{task_type}")

    # 3. Status tag
    tags.add(f"status:{status}")

    # 4. Component tags
    components = get_components(title, description)
    for component in components:
        tags.add(f"component:{component}")

    # 5. Priority (from description if available)
    if "P0" in description or "critical" in title.lower():
        tags.add("priority:P0")
    elif "P1" in description or "high" in title.lower():
        tags.add("priority:P1")
    elif "P2" in description or description == "":
        tags.add("priority:P2")
    elif "P3" in description:
        tags.add("priority:P3")
    elif "P4" in description or "backlog" in title.lower():
        tags.add("priority:P4")

    # 6. Lifecycle tags
    if "consolidate" in title.lower() or "improve" in title.lower():
        tags.add("lifecycle:refactor")
    if "test" in title.lower():
        tags.add("lifecycle:testing")
    if "document" in title.lower():
        tags.add("lifecycle:documentation")

    return sorted(list(tags))

def update_tags():
    """Update all tasks with better tags"""
    print("\n" + "="*70)
    print("  Adding Comprehensive Tags to Vibe Kanban Tasks")
    print("="*70 + "\n")

    if not DB_PATH.exists():
        print(f"[!] Database not found: {DB_PATH}")
        return 1

    try:
        conn = sqlite3.connect(str(DB_PATH))
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()

        project_id_blob = uuid_to_blob(PROJECT_ID)

        # Get all tasks for this project
        cursor.execute("""
            SELECT id, title, description FROM tasks
            WHERE project_id = ?
            ORDER BY created_at
        """, (project_id_blob,))

        tasks = cursor.fetchall()
        print(f"[*] Found {len(tasks)} tasks to tag\n")

        updated = 0

        for task in tasks:
            task_id = task['id']
            title = task['title']
            description = task['description'] or ""

            # Extract Beads ID from description
            beads_id = "unknown"
            if "Beads Issue:" in description:
                beads_id = description.replace("Beads Issue:", "").strip()

            # Generate comprehensive tags
            tags = generate_tags(beads_id, title, description)
            tags_json = json.dumps(tags)

            # Update task (assuming there's a tags column or metadata)
            # Try updating tags column first, fallback to metadata
            try:
                cursor.execute("""
                    UPDATE tasks SET tags = ? WHERE id = ?
                """, (tags_json, task_id))
            except sqlite3.OperationalError:
                # If tags column doesn't exist, try adding to description
                new_desc = f"{description}\n\n[Tags: {', '.join(tags)}]"
                cursor.execute("""
                    UPDATE tasks SET description = ? WHERE id = ?
                """, (new_desc, task_id))

            tag_display = " | ".join(tags)
            print(f"[✓] {beads_id:20} → {tag_display}")
            updated += 1

        conn.commit()
        conn.close()

        # Print summary
        print(f"\n" + "="*70)
        print(f"  Tagging Summary")
        print("="*70)
        print(f"  Updated: {updated} tasks")
        print(f"  Tags added include:")
        print(f"    • Type: task, feature, bug, docs, testing, enhancement")
        print(f"    • Epic: tcr-enforcer-epic, overlayfs-epic, etc.")
        print(f"    • Status: backlog, testing, done")
        print(f"    • Component: cli, overlay, tdd-gate, orchestration, etc.")
        print(f"    • Priority: P0-P4")
        print(f"    • Lifecycle: refactor, testing, documentation")
        print("="*70 + "\n")

        return 0

    except Exception as e:
        print(f"[!] Error: {e}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    import sys
    sys.exit(update_tags())
