# Quest Async/Concurrency Implementation Plan

**Status**: Planning → Ready for Implementation
**Created**: 2025-10-07
**Last Updated**: 2025-10-07
**Related QEPs**: QEP-027 (Async Tasks), QEP-028 (Web Server)

## Overview

This document outlines the phased implementation plan for async/concurrent programming in Quest using Tokio as the foundation runtime.

**Key Decisions Made**:
- ✅ Syntax: `async fun` (universal convention)
- ✅ Task cancellation: Auto-cancel on drop (safer default)
- ✅ REPL: Auto-wrap `await` expressions with `async>` prompt
- ✅ Module organization: Everything in `std/async`
- ✅ Phase 2 includes: Async type methods (instance and static)
- ✅ Phase 4 includes: Task-local storage (moved from Phase 7)
- ✅ Phase 4 includes: Structured concurrency with task groups (optional)

**Timeline**: ~13-18 weeks for Phases 1-6 (production-ready async support)

## Architecture Decision: Tokio as Foundation

✅ **Tokio** is the right choice because:
- Already used for HTTP client (`reqwest`)
- Mature, production-ready async runtime
- Excellent performance and scalability
- Rich ecosystem integration
- Cross-platform support (epoll, kqueue, IOCP)

## Implementation Phases

### **Phase 1: Foundation (QEP-028 - Web Server)**
**Goal**: Get real-world async working ASAP with minimal language changes

**Why First**: Validates architecture, provides immediate value, real production testing

**Duration**: ~2-3 weeks

**Implementation**:
1. ✅ **Basic Tokio runtime** - Embed runtime in main interpreter
2. ✅ **Axum web server** - `quest serve` command
3. ✅ **Thread-local scopes** - Worker thread isolation
4. ✅ **Blocking task execution** - Wrap Quest code in `spawn_blocking`
5. ✅ **WebSocket support** - Real-time communication

**What You Get**:
- Working web applications in Quest
- Real async I/O (HTTP, WebSockets)
- Multi-threaded request handling
- Production testing ground for async architecture

**Key Files**:
- `src/server.rs` (~600 lines) - Axum server implementation
- `src/main.rs` - Add `serve` subcommand
- `src/commands.rs` - CLI argument parsing
- Minimal language changes (no syntax yet)

**Testing Strategy**:
```bash
# Manual testing
quest serve examples/hello_web.q
curl http://localhost:3000

# Integration tests
cd test/server && quest test_server.q

# Load testing
wrk -t4 -c100 -d30s http://localhost:3000
ab -n 10000 -c 100 http://localhost:3000/
```

**Success Criteria**:
- ✅ 5000+ req/s for hello world
- ✅ 1000+ req/s with database queries
- ✅ WebSocket echo server working
- ✅ Production deployment examples

---

### **Phase 2: Language-Level Async (QEP-027 Core)**
**Goal**: Add `async`/`await` syntax and basic task management

**Why Second**: Phase 1 proves runtime works, now expose primitives to users

**Duration**: ~3-4 weeks

**Implementation**:

1. **Grammar changes** (`src/quest.pest`):
   ```pest
   async_function = { "async" ~ "fun" ~ identifier ~ "(" ~ parameter_list? ~ ")" ~ statement* ~ "end" }
   await_expression = { "await" ~ expression }
   async_type_method = { "async" ~ "fun" ~ identifier ~ "(" ~ parameter_list? ~ ")" ~ statement* ~ "end" }
   ```

2. **New QValue variants** (`src/types/mod.rs`):
   ```rust
   QValue::AsyncFun(AsyncFunctionDef),
   QValue::Task(Arc<Mutex<JoinHandle<Result<QValue, String>>>>),
   ```

3. **Evaluation changes** (`src/main.rs`):
   - `eval_async_function()` - Return future/task handle
   - `eval_await()` - Block on task completion
   - Async context tracking (am I inside an async function?)

4. **Async type methods** (`src/types/user_types.rs`):
   - Support `async fun` inside type definitions
   - Both instance and static async methods
   - Proper `self` binding in async context

