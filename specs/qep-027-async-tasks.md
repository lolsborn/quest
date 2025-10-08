# QEP-027: Async Tasks and Concurrent Programming

**Status**: Draft
**Created**: 2025-10-05
**Author**: Claude Code

## Summary

Proposes exposing Tokio-based asynchronous tasks in Quest through an `async`/`await` syntax and `std/async` module, enabling concurrent programming, non-blocking I/O, and efficient handling of I/O-bound operations.

## Motivation

Modern applications increasingly require concurrent execution for:
- **Concurrent I/O** - Handling multiple network connections, file operations simultaneously
- **Background tasks** - Long-running operations without blocking the main thread
- **Responsive applications** - Keep REPL responsive during slow operations
- **Performance** - Utilize multi-core systems efficiently for I/O-bound workloads
- **Integration** - Work with async Rust ecosystem (HTTP clients, databases, etc.)

Current Quest is synchronous, which means:
- Blocking I/O operations freeze the entire program
- Cannot handle multiple operations concurrently
- Poor performance for network-heavy applications (web servers, API clients)
- Cannot leverage async Rust crates (tokio, hyper, reqwest, etc.)

## Design Goals

1. **Familiar syntax** - Python/JavaScript-style `async`/`await`
2. **Simple for common cases** - Basic concurrent tasks should be easy
3. **Powerful for advanced cases** - Full control over task lifecycle, cancellation, timeouts
4. **Tokio-backed** - Leverage Rust's mature async runtime
5. **Backward compatible** - Existing synchronous code continues to work
6. **Type-safe** - Clear distinction between sync and async functions
7. **Integration** - Work seamlessly with existing Quest modules

## Language-Level Syntax

### Async Function Declaration

```quest
# Declare async function
async fun fetch_user(id)
    let response = await http.get(f"https://api.example.com/users/{id}")
    let data = await response.json()
    data
end

# Static async methods
type UserService
    static async fun fetch_all()
        await http.get("https://api.example.com/users")
    end
end

# Instance async methods
type Database
    str: connection_string

    async fun query(sql)
        await db.execute(self.connection_string, sql)
    end
end
```

### Calling Async Functions

```quest
# Must await async functions
async fun main()
    let user = await fetch_user(123)
    puts(user.name)
end

# Can spawn as background task
let task = async.spawn(fun () fetch_user(123) end)
# Do other work...
let user = await task
```

### Concurrent Execution

```quest
use "std/async"

# Run multiple async operations concurrently
async fun fetch_all_users()
    let ids = [1, 2, 3, 4, 5]

    # Launch all requests concurrently
    let tasks = ids.map(fun (id) async.spawn(fun () fetch_user(id) end) end)

    # Wait for all to complete
    let users = await async.join_all(tasks)
    users
end

# Race multiple operations (return first to complete)
async fun fetch_with_fallback()
    let primary = async.spawn(fun () fetch_from_primary() end)
    let backup = async.spawn(fun () fetch_from_backup() end)

    # Returns result of whichever completes first
    let result = await async.race([primary, backup])
    result
end
```

## std/async Module

### Task Management

```quest
use "std/async"

# Spawn a task (runs in background)
async.spawn(fun ()
    await long_running_operation()
end)

# Spawn and get handle
let task = async.spawn(fun ()
    await fetch_data()
end)

# Wait for task completion
let result = await task

# Check task status
if task.is_finished()
    let result = task.try_unwrap()  # Get result without blocking
end

# Cancel task
task.cancel()
if await task.is_cancelled()
    puts("Task was cancelled")
end

# Spawn with name (for debugging)
let task = async.spawn(fun () work() end, name: "worker-1")
```

### Task Object

```quest
type Task
    # Properties
    str?: name                # Task name (if provided)
    int: id                   # Unique task ID
    bool: is_finished()       # Task completed?
    bool: is_cancelled()      # Task was cancelled?

    # Methods
    async fun await()         # Wait for completion, return result
        # Raises if task panicked or was cancelled
    end

    fun cancel()              # Request cancellation
        # Task must check cancellation points
    end

    fun try_unwrap()          # Get result if finished (non-blocking)
        # Returns result or nil if not finished
    end

    fun abort()               # Force-kill task (use sparingly)
        # Immediately terminates task
    end
end
```

