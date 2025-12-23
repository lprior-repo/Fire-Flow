# Fire-Flow Agent Instructions

This project supports **Claude Code** and **QWEN** as primary development agents, integrated with **Beads (bd)** for issue tracking and **Vibe Kanban** for task management.

---

## 🤖 Agent Overview

### **Claude Code** (Recommended Primary Agent)

**What it is:** Anthropic's official CLI for Claude, providing direct access to Claude AI models for software engineering tasks.

**Capabilities:**
- ✅ Code analysis, generation, and refactoring
- ✅ Test-Driven Development (Red-Green-Refactor)
- ✅ Bug fixes with context understanding
- ✅ Documentation writing and updates
- ✅ Architecture design and planning
- ✅ Direct file manipulation and git integration
- ✅ Tool use: Bash, Read, Write, Edit, Glob, Grep, Task agents
- ✅ MCP server integration for extended capabilities

**When to use:**
- Complex code changes requiring reasoning
- Multi-step development tasks
- Documentation and knowledge work
- Architecture decisions
- Code review and refactoring

**Usage in Fire-Flow:**
```bash
# Claude Code is invoked by Vibe Kanban automatically
# Or manually via Claude Code CLI tool
claude-code  # Opens interactive shell
```

**See:** [QWEN.md](./QWEN.md) for detailed Claude Code integration, conventions, and TDD patterns.

---

### **QWEN** (Alternative Agent)

**What it is:** Alibaba's large language model, available as an alternative agent for task execution.

**Capabilities:**
- ✅ Code understanding and generation
- ✅ Testing and validation
- ✅ Documentation tasks
- ✅ Refactoring assistance
- ✅ API integration work

**When to use:**
- Lighter weight tasks
- Parallel execution of independent tasks
- Tasks with clear specifications
- Documentation and content generation

**Usage in Fire-Flow:**
```bash
# QWEN is available through Vibe Kanban task assignment
# Can be selected as alternative to Claude Code
```

**See:** [QWEN.md](./QWEN.md) for detailed agent configuration and capabilities.

---

## 📋 Quick Reference

### **Beads CLI (Issue Tracking)**
```bash
bd ready              # Find available work (issues ready for development)
bd list               # Show all issues
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work (mark started)
bd update <id> --status done         # Complete work
bd sync               # Sync Beads issues with git repository
bd import             # Import issues from JSONL
```

### **Vibe Kanban (Task Board)**
```bash
# Vibe Kanban runs at: http://127.0.0.1:34107
# Project ID: 522ec0f8-0cec-4533-8a2f-ac134da90b26

# Via browser:
# 1. Go to Kanban board
# 2. Assign task to Claude Code or QWEN
# 3. Monitor execution in real-time
```

### **Fire-Flow CLI (Execution)**
```bash
./bin/fire-flow init              # Initialize TCR state
./bin/fire-flow status            # Show TCR enforcement status
./bin/fire-flow tdd-gate          # Check TDD requirements
./bin/fire-flow run-tests         # Execute test suite
./bin/fire-flow commit            # Commit changes
./bin/fire-flow revert            # Revert on test failure
```

---

## 🎯 Agent Workflow Integration

### **1. Task Discovery & Assignment**

**In Vibe Kanban:**
```
Task Created in Kanban
         ↓
Agent Assigned (Claude Code or QWEN)
         ↓
Worktree Spun Up (git worktree add)
         ↓
Startup Script Runs (./scripts/startup.sh)
         ↓
Agent Executes Task
         ↓
Results Posted Back
```

**In Beads CLI:**
```bash
# View available work
bd ready

# Claim a task
bd update Fire-Flow-11f.1.1 --status in_progress

# Work on the task
# ... (agent does work) ...

# Mark complete
bd update Fire-Flow-11f.1.1 --status done
```

### **2. Development Process (Claude Code)**

For detailed TDD workflow and idiomatic Go patterns, see **[QWEN.md](./QWEN.md)**.

**Quick workflow:**
```bash
# 1. Check startup
./scripts/startup.sh --verify-only

# 2. Red-Green-Refactor cycle
go test -v ./...           # RED - see test fail
# ... implement code ...
go test -v ./...           # GREEN - test passes
# ... refactor ...
go test -v ./...           # REFACTOR - still passes

# 3. Commit work
git add -A
bd sync
git commit -m "Feature: implement X"

# 4. Complete Landing the Plane (see below)
```

---

## 🛬 Landing the Plane (Session Completion Protocol)

