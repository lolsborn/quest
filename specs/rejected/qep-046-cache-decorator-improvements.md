# QEP-046: Cache Decorator Improvements

**Status**: Draft
**Created**: 2025-10-08
**Related**: QEP-003 (Decorators)

## Summary

Improve the `Cache` decorator in `lib/std/decorators.q` with better eviction policies (LRU instead of FIFO), configurable size limits, and additional cache management features.

## Motivation

The current `Cache` decorator uses FIFO (First-In-First-Out) eviction, which is simple but inefficient. When the cache reaches `max_size`, it removes the oldest entry regardless of access patterns. This can evict frequently-used values while keeping rarely-used ones.

**Problems with current FIFO approach**:
- Poor cache hit rates for workloads with hot/cold data
- No consideration of access frequency or recency
- Suboptimal performance for typical caching scenarios

**Example of inefficiency**:
```quest
@Cache(max_size: 3)
fun expensive(id)
    # Expensive operation
end

expensive(1)  # Cache: [1]
expensive(2)  # Cache: [1, 2]
expensive(3)  # Cache: [1, 2, 3]
expensive(1)  # Hit - still in cache
expensive(4)  # Cache: [2, 3, 4] - evicts 1 (oldest), even though we just used it!
expensive(1)  # Miss - need to recompute
```

With LRU, entry `1` would have been moved to the "most recent" position when accessed, and entry `2` would have been evicted instead.

## Proposed Changes

### 1. LRU Eviction Policy

Replace FIFO with LRU (Least Recently Used) eviction:

**Implementation approach**:
- Track both insertion order AND access order
- When cache is full, evict the least recently accessed entry
- Update access timestamp/order on cache hits

**Data structures**:
```quest
type Cache
    max_size: Int
    ttl: Int?
    cache: Dict       # Key -> {value, inserted_at, accessed_at}
    access_order: Array  # Keys in LRU order (most recent at end)

    fun _call(*args, **kwargs)
        let key = self._make_key(args, kwargs)

        if self.cache.contains(key)
            let entry = self.cache[key]

            # Check TTL
            if self.ttl != nil and (time.time() - entry["inserted_at"]) > self.ttl
                self.cache.remove(key)
                self.access_order = self.access_order.filter(fun (k) k != key end)
            else
                # Update access order (move to end)
                self.access_order = self.access_order.filter(fun (k) k != key end)
                self.access_order.push(key)
                entry["accessed_at"] = time.time()
                return entry["value"]
            end
        end

        # Cache miss
        let result = self.func(*args, **kwargs)

        # Evict LRU if at capacity
        if self.cache.len() >= self.max_size
            let lru_key = self.access_order[0]  # Least recently used
            self.cache.remove(lru_key)
            self.access_order = self.access_order.slice(1, nil)
        end

        # Add to cache
        self.cache[key] = {
            value: result,
            inserted_at: time.time(),
            accessed_at: time.time()
        }
        self.access_order.push(key)

        return result
    end
end
```

### 2. Configurable Eviction Policies

Allow users to choose eviction strategy:

```quest
@Cache(max_size: 100, policy: "lru")     # Least Recently Used (default)
@Cache(max_size: 100, policy: "fifo")    # First In First Out (current behavior)
@Cache(max_size: 100, policy: "lfu")     # Least Frequently Used
fun cached_function(x)
    # ...
end
```

**Policy comparison**:
- **LRU**: Evict least recently accessed (best for temporal locality)
- **FIFO**: Evict oldest entry (simplest, but least effective)
- **LFU**: Evict least frequently accessed (best for frequency-based access)

### 3. Size Control Options

Provide multiple ways to limit cache size:

```quest
# By number of entries (current)
@Cache(max_size: 1000)

# By memory size (bytes) - future enhancement
@Cache(max_bytes: 10_485_760)  # 10 MB

# By TTL only (no size limit)
@Cache(ttl: 300)  # 5 minutes

# Unlimited cache with TTL
@Cache(ttl: 600)  # No max_size, only time-based eviction
```

### 4. Cache Statistics and Management

Add methods for introspection and management:

```quest
@Cache(max_size: 100)
fun expensive(x)
    x * 2
end

# Access cache statistics
expensive.cache_stats()
# Returns: {
#   hits: 150,
#   misses: 50,
#   hit_rate: 0.75,
#   size: 100,
#   evictions: 10
# }

# Clear cache manually
expensive.cache_clear()

# Get cache info
expensive.cache_info()
# Returns: {
#   max_size: 100,
#   ttl: nil,
#   policy: "lru",
#   current_size: 45
# }

# Preload cache
expensive.cache_set(key: 10, value: 20)
```

