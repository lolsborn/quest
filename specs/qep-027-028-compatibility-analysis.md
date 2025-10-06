# QEP-027 & QEP-028 Compatibility Analysis

**Date**: 2025-10-05
**Evaluated By**: Claude Code

## Executive Summary

**Compatibility Score: 9/10** - Highly compatible with strong synergy

Both QEPs complement each other well and share common infrastructure (Tokio), but can be implemented independently. QEP-028 delivers immediate value (web server), while QEP-027 provides long-term architectural foundation (async runtime).

**Recommended Priority: QEP-028 first, then QEP-027**

## Individual Analysis

### QEP-027: Async Tasks

**Scope**: Language-level async/await support
**Complexity**: ★★★★★ (Very High)
**Value**: ★★★★☆ (High - enables concurrent I/O everywhere)
**Effort**: ~3-4 weeks full-time

**Pros:**
- ✅ Enables truly concurrent I/O operations
- ✅ Leverages Rust's mature async ecosystem (Tokio)
- ✅ Familiar syntax (Python/JS async/await)
- ✅ Future-proof architecture
- ✅ Enables async database queries, HTTP requests, file I/O

**Cons:**
- ❌ Major language change (grammar, evaluator, runtime)
- ❌ Complex implementation (lifetime management, async evaluation)
- ❌ Breaking change for existing modules (need async variants)
- ❌ REPL integration challenges
- ❌ Steep learning curve for Quest users

**Implementation Challenges:**
1. Async function evaluation requires `async fn eval_async()`
2. Pest parser is synchronous (lifetime constraints)
3. Need to manage tokio runtime lifecycle
4. Backward compatibility (sync functions still need to work)
5. Error propagation through async boundaries

---

### QEP-028: Serve Command

**Scope**: Web server via `quest serve` command
**Complexity**: ★★★☆☆ (Medium)
**Value**: ★★★★★ (Very High - immediate practical use)
**Effort**: ~1-2 weeks full-time

**Pros:**
- ✅ Immediate practical value (build web apps in Quest)
- ✅ No language changes (uses existing Quest)
- ✅ Proven architecture (axum + thread pool)
- ✅ Works with existing modules (templates, db, HTTP)
- ✅ Simple mental model (request → dict → response)
- ✅ Includes WebSocket support
- ✅ Production-ready features (timeouts, error handling)

**Cons:**
- ⚠️ Synchronous handlers (blocking I/O in thread pool)
- ⚠️ Limited concurrency (one connection per thread)
- ⚠️ Database connection inefficiency (Phase 1)
- ⚠️ Can't fully leverage async Rust libraries

**Implementation Challenges:**
1. Thread-local scope management
2. Request/response dict conversion
3. Error handling across Rust/Quest boundary
4. WebSocket lifecycle management
5. Connection pooling (Phase 2)

---

## Compatibility Matrix

| Aspect | Compatible? | Notes |
|--------|-------------|-------|
| **Dependencies** | ✅ Yes | Both use Tokio, no conflicts |
| **Architecture** | ✅ Yes | QEP-027 enhances QEP-028 |
| **Grammar Changes** | ✅ Independent | QEP-027 adds syntax, QEP-028 none |
| **Runtime** | ✅ Compatible | QEP-028 uses tokio, QEP-027 formalizes it |
| **Modules** | ✅ Complementary | QEP-027 enables async modules for QEP-028 |
| **User Code** | ✅ Compatible | QEP-028 works with sync, QEP-027 adds async |

## Synergy Analysis

### How They Work Together

**Without QEP-027 (QEP-028 only):**
```quest
# Synchronous handler - blocks thread
fun handle_request(request)
    let user = db.fetch_one("SELECT ...")  # Blocks thread
    let posts = db.fetch_all("SELECT ...")  # Sequential, blocks
    {"status": 200, "json": {"user": user, "posts": posts}}
end
# Throughput limited by blocking I/O
```

**With Both (QEP-028 + QEP-027):**
```quest
# Async handler - doesn't block threads
async fun handle_request(request)
    # Run queries concurrently
    let user_task = async.spawn(fun ()
        await db.fetch_one("SELECT ...")
    end)
    let posts_task = async.spawn(fun ()
        await db.fetch_all("SELECT ...")
    end)

    let results = await async.join_all([user_task, posts_task])
    {"status": 200, "json": {"user": results[0], "posts": results[1]}}
end
# 2x faster response time, better throughput
```

### Combined Benefits

