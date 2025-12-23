#!/usr/bin/env python3
"""
Insert Beads tasks directly into Vibe Kanban SQLite database
Reads exported JSONL and creates tasks via direct SQL insertion
"""

import json
import sqlite3
import uuid
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any

DB_PATH = Path.home() / ".local/share/vibe-kanban/db.sqlite"
PROJECT_ID = "522ec0f8-0cec-4533-8a2f-ac134da90b26"

def uuid_to_blob(uuid_str: str) -> bytes:
    """Convert UUID string to binary blob for SQLite"""
    return uuid.UUID(uuid_str).bytes

def load_tasks(export_file: str) -> List[Dict[str, Any]]:
    """Load exported tasks from JSONL file"""
    tasks = []
    if not Path(export_file).exists():
        print(f"[!] File not found: {export_file}")
        return []

    with open(export_file, 'r') as f:
        for line in f:
            if line.strip():
                try:
                    task = json.loads(line)
                    tasks.append(task)
                except json.JSONDecodeError as e:
                    print(f"[!] JSON parse error: {e}")
    return tasks

def insert_tasks(export_file: str = "/tmp/beads-tasks-export.jsonl"):
    """Insert tasks into Vibe Kanban database"""
    print("\n" + "="*70)
    print("  Inserting Beads Tasks → Vibe Kanban Database")
    print("="*70 + "\n")

    # Check database exists
    if not DB_PATH.exists():
        print(f"[!] Database not found: {DB_PATH}")
        print("[*] Make sure Vibe Kanban is running and has initialized the database")
        return 1

    print(f"[+] Database: {DB_PATH}")

    # Load tasks
    tasks = load_tasks(export_file)
    if not tasks:
        print(f"[!] No tasks found in {export_file}")
        return 1

    print(f"[+] Loaded {len(tasks)} tasks from {export_file}\n")

    try:
        conn = sqlite3.connect(str(DB_PATH))
        cursor = conn.cursor()

        # Convert project_id to blob
        project_id_blob = uuid_to_blob(PROJECT_ID)

        created = 0
        failed = 0

        print(f"[*] Inserting tasks into database...\n")

        for i, task in enumerate(tasks, 1):
            try:
                # Generate unique ID for this task
                task_id = uuid.uuid4().bytes

                # Map status - ensure it's valid
                status = task.get('status', 'todo')
                if status not in ['todo', 'inprogress', 'done', 'cancelled', 'inreview']:
                    status = 'todo'

                title = task.get('title', 'Untitled')[:255]  # Limit title length
                description = task.get('description', '')
                now = datetime.now().isoformat()

                # Insert task
                cursor.execute("""
                    INSERT INTO tasks (id, project_id, title, description, status, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                """, (task_id, project_id_blob, title, description, status, now, now))

                beads_id = task.get('id', 'unknown')
                task_title = title[:40]
                print(f"[{i:2d}/{len(tasks)}] ✓ {beads_id:20} - {task_title}")
                created += 1

            except sqlite3.IntegrityError as e:
                print(f"[{i:2d}/{len(tasks)}] ✗ {task.get('id', 'unknown')} - Database constraint: {e}")
                failed += 1
            except Exception as e:
                print(f"[{i:2d}/{len(tasks)}] ✗ {task.get('id', 'unknown')} - Error: {e}")
                failed += 1

        # Commit changes
        conn.commit()

        # Verify insertion
        cursor.execute("SELECT COUNT(*) FROM tasks WHERE project_id = ?", (project_id_blob,))
        total_in_db = cursor.fetchone()[0]

        conn.close()

        # Print summary
        print(f"\n" + "="*70)
        print(f"  Insertion Summary")
        print("="*70)
        print(f"  Created:    {created} tasks")
        print(f"  Failed:     {failed} tasks")
        print(f"  Total in DB: {total_in_db} tasks for project")
        print("="*70 + "\n")

        if created > 0:
            print(f"[+] Successfully inserted {created} tasks into Vibe Kanban")
            print(f"[*] Refresh your Vibe Kanban UI to see the new tasks")

        return 0 if failed == 0 else 1

    except sqlite3.OperationalError as e:
        print(f"[!] Database error: {e}")
        print("[*] Make sure Vibe Kanban is not currently running")
        return 1
    except Exception as e:
        print(f"[!] Unexpected error: {e}")
        return 1

if __name__ == "__main__":
    import sys
    sys.exit(insert_tasks())