### Timeouts

```quest
use "std/async"

# Timeout on single operation
async fun fetch_with_timeout()
    try
        let result = await async.timeout(fetch_data(), 5)  # 5 seconds
        result
    catch async.TimeoutError as e
        puts("Operation timed out after 5 seconds")
        nil
    end
end

# Timeout on multiple operations
let tasks = [task1, task2, task3]
let results = await async.timeout(async.join_all(tasks), 10)
```

### Sleep and Delays

```quest
use "std/async"

async fun retry_with_backoff(operation)
    let attempt = 0
    while attempt < 5
        try
            return await operation()
        catch e
            attempt = attempt + 1
            if attempt < 5
                let delay = 2 ** attempt  # Exponential backoff
                puts(f"Attempt {attempt} failed, retrying in {delay}s...")
                await async.sleep(delay)
            end
        end
    end
    raise "Max retries exceeded"
end
```

### Channels (Task Communication)

```quest
use "std/async"

# Create unbounded channel
let channel = async.channel()

# Spawn producer
async.spawn(fun ()
    let i = 0
    while i < 10
        await channel.send(i)
        await async.sleep(0.1)
        i = i + 1
    end
    channel.close()
end)

# Spawn consumer
async.spawn(fun ()
    while true
        let msg = await channel.recv()
        if msg == nil  # Channel closed
            break
        end
        puts(f"Received: {msg}")
    end
end)

# Bounded channel (blocks when full)
let channel = async.channel(capacity: 10)
```

### Channel Object

```quest
type Channel
    int?: capacity            # Bounded capacity (nil = unbounded)

    # Send message (blocks if bounded and full)
    async fun send(value)
        # Raises if channel is closed
    end

    # Try send without blocking
    fun try_send(value) → bool
        # Returns true if sent, false if full/closed
    end

    # Receive message (blocks until available)
    async fun recv() → value or nil
        # Returns nil if channel is closed and empty
    end

    # Try receive without blocking
    fun try_recv() → value or nil
        # Returns nil if empty or closed
    end

    fun close()               # Close channel (no more sends)
    fun is_closed() → bool
end
```

### Select (Wait on Multiple Channels)

```quest
use "std/async"

async fun handle_messages()
    let chan1 = async.channel()
    let chan2 = async.channel()
    let timeout_chan = async.timeout_channel(5)

    while true
        # Wait for first available message
        let result = await async.select([
            chan1,
            chan2,
            timeout_chan
        ])

        # result = {channel: Channel, value: any, index: Int}
        if result.index == 0
            puts(f"Channel 1: {result.value}")
        elif result.index == 1
            puts(f"Channel 2: {result.value}")
        elif result.index == 2
            puts("Timeout!")
            break
        end
    end
end
```

### Parallel Task Execution

```quest
use "std/async"

# Join all - wait for all tasks, fail if any fails
let results = await async.join_all([
    async.spawn(fun () task1() end),
    async.spawn(fun () task2() end),
    async.spawn(fun () task3() end)
])
# returns: [result1, result2, result3]

# Try join all - wait for all, collect successes and failures
let results = await async.try_join_all([
    async.spawn(fun () task1() end),
    async.spawn(fun () task2() end),
    async.spawn(fun () task3() end)
])
# returns: {ok: [result1, result3], err: [error2]}

# Race - return first to complete, cancel others
let winner = await async.race([
    async.spawn(fun () fetch_from_server1() end),
    async.spawn(fun () fetch_from_server2() end),
    async.spawn(fun () fetch_from_server3() end)
])
# returns: first successful result

# Race ok - return first successful result
let result = await async.race_ok([
    async.spawn(fun () might_fail1() end),
    async.spawn(fun () might_fail2() end)
])
# returns: first Ok result (ignores failures)
```

### Yield and Task Scheduling

