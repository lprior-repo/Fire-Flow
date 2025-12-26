# Technical Specification: TCR Enforcer for OpenCode

## Document Info

| Field | Value |
|-------|-------|
| Version | 0.1.0 |
| Status | Draft |
| Author | Lewis |
| Created | 2025-12-12 |

---

## 1. Plugin Entry Point

### 1.1 File Location

```
.opencode/plugin/tcr-enforcer.ts
```

Or for global installation:

```
~/.config/opencode/plugin/tcr-enforcer.ts
```

### 1.2 Main Export

```typescript
import type { Plugin } from "@opencode-ai/plugin"

export const TCREnforcer: Plugin = async (context) => {
  const { directory, $, client, project, worktree } = context
  
  // Initialize state manager
  const state = new StateManager(directory)
  await state.init()
  
  return {
    "tool.execute.before": createTDDGate(state, directory),
    "tool.execute.after": createTCRLoop(state, directory, $),
  }
}
```

---

## 2. Type Definitions

### 2.1 Core Types

```typescript
// ═══════════════════════════════════════════════════════════════════════════
// Configuration
// ═══════════════════════════════════════════════════════════════════════════

interface TCRConfig {
  /** Enable/disable the entire plugin */
  enabled: boolean
  
  /** Enforcement mode */
  mode: TCRMode
  
  /** Command to run tests */
  testCommand: string
  
  /** Commit message for auto-commits */
  commitMessage: string
  
  /** Patterns for test files */
  testPatterns: string[]
  
  /** Paths to protect from modification */
  protectedPaths: string[]
  
  /** Delay before running tests (ms) */
  debounceMs: number
  
  /** Show test output on failure */
  showTestOutput: boolean
  
  /** Max chars of test output to show */
  testOutputLimit: number
}

type TCRMode = 
  | "tdd"      // Only TDD gate, no TCR loop
  | "tcr"      // Only TCR loop, no TDD gate  
  | "both"     // Full enforcement
  | "relaxed"  // TCR without revert (just no commit on red)
  | "off"      // Disabled

// ═══════════════════════════════════════════════════════════════════════════
// Test Results
// ═══════════════════════════════════════════════════════════════════════════

interface TestResults {
  /** Names of passing tests */
  passed: string[]
  
  /** Names of failing tests */
  failed: string[]
  
  /** Test run timestamp */
  timestamp: number
  
  /** Total test count */
  total: number
  
  /** Duration in ms */
  duration: number
  
  /** Raw output (truncated) */
  output?: string
}

// ═══════════════════════════════════════════════════════════════════════════
// Statistics
// ═══════════════════════════════════════════════════════════════════════════

interface TCRStats {
  /** Total commits made by TCR */
  commits: number
  
  /** Total reverts made by TCR */
  reverts: number
  
  /** Current consecutive revert streak */
  revertStreak: number
  
  /** Last revert reason (test output) */
  lastRevertReason: string
  
  /** Timestamp of last activity */
  lastActivity: number
  
  /** Session start timestamp */
  sessionStart: number
}

// ═══════════════════════════════════════════════════════════════════════════
// Runtime State
// ═══════════════════════════════════════════════════════════════════════════

interface RuntimeState {
  /** Is plugin currently enabled */
  enabled: boolean
  
  /** Current mode override (if any) */
  modeOverride?: TCRMode
  
  /** Cached test results */
  testResults: TestResults | null
  
  /** Current stats */
  stats: TCRStats
}

// ═══════════════════════════════════════════════════════════════════════════
// Hook Types (from OpenCode)
// ═══════════════════════════════════════════════════════════════════════════

interface ToolInput {
  tool: string  // "write" | "edit" | "bash" | etc.
}

interface ToolOutput {
  args: {
    filePath?: string
    path?: string
    content?: string
    command?: string
    [key: string]: unknown
  }
}
```

### 2.2 Default Values