1. **Better Performance**: Async I/O eliminates thread blocking
2. **Higher Concurrency**: More requests per thread (1000s vs 10s)
3. **Lower Latency**: Parallel database queries, HTTP requests
4. **Scalability**: Not limited by thread pool size
5. **WebSocket Enhancement**: Background tasks for push notifications

### Independence

**QEP-028 can work without QEP-027:**
- ✅ Synchronous handlers in async server (spawn_blocking)
- ✅ Thread pool absorbs blocking I/O
- ✅ Good enough for many use cases (< 1000 req/s)

**QEP-027 can work without QEP-028:**
- ✅ Useful for concurrent scripts, background jobs
- ✅ Async database queries, HTTP client
- ✅ Command-line tools with concurrent operations

---

## Implementation Priority Ranking

### Option A: QEP-028 First (RECOMMENDED)

**Rationale:**
1. **Immediate value** - Web server useful right now
2. **Simpler** - No language changes required
3. **Proof of concept** - Validates Quest for web development
4. **Foundation** - Creates demand for async support
5. **Incremental** - Can add QEP-027 later for performance

**Timeline:**
- Week 1-2: QEP-028 Phase 1 (basic server)
- Week 3-6: QEP-027 (async runtime)
- Week 7-8: QEP-028 Phase 2 (async handlers, connection pooling)

**Pros:**
- ✅ Delivers working web server quickly
- ✅ Users can build apps immediately
- ✅ Less risk (smaller scope initially)
- ✅ Natural progression (sync → async)

**Cons:**
- ⚠️ Performance limitations initially
- ⚠️ May need to refactor handlers later

---

### Option B: QEP-027 First

**Rationale:**
1. **Foundation first** - Async runtime enables everything else
2. **No rework** - QEP-028 built async from start
3. **Better architecture** - Avoid sync-to-async migration
4. **More powerful** - Full async capabilities everywhere

**Timeline:**
- Week 1-4: QEP-027 (async runtime)
- Week 5-6: QEP-028 with async support
- Week 7-8: Polish and examples

**Pros:**
- ✅ Better final architecture
- ✅ No migration pain later
- ✅ Full async power from day one

**Cons:**
- ❌ Delayed practical value (no web server for 4 weeks)
- ❌ Higher risk (complex feature first)
- ❌ Longer before users can build apps

---

### Option C: Parallel Development

**Rationale:**
Implement both simultaneously with coordination

**Pros:**
- ✅ Fastest to complete
- ✅ Can design for compatibility upfront

**Cons:**
- ❌ Resource intensive
- ❌ Coordination overhead
- ❌ Risk of conflicts

---

## Recommended: Phased Approach (Option A)

### Phase 1: Web Server (QEP-028 Minimal) - 1-2 weeks

**Deliverables:**
- ✅ `quest serve` command
- ✅ Synchronous `handle_request()` function
- ✅ Request/response dict conversion
- ✅ Basic examples (hello, templates, API)
- ✅ Thread-pool based concurrency
- ❌ No async handlers yet
- ❌ One DB connection per thread

**Value**: Users can build web apps immediately

---

### Phase 2: Async Runtime (QEP-027 Core) - 3-4 weeks

**Deliverables:**
- ✅ Tokio runtime integration
- ✅ `async fun` / `await` syntax
- ✅ `std/async` module (spawn, sleep, timeout)
- ✅ Channels for communication
- ✅ join_all, race, select
- ❌ No async modules yet (db, http, etc.)

**Value**: Foundation for async I/O everywhere

---

### Phase 3: Async Integration (QEP-027 + QEP-028) - 2-3 weeks

**Deliverables:**
- ✅ Async database modules (db/postgres, db/mysql, db/sqlite)
- ✅ Async HTTP client
- ✅ Async file I/O
- ✅ `async fun handle_request()` support in QEP-028
- ✅ Connection pooling for databases
- ✅ WebSocket background tasks

**Value**: Full async web server with optimal performance

---

### Phase 4: Advanced Features - Ongoing

**Deliverables:**
- ✅ Async streams/iterators
- ✅ Structured concurrency
- ✅ Advanced WebSocket features
- ✅ SSE (Server-Sent Events)
- ✅ HTTP/2 support

---

## Compatibility Score Breakdown

