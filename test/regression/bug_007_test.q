# Regression Test: Bug 007 - Return Statement Not Exiting Function
# 
# Bug Description:
#  The `return` statement did not immediately exit a function when used inside
#  an `if` block. Functions continued executing subsequent statements after the
#  `return`, leading to incorrect behavior.
# 
#  Example that failed:
#   fun test_return(x)
#    if x.eq(1)
#      return "first"  # Should exit here
#    end
#    if x.eq(1)
#      return "second"  # But execution continued
#    end
#    return "third"    # And returned this instead
#   end
#   # Expected: "first", Actual: "third"
# 
# Solution:
#  Implemented control flow mechanism for function returns:
#  1. Added `return_value` field to `Scope` struct to store return values
#  2. Modified return statement handler to store value and signal `__FUNCTION_RETURN__`
#  3. Updated `call_user_function` to catch signal and retrieve stored value
#  4. Control flow structures (if/while/for) propagate the signal correctly
# 
# Status: Fixed - 2025-10-04

use "std/test" { module, describe, it, assert_eq, assert_nil  }

module("Bug 007: Return Statement Not Exiting Function")

describe("Multiple if blocks with returns", fun ()
  it("returns from first matching if block", fun ()
    fun test_return(x)
      if x.eq(1)
        return "first"
      end
      if x.eq(1)
        return "second"
      end
      return "third"
    end

    let result = test_return(1)
    assert_eq(result, "first")
  end)

  it("does not execute code after first return", fun ()
    fun test_with_side_effects(x)
      let counter = 0
      if x.eq(1)
        counter = counter.plus(1)
        return counter
      end
      if x.eq(1)
        counter = counter.plus(10)
        return counter
      end
      counter = counter.plus(100)
      return counter
    end

    let result = test_with_side_effects(1)
    assert_eq(result, 1)
  end)

  it("handles header formatting pattern", fun ()
    fun format_line(line)
      if line.startswith("### ")
        return "H3"
      end
      if line.startswith("## ")
        return "H2"
      end
      if line.startswith("# ")
        return "H1"
      end
      return "regular"
    end

    assert_eq(format_line("# Header"), "H1")
    assert_eq(format_line("## Section"), "H2")
    assert_eq(format_line("### Subsection"), "H3")
    assert_eq(format_line("Normal text"), "regular")
  end)

  it("returns correct value for non-matching conditions", fun ()
    fun test_return(x)
      if x.eq(1)
        return "first"
      end
      if x.eq(2)
        return "second"
      end
      return "third"
    end

    assert_eq(test_return(5), "third")
    assert_eq(test_return(2), "second")
  end)
end)

describe("Return in loops", fun ()
  it("returns from while loop", fun ()
    fun find_in_loop()
      let i = 0
      while i.lt(10)
        if i.eq(3)
          return "found three"
        end
        i = i.plus(1)
      end
      return "not found"
    end

    assert_eq(find_in_loop(), "found three")
  end)

  it("returns from for loop", fun ()
    fun find_in_for_loop()
      for i in 0 to 10
        if i.eq(5)
          return "found five"
        end
      end
      return "not found"
    end

    assert_eq(find_in_for_loop(), "found five")
  end)

  it("returns from nested loops", fun ()
    fun find_in_nested_loops()
      for i in 0 to 5
        for j in 0 to 5
          if i.eq(2) and j.eq(3)
           return "found at 2,3"
          end
        end
      end
      return "not found"
    end

    assert_eq(find_in_nested_loops(), "found at 2,3")
  end)

  it("distinguishes return from break", fun ()
    fun return_vs_break(use_return)
      for i in 0 to 10
        if use_return
          return "returned"
        end
        if i.eq(3)
          break
        end
      end
      return "after loop"
    end

    assert_eq(return_vs_break(true), "returned")
    assert_eq(return_vs_break(false), "after loop")
  end)
end)