5. **`std/async` module** (`src/modules/async.rs`):
   ```quest
   async.spawn(fn, name?) → Task
   async.block_on(fn) → result
   async.sleep(seconds)
   async.yield_now()
   ```

**Example Code**:
```quest
use "std/async"

# Async functions
async fun fetch_user(id)
    let response = await http.get(f"https://api.example.com/users/{id}")
    await response.json()
end

# Async type methods
type UserRepository
    base_url: Str

    async fun fetch(id)
        let response = await http.get(f"{self.base_url}/users/{id}")
        await response.json()
    end

    static async fun create(base_url)
        # Validate connection
        await http.get(base_url)
        UserRepository.new(base_url: base_url)
    end
end

async fun main()
    let repo = await UserRepository.create("https://api.example.com")
    let user = await repo.fetch(123)
    puts(user.name)
end

async.block_on(fun () main() end)
```

**What You Get**:
- Async function declarations
- Async type methods (instance and static)
- Task spawning and awaiting
- Basic concurrency primitives
- Foundation for all future async features

**Testing Strategy**:
```quest
# test/async/basic_test.q
use "std/async"

async fun fetch_data()
    await async.sleep(0.1)
    42
end

let result = async.block_on(fun () fetch_data() end)
assert result == 42

# test/async/spawn_test.q
let task = async.spawn(fun () fetch_data() end)
let result = await task
assert result == 42
```

**Success Criteria**:
- ✅ Can declare async functions
- ✅ Async type methods work (instance and static)
- ✅ Can spawn and await tasks
- ✅ Async overhead < 10% vs sync
- ✅ All basic tests passing

---

### **Phase 3: Channels & Communication (QEP-027 Channels)**
**Goal**: Enable task coordination and message passing

**Why Third**: Tasks alone are limiting, need inter-task communication

**Duration**: ~2 weeks

**Implementation**:

1. **Channel types** (`src/types/channel.rs`):
   ```rust
   QValue::Channel(Arc<Mutex<mpsc::Sender<QValue>>>),
   QValue::ChannelReceiver(Arc<Mutex<mpsc::Receiver<QValue>>>),
   ```

2. **Channel API** (`std/async` additions):
   ```quest
   async.channel(capacity?) → Channel
   channel.send(value)           # Async, blocks if full
   channel.recv() → value        # Async, blocks if empty
   channel.try_send(value) → bool
   channel.try_recv() → value or nil
   channel.close()
   channel.is_closed() → bool
   ```

3. **Select support** (if time allows):
   ```quest
   async.select([chan1, chan2, chan3]) → {channel, value, index}
   ```

**Example Code**:
```quest
use "std/async"

# Producer-consumer pattern
async fun producer(channel, items)
    let i = 0
    while i < items.len()
        await channel.send(items[i])
        await async.sleep(0.1)
        i = i + 1
    end
    channel.close()
end

async fun consumer(channel)
    while true
        let item = await channel.recv()
        if item == nil  # Channel closed
            break
        end
        puts(f"Processing: {item}")
    end
end

async fun main()
    let chan = async.channel()
    async.spawn(fun () producer(chan, [1, 2, 3, 4, 5]) end)
    await consumer(chan)
end

async.block_on(fun () main() end)
```

**What You Get**:
- Producer-consumer patterns
- Background task communication
- Message-passing concurrency
- Foundation for complex coordination

**Testing Strategy**:
```quest
# test/async/channel_test.q
let chan = async.channel()
async.spawn(fun () chan.send(42) end)
let val = await chan.recv()
assert val == 42

# test/async/channel_bounded_test.q
let chan = async.channel(capacity: 2)
chan.try_send(1)
chan.try_send(2)
assert chan.try_send(3) == false  # Full!
```

**Success Criteria**:
- ✅ Channel throughput > 1M msg/s
- ✅ Bounded channels enforce capacity
- ✅ Select works with multiple channels
- ✅ Clean shutdown on channel close

---

