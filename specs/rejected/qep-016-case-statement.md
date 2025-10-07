# QEP-016: Case Statement

**Status:** Draft
**Author:** Quest Team
**Created:** 2025-10-05
**Related:** Control flow

## Abstract

This QEP proposes adding a `case...when...else...end` statement to Quest for multi-way branching. The syntax follows Ruby's elegant pattern, providing a clean alternative to long `if/elif/else` chains.

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

A `case` statement provides:

1. **Clarity** - Intent is immediately obvious
2. **Conciseness** - Less repetition
3. **Performance** - Potential for optimization (jump tables)
4. **Safety** - Single evaluation of the test expression
5. **Familiarity** - Matches Ruby/JavaScript switch syntax

## Specification

### Basic Syntax

```quest
case <expression>
when <value1>
    <statements>
when <value2>
    <statements>
else
    <statements>
end
```

### Grammar

```pest
case_statement = {
    "case" ~ expression ~
    when_clause+ ~
    else_clause? ~
    "end"
}

when_clause = {
    "when" ~ expression_list ~ statement*
}

expression_list = {
    expression ~ ("," ~ expression)*
}
```

### Semantics

1. **Evaluation order:**
   - Evaluate the case expression once
   - Compare against each `when` expression in order
   - Execute the first matching `when` block
   - Skip remaining `when` clauses after a match
   - Execute `else` block if no matches

2. **Comparison:**
   - Uses `==` equality comparison
   - NOT identity (`===` or `is`)

3. **Fall-through:**
   - No fall-through behavior (unlike C/JavaScript)
   - Each `when` implicitly breaks after execution
   - Use explicit `break` if needed to exit early from within a when block

4. **Return value:**
   - Returns the value of the executed block
   - Can be used as an expression

## Examples

### Basic Case Statement

```quest
let day = "Friday"

case day
when "Monday"
    puts("Start of work week")
when "Tuesday", "Wednesday", "Thursday"
    puts("Midweek grind")
when "Friday"
    puts("TGIF!")
when "Saturday", "Sunday"
    puts("Weekend!")
else
    puts("Invalid day")
end
```

### Multiple Values per When

```quest
let grade = 85

case grade
when 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100
    puts("A")
when 80, 81, 82, 83, 84, 85, 86, 87, 88, 89
    puts("B")
when 70, 71, 72, 73, 74, 75, 76, 77, 78, 79
    puts("C")
else
    puts("F")
end
```

### Case as Expression

```quest
let status_code = 404

let message = case status_code
when 200
    "OK"
when 404
    "Not Found"
when 500
    "Internal Server Error"
else
    "Unknown Status"
end

puts(message)  # "Not Found"
```

### Type-Based Dispatch

```quest
let value = 42

case value.cls()
when "Int"
    puts("It's an integer: " .. value.to_string())
when "Float"
    puts("It's a float: " .. value.to_string())
when "Str"
    puts("It's a string: " .. value)
else
    puts("Unknown type")
end
```

### Nested Case Statements

```quest
let category = "fruit"
let item = "apple"

case category
when "fruit"
    case item
    when "apple", "banana"
        puts("Common fruit")
    when "mango", "papaya"
        puts("Tropical fruit")
    else
        puts("Other fruit")
    end
when "vegetable"
    puts("It's a vegetable")
else
    puts("Unknown category")
end
```

### With Complex Expressions

```quest
let x = 15

case x
when 0
    puts("zero")
when 1, 2, 3, 4, 5
    puts("small")
when x > 10 and x < 20
    puts("medium")  # Note: This won't work - when expects values, not conditions
when x >= 20
    puts("large")   # This also won't work
end
```

**Important:** `when` clauses compare for equality (`==`), not boolean evaluation. For range checks, use `if/elif/else` or wait for pattern matching.

### Real-World Use Cases

#### HTTP Status Code Handler

```quest
fun handle_response(status)
    case status
    when 200, 201, 204
        puts("Success")
    when 400, 401, 403
        puts("Client error")
    when 404
        puts("Not found")
    when 500, 502, 503
        puts("Server error")
    else
        puts("Unknown status: " .. status.to_string())
    end
end
```

#### Command Dispatcher

```quest
fun dispatch_command(cmd)
    case cmd
    when "help", "h", "?"
        show_help()
    when "quit", "exit", "q"
        exit_program()
    when "list", "ls"
        list_items()
    when "add", "new"
        add_item()
    else
        puts("Unknown command: " .. cmd)
    end
end
```

#### State Machine

```quest
let state = "pending"

case state
when "pending"
    process_pending()
when "approved"
    process_approved()
when "rejected"
    process_rejected()
when "completed"
    finalize()
else
    raise "Invalid state: " .. state
end
```

