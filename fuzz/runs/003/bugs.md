# Bugs Found in Session 003

## Bug 1: Exception `.type()` method returns QType object instead of string

**Severity**: Medium

**Description**: The `.type()` method on exception objects returns a QType object instead of a string representation of the type name. This makes string comparisons fail.

**Reproduction**:
```quest
try
    raise ValueErr.new("test")
catch e: ValueErr
    puts(e.type())        # Prints "ValueErr" (looks like string)
    puts(e.type().cls())  # Would reveal it's actually a Type object

    # This fails with assertion error:
    test.assert_eq(e.type(), "ValueErr")  # Expected "ValueErr" but got ValueErr
end
```

**Expected Behavior**: `e.type()` should return a string like `"ValueErr"`, `"IndexErr"`, etc.

**Actual Behavior**: `e.type()` returns a Type object that displays as `ValueErr` but is not equal to the string `"ValueErr"`

**Impact**: Makes it difficult to programmatically check exception types using string comparison. Users would need to either:
1. Use type annotations in catch blocks (which works fine)
2. Compare against the actual Type object
3. Convert to string first (if possible)

**Suggested Fix**: Either:
- Option A: Have `.type()` return a string representation
- Option B: Have `.type_name()` or `.type_str()` that returns a string
- Option C: Document that `.type()` returns a Type object and provide a method to convert to string