### **Phase 4: Timeouts, Error Handling & Task-Local Storage (QEP-027 Utilities)**
**Goal**: Production-ready async error handling and context management

**Duration**: ~2-3 weeks

**Implementation**:

1. **Timeout support**:
   ```quest
   async.timeout(task, seconds) → result or TimeoutError
   ```

2. **Parallel operations**:
   ```quest
   async.join_all(tasks) → [results]           # Fail if any fails
   async.try_join_all(tasks) → {ok: [...], err: [...]}
   async.race(tasks) → first_result            # Cancel others
   async.race_ok(tasks) → first_success        # Ignore failures
   ```

3. **Structured concurrency** (optional):
   ```quest
   async.task_group() → TaskGroup              # Scope-based task management
   group.spawn(fn)                             # Add task to group
   # All tasks complete before exiting with-block
   ```

4. **Exception propagation**:
   - Async exceptions bubble through `await`
   - Task panic handling: panic in task = Error on await
   - Cancellation support

5. **Task cancellation**:
   ```quest
   task.cancel()
   task.is_cancelled() → bool
   task.abort()  # Force kill
   ```

6. **Task-local storage** (moved from Phase 7):
   ```quest
   async.task_local(key, value)                # Set task-local variable
   async.task_local(key) → value               # Get task-local variable
   async.with_context(dict, fn)                # Run function with context
   ```

**Example Code**:
```quest
use "std/async"
use "std/log"

# Timeout and retry patterns
async fun fetch_with_timeout(url)
    try
        let result = await async.timeout(http.get(url), 5)
        result
    catch async.TimeoutError as e
        puts("Operation timed out after 5 seconds")
        nil
    end
end

async fun fetch_with_retry(url, max_attempts: 3)
    let attempt = 0
    while attempt < max_attempts
        try
            return await async.timeout(http.get(url), 5)
        catch async.TimeoutError
            attempt = attempt + 1
            if attempt < max_attempts
                puts(f"Retry {attempt}/{max_attempts}...")
                await async.sleep(2 ** attempt)  # Exponential backoff
            end
        end
    end
    raise "Max retries exceeded"
end

# Task-local storage for request context
async fun process_request(request_id, user_id)
    # Set context for this task (propagates to all nested calls)
    async.task_local("request_id", request_id)
    async.task_local("user_id", user_id)

    await fetch_user_data()  # Can access context without passing params
    await log_event("request_complete")
end

async fun fetch_user_data()
    let request_id = async.task_local("request_id")
    let user_id = async.task_local("user_id")

    log.info(f"[{request_id}] Fetching data for user {user_id}")
    # ... fetch data ...
end

# Structured concurrency with task groups
async fun fetch_all_with_group()
    async with async.task_group() as group
        group.spawn(fun () fetch_user(1) end)
        group.spawn(fun () fetch_user(2) end)
        group.spawn(fun () fetch_user(3) end)
        # All tasks automatically awaited before exiting
    end
end

# Run multiple operations concurrently
async fun fetch_all()
    let tasks = [
        async.spawn(fun () fetch_user(1) end),
        async.spawn(fun () fetch_user(2) end),
        async.spawn(fun () fetch_user(3) end)
    ]

    # Wait for all (fails if any fails)
    let users = await async.join_all(tasks)
    users
end
```

**What You Get**:
- Robust error handling for async code
- Concurrent operation patterns
- Production-ready timeout handling
- Retry with backoff patterns
- Task-local storage for context propagation
- Structured concurrency with task groups (optional)

**Testing Strategy**:
```quest
# test/async/timeout_test.q
async fun slow_operation()
    await async.sleep(10)
    42
end

try
    await async.timeout(slow_operation(), 1)
    assert false  # Should not reach
catch async.TimeoutError
    # Expected
end

# test/async/join_test.q
let tasks = [
    async.spawn(fun () 1 end),
    async.spawn(fun () 2 end),
    async.spawn(fun () 3 end)
]
let results = await async.join_all(tasks)
assert results == [1, 2, 3]

# test/async/task_local_test.q
async fun test_context()
    async.task_local("user_id", 123)
    async.task_local("request_id", "abc-123")

    assert async.task_local("user_id") == 123
    assert async.task_local("request_id") == "abc-123"

    # Spawn task - should NOT inherit parent context
    let task = async.spawn(fun ()
        assert async.task_local("user_id") == nil
    end)
    await task
end
```

