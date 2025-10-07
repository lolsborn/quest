# QEP-016: Match Statement with In Blocks

**Status:** Draft
**Author:** Quest Team
**Created:** 2025-10-06
**Related:** Control flow
**Alternative to:** QEP-016 (Case Statement)

## Abstract

This QEP proposes adding a `match...in...else...end` statement to Quest for multi-way branching. The syntax uses `in` blocks inspired by Python's membership testing and pattern matching, providing a clean alternative to long `if/elif/else` chains with an intuitive, readable syntax.

## Motivation

### Current Limitations

Quest currently requires verbose `if/elif/else` chains for multi-way branching:

```quest
let day = "Monday"

if day == "Monday"
    puts("Start of work week")
elif day == "Tuesday"
    puts("Second day")
elif day == "Wednesday"
    puts("Midweek")
elif day == "Thursday"
    puts("Almost Friday")
elif day == "Friday"
    puts("TGIF!")
elif day == "Saturday" or day == "Sunday"
    puts("Weekend!")
else
    puts("Invalid day")
end
```

This is verbose, error-prone (repeated variable), and hard to read.

### Benefits

A `match` statement provides:

1. **Clarity** - Intent is immediately obvious with `in` keyword
2. **Conciseness** - Less repetition
3. **Intuitive** - `in` naturally reads as "value in set of options"
4. **Performance** - Potential for optimization (jump tables, hash lookups)
5. **Safety** - Single evaluation of the test expression
6. **Future-proof** - `match` can naturally extend to pattern matching

## Specification

### Basic Syntax

```quest
match <expression>
in <value1>
    <statements>
in <value2>
    <statements>
else
    <statements>
end
```

### Multiple Values per In Block

```quest
match <expression>
in <value1>, <value2>, <value3>
    <statements>
in <value4>
    <statements>
else
    <statements>
end
```

### Grammar

```pest
match_statement = {
    "match" ~ !("for") ~ expression ~
    in_clause+ ~
    else_clause? ~
    "end"
}

in_clause = {
    "in" ~ expression_list ~ statement+
}

expression_list = {
    expression ~ ("," ~ expression)*
}
```

**Parser disambiguation:**
- `match_statement` uses negative lookahead `!("for")` to prevent parsing `match for` as a match statement
- Context distinguishes `for x in arr` (for_statement) from `match x ... in 1, 2, 3` (match_statement)
- Statement type (`match` vs `for`) unambiguously determines which rule applies

Note: `statement+` (not `statement*`) requires at least one statement per in block.

### Semantics

1. **Evaluation order:**
   - Evaluate the match expression once
   - Compare against each `in` expression in order
   - **Lazy evaluation**: `in` expressions are evaluated left-to-right and stop after first match
   - Execute the first matching `in` block
   - Skip remaining `in` clauses after a match
   - Execute `else` block if no matches

2. **Comparison:**
   - Uses `==` equality comparison
   - NOT identity (`===` or `is`)
   - Each value in comma-separated list is tested: `in 1, 2, 3` means `x == 1 OR x == 2 OR x == 3`
   - Array literals are treated as values: `in [1, 2, 3]` means `x == [1, 2, 3]` (array equality)
   - Expressions evaluate only until match is found (short-circuit behavior)

3. **Fall-through:**
   - No fall-through behavior (unlike C/JavaScript switch)
   - Each `in` block implicitly exits the match after execution

4. **Control flow:**
   - `return` inside an `in` block exits the enclosing function (standard behavior)
   - `break` inside an `in` block exits enclosing loop (if match is inside a loop)
   - `break` cannot be used to exit a match statement itself (unnecessary - use `else`)
   - `continue` inside an `in` block continues enclosing loop (if match is inside a loop)

5. **Return value:**
   - Returns the value of the last statement in the executed block (not explicit `return`)
   - Can be used as an expression
   - Empty in blocks are not allowed (parse error: "in block requires at least one statement")

## Examples

### Basic Match Statement

