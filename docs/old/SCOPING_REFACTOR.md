# Block Scoping Refactor Plan

## Current State
Quest uses a flat `HashMap<String, QValue>` for all variables. Functions clone this HashMap, so:
- ❌ No block scoping (if/elif/else don't create new scopes)
- ❌ Cannot detect which scope a variable belongs to
- ❌ `del` silently fails when trying to delete outer scope variables
- ❌ Assignments in functions don't modify captured variables (closure bug)

## Goal
Implement proper lexical scoping with scope chains, where:
- ✅ Each block (if/elif/else/fun) creates a new scope
- ✅ Variable lookup searches from inner to outer scopes
- ✅ `let` declares in current scope
- ✅ Assignment modifies existing variable or creates in current scope
- ✅ `del` only works on current scope variables
- ✅ Eventually: closures can modify captured variables

## Implementation Added

### Scope Struct (lines 30-118 in main.rs)
```rust
struct Scope {
    scopes: Vec<HashMap<String, QValue>>,
}
```

**Methods:**
- `new()` - Create with one empty scope
- `push()` - Enter new block
- `pop()` - Exit block
- `get(name)` - Lookup variable (searches all scopes)
- `set(name, value)` - Update existing or create in current
- `declare(name, value)` - Create in current scope only
- `delete(name)` - Delete from current scope, error if in outer
- `contains_in_current(name)` - Check current scope only
- `to_flat_map()` / `from_flat_map()` - Compatibility helpers

## Refactor Steps

### Phase 1: Update eval_pair signature
- Change: `fn eval_pair(pair, variables: &mut HashMap)`
- To: `fn eval_pair(pair, scope: &mut Scope)`
- Update all ~50+ call sites

### Phase 2: Update statement handlers
- `Rule::let_statement` → use `scope.declare()`
- `Rule::assignment` → use `scope.set()`
- `Rule::del_statement` → use `scope.delete()`
- `Rule::identifier` lookup → use `scope.get()`

### Phase 3: Add scope push/pop for blocks
- `Rule::if_statement`:
  ```rust
  scope.push();
  // evaluate if body
  scope.pop();
  ```
- Same for elif/else branches
- `Rule::function_declaration` body

### Phase 4: Update function calls
- `call_user_function()` needs to:
  - Create new Scope from parent
  - Add parameters to current scope
  - Pass Scope instead of HashMap

### Phase 5: Module handling
- Module functions need special handling
- Module state changes need to propagate back

### Phase 6: Testing
- Test block scoping (shadowing)
- Test `del` restrictions
- Test nested functions
- Ensure old tests still pass

## Alternative: Incremental Fix

For immediate `del` fix without full refactor:
1. Track "declared_in_current_scope" set alongside variables HashMap
2. `let` adds to this set
3. `del` checks if variable is in this set
4. Function calls clear this set (new scope)

This is a band-aid but would make `del` work correctly without the full refactor.

## Recommendation

The Scope refactor is the right long-term solution. It will:
1. Fix `del` scope restrictions
2. Fix block scoping
3. Enable proper shadowing
4. Make closures fixable later
5. Match the documented specification

Estimated effort: 2-3 hours for full implementation and testing.

The incremental fix would take 30 minutes but leave technical debt.

## Current Blockers

The big challenge is that ~50+ places call `eval_pair` with `variables`. All need updating.
Functions that create new scopes need to call `push()`/`pop()`.
Compatibility with module system needs careful handling.

This is doable but requires careful, systematic changes across the codebase.