**Success Criteria**:
- ✅ Timeouts work reliably
- ✅ Cancellation propagates correctly
- ✅ Exception handling matches sync behavior
- ✅ Task-local storage isolated per task
- ✅ Task groups enforce structured concurrency
- ✅ All error paths tested

---

### **Phase 5: Async I/O Modules (Integration)**
**Goal**: Make stdlib fully async-aware

**Duration**: ~2-3 weeks

**Implementation**:

1. **Async HTTP client** (`std/http/client`):
   ```quest
   async fun get(url) → Response
   async fun post(url, body) → Response
   ```

2. **Async database drivers** (`std/db/*`):
   ```quest
   async fun connect(url) → Connection
   async fun execute(query, params)
   async fun fetch_one(query) → Row
   async fun fetch_all(query) → [Rows]
   ```

3. **Async file I/O** (`std/io`):
   ```quest
   async fun read_file(path) → String
   async fun write_file(path, content)
   async fun read_lines(path) → Stream
   ```

**Example Code**:
```quest
use "std/async"
use "std/http/client"
use "std/db/postgres"

async fun get_user_with_posts(user_id)
    let db = await postgres.connect("postgresql://localhost/mydb")

    # Run queries concurrently
    let user_task = async.spawn(fun ()
        await db.fetch_one("SELECT * FROM users WHERE id = $1", [user_id])
    end)

    let posts_task = async.spawn(fun ()
        await db.fetch_all("SELECT * FROM posts WHERE user_id = $1", [user_id])
    end)

    # Wait for both
    let results = await async.join_all([user_task, posts_task])
    let user = results[0]
    let posts = results[1]

    await db.close()

    {"user": user, "posts": posts}
end
```

**What You Get**:
- Fully async I/O stack
- Non-blocking database queries
- Efficient file operations
- Complete async stdlib coverage

**Testing Strategy**:
```quest
# test/async/http_test.q
async fun test_async_http()
    let resp = await http.get("https://httpbin.org/get")
    assert resp.status() == 200
end

# test/async/db_test.q
async fun test_async_db()
    let conn = await db.connect(":memory:")
    await conn.execute("CREATE TABLE users (id INT, name TEXT)")
    await conn.execute("INSERT INTO users VALUES (1, 'Alice')")
    let user = await conn.fetch_one("SELECT * FROM users WHERE id = 1")
    assert user.name == "Alice"
end
```

**Success Criteria**:
- ✅ All major stdlib modules have async variants
- ✅ Performance matches or beats sync versions
- ✅ API consistency across modules
- ✅ Comprehensive test coverage

---

### **Phase 6: Connection Pooling (QEP-028 Phase 2)**
**Goal**: Efficient resource management for web applications

**Duration**: ~1-2 weeks

**Implementation**:

1. **Database pools** (`std/db/*`):
   ```quest
   db.create_pool(url, {min: 2, max: 20, timeout: 30}) → Pool
   pool.acquire() → Connection
   pool.stats() → {active, idle, max, waiting}
   conn.release()  # Or automatic on scope exit
   pool.close()
   ```

2. **Pool implementations**:
   - `deadpool-postgres` for PostgreSQL
   - `mysql_async` + `deadpool` for MySQL
   - `r2d2_sqlite` for SQLite