describe("Return in nested if statements", fun ()
  it("returns from nested if", fun ()
    fun nested_if_return(x, y)
      if x.gt(0)
        if y.gt(0)
          return "both positive"
        end
        return "x positive"
      end
      return "x not positive"
    end

    assert_eq(nested_if_return(5, 3), "both positive")
    assert_eq(nested_if_return(5, -1), "x positive")
    assert_eq(nested_if_return(-1, 3), "x not positive")
  end)

  it("returns from deeply nested if", fun ()
    fun deeply_nested(a, b, c)
      if a.gt(0)
        if b.gt(0)
          if c.gt(0)
           return "all positive"
          end
          return "a and b positive"
        end
        return "only a positive"
      end
      return "a not positive"
    end

    assert_eq(deeply_nested(1, 2, 3), "all positive")
    assert_eq(deeply_nested(1, 2, -1), "a and b positive")
    assert_eq(deeply_nested(1, -1, 3), "only a positive")
    assert_eq(deeply_nested(-1, 2, 3), "a not positive")
  end)
end)

describe("Return with different value types", fun ()
  it("returns int", fun ()
    fun return_int()
      if true
        return 42
      end
      return 0
    end

    assert_eq(return_int(), 42)
  end)

  it("returns float", fun ()
    fun return_float()
      if true
        return 3.14
      end
      return 0.0
    end

    assert_eq(return_float(), 3.14)
  end)

  it("returns bool", fun ()
    fun return_bool()
      if true
        return true
      end
      return false
    end

    assert_eq(return_bool(), true)
  end)

  it("returns nil explicitly", fun ()
    fun return_nil()
      if true
        return nil
      end
      return "not nil"
    end

    assert_nil(return_nil())
  end)

  it("returns array", fun ()
    fun return_array()
      if true
        return [1, 2, 3]
      end
      return []
    end

    let result = return_array()
    assert_eq(result.len(), 3)
    assert_eq(result.get(0), 1)
  end)

  it("returns dict", fun ()
    fun return_dict()
      if true
        return {"key": "value"}
      end
      return {}
    end

    let result = return_dict()
    assert_eq(result.get("key"), "value")
  end)
end)

describe("Return in elif/else branches", fun ()
  it("returns from elif branch", fun ()
    fun test_elif(x)
      if x.eq(1)
        return "one"
      elif x.eq(2)
        return "two"
      elif x.eq(3)
        return "three"
      else
        return "other"
      end
    end

    assert_eq(test_elif(2), "two")
    assert_eq(test_elif(3), "three")
  end)

  it("returns from else branch", fun ()
    fun test_else(x)
      if x.eq(1)
        return "one"
      else
        return "not one"
      end
    end

    assert_eq(test_else(5), "not one")
  end)

  it("returns from elif with multiple ifs after", fun ()
    fun test_elif_and_ifs(x)
      if x.eq(1)
        return "one"
      elif x.eq(2)
        return "two"
      end

      if x.eq(2)
        return "should not reach"
      end

      return "end"
    end

    assert_eq(test_elif_and_ifs(2), "two")
  end)
end)

describe("Early return pattern (guard clauses)", fun ()
  it("uses guard clause pattern", fun ()
    fun validate_input(x)
      if x.lt(0)
        return "error: negative"
      end
      if x.eq(0)
        return "error: zero"
      end
      if x.gt(100)
        return "error: too large"
      end
      return "valid"
    end

    assert_eq(validate_input(-5), "error: negative")
    assert_eq(validate_input(0), "error: zero")
    assert_eq(validate_input(150), "error: too large")
    assert_eq(validate_input(50), "valid")
  end)

  it("uses multiple guard clauses for complex validation", fun ()
    fun process_value(val, enabled, ready)
      if not enabled
        return "disabled"
      end
      if not ready
        return "not ready"
      end
      if val.lt(1)
        return "invalid value"
      end
      return "processing"
    end

    assert_eq(process_value(5, false, true), "disabled")
    assert_eq(process_value(5, true, false), "not ready")
    assert_eq(process_value(0, true, true), "invalid value")
    assert_eq(process_value(5, true, true), "processing")
  end)
end)