```typescript
const DEFAULT_CONFIG: TCRConfig = {
  enabled: true,
  mode: "both",
  testCommand: "npm test",
  commitMessage: "WIP",
  testPatterns: [
    "\\.test\\.[jt]sx?$",
    "\\.spec\\.[jt]sx?$",
    "_test\\.go$",
    "test_.*\\.py$",
    "Test\\.php$",
    "_test\\.rs$"
  ],
  protectedPaths: [
    "opencode.json",
    ".opencode/plugin",
    ".opencode/tcr",
    ".git"
  ],
  debounceMs: 100,
  showTestOutput: true,
  testOutputLimit: 500
}

const DEFAULT_STATS: TCRStats = {
  commits: 0,
  reverts: 0,
  revertStreak: 0,
  lastRevertReason: "",
  lastActivity: Date.now(),
  sessionStart: Date.now()
}
```

---

## 3. State Manager

### 3.1 Class Definition

```typescript
class StateManager {
  private directory: string
  private dataDir: string
  private config: TCRConfig
  private state: RuntimeState
  
  constructor(directory: string) {
    this.directory = directory
    this.dataDir = path.join(directory, ".opencode/tcr/data")
  }
  
  async init(): Promise<void> {
    // Ensure data directory exists
    await fs.mkdir(this.dataDir, { recursive: true })
    
    // Load config
    this.config = await this.loadConfig()
    
    // Load or initialize state
    this.state = {
      enabled: this.config.enabled,
      modeOverride: undefined,
      testResults: await this.loadTestResults(),
      stats: await this.loadStats()
    }
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // Config
  // ─────────────────────────────────────────────────────────────────────────
  
  private async loadConfig(): Promise<TCRConfig> {
    const configPath = path.join(this.dataDir, "config.yml")
    try {
      const content = await fs.readFile(configPath, "utf-8")
      const userConfig = yaml.parse(content)
      return { ...DEFAULT_CONFIG, ...userConfig }
    } catch {
      return DEFAULT_CONFIG
    }
  }
  
  getConfig(): TCRConfig {
    return this.config
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // Test Results
  // ─────────────────────────────────────────────────────────────────────────
  
  private async loadTestResults(): Promise<TestResults | null> {
    const testPath = path.join(this.dataDir, "test.json")
    try {
      const content = await fs.readFile(testPath, "utf-8")
      return JSON.parse(content)
    } catch {
      return null
    }
  }
  
  getTestResults(): TestResults | null {
    return this.state.testResults
  }
  
  async refreshTestResults(): Promise<TestResults | null> {
    this.state.testResults = await this.loadTestResults()
    return this.state.testResults
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // Stats
  // ─────────────────────────────────────────────────────────────────────────
  
  private async loadStats(): Promise<TCRStats> {
    const statsPath = path.join(this.dataDir, "stats.json")
    try {
      const content = await fs.readFile(statsPath, "utf-8")
      return JSON.parse(content)
    } catch {
      return { ...DEFAULT_STATS }
    }
  }
  
  async saveStats(): Promise<void> {
    const statsPath = path.join(this.dataDir, "stats.json")
    await fs.writeFile(
      statsPath, 
      JSON.stringify(this.state.stats, null, 2)
    )
  }
  
  recordCommit(): void {
    this.state.stats.commits++
    this.state.stats.revertStreak = 0
    this.state.stats.lastActivity = Date.now()
  }
  
  recordRevert(reason: string): void {
    this.state.stats.reverts++
    this.state.stats.revertStreak++
    this.state.stats.lastRevertReason = reason
    this.state.stats.lastActivity = Date.now()
  }
  
  getStats(): TCRStats {
    return this.state.stats
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // Mode Control
  // ─────────────────────────────────────────────────────────────────────────
  
  isEnabled(): boolean {
    return this.state.enabled
  }
  
  getMode(): TCRMode {
    return this.state.modeOverride ?? this.config.mode
  }
  
  setEnabled(enabled: boolean): void {
    this.state.enabled = enabled
  }
  
  setMode(mode: TCRMode): void {
    this.state.modeOverride = mode
  }
}
```

---

## 4. TDD Gate Implementation

