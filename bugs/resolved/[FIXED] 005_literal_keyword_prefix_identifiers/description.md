# Bug 005: Literal Keyword Prefix Identifiers

## Description
Identifiers that start with the literal keywords `nil`, `true`, or `false` (without an underscore separator) fail to parse, while identifiers starting with other keywords work fine.

## Failing Cases
```quest
let nilable = 1      # Parse error
let truely = 2       # Parse error
let falsey = 3       # Parse error
```

## Working Cases
```quest
let nil_value = 1    # Works (with underscore)
let true_flag = 2    # Works (with underscore)
let false_flag = 3   # Works (with underscore)

let if_statement = 4 # Works (other keywords are fine)
let function_name = 5 # Works
let while_loop = 6    # Works
```

## Error Message
```
Parse error:  --> line:col
  |
  | puts(nilable)
  |         ^---
  |
  = expected comparison_op, add_op, mul_op, or index_access
```

## Root Cause
The literal value keywords (`nil`, `true`, `false`) are tokenized differently than control flow keywords in the grammar. The parser treats them as complete tokens and doesn't allow them to be prefixes of longer identifiers.

## Expected Behavior
Identifiers like `nilable`, `truely`, `falsey` should parse successfully, just like `if_statement` and `function_name` do.
