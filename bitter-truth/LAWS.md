# The 3 Laws of bitter-truth

This system operates under a fundamental paradigm shift:

**AI is the operator. Humans are the architects.**

Nushell outputs structured data. Bash outputs text. For an AI, structured data
is the path of least resistance. We optimize the environment for the operator.

---

## Law 1: The No-Human Zone

**Humans must never write Nushell scripts manually.**

If a human starts writing Nushell, the system has failed. The cognitive load
for humans to learn a niche shell is too high. This stack only works if the
AI is the exclusive author.

### Implications

- All `.nu` files are AI-generated
- Humans write **contracts** (DataContract YAML)
- Humans write **prompts** (natural language intent)
- AI compiles intent → Nushell → execution

### The Compiler Metaphor

```
Human Intent (English)
        ↓
   [OpenCode]     ← AI as Compiler
        ↓
Nushell Script    ← Machine Code for AI
        ↓
   [Kestra]       ← CPU (Scheduling)
        ↓
Structured Output
        ↓
 [DataContract]   ← Memory Protection (Validation)
```

---

## Law 2: The Contract is the Law

**DataContract validation must be draconian.**

Since AI writes all logic, the validation of output is the only safeguard
against hallucinated pipelines that could corrupt or destroy data.

### The Self-Healing Protocol

When DataContract validation fails:

1. **Attempt 1-3**: AI self-heals the Nushell script automatically
2. **Attempt 4+**: Page human—not to fix the script, but to fix the **prompt**
3. **Never**: Human edits Nushell directly

```
Contract Failure
      ↓
  [Feedback]  → "Field 'amount' expected integer, got string"
      ↓
  [OpenCode]  → Regenerate Nushell with constraint
      ↓
  [Validate]  → Pass? Done : Loop
      ↓
  [Escalate]  → After N failures, fix the PROMPT not the CODE
```

### Contract Structure

```yaml
# The contract is GOD
models:
  Output:
    fields:
      amount:
        type: integer        # NOT negotiable
        required: true       # NOT optional
        minimum: 0           # NOT negative
```

---

## Law 3: The Ejection Seat

**Maintain escape velocity from Nushell.**

Nushell has <1% market share. If it dies, the AI loses its hands. Every
Nushell script must be translatable to Python/Pandas via the Rosetta Stone.

### The Rosetta Stone

A prompt that lives in `prompts/rosetta-stone.md` can translate any
bitter-truth Nushell script to equivalent Python:

```
Nushell:  sys | get cpu | where usage > 80
Python:   df[df['usage'] > 80]
```

### Escape Conditions

Trigger migration to Python if:

- Nushell project goes unmaintained (>6 months no release)
- Critical bug with no fix
- Performance bottleneck in Nushell itself

### Migration Path

```
1. Run rosetta-stone prompt on all .nu files
2. Generate equivalent Python scripts
3. Update Kestra flows to call Python
4. DataContracts unchanged (they're language-agnostic)
```

---

## Summary

| Law | Rule | Violation Means |
|-----|------|-----------------|
| 1 | AI writes all Nushell | Human cognitive overload |
| 2 | Contract validates all output | Hallucinated destruction |
| 3 | Rosetta Stone exists | Vendor lock-in to dead project |

**The AI is the operator. The contract is the law. The exit is always open.**
