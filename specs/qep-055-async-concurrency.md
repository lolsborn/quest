---
Number: QEP-055
Title: Async/Concurrency Model (Thread-Based Phase 1)
Author: Claude Code
Status: Draft
Created: 2025-10-16
---

# QEP-055: Async/Concurrency Model (Thread-Based Phase 1)

## Overview

Define Quest's concurrency model to support real-time web applications (QEP-054), background tasks, and parallel I/O operations. This QEP describes a **pragmatic, phased approach** starting with OS threads and callbacks, with a clear path to native async/await in the future.

## Status

**Draft** - Design phase

**Related QEPs:**
- **QEP-054**: Real-Time Web Framework (requires concurrency for WebSockets)
- **QEP-051**: Web Server Configuration (may benefit from concurrent request handling)

## Goals

### Phase 1 (This QEP)
- Enable concurrent I/O operations using OS threads
- Provide callback-based API for asynchronous code
- Support WebSocket connections (100-1000 concurrent)
- Background task execution
- Thread-safe primitives (channels, locks)
- Zero breaking changes to existing Quest code

### Phase 2 (Future QEP)
- Native `async`/`await` syntax
- Async runtime integration
- Promise/Future types
- Higher scalability (10,000+ connections)

## Non-Goals

- ❌ Native async/await syntax (Phase 2)
- ❌ Green threads / fibers
- ❌ C10K scalability (10,000+ connections)
- ❌ Actor model / message passing
- ❌ Shared memory parallelism (stay single-threaded for Quest code)

## Motivation

### Current State

Quest is **single-threaded and synchronous**:

```quest
# Blocking I/O
let data = io.read("large_file.txt")  # Blocks until complete
puts("Done")

# Sequential execution
let users = fetch_users()   # Wait
let posts = fetch_posts()   # Wait
# Could be parallel!
```

**Problems:**
1. **WebSockets impossible** - Can't handle multiple connections simultaneously
2. **Slow I/O blocks everything** - One slow database query freezes REPL
3. **No background tasks** - Can't send email while processing request
4. **Wasted time** - Multiple independent I/O operations run sequentially

### Real-World Use Cases

**1. WebSocket Server** (QEP-054)
```quest
# Need to handle 100+ simultaneous connections
web.websocket("/chat", fun (socket)
    socket.on_message(fun (data)
        # Must not block other connections
        let result = process_message(data)
        socket.send(result)
    end)
end)
```

**2. Background Jobs**
```quest
# Send email without blocking HTTP response
fun handle_request(request)
    let order = create_order(request["data"])

    # Send email in background
    async.spawn(fun ()
        send_confirmation_email(order)
    end)

    # Return immediately
    {"status": 200, "body": "Order created"}
end
```

**3. Parallel I/O**
```quest
# Fetch multiple APIs concurrently
let task1 = async.spawn(fun () http.get("https://api1.com") end)
let task2 = async.spawn(fun () http.get("https://api2.com") end)
let task3 = async.spawn(fun () http.get("https://api3.com") end)

# Wait for all (much faster than sequential)
let results = async.join_all([task1, task2, task3])
```

**4. Long-Running Tasks**
```quest
# Process large file without blocking REPL
let task = async.spawn(fun ()
    let lines = io.read("huge.csv").split("\n")
    let i = 0
    while i < lines.len()
        process_line(lines[i])
        i = i + 1
    end
end)

# Continue using REPL while task runs
>>> 2 + 2
4
>>> task.is_done()
false
>>> task.join()  # Wait for completion
nil
```

## Design Philosophy

### Why Not Async/Await (Yet)?

Adding `async`/`await` to Quest would require:

1. **Language changes** - New keywords, AST nodes, parser updates
2. **Evaluator overhaul** - Async recursion, Future type, runtime integration
3. **Type system changes** - Promise types, async function signatures
4. **Stdlib migration** - All I/O operations need async versions
5. **Breaking changes** - User code may need updates
6. **6+ months of work** - Major undertaking

