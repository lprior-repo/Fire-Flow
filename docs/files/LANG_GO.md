# AI Code Validator - Go Module

Go-specific shortcuts, hallucinations, and validation rules. Load when reviewing Go code.

---

## Go-Specific Shortcuts

### GO001: Error Ignoring [BLOCKING]

AI uses `_` to ignore errors instead of handling them.

```go
// Shortcut: Silent failure
data, _ := ioutil.ReadFile(path)
json.Unmarshal(data, &config)  // Error ignored entirely

// Correct
data, err := os.ReadFile(path)
if err != nil {
    return fmt.Errorf("reading config %s: %w", path, err)
}
if err := json.Unmarshal(data, &config); err != nil {
    return fmt.Errorf("parsing config: %w", err)
}
```

Detection: Search for `_, _` and single `_` on error returns. Each needs justification.

### GO002: Bare Error Returns [HIGH]

AI returns `err` without context, making debugging impossible.

```go
// Shortcut: No context
func LoadUser(id string) (*User, error) {
    data, err := db.Query(id)
    if err != nil {
        return nil, err  // Which query? What ID?
    }
    var user User
    if err := json.Unmarshal(data, &user); err != nil {
        return nil, err  // Parse error? What data?
    }
    return &user, nil
}

// Correct: Wrapped errors
func LoadUser(id string) (*User, error) {
    data, err := db.Query(id)
    if err != nil {
        return nil, fmt.Errorf("querying user %s: %w", id, err)
    }
    var user User
    if err := json.Unmarshal(data, &user); err != nil {
        return nil, fmt.Errorf("parsing user %s data: %w", id, err)
    }
    return &user, nil
}
```

### GO003: Nil Slice/Map Confusion [HIGH]

AI doesn't initialize slices/maps properly or confuses nil vs empty.

```go
// Bug: nil map panics on write
var users map[string]*User
users["alice"] = &User{}  // PANIC

// Correct
users := make(map[string]*User)
users["alice"] = &User{}

// Bug: nil slice in JSON becomes null, not []
type Response struct {
    Items []string `json:"items"`
}
resp := Response{}
json.Marshal(resp)  // {"items":null}

// Correct for empty array in JSON
resp := Response{Items: []string{}}
// or
resp := Response{Items: make([]string, 0)}
```

### GO004: Goroutine Leaks [HIGH]

AI spawns goroutines without ensuring they terminate.

```go
// Leak: goroutine runs forever if timeout
func fetch(url string) ([]byte, error) {
    ch := make(chan []byte)
    go func() {
        resp, _ := http.Get(url)
        body, _ := io.ReadAll(resp.Body)
        ch <- body  // Blocked forever if no receiver
    }()
    select {
    case data := <-ch:
        return data, nil
    case <-time.After(5 * time.Second):
        return nil, errors.New("timeout")
        // Goroutine still running, channel never read
    }
}

// Correct: Buffered channel or context cancellation
func fetch(ctx context.Context, url string) ([]byte, error) {
    ch := make(chan []byte, 1)  // Buffered: won't block
    go func() {
        req, _ := http.NewRequestWithContext(ctx, "GET", url, nil)
        resp, err := http.DefaultClient.Do(req)
        if err != nil {
            return
        }
        defer resp.Body.Close()
        body, _ := io.ReadAll(resp.Body)
        ch <- body
    }()
    select {
    case data := <-ch:
        return data, nil
    case <-ctx.Done():
        return nil, ctx.Err()
    }
}
```

### GO005: Context Misuse [HIGH]

#### Storing context in struct
```go
// Wrong: Context should not be stored
type Server struct {
    ctx context.Context  // Don't do this
}

// Correct: Pass context to methods
func (s *Server) Handle(ctx context.Context, req *Request) error
```

#### Not propagating context
```go
// Wrong: Creates new context, loses cancellation
func handler(ctx context.Context) {
    newCtx := context.Background()
    doWork(newCtx)  // Original cancellation ignored
}

// Correct
func handler(ctx context.Context) {
    doWork(ctx)
}
```

#### Ignoring context cancellation
```go
// Wrong: Doesn't check context
func process(ctx context.Context, items []Item) error {
    for _, item := range items {
        heavyWork(item)  // Continues even if cancelled
    }
    return nil
}

// Correct
func process(ctx context.Context, items []Item) error {
    for _, item := range items {
        select {
        case <-ctx.Done():
            return ctx.Err()
        default:
        }
        heavyWork(item)
    }
    return nil
}
```

### GO006: Defer Pitfalls [MEDIUM]

#### Defer in loop
```go
// Bug: Files not closed until function returns
func processFiles(paths []string) error {
    for _, path := range paths {
        f, err := os.Open(path)
        if err != nil {
            return err
        }
        defer f.Close()  // Not closed until function ends!
        process(f)
    }
    return nil
}

// Correct: Closure or separate function
func processFiles(paths []string) error {
    for _, path := range paths {
        if err := processFile(path); err != nil {
            return err
        }
    }
    return nil
}

func processFile(path string) error {
    f, err := os.Open(path)
    if err != nil {
        return err
    }
    defer f.Close()
    return process(f)
}
```

#### Defer with loop variable
```go
// Bug: All defers use final value of i
for i := 0; i < 3; i++ {
    defer fmt.Println(i)  // Prints 2, 2, 2
}

// Correct
for i := 0; i < 3; i++ {
    i := i  // Shadow with new variable
    defer fmt.Println(i)  // Prints 2, 1, 0
}
```

### GO007: Interface Pollution [MEDIUM]

AI creates interfaces for single implementations.

