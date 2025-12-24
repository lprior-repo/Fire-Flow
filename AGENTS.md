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

<skills_system priority="1">

## Available Skills

<!-- SKILLS_TABLE_START -->
<usage>
When users ask you to perform tasks, check if any of the available skills below can help complete the task more effectively. Skills provide specialized capabilities and domain knowledge.

How to use skills:
- Invoke: Bash("openskills read <skill-name>")
- The skill content will load with detailed instructions on how to complete the task
- Base directory provided in output for resolving bundled resources (references/, scripts/, assets/)

Usage notes:
- Only use skills listed in <available_skills> below
- Do not invoke a skill that is already loaded in your context
- Each skill invocation is stateless
</usage>

<available_skills>

<skill>
<name>algorithmic-art</name>
<description>Creating algorithmic art using p5.js with seeded randomness and interactive parameter exploration. Use this when users request creating art using code, generative art, algorithmic art, flow fields, or particle systems. Create original algorithmic art rather than copying existing artists' work to avoid copyright violations.</description>
<location>project</location>
</skill>

<skill>
<name>bdd-beads-planner</name>
<description>"Generate BDD specifications in Gherkin format and create Beads issues with rigorous 5-question refinement methodology. Use when writing user stories, acceptance criteria, BDD specs, Gherkin scenarios, planning epics, features, or stories, converting requirements to specs, or managing Beads issues with proper dependencies."</description>
<location>project</location>
</skill>

<skill>
<name>brand-guidelines</name>
<description>Applies Anthropic's official brand colors and typography to any sort of artifact that may benefit from having Anthropic's look-and-feel. Use it when brand colors or style guidelines, visual formatting, or company design standards apply.</description>
<location>project</location>
</skill>

<skill>
<name>canvas-design</name>
<description>Create beautiful visual art in .png and .pdf documents using design philosophy. You should use this skill when the user asks to create a poster, piece of art, design, or other static piece. Create original visual designs, never copying existing artists' work to avoid copyright violations.</description>
<location>project</location>
</skill>

<skill>
<name>doc-coauthoring</name>
<description>Guide users through a structured workflow for co-authoring documentation. Use when user wants to write documentation, proposals, technical specs, decision docs, or similar structured content. This workflow helps users efficiently transfer context, refine content through iteration, and verify the doc works for readers. Trigger when user mentions writing docs, creating proposals, drafting specs, or similar documentation tasks.</description>
<location>project</location>
</skill>

<skill>
<name>docx</name>
<description>"Comprehensive document creation, editing, and analysis with support for tracked changes, comments, formatting preservation, and text extraction. When Claude needs to work with professional documents (.docx files) for: (1) Creating new documents, (2) Modifying or editing content, (3) Working with tracked changes, (4) Adding comments, or any other document tasks"</description>
<location>project</location>
</skill>

<skill>
<name>frontend-design</name>
<description>Create distinctive, production-grade frontend interfaces with high design quality. Use this skill when the user asks to build web components, pages, artifacts, posters, or applications (examples include websites, landing pages, dashboards, React components, HTML/CSS layouts, or when styling/beautifying any web UI). Generates creative, polished code and UI design that avoids generic AI aesthetics.</description>
<location>project</location>
</skill>

<skill>
<name>gleam</name>
<description>Write idiomatic Gleam code for the BEAM VM and JavaScript. Use when working with .gleam files, Gleam projects, or when the user mentions Gleam, BEAM, OTP actors, or type-safe functional programming.</description>
<location>project</location>
</skill>

<skill>
<name>internal-comms</name>
<description>A set of resources to help me write all kinds of internal communications, using the formats that my company likes to use. Claude should use this skill whenever asked to write some sort of internal communications (status reports, leadership updates, 3P updates, company newsletters, FAQs, incident reports, project updates, etc.).</description>
<location>project</location>
</skill>

<skill>
<name>mcp-builder</name>
<description>Guide for creating high-quality MCP (Model Context Protocol) servers that enable LLMs to interact with external services through well-designed tools. Use when building MCP servers to integrate external APIs or services, whether in Python (FastMCP) or Node/TypeScript (MCP SDK).</description>
<location>project</location>
</skill>

<skill>
<name>nushell</name>
<description>Write and debug Nushell scripts, pipelines, and commands. Use when working with .nu files, writing Nushell code, converting bash to Nushell, or when the user mentions nu, nushell, or structured shell scripting.</description>
<location>project</location>
</skill>

<skill>
<name>parallel-arch-review</name>
<description>This skill should be used when the user asks to "review architecture", "analyze design", "run parallel review", "multi-agent review", "5-perspective review", or when coordinating 24+ agents on code changes. Enforces atomic task decomposition with 5-lens review protocol.</description>
<location>project</location>
</skill>

<skill>
<name>pdf</name>
<description>Comprehensive PDF manipulation toolkit for extracting text and tables, creating new PDFs, merging/splitting documents, and handling forms. When Claude needs to fill in a PDF form or programmatically process, generate, or analyze PDF documents at scale.</description>
<location>project</location>
</skill>

<skill>
<name>pptx</name>
<description>"Presentation creation, editing, and analysis. When Claude needs to work with presentations (.pptx files) for: (1) Creating new presentations, (2) Modifying or editing content, (3) Working with layouts, (4) Adding comments or speaker notes, or any other presentation tasks"</description>
<location>project</location>
</skill>

<skill>
<name>skill-creator</name>
<description>Guide for creating effective skills. This skill should be used when users want to create a new skill (or update an existing skill) that extends Claude's capabilities with specialized knowledge, workflows, or tool integrations.</description>
<location>project</location>
</skill>

<skill>
<name>slack-gif-creator</name>
<description>Knowledge and utilities for creating animated GIFs optimized for Slack. Provides constraints, validation tools, and animation concepts. Use when users request animated GIFs for Slack like "make me a GIF of X doing Y for Slack."</description>
<location>project</location>
</skill>

<skill>
<name>template</name>
<description>Replace with description of the skill and when Claude should use it.</description>
<location>project</location>
</skill>

<skill>
<name>theme-factory</name>
<description>Toolkit for styling artifacts with a theme. These artifacts can be slides, docs, reportings, HTML landing pages, etc. There are 10 pre-set themes with colors/fonts that you can apply to any artifact that has been creating, or can generate a new theme on-the-fly.</description>
<location>project</location>
</skill>

<skill>
<name>web-artifacts-builder</name>
<description>Suite of tools for creating elaborate, multi-component claude.ai HTML artifacts using modern frontend web technologies (React, Tailwind CSS, shadcn/ui). Use for complex artifacts requiring state management, routing, or shadcn/ui components - not for simple single-file HTML/JSX artifacts.</description>
<location>project</location>
</skill>

<skill>
<name>webapp-testing</name>
<description>Toolkit for interacting with and testing local web applications using Playwright. Supports verifying frontend functionality, debugging UI behavior, capturing browser screenshots, and viewing browser logs.</description>
<location>project</location>
</skill>

<skill>
<name>xlsx</name>
<description>"Comprehensive spreadsheet creation, editing, and analysis with support for formulas, formatting, data analysis, and visualization. When Claude needs to work with spreadsheets (.xlsx, .xlsm, .csv, .tsv, etc) for: (1) Creating new spreadsheets with formulas and formatting, (2) Reading or analyzing data, (3) Modify existing spreadsheets while preserving formulas, (4) Data analysis and visualization in spreadsheets, or (5) Recalculating formulas"</description>
<location>project</location>
</skill>

</available_skills>
<!-- SKILLS_TABLE_END -->

</skills_system>