```quest
let day = "Friday"

match day
in "Monday"
    puts("Start of work week")
in "Tuesday", "Wednesday", "Thursday"
    puts("Midweek grind")
in "Friday"
    puts("TGIF!")
in "Saturday", "Sunday"
    puts("Weekend!")
else
    puts("Invalid day")
end
```

### Multiple Values per In Block

```quest
let grade = 85

# Note: For ranges, use range matching (future) or if/elif
match grade
in 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100
    puts("A")
in 80, 81, 82, 83, 84, 85, 86, 87, 88, 89
    puts("B")
in 70, 71, 72, 73, 74, 75, 76, 77, 78, 79
    puts("C")
else
    puts("F")
end

# Better approach using ranges (when implemented):
# match grade
# in 90..100
#     puts("A")
# in 80..89
#     puts("B")
# end
```

### Match as Expression

```quest
let status_code = 404

let message = match status_code
in 200
    "OK"
in 404
    "Not Found"
in 500
    "Internal Server Error"
else
    "Unknown Status"
end

puts(message)  # "Not Found"
```

### Type-Based Dispatch (Class Name String Comparison)

```quest
let value = 42

# IMPORTANT: This matches on class name strings (value.cls() returns "Int", "Str", etc.)
# This is NOT actual type matching (see Future Enhancements for true type patterns)
match value.cls()
in "Int"
    puts("It's an integer: " .. value._str())
in "Float"
    puts("It's a float: " .. value._str())
in "Str"
    puts("It's a string: " .. value)
else
    puts("Unknown type")
end

# For true type matching, wait for future pattern matching QEP
# Future syntax: match value in Int => ... in Str => ...
```

### Nested Match Statements

```quest
let category = "fruit"
let item = "apple"

match category
in "fruit"
    match item
    in "apple", "banana"
        puts("Common fruit")
    in "mango", "papaya"
        puts("Tropical fruit")
    else
        puts("Other fruit")
    end
in "vegetable"
    puts("It's a vegetable")
else
    puts("Unknown category")
end
```

### Real-World Use Cases

#### HTTP Status Code Handler

```quest
fun handle_response(status)
    match status
    in 200, 201, 204
        puts("Success")
    in 400, 401, 403
        puts("Client error")
    in 404
        puts("Not found")
    in 500, 502, 503
        puts("Server error")
    else
        # String interpolation or manual conversion
        puts(f"Unknown status: {status}")
    end
end
```

#### Command Dispatcher

```quest
fun dispatch_command(cmd)
    match cmd
    in "help", "h", "?"
        show_help()
    in "quit", "exit", "q"
        exit_program()
    in "list", "ls"
        list_items()
    in "add", "new"
        add_item()
    else
        puts("Unknown command: " .. cmd)
    end
end
```

#### State Machine

```quest
let state = "pending"

match state
in "pending"
    process_pending()
in "approved"
    process_approved()
in "rejected"
    process_rejected()
in "completed"
    finalize()
else
    raise "Invalid state: " .. state
end
```

#### Configuration Validator

```quest
fun validate_env(env)
    match env
    in "dev", "development"
        setup_dev_config()
    in "test", "testing"
        setup_test_config()
    in "stage", "staging"
        setup_stage_config()
    in "prod", "production"
        setup_prod_config()
    else
        raise "Invalid environment: " .. env
    end
end
```

## Comparison with Other Languages

### Python (3.10+ match)

```python
match day:
    case "Monday":
        print("Start of week")
    case "Tuesday" | "Wednesday":
        print("Midweek")
    case _:
        print("Other")
```

Python's `match` is more powerful (pattern matching), but uses `case` instead of `in`. Quest's `in` keyword is more intuitive for set membership.

### Ruby (case/when)

```ruby
case day
when "Monday"
  puts "Start of week"
when "Tuesday", "Wednesday"
  puts "Midweek"
else
  puts "Other"
end
```

Ruby uses `case...when`. Quest's `match...in` is more readable for checking if a value is "in" a set of options.

### Rust (match)