### 4.1 Gate Factory

```typescript
function createTDDGate(
  state: StateManager, 
  directory: string
): (input: ToolInput, output: ToolOutput) => Promise<void> {
  
  const config = state.getConfig()
  
  return async (input, output) => {
    // Only intercept write/edit operations
    if (!["write", "edit"].includes(input.tool)) {
      return
    }
    
    const filePath = output.args.filePath ?? output.args.path ?? ""
    
    // ───────────────────────────────────────────────────────────────────────
    // 1. Self-protection: Block protected paths
    // ───────────────────────────────────────────────────────────────────────
    if (isProtectedPath(filePath, config.protectedPaths)) {
      throw new Error(
        `🚫 BLOCKED: Cannot modify protected path\n` +
        `Path: ${filePath}\n` +
        `TCR Enforcer protects its own configuration.`
      )
    }
    
    // ───────────────────────────────────────────────────────────────────────
    // 2. Check if enforcement is enabled
    // ───────────────────────────────────────────────────────────────────────
    if (!state.isEnabled()) {
      return
    }
    
    const mode = state.getMode()
    if (mode === "off" || mode === "tcr") {
      // TDD gate disabled in these modes
      return
    }
    
    // ───────────────────────────────────────────────────────────────────────
    // 3. Allow test files freely
    // ───────────────────────────────────────────────────────────────────────
    if (isTestFile(filePath, config.testPatterns)) {
      return
    }
    
    // ───────────────────────────────────────────────────────────────────────
    // 4. Check for failing tests
    // ───────────────────────────────────────────────────────────────────────
    const results = await state.refreshTestResults()
    
    if (!results || results.failed.length === 0) {
      throw new Error(
        `🚫 TDD VIOLATION: No failing tests found\n\n` +
        `You must write a failing test before implementing.\n` +
        `File: ${filePath}\n\n` +
        `TDD Cycle:\n` +
        `  1. Write a failing test (RED)\n` +
        `  2. Write minimal code to pass (GREEN)\n` +
        `  3. Refactor while green (REFACTOR)\n\n` +
        `Current state: No failing tests detected.\n` +
        `Write a test first!`
      )
    }
    
    // Has failing tests - allow implementation
  }
}
```

### 4.2 Helper Functions

```typescript
function isProtectedPath(filePath: string, patterns: string[]): boolean {
  const normalized = filePath.toLowerCase()
  return patterns.some(pattern => 
    normalized.includes(pattern.toLowerCase())
  )
}

function isTestFile(filePath: string, patterns: string[]): boolean {
  return patterns.some(pattern => {
    const regex = new RegExp(pattern)
    return regex.test(filePath)
  })
}
```

---

## 5. TCR Loop Implementation

### 5.1 Loop Factory

