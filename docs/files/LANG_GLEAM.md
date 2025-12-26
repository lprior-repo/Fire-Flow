# AI Code Validator - Gleam Module

Gleam-specific shortcuts, hallucinations, and validation rules. Load when reviewing Gleam code.

---

## Gleam-Specific Shortcuts

### GL001: Result Ignorance [HIGH]

AI uses `let assert` everywhere instead of proper error handling.

```gleam
// Shortcut: Crashes on error
pub fn load_config(path: String) -> Config {
  let assert Ok(content) = simplifile.read(path)
  let assert Ok(config) = json.decode(content, config_decoder)
  config
}

// Correct: Propagate errors
pub fn load_config(path: String) -> Result(Config, ConfigError) {
  use content <- result.try(
    simplifile.read(path)
    |> result.map_error(fn(_) { ConfigError(ReadFailed(path)) })
  )
  use config <- result.try(
    json.decode(content, config_decoder)
    |> result.map_error(fn(e) { ConfigError(ParseFailed(e)) })
  )
  Ok(config)
}
```

Detection: Count `let assert Ok(...)`. Each needs justification.

### GL002: Use Expression Avoidance [MEDIUM]

AI writes nested case expressions instead of using `use`.

```gleam
// Shortcut: Pyramid of doom
pub fn process(input: String) -> Result(Output, Error) {
  case parse(input) {
    Ok(parsed) -> {
      case validate(parsed) {
        Ok(valid) -> {
          case transform(valid) {
            Ok(result) -> Ok(result)
            Error(e) -> Error(TransformError(e))
          }
        }
        Error(e) -> Error(ValidationError(e))
      }
    }
    Error(e) -> Error(ParseError(e))
  }
}

// Correct: Use expressions
pub fn process(input: String) -> Result(Output, Error) {
  use parsed <- result.try(
    parse(input) |> result.map_error(ParseError)
  )
  use valid <- result.try(
    validate(parsed) |> result.map_error(ValidationError)
  )
  use result <- result.try(
    transform(valid) |> result.map_error(TransformError)
  )
  Ok(result)
}
```

### GL003: Pattern Match Gaps [HIGH]

AI doesn't handle all cases in pattern matching.

```gleam
// Bug: Non-exhaustive (won't compile, but AI might generate)
pub fn describe(status: Status) -> String {
  case status {
    Pending -> "Waiting"
    Complete -> "Done"
    // Missing: Failed, Cancelled
  }
}

// Also problematic: Wildcard hiding bugs
pub fn describe(status: Status) -> String {
  case status {
    Pending -> "Waiting"
    Complete -> "Done"
    _ -> "Unknown"  // Hides new variants
  }
}

// Correct: Explicit handling
pub fn describe(status: Status) -> String {
  case status {
    Pending -> "Waiting"
    Complete -> "Done"
    Failed(reason) -> "Failed: " <> reason
    Cancelled -> "Cancelled"
  }
}
```

### GL004: List Pattern Issues [MEDIUM]

AI forgets empty list case or uses inefficient patterns.

```gleam
// Bug: Crashes on empty list
pub fn first(items: List(a)) -> a {
  let assert [head, ..] = items
  head
}

// Correct: Handle empty case
pub fn first(items: List(a)) -> Result(a, Nil) {
  case items {
    [] -> Error(Nil)
    [head, ..] -> Ok(head)
  }
}

// Also correct: Use list.first
pub fn first(items: List(a)) -> Result(a, Nil) {
  list.first(items)
}
```

### GL005: String Building Inefficiency [MEDIUM]

AI concatenates strings in loops instead of using string_builder.

```gleam
// Inefficient: O(n²) string concatenation
pub fn join(items: List(String)) -> String {
  list.fold(items, "", fn(acc, item) { acc <> ", " <> item })
}

// Correct: Use string_builder
import gleam/string_builder

pub fn join(items: List(String)) -> String {
  items
  |> list.intersperse(", ")
  |> string_builder.from_strings
  |> string_builder.to_string
}

// Or just use string.join
pub fn join(items: List(String)) -> String {
  string.join(items, ", ")
}
```

