# AI Code Validator - Examples Module

Concrete validation examples. Load for training or reference.

---

## Example 1: Detecting Stub Functions (Rust)

### Input

**Request:** Create a configuration loader that reads from a file or environment variables with fallback defaults.

**Generated Code:**
```rust
use std::env;
use std::fs;

pub struct Config {
    pub database_url: String,
    pub port: u16,
    pub debug: bool,
}

impl Config {
    pub fn load(path: Option<&str>) -> Result<Self, ConfigError> {
        if let Some(p) = path {
            Self::from_file(p)
        } else {
            Self::from_env()
        }
    }

    fn from_file(path: &str) -> Result<Self, ConfigError> {
        let content = fs::read_to_string(path)?;
        // TODO: Parse TOML
        Ok(Config::default())
    }

    fn from_env() -> Result<Self, ConfigError> {
        Ok(Config {
            database_url: env::var("DATABASE_URL").unwrap_or_default(),
            port: 8080,
            debug: true,
        })
    }
}

impl Default for Config {
    fn default() -> Self {
        Config {
            database_url: String::new(),
            port: 8080,
            debug: false,
        }
    }
}

#[derive(Debug)]
pub struct ConfigError(String);

impl From<std::io::Error> for ConfigError {
    fn from(e: std::io::Error) -> Self {
        ConfigError(e.to_string())
    }
}
```

### Validation Output

```
REJECT

Blocking issues:

[S001] BLOCKING - Explicit Placeholder
Location: from_file(), line 19
Evidence: "// TODO: Parse TOML"
Impact: File loading doesn't actually parse config; always returns defaults
Required: Implement TOML parsing using `toml` crate

[S005] HIGH - Stub Function  
Location: from_file()
Evidence: Reads file content but ignores it, returns Config::default()
Impact: File-based configuration completely non-functional
Required: Parse `content` into Config fields

Additional issues:

[RS003] HIGH - Unwrap Avoidance
Location: from_env(), line 24
Evidence: `env::var("DATABASE_URL").unwrap_or_default()`
Impact: Empty string on missing env var may cause downstream errors
Suggestion: Return error if required, or make field Optional

[S008] MEDIUM - Happy Path Only
Location: from_env()
Evidence: port and debug are hardcoded, not read from env
Impact: Environment-based config doesn't actually read environment
Required: Read PORT, DEBUG from env with fallbacks

Requirements not met:
- [ ] Reads from file: STUB (reads but doesn't parse)
- [ ] Reads from environment: PARTIAL (only DATABASE_URL)
- [ ] Fallback defaults: MET
```

---

## Example 2: Hallucinated API (Go)

### Input

**Request:** Write a function to merge two maps, with the second map's values taking precedence.

**Generated Code:**
```go
package maputil

func Merge[K comparable, V any](base, override map[K]V) map[K]V {
    result := maps.Clone(base)
    maps.Copy(result, override)
    return result
}
```

### Validation Output

```
NEEDS_WORK

Requirements status:
- [x] Merge two maps: IMPLEMENTED
- [x] Second map takes precedence: IMPLEMENTED

Issues:

[S013] HIGH - Hallucinated Import
Location: Function body
Evidence: Uses `maps.Clone` and `maps.Copy` without import
Reality: `golang.org/x/exp/maps` or Go 1.21+ `maps` package
Required: Add import statement, verify Go version compatibility

[GO003] MEDIUM - Nil Map Handling
Location: Function entry
Evidence: No nil checks on inputs
Impact: 
- maps.Clone(nil) returns nil
- maps.Copy to nil map panics
Required: Add nil handling:

    if base == nil && override == nil {
        return nil  // or make(map[K]V)
    }
    if base == nil {
        return maps.Clone(override)
    }
    if override == nil {
        return maps.Clone(base)
    }

Note: Verify your Go version supports generics (1.18+) and maps package (1.21+ or x/exp/maps).
```

---

## Example 3: Happy Path Only (Gleam)

