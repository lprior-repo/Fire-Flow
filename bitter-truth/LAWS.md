# The 4 Laws of bitter-truth

**AI is the operator. Humans are the architects.**

---

## Law 1: The No-Human Zone

**Humans must never write Nushell scripts manually.**

- All `.nu` files are AI-generated
- Humans write **contracts** and **prompts**
- AI compiles intent → Nushell → execution

---

## Law 2: The Contract is the Law

**DataContract validation must be draconian.**

Since AI writes all logic, the contract is the only safeguard.

When validation fails:
1. AI self-heals automatically
2. After N failures: fix the **prompt**, not the code
3. Never: human edits Nushell directly

---

## Law 3: We Set the Standard

**Humans define the target. AI figures out how to hit it.**

```
Human: "I need X with Y constraints"
        ↓
   [Contract]  ← The standard
        ↓
   [AI Loop]   ← bitter-truth finds the path
        ↓
   [Output]    ← Meets the standard or fails
```

The human sets the bar. The AI clears it.

---

## Law 4: Orchestrator Runs Everything

**Kestra owns execution. Nothing runs outside orchestration.**

- No ad-hoc scripts
- No manual invocations in production
- Every execution is tracked, timed, retried
- The orchestrator is the single source of truth for what ran

```
Human Intent → Contract → Kestra → AI → Nushell → Validation → Done
                           ↑
                     Everything flows through here
```

---

## Summary

| Law | Rule |
|-----|------|
| 1 | AI writes all Nushell |
| 2 | Contract validates all output |
| 3 | Human sets standard, AI hits it |
| 4 | Orchestrator runs everything |

**The AI is the operator. The contract is the law. The orchestrator is the runtime.**