## Comparison with Other Languages

### Ruby (Our inspiration)

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

Quest syntax is identical to Ruby! ✅

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

Python's `match` is more powerful (pattern matching), but also more complex.

### JavaScript

```javascript
switch (day) {
    case "Monday":
        console.log("Start of week");
        break;
    case "Tuesday":
    case "Wednesday":
        console.log("Midweek");
        break;
    default:
        console.log("Other");
}
```

JavaScript requires explicit `break` and has fall-through. Quest doesn't have fall-through.

## Implementation Strategy

### Phase 1: Grammar & Parser (Priority: High)

1. Add `case_statement` rule to `quest.pest`
2. Add `when_clause` and `expression_list` rules
3. Ensure `case`, `when` are keywords
4. Add to statement alternatives

**Grammar additions:**
```pest
case_statement = {
    "case" ~ expression ~
    when_clause+ ~
    else_clause? ~
    "end"
}

when_clause = {
    "when" ~ expression_list ~ statement*
}

expression_list = {
    expression ~ ("," ~ expression)*
}
```

### Phase 2: Evaluator (Priority: High)

1. Add `Rule::case_statement` handler to `eval_pair()`
2. Evaluate case expression once
3. Iterate through when clauses:
   - Evaluate each expression in the expression list
   - Compare with case value using `==`
   - If match, execute statements and return
4. If no match, execute else clause (if present)
5. Return result value

**Evaluation logic:**
```rust
Rule::case_statement => {
    let mut inner = pair.into_inner();

    // Evaluate the case expression once
    let case_value = eval_pair(inner.next().unwrap(), scope)?;

    // Iterate through when clauses
    for clause in inner {
        match clause.as_rule() {
            Rule::when_clause => {
                let mut when_inner = clause.into_inner();

                // Check expression list for match
                let expr_list = when_inner.next().unwrap();
                for expr in expr_list.into_inner() {
                    let when_value = eval_pair(expr, scope)?;
                    if values_equal(&case_value, &when_value)? {
                        // Match found - execute statements
                        let mut result = QValue::Nil(QNil::new());
                        for stmt in when_inner {
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
- Basic case statements
- Multiple values per when
- Case as expression
- Nested case statements
- Type-based dispatch
- Missing else clause (returns nil)
- Empty when blocks

**Estimated effort:** 4-6 hours total

## Testing Strategy

### Basic Tests

```quest
# test/control_flow/case_test.q
use "std/test"

test.module("Case Statement")

test.describe("Basic case statement", fun ()
    test.it("matches single value", fun ()
        let result = case 1
        when 1
            "one"
        when 2
            "two"
        else
            "other"
        end

        test.assert_eq(result, "one")    end)

    test.it("matches multiple values", fun ()
        let result = case 2
        when 1
            "one"
        when 2, 3, 4
            "two-four"
        else
            "other"
        end

        test.assert_eq(result, "two-four")    end)

    test.it("uses else clause when no match", fun ()
        let result = case 99
        when 1
            "one"
        when 2
            "two"
        else
            "other"
        end

        test.assert_eq(result, "other")    end)

    test.it("returns nil when no match and no else", fun ()
        let result = case 99
        when 1
            "one"
        when 2
            "two"
        end

        test.assert_eq(result, nil)    end)
end)

test.describe("Case with different types", fun ()
    test.it("matches strings", fun ()
        let day = "Friday"
        let result = case day
        when "Monday"
            "Start"
        when "Friday"
            "TGIF"
        else
            "Other"
        end

        test.assert_eq(result, "TGIF")    end)

    test.it("matches booleans", fun ()
        let result = case true
        when true
            "yes"
        when false
            "no"
        end

        test.assert_eq(result, "yes")    end)
end)

test.describe("Case as expression", fun ()
    test.it("can be assigned to variable", fun ()
        let x = 2
        let result = case x
        when 1
            "one"
        when 2
            "two"
        else
            "other"
        end

        test.assert_eq(result, "two")    end)

    test.it("can be used in expressions", fun ()
        let x = 1
        let message = "The value is " .. case x
        when 1
            "one"
        when 2
            "two"
        else
            "unknown"
        end

        test.assert_eq(message, "The value is one")    end)
end)