```rust
match day {
    "Monday" => println!("Start of week"),
    "Tuesday" | "Wednesday" => println!("Midweek"),
    _ => println!("Other"),
}
```

Rust's match is powerful but uses `=>` arrows. Quest's syntax is more approachable.

## Advantages of `in` Keyword

The `in` keyword has several advantages over `when` or `case`:

1. **Natural Language Flow:** "Match value in [options]" reads naturally
2. **Familiarity:** Python developers know `x in [1, 2, 3]`
3. **Semantic Clarity:** `in` explicitly suggests membership testing
4. **Future Extension:** Can naturally extend to range/pattern matching:
   ```quest
   match x
   in 1..10          # Future: range matching
   in [a, b]         # Future: destructuring
   in Int            # Future: type matching
   end
   ```

## Implementation Strategy

### Phase 1: Grammar & Parser (Priority: High)

1. Add `match_statement` rule to `quest.pest`
2. Add `in_clause` and `expression_list` rules
3. Ensure `match` is a keyword (note: `in` is already used in `for..in`)
4. Add to statement alternatives
5. Add parser tests for `for...in` disambiguation

**Grammar additions:**
```pest
match_statement = {
    "match" ~ !("for") ~ expression ~
    in_clause+ ~
    else_clause? ~
    "end"
}

in_clause = {
    "in" ~ expression_list ~ statement+
}

expression_list = {
    expression ~ ("," ~ expression)*
}
```

**Parser disambiguation test:**
```quest
# Test that for...in and match...in don't conflict
for x in arr
    match x
    in 1, 2, 3
        puts("matched")
    end
end

# Edge case: nested for inside match
match category
in "numbers"
    for x in [1, 2, 3]
        puts(x)
    end
end
```

Note: `statement+` ensures empty in blocks cause parse errors.

### Phase 2: Evaluator (Priority: High)

1. Add `Rule::match_statement` handler to `eval_pair()`
2. Evaluate match expression once
3. Iterate through in clauses:
   - Evaluate each expression in the expression list
   - Compare with match value using `==`
   - If match, execute statements and return
4. If no match, execute else clause (if present)
5. Return result value

**Evaluation logic:**
```rust
Rule::match_statement => {
    let mut inner = pair.into_inner();

    // Evaluate the match expression once
    let match_value = eval_pair(inner.next().unwrap(), scope)?;

    // Iterate through in clauses
    for clause in inner {
        match clause.as_rule() {
            Rule::in_clause => {
                let mut in_inner = clause.into_inner();

                // Check expression list for match
                let expr_list = in_inner.next().unwrap();
                for expr in expr_list.into_inner() {
                    let in_value = eval_pair(expr, scope)?;
                    if values_equal(&match_value, &in_value)? {
                        // Match found - execute statements
                        let mut result = QValue::Nil(QNil::new());
                        for stmt in in_inner {
                            result = eval_pair(stmt, scope)?;
                        }
                        return Ok(result);
                    }
                }
            }
            Rule::else_clause => {
                // No match found - execute else
                let mut result = QValue::Nil(QNil::new());
                for stmt in clause.into_inner() {
                    result = eval_pair(stmt, scope)?;
                }
                return Ok(result);
            }
            _ => {}
        }
    }

    // No match and no else clause
    Ok(QValue::Nil(QNil::new()))
}
```

### Phase 3: Testing (Priority: High)

Comprehensive test coverage:
- Basic match statements
- Multiple values per in block
- Match as expression
- Nested match statements
- Type-based dispatch
- Missing else clause (returns nil)
- Empty in blocks

**Estimated effort:** 4-6 hours total

## Testing Strategy

### Basic Tests

