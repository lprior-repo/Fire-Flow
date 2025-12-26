# AI Code Validator - Rust Module

Rust-specific shortcuts, hallucinations, and validation rules. Load when reviewing Rust code.

---

## Rust-Specific Shortcuts

### RS001: Ownership Avoidance [HIGH]

AI clones excessively to avoid borrow checker.

```rust
// Shortcut: Clone everything
fn process(data: Vec<String>) -> Vec<String> {
    let copy = data.clone();  // Unnecessary
    transform(copy.clone())    // Double unnecessary
}

// Correct: Use references
fn process(data: &[String]) -> Vec<String> {
    transform(data)
}
```

Detection: Count `.clone()` calls. Question each one - is it necessary?

### RS002: Lifetime Elision Abuse [HIGH]

AI adds explicit lifetimes incorrectly or omits required ones.

```rust
// Wrong: Unnecessary explicit lifetime
fn get_name<'a>(user: &'a User) -> &'a str {
    &user.name
}

// Correct: Elision handles this
fn get_name(user: &User) -> &str {
    &user.name
}

// Wrong: Missing required lifetime
fn longest(a: &str, b: &str) -> &str {  // Won't compile
    if a.len() > b.len() { a } else { b }
}

// Correct: Lifetime needed
fn longest<'a>(a: &'a str, b: &'a str) -> &'a str {
    if a.len() > b.len() { a } else { b }
}
```

### RS003: Unwrap Abuse [HIGH]

AI uses `.unwrap()` everywhere instead of proper error handling.

```rust
// Shortcut
let file = File::open(path).unwrap();
let content = std::fs::read_to_string(path).unwrap();
let num: i32 = input.parse().unwrap();

// Correct
let file = File::open(path)?;
let content = std::fs::read_to_string(path)
    .map_err(|e| MyError::FileRead { path, source: e })?;
let num: i32 = input.parse()
    .map_err(|_| MyError::InvalidNumber(input.to_string()))?;
```

Detection: Search for `.unwrap()`, `.expect()`. Each must be justified.

### RS004: Expect Without Context [MEDIUM]

```rust
// Bad
let config = load_config().expect("failed");

// Good
let config = load_config()
    .expect("Failed to load config from ~/.config/app/config.toml");
```

### RS005: Result/Option Confusion [HIGH]

AI returns `Option` when `Result` needed (loses error info) or vice versa.

```rust
// Wrong: Loses error context
fn parse_config(path: &Path) -> Option<Config> {
    let content = std::fs::read_to_string(path).ok()?;  // Error lost
    serde_json::from_str(&content).ok()                  // Error lost
}

// Correct: Preserves errors
fn parse_config(path: &Path) -> Result<Config, ConfigError> {
    let content = std::fs::read_to_string(path)
        .map_err(|e| ConfigError::Read { path: path.into(), source: e })?;
    serde_json::from_str(&content)
        .map_err(|e| ConfigError::Parse { path: path.into(), source: e })
}
```

### RS006: String Type Confusion [MEDIUM]

AI uses `String` when `&str` sufficient or wrong conversions.

```rust
// Wasteful
fn greet(name: String) { println!("Hello {name}"); }
greet("World".to_string());  // Allocation for no reason

// Correct
fn greet(name: &str) { println!("Hello {name}"); }
greet("World");

// Also wrong: &String instead of &str
fn process(s: &String) { ... }  // Should be &str
```

### RS007: Iterator Shortcuts [HIGH]

AI collects into Vec unnecessarily or uses loops instead of iterators.

```rust
// Shortcut: Unnecessary collect
let doubled: Vec<i32> = nums.iter().map(|x| x * 2).collect();
let sum: i32 = doubled.iter().sum();  // Wasted allocation

// Correct: Chain iterators
let sum: i32 = nums.iter().map(|x| x * 2).sum();

// Shortcut: Loop instead of iterator
let mut results = Vec::new();
for item in items {
    if item.is_valid() {
        results.push(item.transform());
    }
}

// Correct
let results: Vec<_> = items.iter()
    .filter(|item| item.is_valid())
    .map(|item| item.transform())
    .collect();
```

### RS008: Async Pitfalls [HIGH]

#### Missing Send bounds
```rust
// Won't work with tokio::spawn
async fn process(data: Rc<Data>) { ... }  // Rc is !Send

// Correct
async fn process(data: Arc<Data>) { ... }
```

#### Blocking in async
```rust
// Wrong: Blocks executor
async fn read_file(path: &Path) -> String {
    std::fs::read_to_string(path).unwrap()  // Blocking!
}

// Correct
async fn read_file(path: &Path) -> Result<String, io::Error> {
    tokio::fs::read_to_string(path).await
}
```

#### Holding locks across await
```rust
// Deadlock risk
async fn update(state: &Mutex<State>) {
    let mut guard = state.lock().unwrap();
    external_call().await;  // Lock held across await!
    guard.value = 42;
}

// Correct
async fn update(state: &Mutex<State>) {
    let new_value = external_call().await;
    let mut guard = state.lock().unwrap();
    guard.value = new_value;
}
```

### RS009: Unsafe Misuse [BLOCKING]

AI uses `unsafe` to bypass borrow checker instead of fixing design.