### 5. Thread-Safety Considerations

For future concurrency support (QEP-027), cache operations need to be atomic:

```quest
# Potential approach with locks (future)
type Cache
    lock: Lock  # Protects cache and access_order

    fun _call(*args, **kwargs)
        with self.lock.acquire() as guard
            # All cache operations here
        end
    end
end
```

## Implementation Phases

### Phase 1: LRU Implementation (Immediate)
- Replace FIFO with LRU eviction
- Maintain backwards compatibility (same API)
- Add basic cache statistics (hits/misses)

### Phase 2: Policy Selection (Near-term)
- Add `policy` parameter: "lru", "fifo", "lfu"
- Implement LFU eviction strategy
- Add `cache_stats()`, `cache_clear()`, `cache_info()` methods

### Phase 3: Advanced Features (Future)
- Memory-based size limits (`max_bytes`)
- Cache preloading (`cache_set()`)
- Conditional caching (predicate functions)
- Persistent caching (disk-backed)

## Pitfalls and Challenges

### 1. Performance Overhead

**Problem**: Maintaining access order adds overhead to every cache hit.

**Mitigations**:
- Use efficient data structures (Dict for O(1) lookup, Array for order)
- Consider approximate LRU for very large caches
- Benchmark against FIFO to quantify overhead

### 2. Memory Usage

**Problem**: Tracking access metadata increases memory per entry.

**Current**: `{key: value}`
**Proposed**: `{key: {value, inserted_at, accessed_at, access_count}}`

**Mitigations**:
- Make metadata optional based on policy
- FIFO only needs insertion order (minimal overhead)
- LRU needs access order (moderate overhead)
- LFU needs access counts (moderate overhead)

### 3. Complex Key Generation

**Problem**: Function arguments must be hashable for cache keys.

**Current approach** (from QEP-003):
```quest
fun _make_key(args, kwargs)
    # Serialize args and kwargs into a string key
    let key = args.map(fun (x) x.str() end).join(",")
    if kwargs.len() > 0
        key = key .. "|" .. kwargs.str()
    end
    return key
end
```

**Issues**:
- Not all types have stable `str()` representations
- Mutable objects (Arrays, Dicts) can cause cache invalidation bugs
- Collisions possible with naive string concatenation

**Improvements**:
- Use `_id()` for unhashable types (object identity)
- Implement proper hashing function
- Document limitations (mutable args may break cache)

### 4. TTL Precision

**Problem**: TTL eviction happens lazily (on access), not proactively.

**Current**: Expired entries stay in cache until accessed, wasting memory.