```quest
# test/control_flow/match_test.q
use "std/test"

test.module("Match Statement")

test.describe("Basic match statement", fun ()
    test.it("matches single value", fun ()
        let result = match 1
        in 1
            "one"
        in 2
            "two"
        else
            "other"
        end

        test.assert_eq(result, "one")    end)

    test.it("matches multiple values", fun ()
        let result = match 2
        in 1
            "one"
        in 2, 3, 4
            "two-four"
        else
            "other"
        end

        test.assert_eq(result, "two-four")    end)

    test.it("uses else clause when no match", fun ()
        let result = match 99
        in 1
            "one"
        in 2
            "two"
        else
            "other"
        end

        test.assert_eq(result, "other")    end)

    test.it("returns nil when no match and no else", fun ()
        let result = match 99
        in 1
            "one"
        in 2
            "two"
        end

        test.assert_eq(result, nil)    end)
end)

test.describe("Match with different types", fun ()
    test.it("matches strings", fun ()
        let day = "Friday"
        let result = match day
        in "Monday"
            "Start"
        in "Friday"
            "TGIF"
        else
            "Other"
        end

        test.assert_eq(result, "TGIF")    end)

    test.it("matches booleans", fun ()
        let result = match true
        in true
            "yes"
        in false
            "no"
        end

        test.assert_eq(result, "yes")    end)
end)

test.describe("Match as expression", fun ()
    test.it("can be assigned to variable", fun ()
        let x = 2
        let result = match x
        in 1
            "one"
        in 2
            "two"
        else
            "other"
        end

        test.assert_eq(result, "two")    end)

    test.it("can be used in expressions", fun ()
        let x = 1
        let message = "The value is " .. match x
        in 1
            "one"
        in 2
            "two"
        else
            "unknown"
        end

        test.assert_eq(message, "The value is one")    end)
end)

test.describe("Nested match statements", fun ()
    test.it("supports nesting and returns nested value", fun ()
        let outer = 1
        let inner = 2

        let result = match outer
        in 1
            match inner
            in 1
                "1-1"
            in 2
                "1-2"
            end
        in 2
            "outer-2"
        end

        # Verify nested match returns value correctly
        test.assert_eq(result, "1-2")    end)

    test.it("nested match returns correct value type", fun ()
        let outer = 2
        let inner = 3

        let result = match outer
        in 1
            42
        in 2
            match inner
            in 3
                99    # This should be the final result
            else
                0
            end
        else
            -1
        end

        # Ensure the inner match's return value propagates correctly
        test.assert_eq(result, 99)        test.assert_type(result, "Int")    end)
end)
```

### Edge Cases

```quest
test.describe("Edge cases", fun ()
    test.it("handles nil match value", fun ()
        let result = match nil
        in nil
            "matched nil"
        else
            "other"
        end

        test.assert_eq(result, "matched nil")    end)

    test.it("evaluates match expression only once", fun ()
        let counter = 0
        fun increment()
            counter = counter + 1
            counter
        end

        let result = match increment()
        in 1
            "one"
        in 2
            "two"
        end

        # increment() should only be called once
        # Note: This test requires Quest to support closure variable mutation
        test.assert_eq(counter, 1)        test.assert_eq(result, "one")    end)

    test.it("executes first matching in block", fun ()
        let result = match 1
        in 1
            "first"
        in 1
            "second"
        end

        # Should match first, not second
        test.assert_eq(result, "first")    end)

    test.it("works with complex expressions", fun ()
        let x = 5
        let result = match x * 2
        in 10
            "matched"
        else
            "no match"
        end

        test.assert_eq(result, "matched")    end)

    test.it("matches array literals", fun ()
        let result = match [1, 2, 3]
        in [1, 2, 3]
            "array matched"
        else
            "no match"
        end

        test.assert_eq(result, "array matched")    end)

    test.it("distinguishes comma-separated values from arrays", fun ()
        let x = 2

        # This checks: x == 1 OR x == 2 OR x == 3
        let result1 = match x
        in 1, 2, 3
            "found"
        end

        # This checks: x == [1, 2, 3]
        let result2 = match x
        in [1, 2, 3]
            "found"
        else
            "not found"
        end

        test.assert_eq(result1, "found")        test.assert_eq(result2, "not found")    end)
end)

test.describe("Control flow inside match", fun ()
    test.it("allows return to exit function", fun ()
        fun test_return(x)
            match x
            in 0
                return "zero"
            in 1
                "one"
            end
            "unreachable"
        end

        test.assert_eq(test_return(0), "zero", nil)
        test.assert_eq(test_return(1), "one", nil)
    end)

    test.it("allows break to exit enclosing loop", fun ()
        let results = []
        for i in [1, 2, 3, 4, 5]
            match i
            in 3
                break
            else
                results.push(i)
            end
        end

        test.assert_eq(results, [1, 2])    end)

    test.it("allows continue in enclosing loop", fun ()
        let results = []
        for i in [1, 2, 3, 4, 5]
            match i
            in 2, 4
                continue
            else
                results.push(i)
            end
        end

        test.assert_eq(results, [1, 3, 5])    end)
end)
```

