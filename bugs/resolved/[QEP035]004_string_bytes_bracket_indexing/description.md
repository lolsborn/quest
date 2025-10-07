# String and Bytes Bracket Indexing Not Supported

## Issue
String and Bytes types don't support bracket indexing `[]` while Arrays and Dicts do.

## Current Behavior
- `"hello"[0]` → Error: Cannot index into type Str
- `b"hello"[0]` → Error: Cannot index into type Bytes

## Expected Behavior
- `"hello"[0]` → should return `"h"`
- `b"hello"[0]` → should return `104` (byte value)

## Works Correctly
- `[1, 2, 3][0]` → `1` ✓
- `{"x": 10}["x"]` → `10` ✓

## Current Workarounds
- Strings: use `slice()` → `"hello".slice(0, 1)` → `"h"`
- Bytes: use `get()` → `b"hello".get(0)` → `104`

## Impact
Inconsistent API - bracket indexing should work uniformly across all indexable types.