**CRITICAL:** Work is NOT complete until `git push` succeeds. This protocol MUST be followed at the end of EVERY work session.

### **Seven-Step Mandatory Completion**

1. **Status Check**
   ```bash
   git status              # See all changes
   bd list                 # Check issue status
   ```

2. **Stage Changes**
   ```bash
   git add -A              # Stage everything
   ```

3. **Sync with Beads**
   ```bash
   bd sync                 # Sync issue tracker
   ```

4. **Commit Work**
   ```bash
   git commit -m "$(cat <<'EOF'
   <Your detailed commit message>

   🤖 Generated with [Claude Code](https://claude.com/claude-code)

   Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
   EOF
   )"
   ```

5. **Sync Again**
   ```bash
   bd sync                 # Final sync
   ```

6. **Push to Remote**
   ```bash
   git push                # MANDATORY - this is the critical step
   ```

7. **Verify Success**
   ```bash
   git status              # MUST show "Your branch is up to date with 'origin/main'"
   ```

### **Critical Rules**

- ⚠️ **Work is NOT complete until `git push` succeeds**
- ⚠️ **NEVER stop before pushing** - that leaves work stranded locally
- ⚠️ **NEVER say "ready to push when you are"** - YOU must push
- ⚠️ **If push fails:** Resolve the error and retry until success
- ⚠️ **If rebase conflicts appear:** Fix conflicts and retry
- ⚠️ **Leave the repository in a clean state** for the next session

### **Example Landing the Plane**

```bash
# Step 1: Check status
$ git status
On branch main
Your branch is ahead of 'origin/main' by 1 commit.

# Step 2: Stage changes
$ git add -A

# Step 3: Sync Beads
$ bd sync
✓ Sync complete

# Step 4: Commit
$ git commit -m "Implement Command interface for CLI consistency"

# Step 5: Sync again
$ bd sync

# Step 6: Push (MANDATORY)
$ git push
To https://github.com/lprior-repo/Fire-Flow.git
   f783e86..959ec2f  main -> main

# Step 7: Verify
$ git status
On branch main
Your branch is up to date with 'origin/main'.
✅ SUCCESS - Work is complete and pushed!
```

---

## 🔧 Startup & Environment Setup

When a worktree is created, agents should run:

```bash
# Verify tools are available
./scripts/startup.sh --verify-only

# Full startup (builds binaries, initializes config)
./scripts/startup.sh

# Check startup log for any warnings
cat .opencode/startup.log
```

**Auto-generated during startup:**
- `.opencode/config.json` - Central configuration
- `.env` - Environment variables
- `.opencode/tcr/state.json` - TCR state tracking
- `bin/fire-flow` - Compiled CLI binary

---

## 📚 Key Documentation Files

| File | Purpose | For |
|------|---------|-----|
| **[QWEN.md](./QWEN.md)** | Agent instructions, TDD patterns, Go idioms | **Claude Code & all agents** |
| **[SDLC_VIBE_KANBAN_SETUP.md](./SDLC_VIBE_KANBAN_SETUP.md)** | SDLC practices, Kanban setup | **Understanding methodology** |
| **[STARTUP_GUIDE.md](./STARTUP_GUIDE.md)** | Startup script documentation | **Environment initialization** |
| **[NEXT_STAGES_FROM_MEM0.md](./NEXT_STAGES_FROM_MEM0.md)** | Implementation roadmap | **Understanding architecture** |
| **[README.md](./README.md)** | Project overview | **Getting started** |

---

## 🎲 Choosing the Right Agent

### **Use Claude Code When:**
- Task requires complex reasoning or multi-step logic
- Architecture decisions need to be made
- Code refactoring across multiple files
- Bug investigation and root cause analysis
- TDD implementation with cycle management
- Documentation and knowledge work

### **Use QWEN When:**
- Simple, well-defined tasks
- Parallel execution of independent tasks
- Quick code generation tasks
- Testing and validation work
- Documentation updates
- Integration work with clear specs

---

## 🔗 Integration Points

### **Vibe Kanban → Worktree → Agent**
```
Kanban Task
    ↓
git worktree create (isolated environment)
    ↓
./scripts/startup.sh (initialize environment)
    ↓
Agent (Claude Code or QWEN) executes task
    ↓
Results captured in .opencode/tcr/results/
    ↓
Worktree removed (clean up)
```

### **Beads → Issue Tracking**
```
Beads Issues (bd list)
    ↓
Exported to Vibe Kanban (Beads → JSONL → Kanban)
    ↓
Agent assigns to self or completes
    ↓
Mark done in Kanban
    ↓
Sync back to Beads (bd sync)
    ↓
Git integration maintained
```

