# Fire-Flow Workflow Tests - Quick Index

## Test Files

| File | Tests | Focus | Lines |
|------|-------|-------|-------|
| [test_self_healing_loop.nu](test_self_healing_loop.nu) | 8 | Multi-attempt self-healing pattern | 433 |
| [test_parallel_executions.nu](test_parallel_executions.nu) | 7 | Concurrent workflow safety | 483 |
| [test_full_workflow.nu](test_full_workflow.nu) | 8 | Complete happy path workflows | 487 |
| [test_error_recovery.nu](test_error_recovery.nu) | 11 | Failure scenarios and recovery | 565 |

## Quick Commands

```bash
# Run all tests
./run-workflow-tests.nu

# Run specific suite
./run-workflow-tests.nu --suite healing
./run-workflow-tests.nu --suite parallel
./run-workflow-tests.nu --suite full
./run-workflow-tests.nu --suite error

# List available tests
./run-workflow-tests.nu --list

# Run with summary
./run-workflow-tests.nu --summary
```

## Documentation

- [README.md](README.md) - Complete documentation, usage, architecture
- [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) - Implementation details, metrics, validation
- [INDEX.md](INDEX.md) - This quick reference

## Test Count: 34 comprehensive workflow tests

## Total Lines: 2,391 lines (tests + docs + runner)