### Input

**Request:** Create a function to parse a user from JSON with validation.

**Generated Code:**
```gleam
import gleam/json
import gleam/dynamic

pub type User {
  User(name: String, email: String, age: Int)
}

pub fn parse_user(json_string: String) -> User {
  let assert Ok(data) = json.decode(json_string, dynamic.dynamic)
  let assert Ok(name) = dynamic.field("name", dynamic.string)(data)
  let assert Ok(email) = dynamic.field("email", dynamic.string)(data)
  let assert Ok(age) = dynamic.field("age", dynamic.int)(data)
  User(name, email, age)
}
```

### Validation Output

```
REJECT

Blocking issues:

[GL001] BLOCKING - Result Ignorance
Location: parse_user(), lines 10-13
Evidence: Four `let assert Ok(...)` patterns
Impact: Function crashes on:
- Invalid JSON
- Missing fields
- Wrong field types
Required: Return Result type and handle errors

[S008] HIGH - Happy Path Only
Location: parse_user()
Evidence: No validation of email format, age range
Impact: Invalid data accepted (empty email, negative age)
Required: Add validation per requirements

Corrected implementation:

```gleam
import gleam/json
import gleam/dynamic
import gleam/result
import gleam/string

pub type User {
  User(name: String, email: String, age: Int)
}

pub type ParseError {
  InvalidJson(json.DecodeError)
  MissingField(String)
  InvalidEmail
  InvalidAge
}

pub fn parse_user(json_string: String) -> Result(User, ParseError) {
  use data <- result.try(
    json.decode(json_string, user_decoder())
    |> result.map_error(InvalidJson)
  )
  use _ <- result.try(validate_email(data.email))
  use _ <- result.try(validate_age(data.age))
  Ok(data)
}

fn user_decoder() -> dynamic.Decoder(User) {
  dynamic.decode3(
    User,
    dynamic.field("name", dynamic.string),
    dynamic.field("email", dynamic.string),
    dynamic.field("age", dynamic.int),
  )
}

fn validate_email(email: String) -> Result(Nil, ParseError) {
  case string.contains(email, "@") {
    True -> Ok(Nil)
    False -> Error(InvalidEmail)
  }
}

fn validate_age(age: Int) -> Result(Nil, ParseError) {
  case age >= 0 && age <= 150 {
    True -> Ok(Nil)
    False -> Error(InvalidAge)
  }
}
```
```

---

## Example 4: String Processing Instead of Structured Data (Nushell)

### Input

**Request:** Find all files larger than 1MB modified in the last week.

**Generated Code:**
```nu
ls -la | lines | each { |line|
  let parts = ($line | split column ' ')
  let size = ($parts | get column5)
  let date = ($parts | get column6)
  if ($size | into int) > 1048576 {
    $line
  }
} | where { |x| $x != null }
```

### Validation Output

```
REJECT

Blocking issues:

[NU001] BLOCKING - Ignoring Structured Data
Location: Entire script
Evidence: Uses `lines` and `split column` on `ls` output
Impact: 
- Fragile: breaks if output format changes
- Wrong: `ls` already returns structured table
- Broken: Column indices likely wrong

Correct implementation:

```nu
ls | where {|f| 
  $f.size > 1mb and 
  $f.modified > ((date now) - 1wk)
}
```

Or more explicitly:

```nu
let one_week_ago = (date now) - 1wk
ls | where size > 1mb | where modified > $one_week_ago
```

[NU007] HIGH - Table vs String Confusion
Evidence: Treating `ls` output as text
Reality: `ls` returns table with typed columns: name, type, size, modified

Key improvements:
- Use structured `size` column (supports units like `1mb`)
- Use structured `modified` column (datetime type)
- Native comparison operators
- No string parsing needed
```

---

## Example 5: PASS Case (Rust)

### Input

**Request:** Safe integer division that returns None for division by zero.