**Example Code**:
```quest
use "std/db/postgres" as db

# Create pool once at module level (global, thread-safe)
let pool = db.create_pool("postgresql://localhost/mydb", {
    "min_connections": 2,      # Keep at least 2 warm
    "max_connections": 20,     # Allow up to 20 concurrent
    "timeout": 30,             # Acquire timeout in seconds
    "idle_timeout": 600,       # Close idle connections after 10 min
    "max_lifetime": 3600       # Recycle connections after 1 hour
})

fun handle_request(request)
    try
        # Acquire connection from pool (blocks if none available)
        let conn = pool.acquire()

        # Use connection normally
        let cursor = conn.cursor()
        cursor.execute("SELECT * FROM users WHERE id = $1", [request["query"]["id"]])
        let user = cursor.fetch_one()

        # Connection automatically released when conn goes out of scope
        {"status": 200, "json": user}
    catch e
        {"status": 500, "body": "Database error"}
    end
end
```

**What You Get**:
- Scalable database access (beyond thread count)
- Resource efficiency (connections shared, not held idle)
- Automatic cleanup (RAII ensures release on error)
- Configurable pool parameters

**Testing Strategy**:
```quest
# test/async/pool_test.q
let pool = db.create_pool("postgresql://localhost/test", {max: 5})

# Verify pool limits
let conns = []
let i = 0
while i < 5
    conns.push(pool.acquire())
    i = i + 1
end

# 6th should timeout
try
    pool.acquire(timeout: 1)
    assert false
catch e
    # Expected timeout
end
```

**Success Criteria**:
- ✅ Connection pool efficiency > 90%
- ✅ Handles connection exhaustion gracefully
- ✅ Automatic cleanup on error
- ✅ Stats API works correctly

---

### **Phase 7: Advanced Features (Future)**
**Goal**: Power user features and advanced patterns

**Duration**: TBD

**Features**:
- Async streams/iterators
- Async context managers (`async with`)
- Custom executors
- Synchronization primitives (Mutex, RwLock, Semaphore)
- Async generators
- Actor model primitives
- Green threads / fibers

**Example Code** (Future):
```quest
# Async streams
async fun read_lines_stream(file)
    let stream = async.stream(fun ()
        let line = await file.readline()
        if line == "" then nil else line end
    end)
    stream
end

# Async context managers
async with AsyncFile.open("test.txt") as file
    let content = await file.read()
    puts(content)
end

# Actor model
type Counter
    impl Actor
        async fun handle(message)
            match message
                in {type: "inc"} self.count += 1
                in {type: "get"} return self.count
            end
        end
    end
end

let counter = Counter.spawn()
await counter.send({type: "inc"})
let value = await counter.send({type: "get"})
```

---

## Implementation Order Summary

```
Phase 1: Web Server (QEP-028)                        [2-3 weeks] ← START HERE
    ↓ Validates async runtime with real production use
Phase 2: async/await syntax + type methods (QEP-027) [3-4 weeks]
    ↓ Core language support for async functions
Phase 3: Channels & select (QEP-027)                 [2 weeks]
    ↓ Task coordination and message passing
Phase 4: Timeouts, utilities & task-local (QEP-027)  [2-3 weeks]
    ↓ Production hardening, error handling, and context management
Phase 5: Async I/O modules                           [2-3 weeks]
    ↓ Full stdlib integration
Phase 6: Connection pooling (QEP-028 P2)             [1-2 weeks]
    ↓ Efficient resource management
Phase 7: Advanced features                           [Future]
    ↓ Power user capabilities
```

**Total Time**: ~13-18 weeks for Phases 1-6

---

## Key Testing Strategies

### **Unit Tests** (per phase)
```bash
# Quest-level tests
./target/release/quest test/async/basic_test.q
./target/release/quest test/async/channel_test.q
./target/release/quest test/async/timeout_test.q

# Rust unit tests
cargo test async
cargo test channels
```

### **Integration Tests**
```quest
// test/server/hello_test.q
use "std/http/client"
let resp = http.get("http://localhost:3000")
assert resp.status() == 200

// test/async/http_integration_test.q
async fun test_concurrent_requests()
    let tasks = [1, 2, 3, 4, 5].map(fun (id)
        async.spawn(fun () fetch_user(id) end)
    end)
    let users = await async.join_all(tasks)
    assert users.len() == 5
end
```