### GL006: Option Misuse [MEDIUM]

AI uses `Option(a)` when `Result(a, Error)` more appropriate.

```gleam
// Loses error context
pub fn find_user(id: String) -> Option(User) {
  case db.query(id) {
    Ok(user) -> Some(user)
    Error(_) -> None  // Was it not found? DB error? Auth error?
  }
}

// Correct: Preserve error information
pub fn find_user(id: String) -> Result(User, UserError) {
  db.query(id)
  |> result.map_error(fn(e) {
    case e {
      DbError(NotFound) -> UserNotFound(id)
      DbError(other) -> DatabaseError(other)
      AuthError(e) -> Unauthorized(e)
    }
  })
}
```

### GL007: Pipe Abuse [LOW]

AI uses pipes where they reduce clarity.

```gleam
// Overly piped
let result =
  input
  |> fn(x) { x + 1 }
  |> fn(x) { x * 2 }

// Clearer
let result = (input + 1) * 2

// Good pipe use: Clear transformation chain
let result =
  users
  |> list.filter(fn(u) { u.active })
  |> list.map(fn(u) { u.email })
  |> list.sort(string.compare)
```

### GL008: Type Alias vs Custom Type [MEDIUM]

AI uses type aliases when custom types provide better safety.

```gleam
// Weak: Type aliases are just names
pub type UserId = String
pub type OrderId = String

pub fn get_user(id: UserId) -> User { ... }
get_user(order_id)  // Compiles! Both are String

// Strong: Custom types prevent mixing
pub type UserId {
  UserId(String)
}
pub type OrderId {
  OrderId(String)
}

pub fn get_user(id: UserId) -> User { ... }
get_user(order_id)  // Compile error!
```

### GL009: Missing Labelled Arguments [MEDIUM]

AI uses positional args where labels improve clarity.

```gleam
// Unclear
pub fn create_user(String, String, Int, Bool) -> User

create_user("alice", "alice@example.com", 25, true)  // What's true?

// Clear
pub fn create_user(
  name name: String,
  email email: String,
  age age: Int,
  active active: Bool,
) -> User

create_user(name: "alice", email: "alice@example.com", age: 25, active: True)
```

### GL010: OTP Pattern Mistakes [HIGH]

For Gleam on BEAM with OTP.

#### Not using actors for shared state
```gleam
// Wrong: Mutable state approach (doesn't work in Gleam)
// AI might hallucinate this from other languages

// Correct: Use actors (gleam_otp)
import gleam/otp/actor

pub type Msg {
  Increment
  GetCount(Subject(Int))
}

pub fn start() -> Result(Subject(Msg), actor.StartError) {
  actor.start(0, fn(msg, count) {
    case msg {
      Increment -> actor.continue(count + 1)
      GetCount(client) -> {
        process.send(client, count)
        actor.continue(count)
      }
    }
  })
}
```

#### Blocking in actor handler
```gleam
// Wrong: Blocking call in message handler
fn handle(msg, state) {
  case msg {
    FetchData(url) -> {
      // This blocks the actor!
      let data = http.get_sync(url)
      actor.continue(State(..state, data: data))
    }
  }
}

// Correct: Async with tasks or separate process
fn handle(msg, state) {
  case msg {
    FetchData(url, reply_to) -> {
      // Spawn async task
      task.async(fn() {
        let data = http.get(url)
        process.send(reply_to, DataFetched(data))
      })
      actor.continue(state)
    }
    DataFetched(data) -> {
      actor.continue(State(..state, data: data))
    }
  }
}
```

---

## Gleam Hallucinations

### Hallucinated Syntax