| Criterion | Score | Notes |
|-----------|-------|-------|
| **Technical Compatibility** | 10/10 | Perfect - both use Tokio |
| **API Compatibility** | 9/10 | Async handlers enhance sync handlers |
| **Code Reuse** | 8/10 | Shared runtime, separate features |
| **User Experience** | 9/10 | Natural progression sync → async |
| **Maintenance** | 9/10 | Independent but complementary |
| **Architecture Alignment** | 10/10 | Both embrace Rust's async ecosystem |

**Overall Compatibility: 9.2/10** - Excellent alignment

---

## Risk Assessment

### Low Risk (QEP-028 First)
- ✅ Proven pattern (sync handlers in async server)
- ✅ Smaller scope
- ✅ No language changes
- ✅ Easy to test and debug

### Medium Risk (QEP-027 First)
- ⚠️ Complex async evaluation
- ⚠️ Lifetime management challenges
- ⚠️ Backward compatibility concerns
- ⚠️ Requires extensive testing

### Combined Risk (Both Together)
- ⚠️ Coordination overhead
- ⚠️ Unclear which issues belong where
- ⚠️ Harder to isolate bugs

---

## Effort Estimates

### QEP-028 Only (Phase 1)
- **Core server**: 40 hours
- **WebSocket**: 16 hours
- **Examples**: 8 hours
- **Documentation**: 8 hours
- **Testing**: 8 hours
- **Total**: ~80 hours (2 weeks)

### QEP-027 Core
- **Runtime integration**: 40 hours
- **Grammar changes**: 24 hours
- **Async evaluation**: 60 hours
- **std/async module**: 32 hours
- **Testing**: 24 hours
- **Documentation**: 16 hours
- **Total**: ~196 hours (5 weeks)

### Combined (Async + Serve)
- **QEP-028 Phase 1**: 80 hours
- **QEP-027 Core**: 196 hours
- **Integration**: 40 hours
- **Connection pooling**: 16 hours
- **Async modules**: 40 hours
- **Total**: ~372 hours (9-10 weeks)

---

## Decision Matrix

| Criterion | QEP-028 First | QEP-027 First | Both Parallel |
|-----------|---------------|---------------|---------------|
| Time to Value | ★★★★★ | ★★☆☆☆ | ★★★★☆ |
| Final Quality | ★★★★☆ | ★★★★★ | ★★★★★ |
| Risk | ★★★★★ | ★★★☆☆ | ★★☆☆☆ |
| Ease | ★★★★★ | ★★☆☆☆ | ★★★☆☆ |
| User Adoption | ★★★★★ | ★★★☆☆ | ★★★★☆ |

**Winner: QEP-028 First** (3 categories won)

---

## Recommended Combined Plan

### Sprint 1-2: QEP-028 Foundation (2 weeks)
**Goal**: Working web server

1. Add axum dependency
2. Implement `quest serve` command
3. Thread-local scope architecture
4. Request/response dict conversion
5. Basic routing examples
6. HTML template integration
7. Database examples (one conn per thread)

**Deliverable**: `quest serve app.q` works

---

### Sprint 3: QEP-028 WebSocket (1 week)
**Goal**: Real-time communication

1. WebSocket upgrade handling
2. Lifecycle functions (connect, message, close)
3. Broadcasting support
4. Chat example

**Deliverable**: WebSocket chat app works

---

### Sprint 4-7: QEP-027 Core Runtime (4 weeks)
**Goal**: Async foundation

1. Tokio runtime integration (embedded in Quest)
2. Grammar: `async fun`, `await` keywords
3. Async evaluation strategy
4. `std/async` module: spawn, sleep, timeout
5. Task and Channel types
6. join_all, race, select primitives

**Deliverable**: Async scripts work standalone

---

### Sprint 8-9: Integration (2 weeks)
**Goal**: Async everywhere

1. Async database modules (db/postgres, db/mysql, db/sqlite)
2. Connection pooling (deadpool)
3. Async HTTP client
4. `async fun handle_request()` support in QEP-028
5. Async file I/O
6. WebSocket background tasks

**Deliverable**: Full-async web server

---

### Sprint 10: Polish & Performance (1 week)
**Goal**: Production ready

1. Benchmarking
2. Performance tuning
3. Documentation updates
4. Migration guide
5. Real-world examples

**Deliverable**: Production-ready async web framework

---

## Alternative: Minimal Viable Approach

If resources are limited, implement **QEP-028 only** (without QEP-027):

**Benefits:**
- ✅ 2 weeks instead of 10 weeks
- ✅ Usable web server immediately
- ✅ Good enough for most apps (< 1K req/s)
- ✅ Can add QEP-027 later if needed