### Phase 1: Pragmatic Approach

Start with **thread-based concurrency** (like Ruby, Python pre-async):

**Advantages:**
✅ **No language changes** - Works with existing Quest syntax
✅ **Simple mental model** - Each task runs on its own thread
✅ **Familiar API** - Callbacks, similar to JavaScript/Node.js
✅ **Good enough** - Handles 100-1000 concurrent operations
✅ **Ship quickly** - Get real-world feedback before async/await
✅ **Forwards compatible** - Can add async/await later without breaking changes

**Trade-offs:**
⚠️ **Thread overhead** - ~2MB per thread (vs ~2KB for async tasks)
⚠️ **Context switching** - More CPU overhead with many threads
⚠️ **Scalability limit** - Not suitable for 10,000+ connections

**When Phase 2 is needed**: If users hit scalability limits in production.

## Architecture

### Thread Model

```
┌─────────────────────────────────────────────┐
│  Main Thread (Quest REPL/Script)           │
│  - Runs user code                           │
│  - Synchronous by default                   │
└─────────────────┬───────────────────────────┘
                  │
                  │ async.spawn()
                  │
        ┌─────────┴─────────┐
        ▼                   ▼
┌──────────────┐    ┌──────────────┐
│ Worker       │    │ Worker       │
│ Thread 1     │    │ Thread 2     │
│              │    │              │
│ Runs Quest   │    │ Runs Quest   │
│ callback     │    │ callback     │
└──────────────┘    └──────────────┘
```

**Key Principles:**
1. **Main thread** runs user's script/REPL
2. **Worker threads** run callbacks spawned via `async.spawn()`
3. **Each thread has isolated Scope** - No shared state by default
4. **Communication via channels** - Safe message passing
5. **GIL-free** - Multiple threads can run Quest code simultaneously (unlike Python)

### Rust Implementation Strategy

```rust
// src/async_runtime.rs (new file)

use std::thread;
use std::sync::{Arc, Mutex};
use crossbeam::channel::{Sender, Receiver};

pub struct AsyncRuntime {
    task_counter: AtomicU64,
}

impl AsyncRuntime {
    pub fn spawn_task(&self, func: QValue, scope: Scope) -> TaskHandle {
        let task_id = self.task_counter.fetch_add(1, Ordering::SeqCst);

        let handle = TaskHandle {
            id: task_id,
            state: Arc::new(Mutex::new(TaskState::Running)),
            result: Arc::new(Mutex::new(None)),
        };

        let handle_clone = handle.clone();

        thread::spawn(move || {
            // Clone scope for isolated execution
            let mut thread_scope = scope.clone_isolated();

            // Execute function on this thread
            let result = match call_function(&func, vec![], &mut thread_scope) {
                Ok(val) => val,
                Err(e) => {
                    *handle_clone.state.lock().unwrap() = TaskState::Failed(e);
                    return;
                }
            };

            // Store result
            *handle_clone.result.lock().unwrap() = Some(result);
            *handle_clone.state.lock().unwrap() = TaskState::Completed;
        });

        handle
    }
}

pub struct TaskHandle {
    id: u64,
    state: Arc<Mutex<TaskState>>,
    result: Arc<Mutex<Option<QValue>>>,
}

enum TaskState {
    Running,
    Completed,
    Failed(String),
}
```

### Scope Isolation

**Critical**: Each thread needs its own `Scope` to prevent data races:

```rust
impl Scope {
    /// Create isolated scope for thread execution
    pub fn clone_isolated(&self) -> Scope {
        Scope {
            // Copy variable bindings (deep clone)
            vars: self.vars.iter()
                .map(|(k, v)| (k.clone(), v.clone()))
                .collect(),

            // Shared globals (read-only, wrapped in Arc)
            globals: Arc::clone(&self.globals),

            // New scope ID for debugging
            id: generate_scope_id(),

            // No parent scope (independent)
            parent: None,
        }
    }
}
```