```quest
use "std/async"

async fun cooperative_task()
    let i = 0
    while i < 1000000
        # Do some work
        compute(i)

        # Yield to other tasks periodically
        if i % 1000 == 0
            await async.yield_now()
        end

        i = i + 1
    end
end

# Block on async function from sync context
fun main()
    # Blocks current thread until async function completes
    let result = async.block_on(fun () fetch_data() end)
    puts(result)
end
```

## Examples

### Example 1: Concurrent HTTP Requests

```quest
use "std/async"
use "std/http/client"

async fun fetch_user(id)
    let response = await http.get(f"https://api.example.com/users/{id}")
    await response.json()
end

async fun fetch_all_users()
    let user_ids = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

    # Launch all requests concurrently
    let tasks = user_ids.map(fun (id)
        async.spawn(fun () fetch_user(id) end)
    end)

    # Wait for all to complete
    let users = await async.join_all(tasks)
    puts(f"Fetched {users.len()} users")
    users
end

# Run from REPL or main
async.block_on(fun () fetch_all_users() end)
```

### Example 2: Background Task with Progress Updates

```quest
use "std/async"

async fun process_files(files)
    let channel = async.channel()
    let total = files.len()

    # Spawn background processor
    let task = async.spawn(fun ()
        let i = 0
        while i < files.len()
            let file = files[i]
            process_file(file)

            # Send progress update
            await channel.send({
                "file": file,
                "progress": (i + 1) / total
            })

            i = i + 1
        end
        channel.close()
        "Done!"
    end)

    # Monitor progress
    while true
        let update = await channel.recv()
        if update == nil
            break
        end
        puts(f"Processed {update.file} ({update.progress * 100}%)")
    end

    # Wait for completion
    let result = await task
    puts(result)
end
```

### Example 3: Timeout and Retry Logic

```quest
use "std/async"
use "std/http/client"

async fun fetch_with_retry(url, max_attempts: 3)
    let attempt = 0

    while attempt < max_attempts
        try
            # Try with 5 second timeout
            let response = await async.timeout(http.get(url), 5)
            return await response.text()
        catch async.TimeoutError
            attempt = attempt + 1
            if attempt < max_attempts
                puts(f"Timeout, retrying ({attempt}/{max_attempts})...")
                await async.sleep(1)
            else
                raise "Max retries exceeded"
            end
        catch e
            puts(f"Error: {e.message()}")
            raise e
        end
    end
end

# Usage
async fun main()
    let data = await fetch_with_retry("https://slow-api.example.com/data")
    puts(data)
end

async.block_on(fun () main() end)
```

### Example 4: Producer-Consumer Pattern

```quest
use "std/async"

async fun producer(channel, items)
    let i = 0
    while i < items.len()
        let item = items[i]
        puts(f"Producing: {item}")
        await channel.send(item)
        await async.sleep(0.5)
        i = i + 1
    end
    channel.close()
    puts("Producer finished")
end

async fun consumer(channel, id)
    while true
        let item = await channel.recv()
        if item == nil
            break
        end
        puts(f"Consumer {id} processing: {item}")
        await async.sleep(1)  # Simulate work
    end
    puts(f"Consumer {id} finished")
end

async fun main()
    let channel = async.channel()
    let items = ["task1", "task2", "task3", "task4", "task5"]

    # Spawn producer
    async.spawn(fun () producer(channel, items) end)

    # Spawn multiple consumers
    let consumers = [
        async.spawn(fun () consumer(channel, 1) end),
        async.spawn(fun () consumer(channel, 2) end),
        async.spawn(fun () consumer(channel, 3) end)
    ]

    # Wait for all consumers
    await async.join_all(consumers)
    puts("All done!")
end

async.block_on(fun () main() end)
```

### Example 5: Select on Multiple Channels

```quest
use "std/async"

async fun monitor_system()
    let cpu_chan = async.channel()
    let memory_chan = async.channel()
    let disk_chan = async.channel()

    # Spawn monitors
    async.spawn(fun ()
        while true
            await async.sleep(1)
            let usage = get_cpu_usage()
            await cpu_chan.send({"type": "cpu", "value": usage})
        end
    end)

    async.spawn(fun ()
        while true
            await async.sleep(2)
            let usage = get_memory_usage()
            await memory_chan.send({"type": "memory", "value": usage})
        end
    end)

    async.spawn(fun ()
        while true
            await async.sleep(5)
            let usage = get_disk_usage()
            await disk_chan.send({"type": "disk", "value": usage})
        end
    end)

    # Monitor all channels
    let count = 0
    while count < 20
        let msg = await async.select([cpu_chan, memory_chan, disk_chan])
        puts(f"{msg.value.type}: {msg.value.value}%")
        count = count + 1
    end
end

async.block_on(fun () monitor_system() end)
```

