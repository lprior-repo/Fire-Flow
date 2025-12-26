# Project Charter: TCR Enforcer for OpenCode

## Document Info

| Field | Value |
|-------|-------|
| Version | 0.1.0 |
| Status | Draft |
| Author | Lewis |
| Created | 2025-12-12 |

---

## 1. Problem Statement

AI coding agents (including OpenCode) exhibit patterns that lead to poor code quality and wasted cycles:

1. **Big-bang implementation**: Agents write 50-200 lines before testing, increasing failure risk
2. **Test avoidance**: Agents skip tests unless explicitly reminded every time
3. **Debugging spirals**: When code breaks, agents enter multi-turn fix cycles that burn context window
4. **No incremental commits**: Changes aren't checkpointed, making recovery difficult

These patterns waste tokens, time, and produce fragile code.

---

## 2. Proposed Solution

Implement a TCR (Test && Commit || Revert) + TDD enforcement plugin for OpenCode that:

1. **Gates implementation** - Blocks writes to implementation files unless a failing test exists
2. **Auto-runs tests** - Executes test suite after every file modification
3. **Auto-commits on green** - Commits working code immediately
4. **Auto-reverts on red** - Discards code that breaks tests (no negotiation)
5. **Self-protects** - Prevents agent from disabling or modifying the enforcer

---

## 3. Goals

### Primary Goals

| Goal | Metric | Target |
|------|--------|--------|
| Reduce debugging cycles | Avg turns to fix broken code | < 2 (vs 5-10 baseline) |
| Increase test coverage | % of impl files with tests | > 90% |
| Smaller commits | Avg lines per commit | < 20 |
| Fewer reverts over time | Revert rate trend | Decreasing week-over-week |

### Secondary Goals

- Teach agents to work in smaller increments through feedback
- Maintain always-green HEAD (every commit passes tests)
- Reduce token waste from debugging
- Provide clear feedback when violations occur

---

## 4. Non-Goals (Out of Scope)

- **IDE integration** - Terminal/OpenCode only for v1
- **Multi-language detection** - Manual config for test commands in v1
- **Cloud sync** - Local only, no telemetry
- **PR/branch workflows** - Focus on local development loop
- **Lint enforcement** - TDD/TCR only for v1 (lint is future enhancement)

---

## 5. Success Criteria

### Must Have (v1.0)

- [ ] TDD gate blocks implementation without failing tests
- [ ] TCR auto-commits on passing tests
- [ ] TCR auto-reverts on failing tests
- [ ] Self-protection prevents config modification
- [ ] Works with at least one test runner (Vitest)
- [ ] Clear error messages on violations
- [ ] On/off toggle via config

### Should Have (v1.1)

- [ ] Support for Jest, pytest, Go test
- [ ] Revert streak detection with coaching messages
- [ ] Stats tracking (commits, reverts, streak)
- [ ] "Relaxed" mode (no revert, just no commit on red)
- [ ] Squash helper command

### Could Have (v2.0)

- [ ] LLM-based over-implementation detection
- [ ] Lint integration for refactor phase
- [ ] Multiple concurrent project support
- [ ] MCP server for cross-tool integration

---

## 6. Stakeholders

| Role | Interest |
|------|----------|
| Developer (Lewis) | Primary user, building for own workflow |
| OpenCode community | Potential users if open-sourced |
| Thrivent teams | Potential adoption for team standardization |

---

## 7. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Agent finds workaround (shell commands) | Medium | High | Block shell access to protected paths |
| Too strict, frustrates users | Medium | Medium | Provide "relaxed" mode option |
| Test runner detection fails | Medium | Medium | Allow manual config, good defaults |
| Performance impact (running tests constantly) | Low | Medium | Cache results, debounce |
| Plugin disabled by agent editing config | High | High | Self-protection in plugin code |

---

## 8. Constraints

- Must work within OpenCode plugin architecture
- Must not require external services (local only)
- Must be language-agnostic (configurable test command)
- Must not significantly slow down development flow

---

## 9. Dependencies

| Dependency | Type | Notes |
|------------|------|-------|
| OpenCode | Runtime | Plugin host |
| @opencode-ai/plugin | Dev | Plugin SDK and types |
| Git | Runtime | For commit/revert operations |
| Test runner | Runtime | User's choice (vitest, jest, etc.) |
| Bun | Runtime | For shell execution ($) |

---

## 10. Timeline

| Phase | Duration | Deliverables |
|-------|----------|--------------|
| Planning | 1 day | This doc set |
| Core Plugin | 2-3 days | TDD gate + TCR loop |
| Test Reporter | 1-2 days | Vitest reporter |
| Testing & Polish | 1-2 days | Integration tests, docs |
| **Total** | **~1 week** | v1.0 release |

---

## 11. Open Questions

1. Should revert message include test failure output? (Probably yes, truncated)
2. How to handle test files that import from impl files that don't exist yet?
3. Should we track revert history for analytics?
4. What's the right debounce time for test runs?
5. How to handle monorepos with multiple test configs?

---

## Approval

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Author | Lewis | 2025-12-12 | ✓ |
