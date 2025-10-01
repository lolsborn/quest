# Known Bugs and Missing Features

This document tracks known issues and missing implementations in Quest.

## Reserved Word: `dict`

**Status**: Design Decision / Limitation
**Priority**: Low
**Discovered**: 2025-10-01

### Issue
The word `dict` is a reserved keyword in Quest (defined in grammar as a type name), which means users cannot use it as a variable name.

### Example
```quest
let dict = {}  # Parse error: expected identifier
let d = {}     # Works fine
```

### Notes
This is intentional as `dict` is reserved for future type annotation syntax like:
```quest
dict: my_dict = {}  # Type annotation (not yet implemented)
```

Users should use alternative names like `d`, `data`, `map`, `obj` for dictionary variables.

---