describe("Return with nested functions", fun ()
  it("returns from inner function", fun ()
    fun outer()
      fun inner()
        return "inner return"
        return "should not reach"
      end

      let result = inner()
      return result .. " -> outer"
    end

    assert_eq(outer(), "inner return -> outer")
  end)

  it("returns from outer function with inner call", fun ()
    fun outer(x)
      fun inner(y)
        if y.eq(5)
          return "inner: five"
        end
        return "inner: other"
      end

      if x.eq(1)
        return "outer: early"
      end

      return inner(x)
    end

    assert_eq(outer(1), "outer: early")
    assert_eq(outer(5), "inner: five")
    assert_eq(outer(10), "inner: other")
  end)

  it("handles multiple levels of nesting", fun ()
    fun level1()
      fun level2()
        fun level3()
          if true
           return "deep"
          end
          return "not reached"
        end
        return level3() .. "-2"
      end
      return level2() .. "-1"
    end

    assert_eq(level1(), "deep-2-1")
  end)
end)

describe("Return without expression", fun ()
  it("returns nil when no expression provided", fun ()
    fun return_nothing()
      if true
        return
      end
      return "not reached"
    end

    assert_nil(return_nothing())
  end)

  it("returns nil from early exit", fun ()
    fun early_exit(x)
      if x.lt(0)
        return
      end
      return "positive"
    end

    assert_nil(early_exit(-5))
    assert_eq(early_exit(5), "positive")
  end)
end)

describe("Return with expressions", fun ()
  it("returns result of expression", fun ()
    fun compute(x)
      if x.gt(0)
        return x.times(2)
      end
      return 0
    end

    assert_eq(compute(5), 10)
    assert_eq(compute(-5), 0)
  end)

  it("returns result of complex expression", fun ()
    fun calculate(a, b)
      if a.gt(b)
        return a.minus(b).times(2)
      end
      return b.minus(a)
    end

    assert_eq(calculate(10, 3), 14)
    assert_eq(calculate(3, 10), 7)
  end)

  it("returns result of method chain", fun ()
    fun format_text(text, uppercase)
      if uppercase
        return text.upper().trim()
      end
      return text.lower().trim()
    end

    assert_eq(format_text("  HELLO  ", true), "HELLO")
    assert_eq(format_text("  HELLO  ", false), "hello")
  end)
end)

describe("Return in combination with other control flow", fun ()
  it("combines return with continue", fun ()
    fun process_array(arr, early_exit)
      let sum = 0
      for item in arr
        if early_exit and item.gt(5)
          return sum
        end
        if item.lt(0)
          continue
        end
        sum = sum.plus(item)
      end
      return sum
    end

    assert_eq(process_array([1, 2, 3, 6, 7], true), 6)
    assert_eq(process_array([1, 2, -3, 4], false), 7)
  end)

  it("combines return with break", fun ()
    fun search_nested(matrix, target)
      for row in matrix
        for val in row
          if val.eq(target)
           return true
          end
          if val.gt(100)
           break
          end
        end
      end
      return false
    end

    assert_eq(search_nested([[1, 2], [3, 4]], 3), true)
    assert_eq(search_nested([[1, 2], [3, 4]], 10), false)
  end)
end)

describe("Edge cases", fun ()
  it("handles function with only return statement", fun ()
    fun just_return()
      return 42
    end

    assert_eq(just_return(), 42)
  end)

  it("handles multiple sequential returns in separate blocks", fun ()
    fun sequential_returns(a, b, c)
      if a
        return "a"
      end
      if b
        return "b"
      end
      if c
        return "c"
      end
      return "none"
    end

    assert_eq(sequential_returns(true, true, true), "a")
    assert_eq(sequential_returns(false, true, true), "b")
    assert_eq(sequential_returns(false, false, true), "c")
    assert_eq(sequential_returns(false, false, false), "none")
  end)

  it("handles return in if with no else and code after", fun ()
    fun return_with_code_after(x)
      if x.eq(1)
        return "returned"
      end
      let y = 10
      return y.to_string()
    end

    assert_eq(return_with_code_after(1), "returned")
    assert_eq(return_with_code_after(2), "10")
  end)
end)
