# Test Strategy: TCR Enforcer for OpenCode

## Document Info

| Field | Value |
|-------|-------|
| Version | 0.1.0 |
| Status | Draft |
| Author | Lewis |
| Created | 2025-12-12 |

---

## 1. Testing Philosophy

Since we're building a TDD enforcement tool, we MUST practice TDD ourselves.

```
Write failing test → Write minimal code → Refactor → Repeat
```

No implementation code without a failing test first.

---

## 2. Test Pyramid

```
                    ┌─────────────┐
                   │  E2E Tests   │  ← 2-3 scenarios
                  │   (Manual)    │
                 └───────────────┘
                ┌─────────────────────┐
               │  Integration Tests   │  ← 5-10 tests
              │   (Plugin in OpenCode) │
             └─────────────────────────┘
           ┌─────────────────────────────────┐
          │         Unit Tests               │  ← 50+ tests
         │  (Pure functions, isolated logic)  │
        └─────────────────────────────────────┘
```

---

## 3. Unit Tests

### 3.1 State Manager

| Test | Description |
|------|-------------|
| `creates data directory` | Should create `.opencode/tcr/data/` if missing |
| `loads default config` | Should return defaults when no config file |
| `merges user config` | Should override defaults with user values |
| `handles corrupt config` | Should fall back to defaults on parse error |
| `loads test results` | Should parse test.json correctly |
| `handles missing test.json` | Should return null when file missing |
| `saves stats` | Should persist stats to stats.json |
| `records commit` | Should increment commits, reset streak |
| `records revert` | Should increment reverts and streak |
| `tracks revert reason` | Should store truncated test output |

```typescript
// test/state-manager.test.ts
import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import { StateManager } from '../src/state-manager'
import fs from 'fs/promises'
import path from 'path'

describe('StateManager', () => {
  const testDir = '/tmp/tcr-test-' + Date.now()
  
  beforeEach(async () => {
    await fs.mkdir(testDir, { recursive: true })
  })
  
  afterEach(async () => {
    await fs.rm(testDir, { recursive: true, force: true })
  })
  
  it('creates data directory if missing', async () => {
    const state = new StateManager(testDir)
    await state.init()
    
    const dataDir = path.join(testDir, '.opencode/tcr/data')
    const exists = await fs.access(dataDir).then(() => true).catch(() => false)
    expect(exists).toBe(true)
  })
  
  it('loads default config when no file exists', async () => {
    const state = new StateManager(testDir)
    await state.init()
    
    const config = state.getConfig()
    expect(config.enabled).toBe(true)
    expect(config.mode).toBe('both')
    expect(config.testCommand).toBe('npm test')
  })
  
  // ... more tests
})
```

### 3.2 Utility Functions

| Test | Description |
|------|-------------|
| `isTestFile - .test.ts` | Should match TypeScript test files |
| `isTestFile - .spec.js` | Should match JavaScript spec files |
| `isTestFile - _test.go` | Should match Go test files |
| `isTestFile - test_*.py` | Should match Python test files |
| `isTestFile - impl.ts` | Should NOT match implementation files |
| `isProtectedPath - opencode.json` | Should match config file |
| `isProtectedPath - .opencode/plugin` | Should match plugin dir |
| `isProtectedPath - src/index.ts` | Should NOT match source files |
| `truncateOutput - short` | Should not truncate short text |
| `truncateOutput - long` | Should truncate with ellipsis |

```typescript
// test/utils.test.ts
import { describe, it, expect } from 'vitest'
import { isTestFile, isProtectedPath, truncateOutput } from '../src/utils'

describe('isTestFile', () => {
  const patterns = [
    '\\.test\\.[jt]sx?$',
    '\\.spec\\.[jt]sx?$',
    '_test\\.go$',
    'test_.*\\.py$'
  ]
  
  it('matches .test.ts files', () => {
    expect(isTestFile('src/foo.test.ts', patterns)).toBe(true)
  })
  
  it('matches .spec.js files', () => {
    expect(isTestFile('lib/bar.spec.js', patterns)).toBe(true)
  })
  
  it('does not match implementation files', () => {
    expect(isTestFile('src/index.ts', patterns)).toBe(false)
  })
})
```

### 3.3 Git Operations

| Test | Description |
|------|-------------|
| `runTests - success` | Should return passed=true on exit 0 |
| `runTests - failure` | Should return passed=false on non-zero exit |
| `runTests - captures output` | Should capture stdout/stderr |
| `gitCommit - stages all` | Should run git add -A |
| `gitCommit - commits` | Should run git commit with message |
| `gitRevert - resets` | Should run git reset --hard HEAD |

