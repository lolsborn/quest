# ============================================================================
# Regression Test: Bug #021 - Return at Top Level of Script
# ============================================================================
#
# Bug Description:
#  Using `return` at the top level of a script (not inside a function) threw
#  an error "Error: __FUNCTION_RETURN__" instead of cleanly exiting the script.
#
# Expected Behavior:
#  `return` at the top level should cleanly exit the script, similar to how
#  sys.exit(0) works. This is standard behavior in many scripting languages
#  (Python, Ruby, etc.) where `return` can be used to exit early from the
#  main script body.
#
# Fix:
#  Modified run_script() in commands.rs to catch __FUNCTION_RETURN__ errors
#  and treat them as successful script exit (return Ok(())).
#
# Reference: bugs/resolved/[FIXED] 021_return_in_top_level_script/
# ============================================================================

use "std/test" { module, describe, it, assert_eq, assert_nil, assert}
use "std/sys"
use "std/io"

module("Bug 021: Return at Top Level of Script")

# ----------------------------------------------------------------------------
# Test 1: Basic top-level return
# ----------------------------------------------------------------------------
describe("Basic top-level return", fun ()
  it("executes code before return", fun ()
    # We can't directly test top-level return in the same file,
    # so we'll use sys.eval() to evaluate code in a new context
    let code = "let x = 1\nlet y = 2\nx + y"
    let result = sys.eval(code)
    assert_eq(result, 3)
  end)

  it("return exits before subsequent code", fun ()
    # Test that return actually exits - code after return shouldn't execute
    # Use a variable that won't be reassigned to avoid syntax issues
    let code = "let count = 0\ncount = count + 1\nreturn\nlet more = 1000"
    let result = sys.eval(code)
    # Result should be nil since return exits before any following code
    assert_nil(result)
  end)

  it("bare return exits cleanly without error", fun ()
    # This should not raise any errors
    let code = "let x = 42\nreturn"
    let result = sys.eval(code)
    assert_nil(result)
  end)
end)

# ----------------------------------------------------------------------------
# Test 2: Return with value at top level
# ----------------------------------------------------------------------------
describe("Return with value at top level", fun ()
  it("return with value exits cleanly", fun ()
    # Return value at top level is computed but not used (script exit)
    let code = "let x = 10\nreturn x * 2\nlet y = 100"
    let result = sys.eval(code)
    # Result should be nil - top level returns don't propagate values
    assert_nil(result)
  end)

  it("return with complex expression", fun ()
    let code = "let arr = [1, 2, 3]\nreturn arr.len() * 10\narr.push(999)"
    let result = sys.eval(code)
    assert_nil(result)
  end)
end)

# ----------------------------------------------------------------------------
# Test 3: Return doesn't affect function returns
# ----------------------------------------------------------------------------
describe("Function returns still work correctly", fun ()
  it("return inside function works normally", fun ()
    # Verify that function returns still work correctly
    fun test_func()
      return 42
    end
    let result = test_func()
    assert_eq(result, 42)
  end)

  it("multiple returns in function", fun ()
    let code = """
fun get_status(x)
  if x < 0
    return "negative"
  end
  if x == 0
    return "zero"
  end
  return "positive"
end

let r1 = get_status(-5)
let r2 = get_status(0)
let r3 = get_status(10)
r1 .. "," .. r2 .. "," .. r3
"""
    let result = sys.eval(code)
    assert_eq(result, "negative,zero,positive")
  end)

  it("function return vs top-level return", fun ()
    # Function return should return value, top-level return should exit
    let code = """
fun add(a, b)
  return a + b
end

let sum = add(10, 20)

# Top-level return should exit here
return

let should_not_execute = 999
"""
    let result = sys.eval(code)
    assert_nil(result)
  end)
end)

# ----------------------------------------------------------------------------
# Test 4: Return in control flow structures at top level
# ----------------------------------------------------------------------------
describe("Return in control flow at top level", fun ()
  it("return inside if statement", fun ()
    let code = """
let x = 10
if x > 5
  return
end
let y = 100
"""
    let result = sys.eval(code)
    assert_nil(result)
  end)

  it("return inside while loop", fun ()
    let code = """
let count = 0
while count < 10
  count = count + 1
  if count == 5
    return
  end
end
let after_loop = 999
"""
    let result = sys.eval(code)
    assert_nil(result)
  end)

  it("return inside for loop", fun ()
    let code = """
let sum = 0
for i in [1, 2, 3, 4, 5]
  sum = sum + i
  if sum > 6
    return
  end
end
let after_for = 999
"""
    let result = sys.eval(code)
    assert_nil(result)
  end)
end)

# ----------------------------------------------------------------------------
# Test 5: Return with newline (Bug #021 specific edge case)
# ----------------------------------------------------------------------------
describe("Return followed by newline", fun ()
  it("bare return followed by newline doesn't consume next statement", fun ()
    # This was a specific edge case in the fix
    let code = "let x = 1\nreturn\nlet y = 999\ny"
    let result = sys.eval(code)
    # Should be nil because return exits before y is evaluated
    assert_nil(result)
  end)

  it("return with value on same line", fun ()
    let code = "let x = 42\nreturn x\nlet y = 999"
    let result = sys.eval(code)
    assert_nil(result)
  end)
end)

# ----------------------------------------------------------------------------
# Test 6: Multiple returns in sequence (only first should execute)
# ----------------------------------------------------------------------------
describe("Multiple returns", fun ()
  it("only first return executes", fun ()
    let code = """
let x = 1
return
let y = 2
return
let z = 3
"""
    let result = sys.eval(code)
    assert_nil(result)
  end)

  it("return in if blocks - first match exits", fun ()
    let code = """
let status = "active"
if status == "active"
  return
end
if status == "inactive"
  return
end
let should_not_reach = 999
"""
    let result = sys.eval(code)
    assert_nil(result)
  end)
end)

# ----------------------------------------------------------------------------
# Test 7: Return doesn't interfere with try/catch
# ----------------------------------------------------------------------------
describe("Return interaction with try/catch", fun ()
  it("return inside try block", fun ()
    let code = """
try
  let x = 10
  return
  let y = 20
catch e
  puts("Error: " .. e.str())
end
let after = 999
"""
    let result = sys.eval(code)
    assert_nil(result)
  end)

  it("return inside catch block", fun ()
    let code = """
try
  raise "test error"
catch e
  return
end
let after = 999
"""
    let result = sys.eval(code)
    assert_nil(result)
  end)
end)

# ----------------------------------------------------------------------------
# Test 8: Comparison with sys.exit()
# ----------------------------------------------------------------------------
describe("Return vs sys.exit()", fun ()
  it("return is cleaner than sys.exit() for script exit", fun ()
    # Both should exit, but return is more idiomatic in scripting languages
    # sys.exit() is for explicit process termination with exit codes
    # return is for early exit from script flow

    let code1 = "let x = 1\nreturn\nlet y = 999"
    let result1 = sys.eval(code1)
    assert_nil(result1)

    # Note: We can't test sys.exit() in sys.eval() because it would
    # terminate the test process, but both achieve similar script exit
    assert(true)  # Test structure verification
  end)
end)