```typescript
function createTCRLoop(
  state: StateManager,
  directory: string,
  $: BunShell
): (input: ToolInput, output: ToolOutput) => Promise<void> {
  
  const config = state.getConfig()
  let debounceTimer: ReturnType<typeof setTimeout> | null = null
  
  return async (input, output) => {
    // Only trigger on write/edit operations
    if (!["write", "edit"].includes(input.tool)) {
      return
    }
    
    const filePath = output.args.filePath ?? output.args.path ?? ""
    
    // Skip protected paths
    if (isProtectedPath(filePath, config.protectedPaths)) {
      return
    }
    
    // Check if enforcement is enabled
    if (!state.isEnabled()) {
      return
    }
    
    const mode = state.getMode()
    if (mode === "off" || mode === "tdd") {
      // TCR loop disabled in these modes
      return
    }
    
    // ───────────────────────────────────────────────────────────────────────
    // Debounce to avoid running tests on rapid consecutive edits
    // ───────────────────────────────────────────────────────────────────────
    if (debounceTimer) {
      clearTimeout(debounceTimer)
    }
    
    await new Promise<void>((resolve) => {
      debounceTimer = setTimeout(resolve, config.debounceMs)
    })
    
    // ───────────────────────────────────────────────────────────────────────
    // Run tests
    // ───────────────────────────────────────────────────────────────────────
    console.log("🧪 TCR: Running tests...")
    
    const testResult = await runTests($, config.testCommand, directory)
    
    if (testResult.passed) {
      // ─────────────────────────────────────────────────────────────────────
      // GREEN: Commit
      // ─────────────────────────────────────────────────────────────────────
      await gitCommit($, config.commitMessage)
      state.recordCommit()
      await state.saveStats()
      
      console.log("✅ TCR: Tests passed → Committed")
      
    } else {
      // ─────────────────────────────────────────────────────────────────────
      // RED: Revert (unless relaxed mode)
      // ─────────────────────────────────────────────────────────────────────
      if (mode === "relaxed") {
        console.log("⚠️  TCR (relaxed): Tests failed → NOT committing")
        console.log("   Fix the tests to commit your changes.")
      } else {
        await gitRevert($)
        state.recordRevert(testResult.output)
        await state.saveStats()
        
        console.log("❌ TCR: Tests failed → REVERTED")
        
        if (config.showTestOutput && testResult.output) {
          const truncated = testResult.output.slice(0, config.testOutputLimit)
          console.log(`📋 Test output:\n${truncated}`)
        }
        
        // Check for revert streak
        const stats = state.getStats()
        if (stats.revertStreak >= 3) {
          console.log(
            `\n⚠️  ${stats.revertStreak} reverts in a row!\n` +
            `Consider:\n` +
            `  • Taking an even smaller step\n` +
            `  • Re-reading the failing test\n` +
            `  • Checking if the test is correct\n` +
            `  • Running tests manually to debug`
          )
        }
      }
    }
  }
}
```

### 5.2 Git Operations

```typescript
async function runTests(
  $: BunShell, 
  command: string,
  directory: string
): Promise<{ passed: boolean; output: string }> {
  try {
    const result = await $`cd ${directory} && ${command}`.text()
    return { passed: true, output: result }
  } catch (err: any) {
    return { 
      passed: false, 
      output: err.stdout ?? err.stderr ?? err.message ?? "Unknown error"
    }
  }
}

async function gitCommit($: BunShell, message: string): Promise<void> {
  await $`git add -A`
  await $`git commit -m ${message} --no-verify`
}

async function gitRevert($: BunShell): Promise<void> {
  await $`git reset --hard HEAD`
}

async function hasUncommittedChanges($: BunShell): Promise<boolean> {
  const status = await $`git status --porcelain`.text()
  return status.trim().length > 0
}
```

---

## 6. Bash Tool Protection

To prevent agents from bypassing via shell commands:

```typescript
// In tool.execute.before, also check bash tool
if (input.tool === "bash") {
  const command = output.args.command ?? ""
  const config = state.getConfig()
  
  // Check if command touches protected paths
  const touchesProtected = config.protectedPaths.some(p => 
    command.includes(p)
  )
  
  // Check for dangerous commands
  const dangerousPatterns = [
    /rm\s+.*\.opencode/,
    /rm\s+-rf?\s+.*tcr/,
    /mv\s+.*\.opencode/,
    /echo\s+.*>\s*.*opencode\.json/,
    /git\s+reset.*--hard/,  // Don't let agent do their own revert
  ]
  
  const isDangerous = dangerousPatterns.some(p => p.test(command))
  
  if (touchesProtected || isDangerous) {
    throw new Error(
      `🚫 BLOCKED: Shell command touches protected paths\n` +
      `Command: ${command}\n` +
      `TCR Enforcer protects its configuration from modification.`
    )
  }
}
```

---

## 7. Test Reporter (Vitest)

### 7.1 Reporter Implementation