## Documentation Updates

### CLAUDE.md

Add to control flow section:

```markdown
**Match statement**:
```quest
match value
in 1
    "one"
in 2, 3
    "two or three"
else
    "other"
end
```

- Python-inspired `in` keyword for natural readability
- No fall-through (each in block implicitly breaks)
- Can be used as expression (returns value)
- Multiple values per in block
```

### User Documentation (docs/docs/language/control_flow.md)

Add comprehensive section with examples for:
- Basic match statements
- Multiple values per in block
- Match as expression
- Real-world examples (HTTP status codes, state machines)
- Comparison with if/elif/else

### LANGUAGE_FEATURE_COMPARISON.md

Update:
```markdown
| Match/switch | ✅ `match...in` | ⚠️ `match` (3.10+) | ✅ `case...when` | Quest uses intuitive `in` blocks |
```

## Design Decisions

### 1. `match...in` vs. `case...when`

**Chosen:** `match...in...end`

**Alternatives considered:**
- Ruby style: `case...when...end`
- Python style: `match...case...`
- C/JavaScript style: `switch...case...`

**Rationale:**
- `in` keyword is highly intuitive: "value in set of options"
- `match` is modern and familiar to Rust/Python developers
- More semantic than `case` or `when`
- Natural extension point for pattern matching
- Reads like natural language: "match x in 1, 2, 3"

### 2. Fall-through Behavior

**Chosen:** No fall-through

**Rationale:**
- Fall-through is error-prone (forgotten `break`)
- Explicit is better than implicit
- Can always use multiple values per in: `in 1, 2, 3`
- Matches Python and Ruby behavior

### 3. Match as Expression

**Chosen:** Yes, match returns a value

**Rationale:**
- More functional style
- Consistent with modern languages (Rust, Scala)
- Enables concise assignment: `let x = match ...`
- No downside

### 4. Pattern Matching

**Chosen:** Not in this QEP

**Rationale:**
- Start simple (equality comparison only)
- Pattern matching is complex (deserves its own QEP)
- Can add later without breaking changes
- Foundation for future pattern matching features

### 5. Reusing `in` Keyword