| Hallucination | Reality |
|---------------|---------|
| `if/else` | Use `case` with `True`/`False` |
| `match` keyword | It's `case` in Gleam |
| `fn x -> x + 1` | `fn(x) { x + 1 }` |
| `do/end` blocks | Gleam uses `{ }` |
| `def` for functions | Use `pub fn` or `fn` |
| `null`/`nil`/`None` | Use `option.None` or `Error(Nil)` |
| `throw`/`raise` | Use `panic` (discouraged) or `Result` |
| `try/catch` | Use `Result` and `use` expressions |

### Hallucinated Standard Library

| Hallucination | Reality |
|---------------|---------|
| `list.find` returns `Option` | Returns `Result(a, Nil)` |
| `string.split_once` | `string.split` or pattern match |
| `map.get` returns `Option` | Returns `Result(v, Nil)` |
| `int.parse` returns `Int` | Returns `Result(Int, Nil)` |
| `list.head` | Use `list.first` |
| `list.tail` | Use `list.rest` |
| `string.chars` | Use `string.to_graphemes` |

### Confused with Elixir/Erlang

| Elixir/Erlang | Gleam |
|---------------|-------|
| `Enum.map` | `list.map` |
| `|>` same behavior | Same! |
| `%{key: value}` | `dict.from_list([#("key", value)])` |
| `[:atom]` | No atoms, use custom types |
| `@spec` | Type annotations are part of signature |
| `defmodule` | Just the file is the module |
| `String.t()` | `String` |

### Target-Specific Hallucinations

AI might not know which target (Erlang or JavaScript).

```gleam
// Erlang-only (won't work on JS target)
import gleam/otp/actor
import gleam/erlang/process

// JavaScript-only
import gleam/javascript/promise

// Check gleam.toml for target
// target = "erlang" or target = "javascript"
```

---

## Gleam Edge Cases

### Equality and Comparison

```gleam
// Structural equality (safe)
[1, 2, 3] == [1, 2, 3]  // True

// Custom types compare structurally
type Point { Point(x: Int, y: Int) }
Point(1, 2) == Point(1, 2)  // True

// But functions can't be compared
let f = fn(x) { x }
let g = fn(x) { x }
f == g  // Compile error!
```

### Integer Division

```gleam
// No automatic float conversion
5 / 2  // Compile error: Int vs Float

// Explicit
5 / 2         // Error
int.divide(5, 2)  // Ok(2) - integer division
5.0 /. 2.0    // 2.5 - float division
int.to_float(5) /. int.to_float(2)  // 2.5
```

### Empty Containers

```gleam
// All safe to iterate
list.map([], fn(x) { x })  // []
dict.map_values(dict.new(), fn(_, v) { v })  // dict.new()

// But accessing empty fails
let assert Ok(first) = list.first([])  // Crashes!
let assert Ok(value) = dict.get(dict.new(), "key")  // Crashes!
```

---

## Gleam Validation Checklist

### Error Handling
- [ ] No `let assert Ok(...)` without justification
- [ ] `Result` used when error context matters
- [ ] Error types are descriptive custom types
- [ ] `use` expressions for Result chaining
- [ ] `panic`/`todo` only in unreachable code

### Type Safety
- [ ] Custom types for domain concepts (not String aliases)
- [ ] Labelled arguments for functions with >2 params
- [ ] Exhaustive pattern matching (no catch-all `_` hiding cases)
- [ ] Opaque types for encapsulation where needed

### Functional Patterns
- [ ] Pipes used appropriately (clear transformation chains)
- [ ] No unnecessary intermediate variables
- [ ] Higher-order functions over explicit recursion
- [ ] `use` for callback-heavy code

### Performance
- [ ] `string_builder` for string concatenation
- [ ] Tail recursion for large lists (or use `list.fold`)
- [ ] Consider `iterator` for lazy processing
- [ ] Avoid repeated list traversals

### BEAM-Specific (Erlang Target)
- [ ] Actors for shared mutable state
- [ ] Supervisors for fault tolerance
- [ ] No blocking in actor handlers
- [ ] Process linking/monitoring where appropriate

### JS-Specific (JavaScript Target)
- [ ] Promises handled correctly
- [ ] FFI bindings typed accurately
- [ ] No Erlang-only imports
