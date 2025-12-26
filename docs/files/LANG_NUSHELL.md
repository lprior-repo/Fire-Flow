# AI Code Validator - Nushell Module

Nushell-specific shortcuts, hallucinations, and validation rules. Load when reviewing Nushell code.

---

## Nushell-Specific Shortcuts

### NU001: Ignoring Structured Data [HIGH]

AI treats Nushell output as strings instead of structured data.

```nu
# Shortcut: String parsing (bash-brain)
ls | lines | each { |line| $line | split column ' ' | get 0 }

# Correct: Use structured data
ls | get name

# Shortcut: grep-style
open data.json | to text | find "error"

# Correct: Query structure
open data.json | where type == "error"
```

### NU002: String Interpolation Mistakes [MEDIUM]

AI confuses string interpolation syntax.

```nu
# Wrong: Bash-style
let name = "world"
echo "hello $name"  # Prints literal $name

# Correct: Nushell interpolation
let name = "world"
$"hello ($name)"

# Wrong: Expression in double quotes
let x = 5
echo "result: $x + 1"  # No math

# Correct
$"result: ($x + 1)"
```

### NU003: Pipeline Type Errors [HIGH]

AI doesn't track types through pipelines.

```nu
# Bug: get on wrong type
"hello" | get name  # Error: string doesn't have 'name'

# Bug: Expecting list, got record
{name: "alice"} | each { |x| $x }  # Error

# Correct: Match command to input type
{name: "alice"} | get name  # "alice"
[{name: "alice"}] | each { |x| $x.name }  # ["alice"]
```

### NU004: Closure Capture Issues [MEDIUM]

AI uses external variables incorrectly in closures.

```nu
# Works in newer Nushell (auto-capture)
let multiplier = 2
[1 2 3] | each { |x| $x * $multiplier }

# But external commands need different handling
let pattern = "error"
ls | where { |row| $row.name | str contains $pattern }  # Might need explicit capture

# Correct: Explicit capture if needed
let pattern = "error"
ls | where { |row| 
  let pat = $pattern  # Capture
  $row.name | str contains $pat 
}
```

### NU005: Error Handling Avoidance [HIGH]

AI ignores potential errors in commands.

```nu
# Shortcut: No error handling
def process-file [path: string] {
  open $path | get data | process
}

# Correct: Handle errors
def process-file [path: string] {
  let content = try {
    open $path
  } catch {
    error make { msg: $"Failed to open ($path)" }
  }
  
  $content | get data? | default [] | process
}
```

### NU006: Custom Command Issues [HIGH]

#### Missing type annotations
```nu
# Weak: No types
def greet [name] {
  $"Hello ($name)"
}

# Strong: Typed
def greet [name: string] -> string {
  $"Hello ($name)"
}
```

#### Flag confusion
```nu
# Wrong: Positional treated as flag
def search [--pattern] {  # No value
  ...
}

# Correct: Flag with value
def search [--pattern: string] {
  ...
}

# Correct: Boolean flag
def search [--verbose(-v)] {
  if $verbose { ... }
}
```

#### Rest parameters
```nu
# Wrong: Can't collect args
def concat [a b c] {
  [$a $b $c] | str join
}

# Correct: Rest parameter
def concat [...items: string] {
  $items | str join
}
```

### NU007: Table vs List vs Record Confusion [HIGH]

```nu
# Record (single item, key-value)
{name: "alice", age: 30}

# List (multiple items)
[1, 2, 3]
["a", "b", "c"]

# Table (list of records)
[[name, age]; ["alice", 30], ["bob", 25]]
# or
[{name: "alice", age: 30}, {name: "bob", age: 25}]

# Bug: Treating table like record
let users = [[name, age]; ["alice", 30]]
$users.name  # Error: table doesn't support direct access

# Correct
$users | get name  # ["alice"]
($users | first).name  # "alice"
```

### NU008: Subexpression vs Block [MEDIUM]

```nu
# Subexpression: Immediate evaluation, returns value
(ls | length)

# Block: Deferred execution
{ ls | length }

# Wrong: Block where subexpression needed
if { true } { ... }  # Error

# Correct
if (true) { ... }
if true { ... }

# Wrong: Subexpression for lazy eval
let lazy = (expensive_operation)  # Runs immediately

# Correct: Use closure for lazy
let lazy = { expensive_operation }
do $lazy  # Runs when called
```

### NU009: Null Handling [HIGH]

```nu
# Bug: Accessing potentially missing field
open data.json | get config.setting  # Crashes if missing

# Correct: Optional access
open data.json | get config.setting?  # Returns null if missing
open data.json | get config.setting? | default "fallback"

# Wrong: Null comparison
if $value == null { ... }  # Syntax depends on version

# Correct
if ($value | is-empty) { ... }
if ($value == null) { ... }  # Check Nu version syntax
```

### NU010: External Command Integration [MEDIUM]

```nu
# Bug: Expecting structured output from external
^git status | get modified  # Error: external returns string

# Correct: Parse external output
^git status --porcelain | lines | parse "{status} {file}"

# Bug: Not handling external errors
^curl $url | from json

# Correct: Check exit code
let result = do { ^curl -f $url } | complete
if $result.exit_code != 0 {
  error make { msg: $"Curl failed: ($result.stderr)" }
}
$result.stdout | from json
```