test.describe("Nested case statements", fun ()
    test.it("supports nesting", fun ()
        let outer = 1
        let inner = 2

        let result = case outer
        when 1
            case inner
            when 1
                "1-1"
            when 2
                "1-2"
            end
        when 2
            "outer-2"
        end

        test.assert_eq(result, "1-2")    end)
end)
```

### Edge Cases

```quest
test.describe("Edge cases", fun ()
    test.it("handles nil case value", fun ()
        let result = case nil
        when nil
            "matched nil"
        else
            "other"
        end

        test.assert_eq(result, "matched nil")    end)

    test.it("evaluates case expression only once", fun ()
        let counter = 0
        fun increment()
            counter = counter + 1
            counter
        end

        case increment()
        when 1
            "one"
        when 2
            "two"
        end

        # increment() should only be called once
        test.assert_eq(counter, 1)    end)

    test.it("executes first matching when block", fun ()
        let result = case 1
        when 1
            "first"
        when 1
            "second"
        end

        # Should match first, not second
        test.assert_eq(result, "first")    end)
end)
```

## Documentation Updates

### CLAUDE.md

Add to control flow section:

```markdown
**Case statement**:
```quest
case value
when 1
    "one"
when 2, 3
    "two or three"
else
    "other"
end
```

- Ruby-style syntax
- No fall-through (each when implicitly breaks)
- Can be used as expression (returns value)
- Multiple values per when clause
```

### User Documentation (docs/docs/language/control-flow.md)

Add comprehensive section with examples for:
- Basic case statements
- Multiple values per when
- Case as expression
- Real-world examples (HTTP status codes, state machines)
- Comparison with if/elif/else

### LANGUAGE_FEATURE_COMPARISON.md

Update from ❌ to ✅:
```markdown
| Case/switch | ✅ `case...when` | ⚠️ `match` (3.10+) | ✅ `case...when` | Quest/Ruby identical syntax |
```

## Design Decisions

### 1. Ruby Syntax vs. C-style Switch

**Chosen:** Ruby `case...when...end`

**Alternatives considered:**
- C/JavaScript style: `switch (x) { case 1: ... }`
- Python style: `match x: case 1: ...`

**Rationale:**
- Quest already uses Ruby-style `if...end`, `while...end`
- More readable (`when` is clearer than `case:`)
- No need for explicit `break` statements
- Consistency with existing Quest syntax

### 2. Fall-through Behavior

**Chosen:** No fall-through

**Rationale:**
- Fall-through is error-prone (forgotten `break`)
- Ruby doesn't have fall-through
- Explicit is better than implicit
- Can always use multiple values per when: `when 1, 2, 3`

### 3. Case as Expression

**Chosen:** Yes, case returns a value

**Rationale:**
- More functional style
- Consistent with Ruby
- Enables concise assignment: `let x = case ...`
- No downside

### 4. Pattern Matching

**Chosen:** Not in this QEP

**Rationale:**
- Start simple (equality comparison only)
- Pattern matching is complex (deserves its own QEP)
- Can add later without breaking changes
- Current proposal matches Ruby's basic case

## Future Enhancements

### 1. Range Matching (Future QEP)

```quest
case age
when 0..12
    "child"
when 13..19
    "teenager"
when 20..64
    "adult"
when 65..
    "senior"
end
```

### 2. Type Pattern Matching (Future QEP)

```quest
case value
when Int
    "integer"
when Str
    "string"
when Array
    "array"
end
```

### 3. Destructuring (Future QEP)

```quest
case point
when [0, 0]
    "origin"
when [x, 0]
    "on x-axis"
when [0, y]
    "on y-axis"
end
```

### 4. Guard Clauses (Future QEP)

```quest
case x
when n if n > 0
    "positive"
when n if n < 0
    "negative"
else
    "zero"
end
```

## Performance Considerations

### Potential Optimizations

1. **Jump Table:** For dense integer cases, compiler could generate jump table
2. **Hash Table:** For string cases, use hash lookup
3. **Short-circuit:** Stop evaluating when clauses after first match
4. **Constant Folding:** Optimize case expressions that are constant

**Note:** Start with naive implementation (linear search). Optimize later if profiling shows it's a bottleneck.

## Breaking Changes

**None.** This is a purely additive feature.

## Compatibility

- All existing code remains valid
- No migration needed
- `case` and `when` become reserved keywords (unlikely to break existing code)

## Open Questions

1. **Should we support fall-through with explicit keyword?**
   - Ruby doesn't have it
   - **Proposed:** No, keep it simple

2. **Should empty when blocks be allowed?**
   - Example: `when 1 when 2 puts("one or two")`
   - **Proposed:** No, require at least one statement or explicit nil

3. **Should case work with arbitrary boolean expressions?**
   - Example: `case when x > 10 ... when x < 0 ...`
   - This is Ruby's "case without argument"
   - **Proposed:** Not in this QEP, maybe future enhancement

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

The `case...when...else...end` statement brings Quest's control flow capabilities in line with Ruby and other modern languages. The Ruby-style syntax fits perfectly with Quest's existing syntax patterns and provides a clean, readable alternative to long `if/elif/else` chains.

This is a high-impact feature that will immediately improve code quality and developer experience.