### Example 6: Async Database Queries

```quest
use "std/async"
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

    {
        "user": user,
        "posts": posts
    }
end

async fun main()
    let data = await get_user_with_posts(123)
    puts(f"User: {data.user.name}")
    puts(f"Posts: {data.posts.len()}")
end

async.block_on(fun () main() end)
```

### Example 7: Simple Web Server (Future)

```quest
use "std/async"
use "std/http/server"  # Hypothetical async server module

async fun handle_request(request)
    if request.path == "/"
        {"status": 200, "body": "Hello, World!"}
    elif request.path == "/users"
        # Fetch from database asynchronously
        let users = await fetch_all_users()
        {"status": 200, "body": json.stringify(users)}
    else
        {"status": 404, "body": "Not Found"}
    end
end

async fun main()
    let server = http.server("127.0.0.1:8080")
    puts("Server listening on http://127.0.0.1:8080")

    # Accept connections concurrently
    while true
        let request = await server.accept()

        # Handle each request in separate task
        async.spawn(fun ()
            let response = await handle_request(request)
            await request.send_response(response)
        end)
    end
end

async.block_on(fun () main() end)
```

## Implementation Notes

### Tokio Runtime Integration

Quest will embed a Tokio runtime in the main evaluator:

```rust
use tokio::runtime::Runtime;

pub struct QuestRuntime {
    runtime: Runtime,
    // ... other fields
}

impl QuestRuntime {
    pub fn new() -> Self {
        let runtime = Runtime::new().unwrap();
        QuestRuntime { runtime }
    }

    pub fn block_on<F>(&self, future: F) -> F::Output
    where
        F: Future,
    {
        self.runtime.block_on(future)
    }

    pub fn spawn<F>(&self, future: F) -> JoinHandle<F::Output>
    where
        F: Future + Send + 'static,
        F::Output: Send + 'static,
    {
        self.runtime.spawn(future)
    }
}
```

### Async Function Representation

Async functions in Quest are represented as special function objects:

```rust
pub enum QValue {
    // ... existing variants
    AsyncFun(AsyncFunctionDef),
    Task(Arc<Mutex<Task>>),
    Channel(Arc<Mutex<mpsc::Sender<QValue>>>),
}

pub struct AsyncFunctionDef {
    name: String,
    params: Vec<String>,
    body: Vec<Statement>,
}
```

### Evaluation Strategy

When evaluating async functions:

1. **Declaration**: `async fun` creates `QValue::AsyncFun`
2. **Call**: Calling async function returns `QValue::Task` (future)
3. **Await**: `await task` blocks current async context until task completes
4. **Spawn**: `async.spawn()` schedules task on Tokio runtime

### REPL Integration

The REPL can automatically wrap async expressions in `block_on`:

```quest
quest> async fun test() 42 end
quest> test()  # Error: Cannot call async function without await
quest> await test()  # Error: Cannot await outside async context
quest> async.block_on(fun () test() end)  # OK
42
```

Or provide a special mode:

```quest
quest> async mode on
quest (async)> await test()
42
```

### Task Cancellation

Tasks support cooperative cancellation:

```rust
use tokio_util::sync::CancellationToken;

pub struct Task {
    handle: JoinHandle<QValue>,
    cancel_token: CancellationToken,
}

impl Task {
    pub fn cancel(&self) {
        self.cancel_token.cancel();
    }
}
```

Tasks must check cancellation points:

```quest
async fun long_task()
    let i = 0
    while i < 1000000
        if async.is_cancelled()
            puts("Task cancelled")
            return nil
        end

        # Do work
        compute(i)

        if i % 1000 == 0
            await async.yield_now()  # Cancellation check point
        end

        i = i + 1
    end
end
```