### **Load Testing** (Phase 1)
```bash
# Web server benchmarks
wrk -t4 -c100 -d30s http://localhost:3000
ab -n 10000 -c 100 http://localhost:3000/

# Channel throughput
./target/release/quest benches/async/channel_throughput.q

# Task spawn overhead
./target/release/quest benches/async/spawn_overhead.q
```

### **Benchmark Suite**
```quest
// benches/async/spawn_overhead.q - Measure spawn/await cost
// benches/async/channel_throughput.q - Message passing performance
// benches/web_server.q - Requests per second
// benches/async/parallel_io.q - Concurrent I/O operations
```

---

## Decisions Made

1. **REPL async mode**: ✅ **ACCEPTED**
   - **Decision**: Yes, auto-wrap with `async>` prompt to show mode
   - User can type `await fetch_data()` directly in REPL
   - Implementation: Detect `await` keyword, auto-wrap in `block_on`

2. **Task cancellation**: ✅ **ACCEPTED**
   - **Decision**: Auto-cancel dropped tasks (matches Rust's behavior)
   - More predictable, prevents resource leaks
   - Safer default for production code

3. **Syntax**: ✅ **ACCEPTED**
   - **Decision**: `async fun` (matches Python/Rust/JavaScript)
   - Universal convention across major languages
   - Strong ecosystem alignment

4. **Structured concurrency**: ✅ **ACCEPTED with enhancement**
   - **Decision**: Optional, but prioritize `task_group()` for Phase 4
   - Allow both styles (fire-and-forget vs scoped)
   - Structured concurrency increasingly recognized as best practice

5. **Web server hot reload**: ✅ **ACCEPTED**
   - **Decision**: Phase 2 enhancement (or later)
   - Development quality-of-life feature
   - Can use external tools like `watchexec` in meantime

6. **WebSocket in Phase 1**: ✅ **ACCEPTED**
   - **Decision**: Include in Phase 1 (already implemented)
   - High value feature, validates bidirectional async I/O

7. **Module organization**: ✅ **ACCEPTED**
   - **Decision**: Everything in `std/async`
   - Simpler mental model, one import for all async features
   - Channels are inherently async constructs

8. **Task-local storage**: ✅ **MOVED TO PHASE 4**
   - **Decision**: Move from Phase 7 to Phase 4
   - Critical for web server context propagation (request IDs, logging correlation, distributed tracing)
   - Important for database transaction context management

---

## Success Metrics

### **Phase 1 (Web Server)**:
- ✅ 5000+ req/s for hello world
- ✅ 1000+ req/s with database queries
- ✅ 500+ req/s with template rendering
- ✅ WebSocket echo server working
- ✅ Production deployment examples
- ✅ Complete documentation with examples

### **Phase 2-4 (Core Async)**:
- ✅ Async overhead < 10% vs sync for simple operations
- ✅ Channel throughput > 1M msg/s
- ✅ Task spawn time < 10µs
- ✅ All basic async patterns working (spawn, await, timeout)
- ✅ Exception handling matches sync semantics

### **Phase 5-6 (Integration)**:
- ✅ All major stdlib modules have async variants
- ✅ Connection pool efficiency > 90%
- ✅ Database query performance matches raw driver
- ✅ HTTP client performance competitive with reqwest
- ✅ Complete async stdlib coverage

### **Overall Project Success**:
- ✅ Can build production web apps in Quest
- ✅ Performance competitive with Node.js/Python async
- ✅ Clear, familiar API for developers
- ✅ Comprehensive test coverage (>80%)
- ✅ Complete documentation with real-world examples
- ✅ At least 3 example applications using async features

---

## Risk Mitigation

### **Risk**: Tokio runtime integration breaks existing sync code
**Mitigation**:
- Phase 1 uses `spawn_blocking` exclusively
- Zero language changes in Phase 1
- Extensive testing of existing test suite
- Backward compatibility is requirement #1

### **Risk**: Async/await syntax too complex for users
**Mitigation**:
- Copy proven Python/Rust/JavaScript patterns
- Extensive examples and tutorials
- Simple default behaviors (auto-cancel, auto-release)
- Progressive disclosure (basic → advanced)

### **Risk**: Performance not competitive
**Mitigation**:
- Benchmark early and often (Phase 1)
- Set clear performance targets before Phase 2
- Profile hot paths and optimize aggressively
- Consider compilation/JIT if needed

### **Risk**: Too much scope, never ship
**Mitigation**:
- Each phase is independently valuable and shippable
- Can stop after any phase and still have useful features
- Phase 1 alone provides immediate production value
- Time-box each phase, cut features if needed

### **Risk**: Channel API too low-level
**Mitigation**:
- Provide high-level patterns in stdlib
- Document common patterns extensively
- Consider higher-level abstractions in Phase 7

### **Risk**: Database pooling too complex
**Mitigation**:
- Keep simple `db.connect()` for basic use
- Pool is opt-in, not required
- Sensible defaults (min: 2, max: 10)
- Clear migration guide

---

## Dependencies & Prerequisites

### **Rust Crates** (already have most):
```toml
[dependencies]
tokio = { version = "1.35", features = ["full"] }
axum = "0.7"
tower = "0.4"
tower-http = { version = "0.5", features = ["trace"] }
hyper = { version = "1.0", features = ["full"] }
deadpool-postgres = "0.12"  # Phase 6
mysql_async = "0.32"        # Phase 6
r2d2 = "0.8"                # Phase 6
r2d2_sqlite = "0.23"        # Phase 6
tokio-tungstenite = "0.21"  # WebSockets
```

### **Knowledge Requirements**:
- Tokio runtime basics
- Rust async/await patterns
- Axum web framework
- Pest grammar modifications
- Quest evaluator internals

### **Infrastructure**:
- Load testing tools (`wrk`, `ab`)
- Benchmark harness
- CI/CD pipeline updates
- Documentation website

---

## Documentation Plan

### **User Documentation**:
1. **Getting Started with Async** (`docs/async/getting-started.md`)
   - Basic async/await tutorial
   - Simple examples
   - Common patterns

2. **Async API Reference** (`docs/async/api.md`)
   - Complete `std/async` module docs
   - All functions and objects
   - Code examples for each API

3. **Web Server Guide** (`docs/webserver.md`)
   - `quest serve` usage
   - Request/response handling
   - WebSocket applications
   - Deployment guide

4. **Advanced Async Patterns** (`docs/async/patterns.md`)
   - Producer-consumer
   - Retry with backoff
   - Fan-out/fan-in
   - Circuit breaker pattern

5. **Performance Tuning** (`docs/async/performance.md`)
   - Benchmarking async code
   - Connection pooling
   - Optimization tips

### **Developer Documentation**:
1. **Architecture Overview** (`docs/dev/async-architecture.md`)
   - Tokio integration
   - Evaluator changes
   - Memory management

2. **Implementation Guide** (`docs/dev/async-implementation.md`)
   - Adding new async modules
   - Testing async code
   - Debugging tips

### **CLAUDE.md Updates**:
- Add async/await section
- Document `std/async` module
- Update examples with async patterns
- Link to comprehensive docs

---

## Related QEPs

- **QEP-027**: Async Tasks and Concurrent Programming (core specification)
- **QEP-028**: Web Server Command (first production use case)
- **QEP-001**: Database API (needs async variants in Phase 5)
- **QEP-012**: Process Module (could benefit from async process spawning)
- **QEP-013**: File Objects (needs async variants in Phase 5)

---

## Conclusion

This phased approach provides:
- **Early value**: Phase 1 ships production-ready web server
- **Low risk**: Each phase builds on proven previous phase
- **Clear milestones**: Each phase has concrete deliverables
- **Flexibility**: Can adjust scope based on learnings
- **Production focus**: Real-world use drives design decisions

The total timeline of 12-16 weeks provides a realistic path to full async/concurrent programming support in Quest, with each phase delivering independently valuable features.

**Recommended Starting Point**: Begin with Phase 1 (Web Server) to validate the Tokio integration and gather real-world feedback before committing to language-level async/await syntax.