**Important**: `QValue` must remain `Clone` for this to work (already the case).

## API Design

### Module: std/async

```quest
use "std/async" as async

# Core functions:
async.spawn(func)                    # Run function on new thread
async.join(task)                     # Wait for task completion
async.join_all(tasks: Array)         # Wait for multiple tasks
async.race(tasks: Array)             # Wait for first completion
async.sleep(milliseconds: Int)       # Sleep current thread

# Channels (message passing):
async.channel()                      # Create unbounded channel
async.channel(capacity: Int)         # Create bounded channel

# Synchronization primitives:
async.mutex(initial_value)           # Create mutex
async.atomic(value: Int)             # Create atomic integer
```

### Task Spawning

```quest
use "std/async" as async

# Basic spawn - returns immediately
let task = async.spawn(fun ()
    puts("Running in background")
    return 42
end)

puts("Main thread continues")

# Wait for result
let result = async.join(task)
puts(result)  # 42

# Check status without blocking
if task.is_done()
    puts("Task completed!")
end
```

### Task Object API

```quest
# Task handle returned by async.spawn()

task.id()           # Unique task ID (Int)
task.is_done()      # Bool - has task completed?
task.is_running()   # Bool - is task still running?
task.join()         # Block until complete, return result
task.join_timeout(ms: Int)  # Wait with timeout, returns nil on timeout
task.try_join()     # Non-blocking join, returns nil if not done
```

### Parallel Execution

```quest
use "std/async" as async
use "std/http/client" as http

# Spawn multiple tasks
let tasks = [
    async.spawn(fun () http.get("https://api1.com/users") end),
    async.spawn(fun () http.get("https://api2.com/posts") end),
    async.spawn(fun () http.get("https://api3.com/comments") end)
]

# Wait for all to complete
let results = async.join_all(tasks)

puts("Users: " .. results[0].body)
puts("Posts: " .. results[1].body)
puts("Comments: " .. results[2].body)
```

### Channels (Message Passing)

```quest
use "std/async" as async

# Create unbounded channel
let (sender, receiver) = async.channel()

# Spawn producer task
async.spawn(fun ()
    let i = 0
    while i < 10
        sender.send(i)
        async.sleep(100)  # 100ms delay
        i = i + 1
    end
    sender.close()  # Signal completion
end)

# Consume messages on main thread
while true
    let msg = receiver.recv()  # Blocks until message available

    if msg == nil
        break  # Channel closed
    end

    puts("Received: " .. msg.str())
end
```

### Channel Object API

```quest
# Sender API
sender.send(value)           # Send message (blocks if bounded channel is full)
sender.try_send(value)       # Non-blocking send, returns false if full
sender.close()               # Close sender (signals no more messages)
sender.is_closed()           # Bool - is sender closed?

# Receiver API
receiver.recv()              # Receive message (blocks until available)
receiver.recv_timeout(ms: Int)  # Receive with timeout, returns nil on timeout
receiver.try_recv()          # Non-blocking receive, returns nil if empty
receiver.is_closed()         # Bool - is channel closed and empty?
```

### Synchronization Primitives

#### Mutex (Mutual Exclusion)

```quest
use "std/async" as async

let mutex = async.mutex(initial_value: 0)

# Spawn multiple threads incrementing counter
let tasks = []
let i = 0
while i < 10
    let task = async.spawn(fun ()
        let j = 0
        while j < 100
            mutex.with_lock(fun (counter)
                counter + 1  # Return new value
            end)
            j = j + 1
        end
    end)
    tasks.push(task)
    i = i + 1
end

# Wait for all
async.join_all(tasks)

# Read final value
let final = mutex.with_lock(fun (counter) counter end)
puts(final)  # 1000 (10 threads * 100 increments)
```

#### Atomic Integer

