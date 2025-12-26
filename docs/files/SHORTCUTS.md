# AI Code Validator - Shortcut Taxonomy

Reference of AI shortcut patterns. Load when performing deep review.

---

## Incompleteness Shortcuts (S001-S007)

### S001: Explicit Placeholders [BLOCKING]

Patterns to detect:
```
TODO, FIXME, XXX, HACK, BUG
"implement this", "add later", "your code here"
"rest of implementation", "etc.", "and so on"
"similar for", "repeat for", "handle other cases"
```

### S002: Code Ellipsis [BLOCKING]

```
...              # As code, not spread operator
// ...           # In any comment style
/* ... */
```

Disambiguate: JS spread `[...arr]` and Python `*args` are legitimate.

### S003: Language Placeholders [BLOCKING]

| Language | Placeholder |
|----------|-------------|
| Python | `pass`, `raise NotImplementedError` |
| JS/TS | `throw new Error("Not implemented")` |
| Rust | `todo!()`, `unimplemented!()`, `panic!("not implemented")` |
| Go | `panic("not implemented")` |
| Java | `throw new UnsupportedOperationException()` |
| Gleam | `todo`, `panic` |

### S004: Truncation [BLOCKING]

Indicators:
- Unbalanced `{}`, `[]`, `()`
- Unclosed strings or comments
- File ends mid-statement
- Imports declared but unused
- Functions called but undefined

### S005: Stub Functions [HIGH]

Function exists but doesn't work. Patterns:
- Returns hardcoded value ignoring params
- Returns input unchanged
- Only logs/prints
- Empty body or just `pass`/`return`
- Delegates to another stub

Detection: Does function body USE the parameters meaningfully?

### S006: Partial Iteration [HIGH]

Request: "Handle GET, POST, PUT, DELETE"
Shortcut: Only GET and POST implemented

Count items requested vs items implemented. Verify each has REAL implementation.

### S007: Missing Components [HIGH]

- Error types thrown but undefined
- Helpers called but not implemented
- Types referenced but not provided
- Config files mentioned but not created

Detection: Every identifier must be imported, defined, or built-in.

---

## Logic Shortcuts (S008-S012)

### S008: Happy Path Only [HIGH]

No handling for:
- Null/undefined/None inputs
- Wrong types
- Empty collections
- Network failures
- File not found
- Permission denied
- Timeout

Questions to ask:
1. What if input is null?
2. What if input is wrong type?
3. What if external call fails?
4. What if resource doesn't exist?

### S009: Edge Case Ignorance [HIGH]

#### Numeric
- Zero (division, indices)
- Negative (when positive expected)
- Overflow/underflow
- NaN, Infinity
- Floating point precision

#### Collections
- Empty `[]`, `{}`, `""`
- Single element
- Very large (memory/performance)
- Duplicates
- Nested structures

#### Strings
- Empty, whitespace-only
- Unicode (emoji, RTL, combining)
- Special chars (quotes, backslash, null byte)
- Very long

#### Temporal
- Midnight, year boundaries
- Leap years, DST
- Timezone edge cases

#### Concurrency
- Race conditions
- Resource exhaustion
- Partial failure
- Timeout during operation

### S010: Simplified Algorithm [HIGH]

Request requires complex algorithm, AI implements simpler one.

Examples:
- Quicksort requested → bubble sort implemented
- Nested parsing → regex that fails on nesting
- Graph with cycles → tree traversal without cycle detection

Detection: Does implementation complexity match problem complexity?

### S011: Hardcoded Assumptions [MEDIUM]

```
const TIMEOUT = 5000;        // Should be configurable
const API_URL = "https://prod.example.com";  // Should vary by env
const PAGE_SIZE = 10;        // Should be parameter
```

### S012: Inverted Logic [HIGH]

- "reject invalid" → accepts invalid
- "sort descending" → sorts ascending
- "find NOT matching" → finds matching
- "throw if X" → throws if NOT X

Detection: State condition in words, compare to requirement exactly.

---

## Hallucination Shortcuts (S013-S016)

### S013: Hallucinated Imports [BLOCKING]

Common fakes:

| Language | Fake | Real |
|----------|------|------|
| Python | `from collections import OrderedSet` | `ordered_set` package |
| JS | `import { useAsyncEffect } from 'react'` | Doesn't exist |
| Rust | `use std::collections::OrderedMap` | `indexmap` crate |

### S014: Hallucinated Methods [BLOCKING]

| Fake | Real |
|------|------|
| `array.flatten()` | `array.flat()` |
| `string.contains()` | `string.includes()` (JS) |
| `Object.deepCopy()` | `structuredClone()` |

Also: wrong parameter order, invented optional params, wrong return types.

### S015: Hallucinated Behavior [HIGH]

Incorrect assumptions:
- `Array.sort()` is stable (not until ES2019)
- `JSON.parse()` returns null on error (it throws)
- File operations are atomic (they aren't)
- Dictionary iteration order (varies)

### S016: Hallucinated Config [MEDIUM]

- Invented CLI flags
- Non-existent env vars
- Made-up config syntax
- Invalid option values

---

## Requirement Drift (S017-S020)

### S017: Wrong Problem [BLOCKING]

Code solves different problem than asked.
- "shortest path" → any path
- "case-insensitive" → case-sensitive
- "concurrent" → sequential

### S018: Scope Reduction [HIGH]

Implements subset, ignores rest.
- "all HTTP codes" → only 200 and 500
- "CRUD" → only CR

### S019: Scope Expansion [MEDIUM]

Adds unrequested features while missing requested ones. The extras distract from missing requirements.

### S020: Interface Mismatch [HIGH]

- Different function names
- Different parameter shapes
- Different return types
- Throws instead of returns error

---

## Pseudo-Tests (S021-S025)

### S021: Tautological Tests [HIGH]

```python
assert True
expect(something).toBeDefined()  # When that's trivial
```

### S022: Happy Path Only Tests [HIGH]

No tests for:
- Invalid input
- Error conditions
- Edge cases
- Concurrent scenarios

### S023: Implementation-Coupled [HIGH]

Tests internal details not behavior:
- Specific method call counts
- Exact log messages
- Iteration order when order irrelevant

### S024: Mock Abuse [HIGH]

Everything mocked → test verifies mocks return what mocks return.

### S025: Bug-Mirroring Tests [HIGH]

Expected values copied from buggy output. Tests pass despite bugs.

---

## Quality Shortcuts (S026-S030)

### S026: Copy-Paste Code [MEDIUM]

Duplicated blocks that should be functions.

### S027: God Functions [MEDIUM]

- \>50 lines
- Deep nesting
- Does unrelated things
- Multiple levels of abstraction

### S028: Inefficient Algorithms [MEDIUM]

- Nested loops that could use hash map
- String concat in loops
- Object creation in tight loops
- N+1 queries

### S029: Resource Leaks [MEDIUM]

Unclosed: file handles, connections, sockets, listeners, timers, locks.

### S030: Poor Naming [LOW]

Single-letter vars, generic names (`data`, `result`, `temp`), misleading names.