```rust
// Wrong: Unsafe to avoid lifetime issues
unsafe fn get_ref<'a>(data: &Data) -> &'a str {
    std::mem::transmute(data.get_name())  // UB waiting to happen
}

// Red flags in unsafe blocks:
// - transmute
// - Raw pointer arithmetic without bounds checks
// - Mutable aliasing
// - Dereferencing user-provided pointers
```

Detection: Every `unsafe` block needs explicit justification. Question heavily.

### RS010: Derive Gaps [MEDIUM]

AI forgets necessary derives or adds unnecessary ones.

```rust
// Missing Clone needed for .clone() call elsewhere
#[derive(Debug)]
struct Config { ... }

// Missing PartialEq needed for assert_eq! in tests
#[derive(Debug, Clone)]
struct Response { ... }

// Unnecessary: Derive traits never used
#[derive(Debug, Clone, PartialEq, Eq, Hash, PartialOrd, Ord, Default)]
struct SimpleWrapper(i32);  // Probably only needs Debug
```

---

## Rust Hallucinations

### Hallucinated std Types/Methods

| Hallucination | Reality |
|---------------|---------|
| `std::collections::OrderedMap` | Use `indexmap` crate |
| `std::collections::OrderedSet` | Use `indexmap::IndexSet` |
| `String::is_empty_or_whitespace()` | `s.trim().is_empty()` |
| `Vec::remove_all()` | `vec.retain(\|x\| ...)` or `vec.clear()` |
| `Option::contains()` | Only on nightly, use `opt == Some(val)` |
| `Result::contains()` | Doesn't exist |
| `Path::exists()` | Correct! But `try_exists()` for Result |
| `HashMap::get_or_insert()` | Use `.entry().or_insert()` |
| `String::split_at_str()` | Use `split_once()` |
| `Iterator::intersperse()` | Nightly only |

### Hallucinated Error Handling

```rust
// Wrong: No TryFrom for many expected conversions
let x: u32 = some_i64.try_into()?;  // May not exist for all types

// Wrong: ? in main without setup
fn main() {
    let f = File::open("x")?;  // Won't compile without return type
}

// Correct
fn main() -> Result<(), Box<dyn Error>> {
    let f = File::open("x")?;
    Ok(())
}
```

### Hallucinated Async

| Hallucination | Reality |
|---------------|---------|
| `async std::fs::*` | Use `tokio::fs` |
| `std::sync::Mutex` in async | Use `tokio::sync::Mutex` |
| `.await` on std types | std is sync, need async runtime types |
| `#[tokio::main]` without dep | Need `tokio` in Cargo.toml |

### Hallucinated Traits

```rust
// Wrong: Copy on types containing String/Vec
#[derive(Copy, Clone)]
struct Data {
    name: String,  // String is !Copy
}

// Wrong: Assuming Default exists
let config = Config::default();  // Only if #[derive(Default)] or impl
```

---

## Rust Edge Cases

### Integer Overflow

```rust
// Debug: panics. Release: wraps silently!
let x: u8 = 255;
let y = x + 1;  // Panic in debug, 0 in release

// Explicit behavior
let y = x.wrapping_add(1);   // Always wraps: 0
let y = x.saturating_add(1); // Clamps: 255
let y = x.checked_add(1);    // Returns None
```

### String Indexing

```rust
// Wrong: Rust strings aren't char-indexable
let c = s[0];  // Won't compile

// Correct
let c = s.chars().next();
let c = s.as_bytes()[0];  // Only if you know it's ASCII
let substring = &s[0..4]; // Panics if not char boundary!
```

### Slice Patterns

```rust
// Panic on empty
let [first, ..] = &slice[..];  // Panics if slice empty

// Safe
if let [first, ..] = &slice[..] { ... }
// Or
let first = slice.first();
```

---

## Rust Validation Checklist

### Ownership & Borrowing
- [ ] No unnecessary `.clone()` calls
- [ ] References used where ownership not needed
- [ ] Lifetimes only where elision insufficient
- [ ] No `&String` params (use `&str`)
- [ ] No `&Vec<T>` params (use `&[T]`)

### Error Handling
- [ ] No unexplained `.unwrap()`
- [ ] `.expect()` has useful message
- [ ] `Result` used when error context matters
- [ ] `?` propagation used consistently
- [ ] Custom error types where appropriate

### Async
- [ ] No blocking ops in async fns
- [ ] `tokio::fs` not `std::fs` in async
- [ ] `tokio::sync::Mutex` not `std::sync` if held across await
- [ ] `Send` bounds for spawned futures
- [ ] No locks held across `.await`

### Safety
- [ ] Every `unsafe` block justified
- [ ] No `transmute` without extremely good reason
- [ ] Raw pointer use has bounds checking
- [ ] FFI boundaries validated

### Performance
- [ ] Iterators preferred over loops with collect
- [ ] No unnecessary allocations in hot paths
- [ ] `&str` over `String` for read-only
- [ ] `Cow<str>` for maybe-owned strings
- [ ] `Box<[T]>` over `Vec<T>` for fixed-size

### Idioms
- [ ] `if let` / `match` over `.is_some()` + `.unwrap()`
- [ ] `?` over `match` for error propagation
- [ ] Builder pattern for complex construction
- [ ] `impl Into<T>` for flexible APIs
- [ ] `Default` implemented where sensible