```quest
use "std/async" as async

let counter = async.atomic(0)

# Atomic operations (lock-free)
counter.fetch_add(5)     # Returns old value, adds 5
counter.fetch_sub(3)     # Returns old value, subtracts 3
counter.load()           # Read current value
counter.store(100)       # Set to 100

# Example: thread-safe counter
let tasks = []
let i = 0
while i < 10
    tasks.push(async.spawn(fun ()
        let j = 0
        while j < 1000
            counter.fetch_add(1)
            j = j + 1
        end
    end))
    i = i + 1
end

async.join_all(tasks)
puts(counter.load())  # 10000
```

## Integration with QEP-054 (WebSockets)

### WebSocket Handler Implementation

```quest
use "std/web" as web
use "std/async" as async

# WebSocket handler - each connection gets a thread
web.websocket("/chat", fun (socket)
    # This callback runs on dedicated thread per connection

    socket.on_message(fun (data)
        # Blocking operations are OK - won't block other connections
        let result = database.query("SELECT * FROM messages WHERE id = ?", [data])

        # Can spawn subtasks if needed
        async.spawn(fun ()
            send_notification(user_id, result)
        end)

        socket.send(result)
    end)
end)
```

**Scalability**: With 2MB per thread, can handle ~500-1000 connections per GB of RAM.

## Error Handling

### Task Failures

```quest
use "std/async" as async

let task = async.spawn(fun ()
    raise Err.new("Something went wrong!")
end)

# join() re-raises the exception on calling thread
try
    let result = async.join(task)
catch e: Err
    puts("Task failed: " .. e.message())
end

# Or check status first
if task.is_failed()
    let error = task.error()  # Get error without re-raising
    puts("Task error: " .. error.message())
end
```

## Use Case Examples

### Example 1: Background Email Sender

```quest
use "std/async" as async
use "std/web" as web

fun handle_request(request)
    if request["path"] == "/signup"
        let user = create_user(request["data"])

        # Send welcome email in background (don't block response)
        async.spawn(fun ()
            try
                send_welcome_email(user["email"])
                puts("Email sent to " .. user["email"])
            catch e: Err
                puts("Email failed: " .. e.message())
            end
        end)

        # Return immediately
        return {"status": 200, "body": "User created!"}
    end
end

web.serve(handle_request, port: 3000)
```

### Example 2: Parallel API Aggregation

```quest
use "std/async" as async
use "std/http/client" as http
use "std/encoding/json" as json

fun fetch_dashboard_data(user_id)
    # Fetch from multiple sources in parallel
    let tasks = [
        async.spawn(fun ()
            let resp = http.get("https://api.example.com/users/" .. user_id.str())
            json.parse(resp.body)
        end),

        async.spawn(fun ()
            let resp = http.get("https://api.example.com/posts?user=" .. user_id.str())
            json.parse(resp.body)
        end),

        async.spawn(fun ()
            let resp = http.get("https://api.example.com/analytics/" .. user_id.str())
            json.parse(resp.body)
        end)
    ]

    # Wait for all (much faster than sequential)
    let results = async.join_all(tasks)

    return {
        "user": results[0],
        "posts": results[1],
        "analytics": results[2]
    }
end
```

### Example 3: Worker Pool Pattern

```quest
use "std/async" as async

fun worker_pool(num_workers, tasks)
    let (task_sender, task_receiver) = async.channel()
    let (result_sender, result_receiver) = async.channel()

    # Spawn worker threads
    let workers = []
    let i = 0
    while i < num_workers
        let worker = async.spawn(fun ()
            while true
                let task = task_receiver.recv()
                if task == nil
                    break
                end

                # Process task
                let result = task["func"](task["data"])
                result_sender.send({
                    "task_id": task["id"],
                    "result": result
                })
            end
        end)
        workers.push(worker)
        i = i + 1
    end

    # Send tasks to workers
    let j = 0
    while j < tasks.len()
        task_sender.send({
            "id": j,
            "func": tasks[j]["func"],
            "data": tasks[j]["data"]
        })
        j = j + 1
    end
    task_sender.close()

    # Collect results
    let results = []
    let k = 0
    while k < tasks.len()
        results.push(result_receiver.recv())
        k = k + 1
    end

    # Wait for workers
    async.join_all(workers)

    return results
end
```