### Memory Management

Tasks are reference-counted:
- `Task` wraps `Arc<Mutex<JoinHandle>>`
- Dropped tasks are automatically cancelled (configurable)
- Channels use bounded queues to prevent unbounded memory growth

### Error Handling

Async errors propagate through await:

```quest
async fun might_fail()
    raise "Something went wrong"
end

async fun handle_error()
    try
        await might_fail()
    catch e
        puts(f"Caught: {e.message()}")
    end
end
```

Panics in tasks:

```quest
let task = async.spawn(fun ()
    raise "Panic in task"
end)

try
    await task
catch e
    puts("Task panicked: " .. e.message())
end
```

### Performance Considerations

1. **Task overhead**: Tokio tasks are lightweight (~2KB stack)
2. **Channel capacity**: Bounded channels prevent memory issues
3. **Async overhead**: Small overhead for async/await machinery
4. **Executor efficiency**: Tokio's work-stealing scheduler scales to many cores

### Cross-Platform Support

Tokio supports:
- **Unix/Linux**: epoll
- **macOS**: kqueue
- **Windows**: IOCP

All async operations work consistently across platforms.

## Migration Strategy

### Phase 1: Core Runtime (This QEP)
- Tokio runtime integration
- `async`/`await` syntax
- Basic task spawning and management
- Channels and select

### Phase 2: Async I/O Modules
- Async versions of `std/io` (file operations)
- Async `std/http/client`
- Async `std/db/*` (database drivers)

### Phase 3: Advanced Features
- Async streams (iterators)
- Async context managers
- Task pools and executors
- Advanced synchronization primitives (Mutex, RwLock, Semaphore)

### Backward Compatibility

Existing synchronous code continues to work:
- Sync functions can be called from anywhere
- Async functions can only be called from async contexts (or via `block_on`)
- Mixing sync/async is explicit and clear

## API Reference

### async.spawn(fn, name?) → Task

Spawn a new task on the runtime.

```quest
let task = async.spawn(fun ()
    await long_operation()
end, name: "worker-1")
```

### async.block_on(fn) → result

Block current thread until async function completes.

```quest
# From synchronous context
let result = async.block_on(fun ()
    await fetch_data()
end)
```

### async.sleep(seconds) → nil

Sleep asynchronously for specified duration.

```quest
await async.sleep(1.5)  # Sleep 1.5 seconds
```

### async.timeout(task, seconds) → result

Wait for task with timeout.

```quest
try
    let result = await async.timeout(fetch_data(), 5)
catch async.TimeoutError
    puts("Timeout!")
end
```

### async.join_all(tasks) → Array

Wait for all tasks to complete successfully.

```quest
let results = await async.join_all([task1, task2, task3])
```

### async.try_join_all(tasks) → {ok: Array, err: Array}

Wait for all tasks, collect successes and failures.

```quest
let results = await async.try_join_all([task1, task2, task3])
puts(f"{results.ok.len()} succeeded, {results.err.len()} failed")
```

### async.race(tasks) → result

Return result of first task to complete.

```quest
let winner = await async.race([task1, task2, task3])
```

### async.race_ok(tasks) → result

Return first successful result (ignore failures).

```quest
let result = await async.race_ok([
    async.spawn(fun () fetch_from_primary() end),
    async.spawn(fun () fetch_from_backup() end)
])
```

### async.yield_now() → nil

Yield to allow other tasks to run.

```quest
await async.yield_now()
```

### async.channel(capacity?) → Channel

Create a channel for task communication.

```quest
let chan = async.channel()          # Unbounded
let chan = async.channel(capacity: 100)  # Bounded
```

### async.select(channels) → {channel: Channel, value: any, index: Int}

Wait for first available message from multiple channels.

```quest
let msg = await async.select([chan1, chan2, chan3])
puts(f"Received from channel {msg.index}: {msg.value}")
```

## Alternatives Considered

### 1. Callback-Based Async (Node.js style)

```quest
# Not chosen - callback hell
fetch_user(123, fun (user)
    fetch_posts(user.id, fun (posts)
        puts(posts)
    end)
end)
```

