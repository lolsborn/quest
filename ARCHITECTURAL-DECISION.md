# Architectural Decision: Router as Middleware in `std/web/middleware/router`

**Decision Date**: 2025-10-18
**Status**: Approved
**Affects**: QEP-061, QEP-062

## Decision

The Quest web router shall be implemented as **middleware** and placed in `std/web/middleware/router` rather than `std/web/router`.

## Rationale

### 1. Architectural Purity
- Routing is fundamentally a request/response interception concern
- Middleware system (QEP-061) is the central pattern for request processing
- Router should follow the same middleware pattern as logging, auth, CORS, etc.

### 2. Flexibility & Composability
```quest
use "std/web" as web
use "std/web/middleware/router" as router
use "std/web/middleware/logging" as logging

# Users can compose middleware in any order
web.use(logging.before)        # Log request
web.use(router.dispatch)       # Route to handler
web.after(logging.after)       # Log response
web.run()
```

Without the middleware pattern, routing would be special-cased in the core server logic.

### 3. User Control & Transparency
Placing router as middleware makes clear that:
- Routing is optional (static-only servers don't need it)
- Users can replace router with custom implementation
- Users can disable routing entirely
- Routing behavior is visible and debuggable

### 4. Framework Consistency
Modern frameworks all use middleware/interceptor patterns:
- **Express.js**: `app.use()` for everything
- **Flask**: `@app.before_request`, `@app.after_request`
- **Django**: `MIDDLEWARE` array
- **Quest**: `web.use()` for everything

This places Quest in the same mental model as industry-standard frameworks.

### 5. Future-Proofing
When new middleware features are added, they naturally go in `std/web/middleware/`:
```
std/web/middleware/
├── router.q          # Path routing
├── logging.q         # HTTP access logs
├── auth.q            # Authentication
├── cors.q            # CORS handling
├── compression.q     # Response compression
├── rate_limit.q      # Rate limiting
└── custom.q          # User implementations
```

## File Structure

```
lib/std/web/
├─ index.q                    # Main web API (add_static, set_cors, use, after, run)
├─ middleware/
│  ├─ router.q                # QEP-062: Routing as middleware (NEW LOCATION)
│  └─ (future: logging, auth, etc.)
└─ (future: utilities)
```

## Migration of QEP-062

All references to `std/web/router` have been updated to `std/web/middleware/router`:

### Usage Example

**OLD** (not used):
```quest
use "std/web/router" as router
```

**NEW** (active):
```quest
use "std/web/middleware/router" as router
```

## API Surface

The user-facing API remains unchanged:

```quest
use "std/web" as web
use "std/web/middleware/router" as router

# Define routes (same as before)
router.get("/post/{slug}", fun (req)
  # ...
end)

# Register as middleware (same as before)
web.use(router.dispatch_middleware)

web.run()
```

## Implementation Order

1. **Phase 3**: HTTP server startup in `web.run()`
2. **Phase 4**: Static files + dynamic routes
3. **Phase 5**: Middleware chain support (QEP-061)
4. **Phase 6**: Routing middleware (QEP-062) at `std/web/middleware/router`

## Backward Compatibility

No backward compatibility concerns since:
- QEP-062 is not yet implemented
- This is the canonical location before any public release
- No existing code uses `std/web/router`

## Alternatives Considered

### Alternative 1: `std/web/router` (Top-Level)
**Pros**: Simpler import path
**Cons**: Treats routing as special-case, not middleware; inconsistent with framework design
**Decision**: Rejected ✗

### Alternative 2: `std/web/routing/router`
**Pros**: More specific folder name
**Cons**: Not extensible; doesn't match middleware pattern
**Decision**: Rejected ✗

### Alternative 3: `std/web/middleware/router` (Selected)
**Pros**: Architectural consistency; future-proof; user control; composable
**Cons**: Slightly longer import path (acceptable)
**Decision**: Approved ✅

## References

- QEP-061: Web Server Middleware System
- QEP-062: Flexible Path Parameter Routing
- QEP-060: Application-Centric Web Server Architecture
- QEP-051: Web Framework API

## Sign-Off

- ✅ Architecture: Consistent with middleware pattern
- ✅ Design: Future-proof and extensible
- ✅ Implementation: QEP-062 updated accordingly
- ✅ Documentation: PHASE3 plan updated

**Ready for Phase 3 implementation**.