```typescript
// test/git-ops.test.ts
import { describe, it, expect, vi } from 'vitest'
import { runTests, gitCommit, gitRevert } from '../src/git-ops'

describe('runTests', () => {
  it('returns passed=true on successful test run', async () => {
    const mockShell = vi.fn().mockReturnValue({
      text: () => Promise.resolve('All tests passed')
    })
    
    const result = await runTests(mockShell, 'npm test', '/project')
    
    expect(result.passed).toBe(true)
    expect(result.output).toContain('All tests passed')
  })
  
  it('returns passed=false on test failure', async () => {
    const mockShell = vi.fn().mockRejectedValue({
      stdout: 'FAIL: expected true, got false'
    })
    
    const result = await runTests(mockShell, 'npm test', '/project')
    
    expect(result.passed).toBe(false)
  })
})
```

### 3.4 TDD Gate

| Test | Description |
|------|-------------|
| `blocks impl without failing tests` | Should throw when no failing tests |
| `allows impl with failing tests` | Should not throw when failing tests exist |
| `always allows test files` | Should not throw for test file writes |
| `blocks protected paths` | Should throw for opencode.json etc |
| `respects disabled state` | Should not throw when disabled |
| `respects tdd mode` | Should enforce in tdd/both modes |
| `skips in tcr-only mode` | Should not enforce in tcr mode |

```typescript
// test/tdd-gate.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { createTDDGate } from '../src/tdd-gate'

describe('TDD Gate', () => {
  let mockState: any
  
  beforeEach(() => {
    mockState = {
      isEnabled: vi.fn().mockReturnValue(true),
      getMode: vi.fn().mockReturnValue('both'),
      getConfig: vi.fn().mockReturnValue({
        testPatterns: ['\\.test\\.[jt]s$'],
        protectedPaths: ['opencode.json', '.opencode/']
      }),
      refreshTestResults: vi.fn()
    }
  })
  
  it('blocks implementation without failing tests', async () => {
    mockState.refreshTestResults.mockResolvedValue({
      passed: ['test1', 'test2'],
      failed: []
    })
    
    const gate = createTDDGate(mockState, '/project')
    
    await expect(gate(
      { tool: 'write' },
      { args: { filePath: 'src/index.ts' } }
    )).rejects.toThrow('TDD VIOLATION')
  })
  
  it('allows implementation with failing tests', async () => {
    mockState.refreshTestResults.mockResolvedValue({
      passed: ['test1'],
      failed: ['test2']
    })
    
    const gate = createTDDGate(mockState, '/project')
    
    await expect(gate(
      { tool: 'write' },
      { args: { filePath: 'src/index.ts' } }
    )).resolves.toBeUndefined()
  })
  
  it('always allows test files', async () => {
    mockState.refreshTestResults.mockResolvedValue(null)
    
    const gate = createTDDGate(mockState, '/project')
    
    await expect(gate(
      { tool: 'write' },
      { args: { filePath: 'src/foo.test.ts' } }
    )).resolves.toBeUndefined()
  })
})
```

### 3.5 TCR Loop

| Test | Description |
|------|-------------|
| `commits on passing tests` | Should call gitCommit when tests pass |
| `reverts on failing tests` | Should call gitRevert when tests fail |
| `skips revert in relaxed mode` | Should not revert in relaxed mode |
| `updates stats on commit` | Should call recordCommit |
| `updates stats on revert` | Should call recordRevert |
| `debounces rapid edits` | Should only run tests once for rapid edits |
| `skips protected paths` | Should not run for protected files |

```typescript
// test/tcr-loop.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { createTCRLoop } from '../src/tcr-loop'

describe('TCR Loop', () => {
  let mockState: any
  let mockShell: any
  
  beforeEach(() => {
    mockState = {
      isEnabled: vi.fn().mockReturnValue(true),
      getMode: vi.fn().mockReturnValue('both'),
      getConfig: vi.fn().mockReturnValue({
        testCommand: 'npm test',
        commitMessage: 'WIP',
        protectedPaths: ['.opencode/'],
        debounceMs: 0,
        showTestOutput: false
      }),
      recordCommit: vi.fn(),
      recordRevert: vi.fn(),
      saveStats: vi.fn(),
      getStats: vi.fn().mockReturnValue({ revertStreak: 0 })
    }
    
    mockShell = vi.fn()
  })
  
  it('commits on passing tests', async () => {
    // Mock successful test run
    mockShell
      .mockReturnValueOnce({ text: () => Promise.resolve('PASS') })  // test
      .mockReturnValueOnce({ text: () => Promise.resolve('') })      // git add
      .mockReturnValueOnce({ text: () => Promise.resolve('') })      // git commit
    
    const loop = createTCRLoop(mockState, '/project', mockShell)
    
    await loop(
      { tool: 'write' },
      { args: { filePath: 'src/index.ts' } }
    )
    
    expect(mockState.recordCommit).toHaveBeenCalled()
  })
})
```