**Limitations:**
- ⚠️ Blocking I/O (handlers block threads)
- ⚠️ Lower throughput (thread-limited concurrency)
- ⚠️ Sequential database queries
- ⚠️ Can't do background tasks in WebSocket

**Who this serves:**
- Small web apps (< 1000 req/s)
- Internal tools and dashboards
- Prototypes and MVPs
- Most Quest users (pragmatic choice)

---

## Technical Compatibility Details

### Shared Infrastructure

Both QEPs use:
- **Tokio**: Async runtime (already in deps for HTTP client)
- **Thread pools**: Worker threads for handling load
- **HTTP stack**: hyper/axum for HTTP protocol

### Integration Points

**QEP-028 references QEP-027:**
- Line 1338: "Should we support async/await?" → Yes, via QEP-027
- Line 955-990: Dashboard example needs background tasks → QEP-027
- Line 1226-1319: Phase 2 could use async connection pooling → QEP-027

**QEP-027 enables QEP-028:**
- Example 7 (line 629-663): Web server example → Implemented by QEP-028
- Async database queries → Makes QEP-028 handlers faster
- Background tasks → Enables WebSocket push notifications

### No Conflicts

- ✅ No overlapping code areas
- ✅ Grammar changes are additive (QEP-027 only)
- ✅ Can be developed independently
- ✅ Can be merged without conflicts

---

## User Impact

### QEP-028 Alone (Sync Server)
```quest
# Users write simple synchronous handlers
use "std/db/sqlite" as db

let conn = db.connect("app.db")

fun handle_request(request)
    let users = conn.cursor().execute("SELECT * FROM users").fetch_all()
    {"status": 200, "json": users}
end
```

**Experience**: Simple, blocking, works well for low/medium traffic

---

### QEP-028 + QEP-027 (Async Server)
```quest
# Users can write async handlers for better performance
use "std/db/sqlite" as db

let pool = db.create_pool("app.db", {"max_connections": 20})

async fun handle_request(request)
    # Fetch user and posts concurrently (2x faster)
    let user = async.spawn(fun () await pool.query("SELECT * FROM users WHERE id = $1", [id]) end)
    let posts = async.spawn(fun () await pool.query("SELECT * FROM posts WHERE user_id = $1", [id]) end)

    let results = await async.join_all([user, posts])
    {"status": 200, "json": {"user": results[0], "posts": results[1]}}
end
```

**Experience**: More complex, non-blocking, scales to high traffic

---

## Recommendation: Staged Implementation

### Stage 1: Prove Value (QEP-028 Only)
**Duration**: 2-3 weeks
**Goal**: Demonstrate Quest as web framework

Deploy QEP-028 in synchronous mode. If users love it and need better performance, move to Stage 2.

**Success Metrics:**
- 3+ real applications built with Quest
- Positive user feedback
- Performance acceptable for target use cases

---

### Stage 2: Scale Performance (Add QEP-027)
**Duration**: 4-5 weeks
**Goal**: Enable high-performance async

If Stage 1 succeeds and users need:
- Higher throughput (> 1K req/s)
- Concurrent database queries
- Background tasks
- WebSocket push notifications

Then implement QEP-027 and integrate with QEP-028.

---

### Stage 3: Ecosystem (Async Everywhere)
**Duration**: Ongoing
**Goal**: Full async ecosystem

- Async versions of all I/O modules
- Async iterators/streams
- Advanced concurrency primitives
- Async context managers

---

## Conclusion

**Compatibility**: 9/10 - Excellent synergy, no conflicts

**Recommended Path**:
1. ✅ **QEP-028 first** (2-3 weeks) - Immediate value
2. ⏸️ **Validate with users** - Is performance adequate?
3. ✅ **QEP-027 if needed** (4-5 weeks) - Scale performance
4. ✅ **Integration** (2-3 weeks) - Async server

**Total Time**: 2-3 weeks (minimal) to 8-11 weeks (full async)

**Key Decision Point**: After QEP-028 ships, gather user feedback. If sync handlers meet 80% of use cases, delay QEP-027. If users demand higher performance, prioritize QEP-027.

**Why QEP-028 first wins:**
- Immediate practical value (build apps now)
- Lower risk (smaller scope)
- Validates Quest for web development
- Creates demand for async (data-driven decision)
- Can always add QEP-027 later if needed

This is the pragmatic, user-focused approach that delivers value incrementally while preserving the option to add full async support when justified by real-world needs.