**Note:** Quest already uses `in` in `for...in` loops. This is not a conflict:
- Context disambiguates: `for x in arr` vs. `match x in 1, 2, 3`
- Parser can distinguish based on statement type (`match_statement` vs `for_statement`)
- Many languages reuse keywords contextually (Python's `in` works in both contexts)

**Parser disambiguation strategy:**
```pest
# for_statement starts with "for", match_statement starts with "match"
statement = {
    for_statement
    | match_statement
    | ...
}
```

No lookahead needed - statement type determines context unambiguously.

## Future Enhancements

### 1. Range Matching (Future QEP)

```quest
match age
in 0..12
    "child"
in 13..19
    "teenager"
in 20..64
    "adult"
in 65..
    "senior"
end
```

### 2. Type Pattern Matching (Future QEP)

```quest
# Match against actual type objects, not class name strings
match value
in Int        # Actual type matching, not value.cls() == "Int"
    "integer"
in Str
    "string"
in Array
    "array"
end
```

### 3. Destructuring (Future QEP)

```quest
match point
in [0, 0]
    "origin"
in [x, 0]
    "on x-axis"
in [0, y]
    "on y-axis"
end
```

### 4. Guard Clauses (Future QEP)

```quest
match x
in n if n > 0
    "positive"
in n if n < 0
    "negative"
else
    "zero"
end
```

### 5. Contains/Membership Checking (Requires Different Syntax)

**Note:** The `in` keyword in `match...in` means "match value IN this set of options", but it uses equality (`==`) not membership testing.

```quest
# Current behavior: equality check
match status
in valid_codes  # Checks: status == valid_codes (array equality)
    "success"
end

# For membership testing (check if status is IN the array), use:
if valid_codes.contains(status)
    puts("success")
end

# Future syntax option (requires new QEP):
match status
in* valid_codes  # New operator: checks if status is member of valid_codes
    "success"
end
```

This semantic distinction is important:
- `in 1, 2, 3` → checks `x == 1 OR x == 2 OR x == 3`
- `in [1, 2, 3]` → checks `x == [1, 2, 3]` (entire array equality)
- `in* [1, 2, 3]` → (future) checks `[1, 2, 3].contains(x)` (membership)

## Performance Considerations

### Realistic Optimizations

1. **Single Evaluation:** Match expression evaluated only once (key benefit over if/elif chains)
2. **Short-circuit:** Stop evaluating in clauses after first match (lazy evaluation)
3. **Constant Folding:** Optimize match expressions that are compile-time constants

**Implementation approach:** Start with straightforward linear search through `in` clauses. The primary performance benefit comes from evaluating the match expression once, not from complex optimizations.

**Advanced optimizations:** Jump tables (dense integers) and hash tables (strings) would require static analysis, JIT compilation, or significant interpreter complexity. These optimizations should only be considered if profiling identifies match statements as bottlenecks. For an interpreter, the simplicity and correctness of linear search outweighs the complexity of advanced optimization techniques.

## Breaking Changes

**None.** This is a purely additive feature.

## Compatibility

- All existing code remains valid
- No migration needed
- `match` becomes a reserved keyword
- `in` already reserved (used in `for...in`)

## Clarifications & Design Details

### Expression List Semantics

```quest
# Comma-separated values are OR'd:
match x
in 1, 2, 3    # Means: x == 1 OR x == 2 OR x == 3
    "matched"
end

# Array literal is a single value:
match x
in [1, 2, 3]  # Means: x == [1, 2, 3] (array equality)
    "matched"
end

# Multiple lines are supported for long value lists:
match grade
in 90, 91, 92,
   93, 94, 95,
   96, 97, 98,
   99, 100
    "A"
in 80, 81, 82,
   83, 84, 85
    "B"
end

# Newlines and whitespace between commas are allowed
match status
in 200,
   201,
   202,
   204
    "success"
end

# Recommended: Use ranges when available (future feature)
# match grade
# in 90..100
#     "A"
# end
```

### Control Flow Inside Match

**Summary:** `return` exits the function, `break`/`continue` affect enclosing loops, NOT the match statement itself.

```quest
# return exits the enclosing function (standard behavior)
fun process(x)
    match x
    in 0
        return "zero"    # Exits process(), returns "zero"
    in 1
        puts("one")      # Prints and continues
    end
    "done"               # Only reached if x != 0
end

# break exits the enclosing loop (if match is inside a loop)
for item in items
    match item
    in "skip"
        continue         # Continues to next iteration of for loop
    in "stop"
        break            # Exits for loop entirely
    in "value"
        process(item)    # Normal processing
    end
end

# break/continue CANNOT be used to exit match itself
# This is unnecessary - match already exits after first matching block
match x
in 1
    if condition
        break            # ERROR: no loop to break from
    end
in 2
    puts("two")
end

# Each in block implicitly exits the match after execution (no fall-through)
# To exit early, use return or nest match inside a loop
```

**Key points:**
- `return` → exits enclosing function
- `break` → exits enclosing loop (ERROR if no enclosing loop)
- `continue` → continues enclosing loop (ERROR if no enclosing loop)
- No fall-through → each `in` block automatically exits match after execution

### Error Messages

Common error scenarios and their messages:

```quest
# Empty in block
match x
in 1
end
# Parse error: "in block requires at least one statement"

# No match and no else clause
let result = match 99
in 1
    "one"
end
# Returns nil (not an error - this is valid behavior)

# Invalid syntax: missing comma
match x
in 1 2
    "bad"
end
# Parse error: "expected statement or comma, found integer literal"

# Break outside loop
match x
in 1
    break
end
# Runtime error: "break statement not inside loop"

# Continue outside loop
match x
in 1
    continue
end
# Runtime error: "continue statement not inside loop"

# Missing end keyword
match x
in 1
    "one"
# Parse error: "expected 'in', 'else', or 'end', found EOF"

# Missing expression after match
match
in 1
    "one"
end
# Parse error: "expected expression after 'match', found 'in'"
```

### REPL Behavior

Multi-line match statements work with continuation prompts, similar to other multi-line constructs:

```
quest> let x = 2
quest> match x
  .> in 1
 ..>     "one"
 ..> in 2
 ..>     "two"
 ..> else
 ..>     "other"
 ..> end
"two"
```

**Nesting level tracking:**
- `match` increments nesting level (continuation prompt changes from `>` to `.>`)
- `in` and `else` maintain nesting level (continue with `..>`)
- `end` decrements nesting level
- Evaluates when nesting returns to 0

**Partial input behavior:**
```
quest> match status
  .> in 200
 ..>     "OK"
 ..>     # User can continue entering statements
 ..>     puts("Success!")
 ..> in 404
 ..>     "Not Found"
 ..> end
Success!
"OK"
```

**Inline match (single line, no continuation prompts):**
```
quest> let result = match 1 in 1 "one" in 2 "two" end
# Parse error - inline match not supported, use explicit blocks
```

Note: Match statements MUST use multi-line block syntax. Single-line condensed syntax is not supported.

## Open Questions

1. **Should we support fall-through with explicit keyword?**
   - Most modern languages don't
   - **Proposed:** No, keep it simple

2. **Should match work without an expression (boolean mode)?**
   - Example: `match in x > 10 ... in x < 0 ...`
   - This would be like Ruby's "case without argument"
   - **Proposed:** Not in this QEP, maybe future enhancement

3. **Should we support inline match expressions?**
   - Example: `let x = match y in 1 => "a" in 2 => "b" end`
   - Would require different syntax (arrow `=>` instead of blocks)
   - **Proposed:** Not in this QEP - keep block syntax consistent with other control structures

## Comparison: `match...in` vs. `case...when`

| Aspect | `match...in` | `case...when` |
|--------|-------------|---------------|
| Readability | "Match x in 1, 2, 3" - natural language | "Case x when 1" - less intuitive |
| Semantic clarity | `in` suggests membership testing | `when` is more temporal |
| Python familiarity | `in` keyword familiar to Python devs | `when` less common |
| Ruby familiarity | Less familiar to Ruby devs | Identical to Ruby |
| Future pattern matching | `match` naturally extends to patterns | `case` less associated with patterns |
| Modern feel | `match` used in Rust, Python, Scala | `case` feels older (C, Java) |

**Recommendation:** `match...in` for better semantics and future extensibility.

## Status

- [ ] Grammar design
- [ ] Parser implementation
- [ ] Evaluator implementation
- [ ] Basic tests
- [ ] Edge case tests
- [ ] Documentation
- [ ] CLAUDE.md updates
- [ ] User docs (control-flow.md)
- [ ] LANGUAGE_FEATURE_COMPARISON.md update

## Conclusion

The `match...in...else...end` statement brings intuitive multi-way branching to Quest. The `in` keyword provides semantic clarity that naturally reads as "match this value in these options," making code more readable and maintainable. The `match` keyword positions Quest for future pattern matching features while providing immediate value with simple equality-based matching.

This syntax is more intuitive than traditional `case`/`when` approaches and provides a solid foundation for future pattern matching enhancements.