---

## 4. Integration Tests

### 4.1 Plugin Loading

```typescript
// test/integration.test.ts
import { describe, it, expect } from 'vitest'
import { TCREnforcer } from '../src/index'

describe('Plugin Integration', () => {
  it('exports a valid plugin', () => {
    expect(typeof TCREnforcer).toBe('function')
  })
  
  it('returns hook handlers', async () => {
    const mockContext = {
      directory: '/tmp/test-project',
      $: vi.fn(),
      client: {},
      project: {},
      worktree: '/tmp/test-project'
    }
    
    const handlers = await TCREnforcer(mockContext)
    
    expect(handlers['tool.execute.before']).toBeDefined()
    expect(handlers['tool.execute.after']).toBeDefined()
  })
})
```

### 4.2 Full Workflow Tests

| Test | Description |
|------|-------------|
| `TDD workflow` | Write test → impl → pass → commit |
| `TCR revert` | Write test → bad impl → revert |
| `Self-protection` | Try to edit config → blocked |
| `Mode switching` | Change mode, verify behavior |

---

## 5. End-to-End Tests

Manual testing scenarios:

### Scenario 1: Happy Path TDD

```
1. Create new project with TCR enforcer
2. Try to write implementation file
   → Expected: BLOCKED "No failing tests"
3. Write a failing test
   → Expected: Allowed
4. Write implementation to pass test
   → Expected: Allowed, tests run, committed
5. Check git log
   → Expected: "WIP" commit present
```

### Scenario 2: TCR Revert

```
1. Create project with passing test
2. Write implementation that breaks test
   → Expected: Tests fail, code REVERTED
3. Check file contents
   → Expected: Code is gone (reset to HEAD)
4. Check stats
   → Expected: revertStreak = 1
```

### Scenario 3: Self-Protection

```
1. Try to edit opencode.json
   → Expected: BLOCKED
2. Try to delete .opencode/plugin/tcr-enforcer.ts
   → Expected: BLOCKED
3. Try via shell: rm -rf .opencode/tcr
   → Expected: BLOCKED
```

### Scenario 4: Relaxed Mode

```
1. Set mode: "relaxed"
2. Write failing implementation
   → Expected: Tests fail, NOT committed, NOT reverted
3. Fix implementation
   → Expected: Tests pass, committed
```

---

## 6. Test Coverage Goals

| Module | Target | Notes |
|--------|--------|-------|
| state-manager.ts | 90% | Core logic |
| tdd-gate.ts | 95% | Critical path |
| tcr-loop.ts | 90% | Critical path |
| git-ops.ts | 80% | External commands |
| utils.ts | 100% | Pure functions |
| index.ts | 70% | Wiring code |
| **Overall** | **85%** | |

---

## 7. Test Environment

### Setup

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html'],
      exclude: ['test/**', 'docs/**']
    },
    testTimeout: 5000
  }
})
```

### Mocking Strategy

| Dependency | Mock Strategy |
|------------|---------------|
| File system | Use temp directories, clean up after |
| Shell commands | Mock `$` function |
| Git operations | Mock or use test repo |
| OpenCode SDK | Mock context object |

---

## 8. CI Pipeline

```yaml
# .github/workflows/test.yml
name: Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: oven-sh/setup-bun@v1
        with:
          bun-version: latest
      
      - run: bun install
      
      - run: bun test
      
      - run: bun test:coverage
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
```

---

## 9. Test Data

### Sample Config

```yaml
# test/fixtures/config.yml
enabled: true
mode: both
testCommand: "bun test"
commitMessage: "WIP"
testPatterns:
  - "\\.test\\.[jt]s$"
protectedPaths:
  - "opencode.json"
  - ".opencode/"
```

### Sample Test Results

```json
// test/fixtures/test.json
{
  "passed": ["should add numbers", "should subtract numbers"],
  "failed": ["should multiply numbers"],
  "timestamp": 1702400000000,
  "total": 3,
  "duration": 150
}
```

---

## 10. Testing Checklist

Before PR:
- [ ] All unit tests pass
- [ ] Coverage meets targets
- [ ] No TypeScript errors
- [ ] Integration tests pass
- [ ] Manual E2E verification

Before Release:
- [ ] Full regression suite
- [ ] Performance benchmarks
- [ ] Edge case verification
- [ ] Documentation tests (examples work)