---

## Nushell Hallucinations

### Confused with Bash

| Bash | Nushell |
|------|---------|
| `$variable` | `$variable` (same! but in strings: `$"($var)"`) |
| `$(command)` | `(command)` |
| `export VAR=value` | `$env.VAR = "value"` |
| `if [ condition ]` | `if condition { }` |
| `for i in 1 2 3` | `for i in [1 2 3] { }` |
| `command \| grep pattern` | `command \| where column =~ pattern` |
| `command > file` | `command \| save file` |
| `command 2>&1` | `command \| complete` |
| `` `backticks` `` | No backtick execution |
| `&&` and `\|\|` | `and` and `or` (or just pipeline) |

### Confused with PowerShell

| PowerShell | Nushell |
|------------|---------|
| `$_.Property` | `$in.property` or `{ \|row\| $row.property }` |
| `ForEach-Object` | `each` |
| `Where-Object` | `where` |
| `Select-Object` | `select` |
| `@(array)` | `[array]` |
| `@{hash=table}` | `{key: value}` |
| `$null` | `null` |
| `-eq`, `-ne` | `==`, `!=` |

### Hallucinated Commands

| Hallucination | Reality |
|---------------|---------|
| `echo` (for strings) | Use bare string or `print` |
| `map` | Use `each` |
| `filter` | Use `where` |
| `reduce` with different signature | `reduce { \|acc, it\| ... }` |
| `head`/`tail` | `first`/`last` |
| `cut` | `select` or `get` |
| `awk` | Built-in table operations |
| `sed` | `str replace` |
| `jq` | Built-in JSON handling |

### Hallucinated Syntax

```nu
# Wrong: Bash-style variable assignment
name="value"

# Correct
let name = "value"
mut name = "value"  # If mutable

# Wrong: Bash-style function
function greet() { ... }

# Correct
def greet [] { ... }

# Wrong: Bash-style arrays
arr=(1 2 3)

# Correct
let arr = [1 2 3]

# Wrong: Bash-style conditionals
if [[ $x == "y" ]]; then ... fi

# Correct
if $x == "y" { ... }
```

### Hallucinated Operators

| Hallucination | Reality |
|---------------|---------|
| `.` for method calls | Use `\|` pipeline |
| `->` for lambdas | `{ \|x\| ... }` |
| `..` exclusive range | `0..5` is inclusive, use `0..<5` |
| `++` for concat | `append` or `$list1 ++ $list2` (check version) |
| `//` for default | `? \| default value` |

---

## Nushell Edge Cases

### Numeric Types

```nu
# Integers and floats are distinct
5 / 2      # 2 (integer division)
5.0 / 2.0  # 2.5

# Explicit conversion
5 | into float | $in / 2  # 2.5

# Filesizes are special
1gb + 500mb  # 1.5gb
1gb / 1mb    # 1024

# Durations
1hr + 30min  # 1hr 30min
```

### Path Handling

```nu
# Paths are structured
let p = "/home/user/file.txt" | path parse
# {parent: "/home/user", stem: "file", extension: "txt"}

# Wrong: String concat for paths
$dir + "/" + $file

# Correct: Path join
$dir | path join $file
```

### Environment Variables

```nu
# Read
$env.PATH

# Write (persists in session)
$env.MY_VAR = "value"

# Temporary (for one command)
with-env { MY_VAR: "value" } { command }

# Load from file
source env.nu
```

### Immutability

```nu
# Default immutable
let x = 5
$x = 6  # Error!

# Explicit mutability
mut x = 5
$x = 6  # OK

# Collections are deep-immutable
let data = {a: {b: 1}}
$data.a.b = 2  # Error!

# Must reconstruct
let data = {a: {b: 1}}
let data = ($data | upsert a.b 2)
```

---

## Nushell Validation Checklist

### Type Awareness
- [ ] Commands match input type (record vs list vs table)
- [ ] String interpolation uses `$"(...)"` syntax
- [ ] Numeric operations respect int vs float
- [ ] Paths use `path join`, not string concat
- [ ] External commands wrapped appropriately

### Error Handling
- [ ] `try`/`catch` around fallible operations
- [ ] Optional access `?` for potentially missing fields
- [ ] `default` values for nullable results
- [ ] External command exit codes checked

### Custom Commands
- [ ] Type annotations on parameters
- [ ] Return type specified
- [ ] Flags properly typed (`:type` vs boolean)
- [ ] Rest parameters where variable args needed
- [ ] Documentation comments added

### Pipeline Patterns
- [ ] Structured data used (not string parsing)
- [ ] Appropriate commands for data shape
- [ ] No unnecessary conversions (to text and back)
- [ ] Streaming where possible (avoid `collect`)

### Idioms
- [ ] `each` not `for` for transformations
- [ ] `where` not grep/filter
- [ ] `select`/`get` not cut/awk
- [ ] Built-in parsers (json, csv, toml) not external tools
- [ ] `$in` for implicit piped value in blocks
