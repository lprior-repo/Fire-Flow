# Rosetta Stone: Nushell → Python Translation

You are translating Nushell scripts to equivalent Python code.

## Context

These scripts are part of the bitter-truth system where:
- AI generates Nushell scripts
- DataContract validates output
- Kestra orchestrates execution

The Python translation must produce **identical output** to the Nushell original.

## Translation Rules

### Data Flow

| Nushell | Python |
|---------|--------|
| `open file.json` | `pd.read_json('file.json')` or `json.load(open('file.json'))` |
| `open file.csv` | `pd.read_csv('file.csv')` |
| `$in \| from json` | `json.loads(stdin.read())` |
| `to json` | `json.dumps(data)` |
| `save file.json` | `json.dump(data, open('file.json', 'w'))` |

### Filtering & Selection

| Nushell | Python (Pandas) |
|---------|-----------------|
| `where col > 10` | `df[df['col'] > 10]` |
| `where col =~ 'pattern'` | `df[df['col'].str.contains('pattern')]` |
| `select col1 col2` | `df[['col1', 'col2']]` |
| `get col` | `df['col'].tolist()` |
| `first 5` | `df.head(5)` |
| `last 5` | `df.tail(5)` |

### Transformation

| Nushell | Python |
|---------|--------|
| `each {\|x\| $x * 2}` | `[x * 2 for x in items]` or `df.apply(lambda x: x * 2)` |
| `sort-by col` | `df.sort_values('col')` |
| `sort-by col --reverse` | `df.sort_values('col', ascending=False)` |
| `group-by col` | `df.groupby('col')` |
| `length` | `len(df)` |
| `reverse` | `df.iloc[::-1]` or `list(reversed(items))` |

### String Operations

| Nushell | Python |
|---------|--------|
| `str upcase` | `.upper()` |
| `str downcase` | `.lower()` |
| `str trim` | `.strip()` |
| `str length` | `len(s)` |
| `split chars` | `list(s)` |
| `str join` | `''.join(chars)` |
| `lines` | `text.splitlines()` |

### Records & Tables

| Nushell | Python |
|---------|--------|
| `{name: "x", value: 1}` | `{"name": "x", "value": 1}` |
| `$record.field` | `record['field']` |
| `$record.field?` | `record.get('field')` |
| `update col { val }` | `df['col'] = val` |

### Control Flow

| Nushell | Python |
|---------|--------|
| `if $cond { a } else { b }` | `a if cond else b` |
| `for x in $list { }` | `for x in items:` |
| `try { } catch { }` | `try: ... except: ...` |

### I/O

| Nushell | Python |
|---------|--------|
| `print -e "msg"` | `print("msg", file=sys.stderr)` |
| `open --raw /dev/stdin` | `sys.stdin.read()` |

## Template

Given a Nushell script, produce Python that:

1. Uses `pandas` for table operations
2. Uses `json` for serialization
3. Reads from `sys.stdin` if the original uses `/dev/stdin`
4. Writes to `sys.stdout` for main output
5. Writes to `sys.stderr` for logs
6. Returns same exit codes

## Example

### Nushell Input
```nu
def main [] {
    let input = open --raw /dev/stdin | from json
    let message = $input.message? | default ""

    if ($message | is-empty) {
        { success: false, error: "message required" } | to json | print
        exit 1
    }

    {
        success: true
        data: {
            echo: $message
            reversed: ($message | split chars | reverse | str join)
            length: ($message | str length)
        }
    } | to json | print
}
```

### Python Output
```python
#!/usr/bin/env python3
import sys
import json

def main():
    input_data = json.loads(sys.stdin.read())
    message = input_data.get("message", "")

    if not message:
        print(json.dumps({"success": False, "error": "message required"}))
        sys.exit(1)

    output = {
        "success": True,
        "data": {
            "echo": message,
            "reversed": message[::-1],
            "length": len(message)
        }
    }
    print(json.dumps(output))

if __name__ == "__main__":
    main()
```

## Instructions

Translate the following Nushell script to Python:

```nu
{NUSHELL_SCRIPT}
```

Produce equivalent Python that passes the same DataContract validation.