---

## ⚠️ Common Gotchas

### **Gotcha 1: Forgetting to Push**
```bash
# ❌ WRONG - Session ends, work is stranded
git commit -m "Fix bug"
# (closes terminal without pushing)

# ✅ RIGHT - Complete Landing the Plane
git commit -m "Fix bug"
bd sync
git push
git status  # Verify pushed
```

### **Gotcha 2: Not Running Startup**
```bash
# ❌ WRONG - Binary might be stale
./bin/fire-flow run-tests

# ✅ RIGHT - Fresh startup ensures fresh build
./scripts/startup.sh
./bin/fire-flow run-tests
```

### **Gotcha 3: Ignoring Test Failures**
```bash
# ❌ WRONG - Commit with failing tests
go test ./...  # FAIL
git commit -m "Work in progress"

# ✅ RIGHT - TDD: Red-Green-Refactor
go test ./...  # RED - see failure
# ... fix code ...
go test ./...  # GREEN - passes
git commit -m "Feature: implement X"
```

### **Gotcha 4: Working on Multiple Tasks**
```bash
# ❌ WRONG - Multiple uncommitted changes
bd update task1 --status in_progress
# ... work on task1 ...
bd update task2 --status in_progress
# ... work on task2 ...
# (which task is this commit for?)

# ✅ RIGHT - Complete one task, land plane, move to next
bd update task1 --status in_progress
# ... work on task1 ...
git commit -m "Complete task1"
bd sync && git push  # Landing the Plane
bd update task2 --status in_progress
# ... work on task2 ...
```

---

## 📞 Getting Help

### **For Claude Code:**
- `/help` - Claude Code help command
- View [QWEN.md](./QWEN.md) - Complete agent instructions
- Check [STARTUP_GUIDE.md](./STARTUP_GUIDE.md) - Environment setup help
- Report issues: https://github.com/anthropics/claude-code/issues

### **For QWEN:**
- Check task requirements in Vibe Kanban
- Reference [QWEN.md](./QWEN.md) for conventions
- Review similar completed tasks
- Update issue with questions via bd

### **For Fire-Flow:**
- `./bin/fire-flow --help` - CLI help
- Review [NEXT_STAGES_FROM_MEM0.md](./NEXT_STAGES_FROM_MEM0.md) - Architecture
- Check Beads issues: `bd ready`
- View Kanban board: http://127.0.0.1:34107

---

## 📊 Agent Metrics & Tracking

**Via Beads:**
```bash
bd list              # See all issues and status
bd show <id>         # View issue metrics
```

**Via Vibe Kanban:**
- Real-time task progress dashboard
- Agent execution logs
- Worktree isolation metrics
- Success/failure tracking

**Via Fire-Flow:**
```bash
./bin/fire-flow status   # Show TCR enforcement status
cat .opencode/startup.log # View startup metrics
```

---

## 🚀 Best Practices

1. **Read the requirements** - Always understand the task fully before starting
2. **Check QWEN.md** - Reference conventions, patterns, and examples
3. **Run startup** - Always ensure fresh environment: `./scripts/startup.sh`
4. **Follow TDD** - Red-Green-Refactor cycle for code changes
5. **Commit frequently** - Make logical commits with clear messages
6. **Land the plane** - ALWAYS complete the 7-step protocol at session end
7. **Test thoroughly** - Run tests before committing
8. **Update Beads** - Mark issues as complete when done
9. **Document changes** - Update relevant docs when changing behavior
10. **Ask for help** - Use issue descriptions and comments for clarification

---

## 📅 Session Handoff Template

When handing off to another agent/session:

```markdown
## Session Summary

**Completed:**
- [x] Task 1: Description
- [x] Task 2: Description

**In Progress:**
- [ ] Task 3: Description (currently at step X)

**Blockers:**
- Issue X prevents completion of task Y (needs: ...)

**Recommendations:**
- Next agent should focus on task 3 after addressing blocker

**State Files:**
- Beads issues updated: see `bd list`
- State file: `.opencode/tcr/state.json`
- Startup log: `.opencode/startup.log`

**Landing the Plane Status:**
✅ All work committed and pushed to origin/main
```

---

**Last Updated:** 2025-12-23
**Status:** Ready for agent use
**Integration:** Vibe Kanban ↔ Beads ↔ Git ↔ Fire-Flow CLI
