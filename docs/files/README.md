# AI Code Validator

A hybrid system for validating AI-generated code. Uses XML DAG for execution flow, Markdown for reference content.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  VALIDATOR_DAG.xml    ← Execution logic (load for agents)  │
│  ├── Phase dependencies & blocking conditions              │
│  ├── State transitions                                     │
│  └── Module loading triggers                               │
├─────────────────────────────────────────────────────────────┤
│  CORE.md              ← Quick reference (load for humans)  │
├─────────────────────────────────────────────────────────────┤
│  SHORTCUTS.md         ← Full taxonomy (30 patterns)        │
│  LANG_RUST.md         ← Rust: RS001-RS010                  │
│  LANG_GO.md           ← Go: GO001-GO009                    │
│  LANG_GLEAM.md        ← Gleam: GL001-GL010                 │
│  LANG_NUSHELL.md      ← Nushell: NU001-NU010               │
│  LANG_KESTRA.md       ← Kestra: KE001-KE010                │
│  EXAMPLES.md          ← Training examples                  │
└─────────────────────────────────────────────────────────────┘
```

## Why Hybrid?

Based on Anthropic's research:
- **XML** for complex, multi-step, strict-section tasks with dependencies
- **Markdown** for human-readable reference content

The validator needs both:
- Machine-parseable DAG for agentic execution (XML)
- Maintainable checklists and examples (Markdown)

See `ANALYSIS.md` for full rationale.

## Usage

### Agentic Workflow (Cohort/governance)
```
Load: VALIDATOR_DAG.xml + LANG_*.md (per detected language)
```

### Human Review
```
Load: CORE.md + SHORTCUTS.md + LANG_*.md
```

### Training
```
Load: All modules including EXAMPLES.md
```

## Validation DAG

```
P1_REQUIREMENTS ──→ P2_COMPLETENESS ──→ P3_REQUIREMENTS ──→ ...
                         │                    │
                    [BLOCKING]           [BLOCKING]
                         │                    │
                         ▼                    ▼
                      REJECT               REJECT
                         
... ──→ P4_CORRECTNESS ──→ P5_HALLUCINATION ──→ P6_TESTS ──→ P7_QUALITY ──→ VERDICT
                                   │
                              [BLOCKING]
                                   │
                                   ▼
                                REJECT
```

Blocking phases halt on failure. Non-blocking phases accumulate issues.

## Verdicts

| Verdict | Criteria |
|---------|----------|
| `PASS` | All requirements met, no blocking issues |
| `NEEDS_WORK` | Requirements met but HIGH/MEDIUM issues exist |
| `REJECT` | Incomplete, requirements unmet, or hallucinated APIs |

## Token Efficiency

| Load Profile | ~Tokens | When |
|--------------|---------|------|
| CORE.md only | 1,500 | Quick reference |
| DAG + 1 lang | 4,000 | Targeted validation |
| Full stack | 15,000 | Deep review |

## Adding Languages

1. Create `LANG_[NAME].md` following existing pattern
2. Add module reference to `VALIDATOR_DAG.xml` config
3. Include:
   - Language-specific shortcuts (XX001-XX0nn)
   - Hallucination table (fake vs real APIs)
   - Edge cases unique to language
   - Validation checklist