**Rejected**: Leads to deeply nested callbacks, poor error handling.

### 2. Promise-Based (JavaScript Promises)

```quest
# Not chosen - verbose chaining
fetch_user(123).then(fun (user)
    fetch_posts(user.id)
end).then(fun (posts)
    puts(posts)
end).catch(fun (err)
    puts(err)
end)
```

**Rejected**: Less readable than async/await, more verbose.

### 3. Green Threads (Go-style)

```quest
# Not chosen - implicit concurrency
go fetch_user(123)  # Spawns goroutine
```

**Rejected**: Implicit concurrency is hard to reason about, async/await is more explicit.

### 4. CSP Channels Only (No async/await)

```quest
# Not chosen - channels without async/await
let task = spawn(fun () fetch_user(123) end)
let result = <-task  # Channel receive syntax
```

**Rejected**: Less familiar to most developers, async/await is widely adopted.

## Open Questions

1. **REPL async mode**: Should REPL automatically wrap expressions in `block_on`?
2. **Task cancellation**: Should dropped tasks be auto-cancelled or detached?
3. **Syntax**: Use `async fun` or `fun async`? (Proposed: `async fun` to match Python/Rust)
4. **Module organization**: Should channels be in `std/async` or separate `std/sync` module?
5. **Task local storage**: Do we need task-local variables (like thread-local)?
6. **Structured concurrency**: Should we enforce task scoping (nurseries/scopes)?
7. **Async iteration**: Syntax for async iterators/streams?

## Future Enhancements

### Async Streams

```quest
use "std/async"

async fun read_lines_async(file)
    let stream = async.stream(fun ()
        let line = await file.readline()
        if line == ""
            nil  # End of stream
        else
            line
        end
    end)

    stream
end

# Usage
async fun process_file()
    let stream = await read_lines_async("large.txt")
    while true
        let line = await stream.next()
        if line == nil
            break
        end
        process(line)
    end
end
```

### Async Context Managers

```quest
async type AsyncFile
    str: path

    static async fun open(path)
        let file = await open_file_async(path)
        AsyncFile.new(path: path, handle: file)
    end

    async fun _enter()
        self
    end

    async fun _exit()
        await self.close()
    end

    async fun read()
        await read_async(self.handle)
    end
end

# Usage
async with AsyncFile.open("test.txt") as file
    let content = await file.read()
    puts(content)
end
```

### Async Trait Methods

```quest
trait AsyncRepository
    async fun save(entity)
    async fun find(id)
    async fun delete(id)
end

type UserRepository
    impl AsyncRepository
        async fun save(user)
            await db.execute("INSERT INTO users ...", [user])
        end

        async fun find(id)
            await db.fetch_one("SELECT * FROM users WHERE id = $1", [id])
        end

        async fun delete(id)
            await db.execute("DELETE FROM users WHERE id = $1", [id])
        end
    end
end
```

## References

- Tokio documentation: https://tokio.rs/
- Rust async book: https://rust-lang.github.io/async-book/
- Python asyncio: https://docs.python.org/3/library/asyncio.html
- JavaScript async/await: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/async_function
- Go goroutines: https://go.dev/tour/concurrency
- Structured concurrency: https://vorpus.org/blog/notes-on-structured-concurrency-or-go-statement-considered-harmful/

## Related QEPs

- **QEP-012**: Process Module - Could benefit from async process spawning
- **QEP-013**: File Objects - Should have async variants
- **QEP-001**: Database Module - Should support async queries
- **QEP-HTTP**: HTTP Client - Should use async I/O

## Conclusion

Adding async/await and Tokio-based task management to Quest enables:
- **Concurrent programming** with familiar syntax
- **Non-blocking I/O** for better performance
- **Scalable applications** handling many connections
- **Integration** with Rust's async ecosystem

The design prioritizes:
- **Familiarity**: Python/JavaScript-style async/await
- **Safety**: Explicit async contexts, clear error handling
- **Performance**: Tokio's efficient runtime
- **Ergonomics**: Simple for common cases, powerful for advanced

This QEP provides the foundation for Quest to become a viable choice for I/O-intensive applications, web services, and concurrent systems programming.
