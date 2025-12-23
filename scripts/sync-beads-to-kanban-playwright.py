#!/usr/bin/env python3
"""
Sync Beads to Vibe Kanban using Playwright browser automation
Automatically creates tasks in the Kanban board via the web UI
"""

import json
import asyncio
from pathlib import Path
from typing import List, Dict, Any
import sys

try:
    from playwright.async_api import async_playwright, expect
except ImportError:
    print("[!] Playwright not installed. Install with:")
    print("    pip install playwright")
    print("    playwright install")
    sys.exit(1)


class BeadsToKanbanSync:
    def __init__(self, kanban_url: str = "http://127.0.0.1:34107"):
        self.kanban_url = kanban_url
        self.project_id = "522ec0f8-0cec-4533-8a2f-ac134da90b26"
        self.created = 0
        self.failed = 0
        self.skipped = 0

    async def load_tasks(self, export_file: str) -> List[Dict[str, Any]]:
        """Load exported tasks from JSONL file"""
        tasks = []
        if not Path(export_file).exists():
            print(f"[!] File not found: {export_file}")
            return []

        with open(export_file, 'r') as f:
            for line in f:
                if line.strip():
                    try:
                        tasks.append(json.loads(line))
                    except json.JSONDecodeError:
                        pass
        return tasks

    async def add_task_via_ui(self, page, task: Dict[str, Any]) -> bool:
        """Add a single task via the Kanban UI"""
        try:
            # Try to find "Add Task" button or similar
            # This is UI-specific and may need adjustment based on Vibe Kanban's actual UI

            # Look for an add button
            add_button = await page.query_selector('button:has-text("Add Task"), button:has-text("+ Task"), button:has-text("New Task"), .add-task-btn, .btn-add')

            if not add_button:
                # Try clicking in empty area or look for other patterns
                print(f"[⚠] Could not find 'Add Task' button for {task.get('id', 'unknown')}")
                return False

            await add_button.click()
            await page.wait_for_timeout(500)

            # Fill in task details
            # These selectors are examples and may need adjustment

            # Try to find and fill title input
            title_input = await page.query_selector('input[placeholder*="title"], input[placeholder*="Task name"], textarea')
            if title_input:
                await title_input.fill(task.get('title', ''))

            # Try to find and fill description
            desc_input = await page.query_selector('textarea[placeholder*="description"], textarea:nth-of-type(2)')
            if desc_input:
                await desc_input.fill(task.get('description', ''))

            # Try to set status
            status = task.get('status', 'todo')
            status_selector = await page.query_selector(f'[data-status="{status}"], .status-{status}')
            if status_selector:
                await status_selector.click()

            # Submit the task (look for Save button)
            save_button = await page.query_selector('button:has-text("Save"), button:has-text("Add"), button:has-text("Create")')
            if save_button:
                await save_button.click()
                await page.wait_for_timeout(300)
                return True

            return False

        except Exception as e:
            print(f"[!] Error adding task {task.get('id', 'unknown')}: {e}")
            return False

    async def sync(self, export_file: str = "/tmp/beads-tasks-export.jsonl"):
        """Main sync method"""
        print("\n" + "="*70)
        print("  Beads → Vibe Kanban Sync (Browser Automation)")
        print("="*70 + "\n")

        # Load tasks
        tasks = await self.load_tasks(export_file)
        if not tasks:
            print(f"[!] No tasks found in {export_file}")
            return 1

        print(f"[+] Loaded {len(tasks)} tasks from {export_file}\n")

        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=False)  # headless=False so you can see it
            context = await browser.new_context(viewport={"width": 1280, "height": 720})
            page = await context.new_page()

            try:
                # Navigate to Kanban board
                kanban_url = f"{self.kanban_url}/projects/{self.project_id}/tasks"
                print(f"[*] Opening Kanban board: {kanban_url}")
                await page.goto(kanban_url, wait_until="networkidle")
                await page.wait_for_timeout(1000)

                print(f"[*] Starting task creation (this may take a while)...\n")

                # Add each task
                for i, task in enumerate(tasks, 1):
                    task_id = task.get('id', 'unknown')
                    task_title = task.get('title', '')[:50]

                    print(f"[{i}/{len(tasks)}] Adding: {task_id} - {task_title}")

                    success = await self.add_task_via_ui(page, task)
                    if success:
                        self.created += 1
                        print(f"      ✓ Created")
                    else:
                        self.failed += 1
                        print(f"      ✗ Failed")

                    # Small delay between tasks
                    await page.wait_for_timeout(200)

            except Exception as e:
                print(f"\n[!] Sync interrupted: {e}")

            finally:
                await browser.close()

        # Print summary
        print(f"\n" + "="*70)
        print(f"  Sync Summary")
        print("="*70)
        print(f"  Created: {self.created}")
        print(f"  Failed:  {self.failed}")
        print(f"  Skipped: {self.skipped}")
        print(f"  Total:   {len(tasks)}")
        print("="*70 + "\n")

        return 0 if self.failed == 0 else 1


async def main():
    """Main entry point"""
    sync = BeadsToKanbanSync()
    return await sync.sync()


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