**Generated Code:**
```rust
/// Safely divides two integers, returning None if divisor is zero.
/// 
/// # Examples
/// ```
/// assert_eq!(safe_divide(10, 2), Some(5));
/// assert_eq!(safe_divide(10, 0), None);
/// assert_eq!(safe_divide(0, 5), Some(0));
/// ```
pub fn safe_divide(dividend: i64, divisor: i64) -> Option<i64> {
    if divisor == 0 {
        None
    } else {
        Some(dividend / divisor)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn divides_evenly() {
        assert_eq!(safe_divide(10, 2), Some(5));
    }

    #[test]
    fn division_by_zero_returns_none() {
        assert_eq!(safe_divide(10, 0), None);
    }

    #[test]
    fn zero_dividend() {
        assert_eq!(safe_divide(0, 5), Some(0));
    }

    #[test]
    fn negative_numbers() {
        assert_eq!(safe_divide(-10, 2), Some(-5));
        assert_eq!(safe_divide(10, -2), Some(-5));
        assert_eq!(safe_divide(-10, -2), Some(5));
    }

    #[test]
    fn integer_truncation() {
        assert_eq!(safe_divide(7, 2), Some(3));
    }
}
```

### Validation Output

```
PASS

Requirements verified:
- [x] Division operation: IMPLEMENTED (line 11)
- [x] Returns None for zero divisor: IMPLEMENTED (lines 8-10)
- [x] Returns Some for valid division: IMPLEMENTED (line 11)

Edge cases covered:
- [x] Zero divisor: Tested (division_by_zero_returns_none)
- [x] Zero dividend: Tested (zero_dividend)
- [x] Negative numbers: Tested (negative_numbers)
- [x] Truncation behavior: Tested (integer_truncation)

Test quality: GOOD
- Tests cover success and failure cases
- Tests cover edge cases
- Assertions are meaningful

No issues found.
```

---

## Example 6: Partial Implementation (Go)

### Input

**Request:** HTTP handler supporting GET, POST, PUT, DELETE for a /users endpoint.

**Generated Code:**
```go
func usersHandler(w http.ResponseWriter, r *http.Request) {
    switch r.Method {
    case http.MethodGet:
        users, _ := db.GetAllUsers()
        json.NewEncoder(w).Encode(users)
    case http.MethodPost:
        var user User
        json.NewDecoder(r.Body).Decode(&user)
        db.CreateUser(user)
        w.WriteHeader(http.StatusCreated)
    default:
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
    }
}
```

### Validation Output

```
REJECT

Blocking issues:

[S006] BLOCKING - Partial Iteration
Location: usersHandler switch statement
Evidence: Request specified 4 methods, only 2 implemented
- Requested: GET, POST, PUT, DELETE
- Implemented: GET, POST
- Missing: PUT, DELETE
Impact: PUT and DELETE return 405 incorrectly
Required: Implement PUT and DELETE cases

Additional issues:

[GO001] HIGH - Error Ignoring
Location: Lines 4, 7, 9
Evidence: Multiple `_` ignoring errors
- `db.GetAllUsers()` error ignored
- `json.NewDecoder().Decode()` error ignored
- `db.CreateUser()` error ignored (implicit)
Impact: Errors silently ignored, clients get wrong responses

[GO002] HIGH - Bare Returns
Location: Throughout
Evidence: No error context provided
Required: Wrap errors with context

[S008] HIGH - Happy Path Only
Evidence: No validation of:
- Empty request body
- Invalid JSON
- Missing required fields
- User ID for PUT/DELETE

Required changes:
1. Add PUT handler (update user by ID)
2. Add DELETE handler (delete user by ID)
3. Handle all errors with proper HTTP status codes
4. Validate input before processing
```

---

## Severity Reference

| Severity | Meaning | Action |
|----------|---------|--------|
| BLOCKING | Cannot proceed | Stop, fix before any other review |
| HIGH | Production risk | Must fix before deployment |
| MEDIUM | Quality issue | Should fix, may cause future problems |
| LOW | Suggestion | Consider improving |
