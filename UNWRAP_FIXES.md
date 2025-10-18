# Unwrap Error Handling Fixes

## Summary
Fixed all unsafe `.unwrap()` calls in the server module with proper error handling. This improves reliability and prevents panics in production environments.

## Changes Made

### 1. Error Response Helper (src/server.rs:27-39)
**Issue**: `error_response()` could panic if response body building failed
**Fix**: Added `.unwrap_or_else()` with fallback error response
```rust
// Before: .unwrap()
// After:
.unwrap_or_else(|e| {
    eprintln!("Failed to build error response: {}", e);
    // Returns fallback 500 error response
})
```

### 2. WebSocketRegistry Lock Handling (lines 154-198)
**Issue**: RwLock poison errors would cause panics in 3 methods
**Fix**: Added poison error recovery using `.into_inner()`
- `register()` - lines 155-160
- `unregister()` - lines 172-177
- `broadcast()` - lines 186-191

```rust
// Before: let mut conns = self.connections.write().unwrap();
// After:
let mut conns = match self.connections.write() {
    Ok(guard) => guard,
    Err(poison) => {
        eprintln!("Warning: WebSocket registry lock was poisoned, recovering");
        poison.into_inner()
    }
};
```

### 3. Redirect Response Building (src/server.rs:600-606)
**Issue**: Response body building could panic
**Fix**: Added proper error handling with fallback response
```rust
// Before: return response.body(Body::empty()).unwrap();
// After:
match response.body(Body::empty()) {
    Ok(resp) => return resp,
    Err(e) => {
        eprintln!("Failed to build redirect response: {}", e);
        return (StatusCode::INTERNAL_SERVER_ERROR, "Redirect error").into_response();
    }
}
```

### 4. JSON Serialization Fallbacks (lines 1367-1368, 1382-1383)
**Issue**: `serde_json::to_string()` could theoretically fail
**Fix**: Added `.unwrap_or_else()` with manual JSON encoding fallback
```rust
// Before: .unwrap()
// After:
.unwrap_or_else(|_| format!("\"{}\"", s.value.escape_default()))
```

## Cleanup

### Unused Imports Removed
- **src/modules/web.rs**: Removed unused `QString` and `QInt` imports
- **src/commands.rs**: Removed unused imports:
  - `std::time::Duration`
  - `notify::{Watcher, RecursiveMode, Event, EventKind}`
  - `crate::server::{start_server, start_server_with_shutdown}`

### Dead Code Marked
Added `#[allow(dead_code)]` with documentation to functions from old architecture:
- `src/commands.rs:382` - `load_quest_web_config()` (deprecated in favor of QEP-060)
- `src/commands.rs:421` - `load_web_config_from_toml()` (deprecated in favor of QEP-060)
- `src/server.rs:259` - `start_server()` (kept for backward compatibility)

## Impact

### Reliability
- ✅ Eliminates panic risk in error paths
- ✅ Enables graceful error recovery for RwLock poisoning
- ✅ Returns meaningful error responses instead of crashing

### Code Quality
- ✅ Removes all compiler warnings
- ✅ Cleans up unused imports
- ✅ Documents deprecated functions

### Testing
- ✅ No breaking changes to public API
- ✅ All existing tests pass
- ✅ Code compiles without warnings

## Build Status
```
✅ Compiles successfully (release mode)
✅ No compiler warnings
✅ No unsafe unwrap() calls remain
```

## Verification
```bash
# Check for remaining unwrap() calls
grep -n "\.unwrap()" src/server.rs  # Returns 0 results

# Build verification
cargo build --release  # Completes without warnings
```

## Notes

1. **JSON Serialization**: The remaining `unwrap_or_else()` calls in JSON serialization are extremely low-risk since `serde_json::to_string()` virtually never fails for strings. However, they've been made safe anyway for completeness.

2. **RwLock Poison Recovery**: The pattern `poison.into_inner()` allows us to recover from thread panics and continue serving requests. This is appropriate for a web server where availability is more important than poisoned thread detection.

3. **Error Logging**: All error conditions are logged to stderr with context, making it easier to debug issues in production.

---

**Status**: ✅ Complete and ready for review/merge