## Performance Considerations

### Thread Overhead

**Memory**: ~2MB per thread (OS stack + overhead)
- 100 threads = ~200MB
- 1000 threads = ~2GB
- 10,000 threads = ~20GB ❌ Not practical

**Recommendation**: Design for <1000 concurrent tasks in Phase 1.

### When to Use Threads vs Sequential

**Use threads when**:
✅ Multiple independent I/O operations (HTTP, database, files)
✅ Background tasks that don't need immediate results
✅ Concurrent connections (WebSockets)

**Avoid threads when**:
❌ Quick operations (<10ms) - overhead not worth it
❌ Thousands of tasks - hit thread limits

## Testing Strategy

```quest
use "std/test" as test
use "std/async" as async

test.describe("async.spawn", fun ()
    test.it("executes function on separate thread", fun ()
        let task = async.spawn(fun ()
            return 42
        end)

        let result = async.join(task)
        test.assert_eq(result, 42)
    end)

    test.it("handles exceptions", fun ()
        let task = async.spawn(fun ()
            raise Err.new("Test error")
        end)

        test.assert_raises(fun ()
            async.join(task)
        end, Err)
    end)
end)
```

## Security Considerations

### Thread Isolation

Each spawned thread gets **isolated scope** - no shared mutable state by default:

```quest
let secret = "password123"

async.spawn(fun ()
    # Gets copy of 'secret', not reference
    puts(secret)  # "password123"
    secret = "hacked"  # Modifies local copy only
end)

puts(secret)  # Still "password123" - parent unchanged
```

**This prevents**:
- Accidental data races
- Concurrent modification bugs
- Security leaks via shared state

### Resource Limits

**Quest should enforce**: Maximum thread limit (configurable, default 1000).

## Documentation Plan

### Add to docs/docs/

1. **async-concurrency.md** - Complete async API reference
2. **threads-guide.md** - When to use threads, patterns
3. **channels-tutorial.md** - Message passing examples

### Update CLAUDE.md

Add concurrency section with basic examples and link to detailed docs.

## Implementation Timeline

### Phase 1: Core Infrastructure (3-4 weeks)

**Week 1-2**: Rust async runtime + Quest API
- AsyncRuntime struct
- Task spawning with thread::spawn
- TaskHandle implementation
- Scope cloning/isolation
- async.spawn(), async.join(), async.join_all()
- Basic tests

**Week 3**: Channels
- crossbeam channel integration
- Sender/Receiver Quest objects
- Bounded and unbounded channels
- send(), recv() implementations

**Week 4**: Synchronization primitives
- Mutex implementation
- Atomic integers
- Integration tests

### Phase 2: Polish and Integration (2-3 weeks)

**Week 5**: Error handling
- Exception propagation across threads
- task.is_failed(), task.error()
- Graceful shutdown
- Resource cleanup

**Week 6**: QEP-054 integration
- WebSocket thread-per-connection
- Background task helpers
- Performance testing

**Week 7**: Documentation and examples
- API reference docs
- Tutorial guides
- Best practices

### Phase 3: Future Enhancements (Separate QEP)

- Native async/await syntax
- Promise/Future types
- Async runtime (Tokio integration)
- Migration path from thread-based to async/await

**Timeline**: 6-12 months after Phase 1 ships (based on user feedback)

## Success Criteria

### Phase 1 (Thread-Based)