```typescript
// File: tcr-vitest-reporter.ts
import type { Reporter, File, Task } from 'vitest'
import fs from 'fs'
import path from 'path'

interface TCRTestResults {
  passed: string[]
  failed: string[]
  timestamp: number
  total: number
  duration: number
}

export class TCRVitestReporter implements Reporter {
  private projectRoot: string
  private startTime: number = 0
  
  constructor(projectRoot?: string) {
    this.projectRoot = projectRoot ?? process.cwd()
  }
  
  onInit() {
    this.startTime = Date.now()
  }
  
  onFinished(files?: File[]) {
    const results: TCRTestResults = {
      passed: [],
      failed: [],
      timestamp: Date.now(),
      total: 0,
      duration: Date.now() - this.startTime
    }
    
    if (files) {
      for (const file of files) {
        this.collectResults(file.tasks, results)
      }
    }
    
    results.total = results.passed.length + results.failed.length
    
    // Write results
    const outputDir = path.join(this.projectRoot, '.opencode/tcr/data')
    fs.mkdirSync(outputDir, { recursive: true })
    
    const outputPath = path.join(outputDir, 'test.json')
    fs.writeFileSync(outputPath, JSON.stringify(results, null, 2))
  }
  
  private collectResults(tasks: Task[], results: TCRTestResults) {
    for (const task of tasks) {
      if (task.type === 'test') {
        if (task.result?.state === 'pass') {
          results.passed.push(task.name)
        } else if (task.result?.state === 'fail') {
          results.failed.push(task.name)
        }
      }
      
      // Recurse into suites
      if ('tasks' in task && task.tasks) {
        this.collectResults(task.tasks, results)
      }
    }
  }
}

export default TCRVitestReporter
```

### 7.2 Vitest Config

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config'
import { TCRVitestReporter } from './tcr-vitest-reporter'

export default defineConfig({
  test: {
    reporters: [
      'default',
      new TCRVitestReporter(process.cwd())
    ]
  }
})
```

---

## 8. Error Messages

All user-facing error messages should be:
- Clear about what happened
- Actionable (tell user what to do)
- Not condescending

```typescript
const MESSAGES = {
  TDD_VIOLATION: (filePath: string) => `
🚫 TDD VIOLATION: No failing tests found

You must write a failing test before implementing.
File: ${filePath}

TDD Cycle:
  1. Write a failing test (RED)
  2. Write minimal code to pass (GREEN)  
  3. Refactor while green (REFACTOR)

Current state: No failing tests detected.
Write a test first!
`.trim(),

  TCR_REVERTED: (output: string) => `
❌ TCR: Tests failed → Your changes were REVERTED

The code you just wrote did not pass tests.
It has been removed (git reset --hard HEAD).

Take a smaller step that keeps tests passing.

Test output:
${output}
`.trim(),

  PROTECTED_PATH: (filePath: string) => `
🚫 BLOCKED: Cannot modify protected path

Path: ${filePath}
TCR Enforcer protects its own configuration.
`.trim(),

  REVERT_STREAK: (count: number) => `
⚠️  ${count} reverts in a row!

Consider:
  • Taking an even smaller step
  • Re-reading the failing test
  • Checking if the test is correct
  • Running tests manually to debug
`.trim()
}
```

---

## 9. CLI Commands (Future)

Custom tools the plugin could expose:

```typescript
tool: {
  tcr_status: tool({
    description: "Show TCR enforcer status and stats",
    args: {},
    async execute() {
      const stats = state.getStats()
      const config = state.getConfig()
      return `
TCR Enforcer Status
  Enabled: ${state.isEnabled()}
  Mode: ${state.getMode()}
  
Session Stats
  Commits: ${stats.commits}
  Reverts: ${stats.reverts}
  Current streak: ${stats.revertStreak}

Config
  Test command: ${config.testCommand}
  Commit message: ${config.commitMessage}
`.trim()
    }
  }),
  
  tcr_toggle: tool({
    description: "Toggle TCR enforcer on/off",
    args: {
      enabled: tool.schema.boolean().optional()
    },
    async execute({ enabled }) {
      const newState = enabled ?? !state.isEnabled()
      state.setEnabled(newState)
      return `TCR Enforcer is now ${newState ? 'ENABLED' : 'DISABLED'}`
    }
  })
}
```