**Options**:
1. **Lazy eviction** (current): Check TTL on access only (simple, some waste)
2. **Periodic cleanup**: Background task to prune expired entries (complex, requires timers)
3. **Probabilistic eviction**: Random sampling of entries on access (Python's cachetools approach)

**Recommendation**: Start with lazy eviction, document behavior, add periodic cleanup in Phase 3.

### 5. Decorator Stacking

**Problem**: Multiple decorators may interact unexpectedly.

```quest
@Timing
@Cache(max_size: 100)
fun expensive(x)
    # Which timing gets measured? Cached calls or actual execution?
end
```

**Answer**: Decorators apply bottom-to-top, so `Cache` wraps the function first, then `Timing` wraps the cached version. Timing measures cache hits (fast) and misses (slow).

**Consideration**: Document this behavior clearly.

## Size Control Options

### Option 1: Entry Count (Current)
```quest
@Cache(max_size: 1000)  # Maximum 1000 entries
```

**Pros**: Simple, predictable
**Cons**: Memory usage varies by value size
**Use case**: Uniform value sizes, simple caching needs

### Option 2: Memory Size
```quest
@Cache(max_bytes: 10_485_760)  # 10 MB limit
```

**Pros**: Predictable memory usage
**Cons**: Requires size estimation for values (complex)
**Use case**: Memory-constrained environments
**Implementation**: Use `sys.get_size(value)` (if available) to estimate bytes

### Option 3: TTL Only
```quest
@Cache(ttl: 300)  # 5 minutes, no size limit
```

**Pros**: Simple time-based invalidation
**Cons**: Unbounded memory growth
**Use case**: Short-lived processes, known access patterns

### Option 4: Hybrid
```quest
@Cache(max_size: 1000, max_bytes: 10_485_760, ttl: 300)
# Evict when ANY limit is reached
```

**Pros**: Maximum flexibility
**Cons**: Most complex to implement
**Use case**: Production systems with strict resource limits

## Alternatives Considered

### 1. External Caching Libraries

**Option**: Use Redis or Memcached for caching instead of in-process cache.

**Pros**:
- Battle-tested eviction policies
- Distributed caching across processes
- Persistence

**Cons**:
- External dependencies
- Network overhead on every access
- Complexity for simple use cases

**Decision**: Keep in-process caching for simplicity, consider external caching as separate feature.

### 2. Approximate LRU

**Option**: Use probabilistic data structures (e.g., Clock algorithm) for faster LRU approximation.

**Pros**:
- Lower overhead than true LRU
- Still much better than FIFO

**Cons**:
- More complex implementation
- Non-deterministic eviction

**Decision**: Start with true LRU, consider approximate LRU if profiling shows bottlenecks.

### 3. Adaptive Policies

**Option**: Automatically switch policies based on access patterns (ARC cache).

**Pros**:
- Best of all worlds
- No tuning required

**Cons**:
- Very complex implementation
- Hard to reason about behavior

**Decision**: Too complex for MVP, consider for future research.

## Backwards Compatibility

**Breaking changes**: None (new parameters are optional)

**Migration path**:
- Current `@Cache(max_size: 100)` continues to work
- Default policy changes from FIFO to LRU (better behavior, but technically breaking)
- Add `policy: "fifo"` to preserve exact old behavior if needed

**Recommendation**: Accept the FIFO→LRU change as a bug fix, document in changelog.

## Testing Strategy

```quest
# Test LRU eviction order
test.it("evicts least recently used entry", fun ()
    @Cache(max_size: 3)
    fun f(x) x * 2 end

    f(1)  # Cache: [1]
    f(2)  # Cache: [1, 2]
    f(3)  # Cache: [1, 2, 3]
    f(1)  # Hit, cache: [2, 3, 1] (1 moved to end)
    f(4)  # Evicts 2 (LRU), cache: [3, 1, 4]

    # Verify 2 was evicted (would need cache inspection API)
    let stats = f.cache_stats()
    test.assert_eq(stats["size"], 3)
end)

# Test policy selection
test.it("respects FIFO policy", fun ()
    @Cache(max_size: 3, policy: "fifo")
    fun f(x) x * 2 end

    f(1)
    f(2)
    f(3)
    f(1)  # Hit
    f(4)  # Evicts 1 (oldest) even though we just accessed it

    # Verify FIFO behavior
end)

# Test TTL interaction with eviction
test.it("prioritizes TTL over LRU", fun ()
    @Cache(max_size: 2, ttl: 1)
    fun f(x) x * 2 end

    f(1)
    time.sleep(1.1)  # Entry 1 expires
    f(2)
    f(3)  # Should evict expired 1, not fresh 2
end)
```

## Performance Expectations

**Benchmarks** (estimated):
- FIFO eviction: O(1) insertion, O(1) eviction
- LRU eviction: O(1) insertion, O(n) eviction (array filter/push)
- LFU eviction: O(1) insertion, O(n) eviction (find min frequency)

**Optimization**: Replace Array-based access order with linked list for O(1) LRU updates (future enhancement).

**Cache hit speedup**: 10-100x for expensive functions (typical)
**LRU overhead**: ~5-10% slower than FIFO (acceptable tradeoff)

## Documentation Updates

- Update `lib/std/decorators.q` docstrings with policy options
- Add examples for each eviction policy
- Document cache management methods (`cache_stats()`, etc.)
- Add performance guidelines (when to use which policy)
- Update `docs/docs/stdlib/decorators.md` in Docusaurus

## Future Enhancements

1. **Persistent caching**: Save cache to disk between runs
2. **Distributed caching**: Share cache across processes (IPC/Redis)
3. **Conditional caching**: `@Cache(condition: fun (result) result != nil end)`
4. **Partial key caching**: Cache based on subset of arguments
5. **Cache warming**: Preload cache with common values
6. **Cache invalidation**: Manual or pattern-based invalidation
7. **Compression**: Compress large cached values to save memory

## References

- QEP-003: Function Decorators
- Python functools.lru_cache: https://docs.python.org/3/library/functools.html#functools.lru_cache
- Cachetools (Python): https://github.com/tkem/cachetools
- ARC Cache paper: https://www.usenix.org/legacy/event/fast03/tech/full_papers/megiddo/megiddo.pdf

## Decision

**Status**: Draft - awaiting review

**Next steps**:
1. Review LRU implementation approach
2. Decide on default policy (LRU vs. FIFO)
3. Prioritize Phase 1 features
4. Implement and benchmark
