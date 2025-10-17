use "std/test" {module, it, describe, assert, assert_eq}

module("Control Flow - If/Elif/Else")

describe("Simple if statement", fun ()
  it("executes if branch when condition is true", fun ()
    let result = nil
    if true
      result = "if executed"
    end
    assert_eq(result, "if executed")
  end)

  it("skips if branch when condition is false", fun ()
    let result = "unchanged"
    if false
      result = "if executed"
    end
    assert_eq(result, "unchanged")
  end)
end)

describe("If with else", fun ()
  it("executes if branch when condition is true", fun ()
    let result = nil
    if true
      result = "if"
    else
      result = "else"
    end
    assert_eq(result, "if")
  end)

  it("executes else branch when condition is false", fun ()
    let result = nil
    if false
      result = "if"
    else
      result = "else"
    end
    assert_eq(result, "else")
  end)
end)

describe("If with elif", fun ()
  it("executes if branch when first condition is true", fun ()
    let value = 1
    let result = nil
    if value == 1
      result = "if"
    elif value == 2
      result = "elif"
    end
    assert_eq(result, "if")
  end)

  it("executes elif branch when if condition is false and elif condition is true", fun ()
    let value = 2
    let result = nil
    if value == 1
      result = "if"
    elif value == 2
      result = "elif"
    end
    assert_eq(result, "elif")
  end)

  it("executes neither branch when both conditions are false", fun ()
    let value = 3
    let result = "unchanged"
    if value == 1
      result = "if"
    elif value == 2
      result = "elif"
    end
    assert_eq(result, "unchanged")
  end)
end)

describe("If with multiple elif", fun ()
  it("executes first matching branch", fun ()
    let value = 2
    let result = nil
    if value == 1
      result = "if"
    elif value == 2
      result = "elif1"
    elif value == 2
      result = "elif2"
    end
    assert_eq(result, "elif1")
  end)

  it("executes second elif when first elif fails", fun ()
    let value = 3
    let result = nil
    if value == 1
      result = "if"
    elif value == 2
      result = "elif1"
    elif value == 3
      result = "elif2"
    end
    assert_eq(result, "elif2")
  end)
end)

describe("If with elif and else", fun ()
  it("executes if when condition is true", fun ()
    let value = 1
    let result = nil
    if value == 1
      result = "if"
    elif value == 2
      result = "elif"
    else
      result = "else"
    end
    assert_eq(result, "if")
  end)

  it("executes elif when if is false and elif is true", fun ()
    let value = 2
    let result = nil
    if value == 1
      result = "if"
    elif value == 2
      result = "elif"
    else
      result = "else"
    end
    assert_eq(result, "elif")
  end)

  it("executes else when all conditions are false", fun ()
    let value = 3
    let result = nil
    if value == 1
      result = "if"
    elif value == 2
      result = "elif"
    else
      result = "else"
    end
    assert_eq(result, "else")
  end)
end)

describe("If/elif/else in for loops", fun ()
  it("correctly executes branches for each iteration", fun ()
    let results = []
    for i in [1, 2, 3]
      if i == 1
        results.push("if")
      elif i == 2
        results.push("elif")
      else
        results.push("else")
      end
    end
    assert_eq(results, ["if", "elif", "else"])
  end)

  it("handles multiple elif in loop", fun ()
    let results = []
    for i in [1, 2, 3, 4]
      if i == 1
        results.push("a")
      elif i == 2
        results.push("b")
      elif i == 3
        results.push("c")
      else
        results.push("d")
      end
    end
    assert_eq(results, ["a", "b", "c", "d"])
  end)

  it("only executes one branch per iteration", fun ()
    let count = 0
    for i in [1, 2, 3]
      if i == 2
        count = count + 1
      elif i == 2
        count = count + 10  # Should not execute
      else
        count = count + 100  # Should not execute for i==2
      end
    end
    # Should be: 100 (i=1 else) + 1 (i=2 if) + 100 (i=3 else) = 201
    assert_eq(count, 201)
  end)
end)

describe("Nested if/elif/else", fun ()
  it("handles nested conditions correctly", fun ()
    let x = 1
    let y = 2
    let result = nil

    if x == 1
      if y == 2
        result = "nested"
      else
        result = "outer-if"
      end
    elif x == 2
      result = "elif"
    else
      result = "else"
    end

    assert_eq(result, "nested")
  end)
end)

describe("If/elif/else return values", fun ()
  it("returns value from if branch", fun ()
    fun test_if(x)
      if x == 1
        return "one"
      elif x == 2
        return "two"
      else
        return "other"
      end
    end

    assert_eq(test_if(1), "one")
  end)

  it("returns value from elif branch", fun ()
    fun test_elif(x)
      if x == 1
        return "one"
      elif x == 2
        return "two"
      else
        return "other"
      end
    end

    assert_eq(test_elif(2), "two")
  end)

  it("returns value from else branch", fun ()
    fun test_else(x)
      if x == 1
        return "one"
      elif x == 2
        return "two"
      else
        return "other"
      end
    end

    assert_eq(test_else(3), "other")
  end)
end)