```go
// Over-engineered: Interface nobody else implements
type UserRepository interface {
    FindByID(id string) (*User, error)
    Save(user *User) error
    Delete(id string) error
}

type userRepo struct { db *sql.DB }
// Only implementation ever

// Better: Accept interfaces, return structs
// Define interface at consumer, not producer
func NewService(repo *UserRepo) *Service  // Concrete type

// Consumer defines what it needs
type userFinder interface {
    FindByID(id string) (*User, error)
}
```

### GO008: Channel Mistakes [HIGH]

#### Closing channel from receiver
```go
// Wrong: Only sender should close
func consumer(ch <-chan int) {
    for v := range ch {
        process(v)
    }
    close(ch)  // Panic if sender also closes or sends
}
```

#### Not closing channels
```go
// Bug: Range blocks forever
func producer() <-chan int {
    ch := make(chan int)
    go func() {
        for i := 0; i < 10; i++ {
            ch <- i
        }
        // Forgot close(ch)
    }()
    return ch
}

for v := range producer() {  // Blocks after 10 items
    fmt.Println(v)
}
```

### GO009: Slice Gotchas [HIGH]

#### Append to slice from parameter
```go
// Bug: May modify original backing array
func appendItem(items []string, item string) []string {
    return append(items, item)  // Might modify caller's slice
}

// Correct if isolation needed
func appendItem(items []string, item string) []string {
    result := make([]string, len(items), len(items)+1)
    copy(result, items)
    return append(result, item)
}
```

#### Slice of pointers from loop
```go
// Bug: All pointers point to same variable
var ptrs []*int
for _, v := range values {
    ptrs = append(ptrs, &v)  // All point to v!
}

// Correct
for _, v := range values {
    v := v  // Shadow
    ptrs = append(ptrs, &v)
}
// Or in Go 1.22+, loop variables are per-iteration
```

---

## Go Hallucinations

### Hallucinated Packages

| Hallucination | Reality |
|---------------|---------|
| `ioutil.ReadFile` | `os.ReadFile` (Go 1.16+) |
| `ioutil.WriteFile` | `os.WriteFile` (Go 1.16+) |
| `io/ioutil` anything | Mostly in `io` and `os` now |
| `context.TODO()` for production | Use `context.Background()` or pass real context |
| `errors.Wrapf` | Use `fmt.Errorf("...: %w", err)` (stdlib) |
| `log.Fatalf` with `%w` | `%w` only works with `fmt.Errorf` |

### Hallucinated Methods

| Hallucination | Reality |
|---------------|---------|
| `slice.Contains()` | `slices.Contains()` (Go 1.21+) or loop |
| `map.Keys()` | `maps.Keys()` (Go 1.21+) or loop |
| `string.IsEmpty()` | `s == ""` or `len(s) == 0` |
| `error.Unwrap()` | `errors.Unwrap(err)` (function, not method) |
| `sync.Map.Len()` | Doesn't exist, must iterate |
| `http.Response.JSON()` | Must use `json.NewDecoder(resp.Body)` |

### Hallucinated Behavior

```go
// Wrong: map iteration order is NOT stable
for k, v := range m {  // Order varies between runs
}

// Wrong: strings are NOT mutable
s := "hello"
s[0] = 'H'  // Compile error

// Wrong: nil error equality
var err error = nil
var myErr *MyError = nil
err = myErr
err == nil  // FALSE! Interface holds (*MyError, nil)
```

---

## Go Edge Cases

### Zero Values Matter

```go
var s string   // "" not nil
var i int      // 0
var b bool     // false
var p *int     // nil
var m map[K]V  // nil (reads ok, writes panic)
var sl []T     // nil (append ok, len=0)
var ch chan T  // nil (blocks forever)
```

### Numeric Overflow

```go
// Silent overflow
var x uint8 = 255
x++  // x is now 0, no error

// Check with math package
import "math"
if x > math.MaxUint8 - 1 {
    // Would overflow
}
```

### JSON Gotchas

```go
// Unexported fields ignored
type Config struct {
    name string  // Won't marshal/unmarshal
    Name string  // This works
}

// Numbers become float64
var data map[string]interface{}
json.Unmarshal([]byte(`{"id": 123}`), &data)
id := data["id"].(int)  // PANIC: it's float64
id := data["id"].(float64)  // Correct
id := int(data["id"].(float64))  // If you need int
```

---

## Go Validation Checklist

### Error Handling
- [ ] No ignored errors without comment explaining why
- [ ] Errors wrapped with `fmt.Errorf("context: %w", err)`
- [ ] Sentinel errors defined with `errors.New` at package level
- [ ] Error checks before using result (`if err != nil` first)
- [ ] Custom error types implement `Error()` and optionally `Unwrap()`

### Concurrency
- [ ] All spawned goroutines have termination path
- [ ] Channels closed by sender only
- [ ] Context propagated and checked
- [ ] No data races (use `-race` flag in tests)
- [ ] `sync.Mutex` not copied after first use
- [ ] `sync.WaitGroup` `.Add()` before goroutine spawn

### Memory Safety
- [ ] Maps initialized before write
- [ ] Nil pointer checks before dereference
- [ ] Slice capacity considered when appending
- [ ] Loop variables not captured by reference (pre-Go 1.22)
- [ ] No `unsafe` without extremely good reason

### Idioms
- [ ] `defer` for cleanup (but not in loops)
- [ ] Accept interfaces, return structs
- [ ] Errors are values, not exceptions
- [ ] Make zero value useful
- [ ] Short variable names in small scopes

### Performance
- [ ] `strings.Builder` for string concatenation
- [ ] `sync.Pool` for frequently allocated objects
- [ ] `bytes.Buffer` reused where possible
- [ ] HTTP clients reused (not created per request)
- [ ] Database connections pooled