- ✅ Can spawn background tasks with `async.spawn()`
- ✅ Tasks execute on separate OS threads
- ✅ Can wait for task completion with `async.join()`
- ✅ Channels work for message passing
- ✅ Mutex prevents race conditions
- ✅ Exceptions propagate correctly across threads
- ✅ All tests pass (unit + integration)
- ✅ Documentation complete
- ✅ QEP-054 WebSockets work with 100+ connections
- ✅ No breaking changes to existing Quest code
- ✅ Performance acceptable for 100-1000 concurrent tasks

### Phase 2 (Async/Await - Future)

- ✅ Native `async` and `await` keywords
- ✅ Promise/Future types in type system
- ✅ Async stdlib functions (io, http, db)
- ✅ Backwards compatible with Phase 1 thread-based API
- ✅ 10,000+ concurrent tasks supported
- ✅ Lower memory overhead than threads

## Alternatives Considered

### 1. Async/Await from Start

**Pros**: Better scalability, lower overhead, industry standard
**Cons**: 6+ months work, breaking changes, complex implementation
**Decision**: Too risky for first iteration

### 2. Green Threads / Fibers

**Pros**: Synchronous API, better scalability than OS threads
**Cons**: Complex runtime, stack management issues, still major work
**Decision**: Interesting for Phase 3, but threads are simpler

### 3. Callbacks Only (No Threading)

**Pros**: Minimal implementation, no threading complexity
**Cons**: Can't block, callback hell, poor developer experience
**Decision**: Not sufficient for WebSockets and background tasks

### 4. Actor Model (Erlang-style)

**Pros**: Proven for concurrency, message passing built-in
**Cons**: Major paradigm shift, doesn't fit Quest's design
**Decision**: Too different from Quest's functional style

## Migration Path to Phase 2

When Quest adds async/await, the thread-based API remains compatible:

```quest
# Phase 1 code (thread-based)
let task = async.spawn(fun ()
    return fetch_data()
end)
let result = async.join(task)

# Phase 2 code (async/await) - same result
async fun fetch_data_async()
    let response = await http.get("https://api.com")
    return response
end

let result = await fetch_data_async()
```

**Compatibility strategy**:
- Keep `async.spawn()` working (compatibility shim)
- `spawn()` can wrap async functions
- `join()` can await promises
- No breaking changes for users

## Open Questions

### 1. Thread Pool vs Unbounded Threads?

**Current design**: Each `spawn()` creates new OS thread

**Alternative**: Thread pool (fixed number of threads, queue tasks)

**Decision**: Start with unbounded, add pool in Phase 1.5 if needed

### 2. Default Thread Stack Size?

Rust default: 2MB per thread

**Decision**: Start with 2MB default, make configurable

### 3. Automatic Cleanup of Detached Tasks?

**Decision**: Allow detached, add `task.detach()` explicit method

### 4. Channel Semantics: Clone or Move?

**Decision**: Clone (Quest's default) - simpler, more predictable

## References

- [Rust std::thread documentation](https://doc.rust-lang.org/std/thread/)
- [crossbeam crate](https://docs.rs/crossbeam/)
- [Python threading module](https://docs.python.org/3/library/threading.html)
- [Ruby Thread class](https://ruby-doc.org/core-3.0.0/Thread.html)
- [QEP-054: Real-Time Web Framework](qep-054-realtime-web-framework.md)
- [Node.js Worker Threads](https://nodejs.org/api/worker_threads.html)

## Summary

This QEP defines a **pragmatic, phased approach** to concurrency in Quest:

**Phase 1** (this QEP): Thread-based concurrency with callbacks
- ✅ Ships quickly (5-7 weeks)
- ✅ No breaking changes
- ✅ Good enough for 100-1000 concurrent tasks
- ✅ Enables QEP-054 WebSockets
- ✅ Real-world feedback before async/await

**Phase 2** (future QEP): Native async/await
- When users hit scalability limits
- Backwards compatible with Phase 1
- 6-12 months after Phase 1 ships

**This approach balances pragmatism with ambition** - ship something useful quickly, iterate based on feedback.
