use "std/test"

test.module("Match Statement (QEP-016)")

test.describe("Basic match statement", fun ()
  test.it("matches single value", fun ()
    fun get_result()
      match 1
      in 1
        "one"
      in 2
        "two"
      else
        "other"
      end
    end

    test.assert_eq(get_result(), "one")
  end)

  test.it("matches multiple values", fun ()
    fun get_result()
      match 2
        in 1
          "one"
        in 2, 3, 4
          "two-four"
        else
          "other"
      end
    end

    test.assert_eq(get_result(), "two-four")
  end)

  test.it("uses else clause when no match", fun ()
    fun get_result()
      match 99
      in 1
        "one"
      in 2
        "two"
      else
        "other"
      end
    end

    test.assert_eq(get_result(), "other")
  end)

  test.it("returns nil when no match and no else", fun ()
    fun get_result()
      match 99
      in 1
        "one"
      in 2
        "two"
      end
    end

    test.assert_eq(get_result(), nil)
  end)
end)

test.describe("Match with different types", fun ()
  test.it("matches strings", fun ()
    fun get_result(day)
      match day
      in "Monday"
        "Start"
      in "Friday"
        "TGIF"
      else
        "Other"
      end
    end

    test.assert_eq(get_result("Friday"), "TGIF")
  end)

  test.it("matches booleans", fun ()
    fun get_result()
      match true
      in true
        "yes"
      in false
        "no"
      end
    end

    test.assert_eq(get_result(), "yes")
  end)

  test.it("matches integers", fun ()
    fun get_result(x)
      match x
      in 1, 2, 3
        "small"
      in 42
        "answer"
      else
        "other"
      end
    end

    test.assert_eq(get_result(42), "answer")
  end)
end)

test.describe("Match as last statement in function", fun ()
  test.it("returns match result", fun ()
    fun get_value(x)
      match x
      in 1
        "one"
      in 2
        "two"
      else
        "other"
      end
    end

    test.assert_eq(get_value(2), "two")
  end)
end)

test.describe("Nested match statements", fun ()
  test.it("supports nesting and returns nested value", fun ()
    fun get_result(outer, inner)
      match outer
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
    end

    test.assert_eq(get_result(1, 2), "1-2")
  end)

  test.it("nested match returns correct value type", fun ()
    fun get_result(outer, inner)
      match outer
      in 1
        42
      in 2
        match inner
        in 3
          99
        else
          0
        end
      else
        -1
      end
    end

    let result = get_result(2, 3)
    test.assert_eq(result, 99)
    test.assert_type(result, "Int")
  end)
end)

test.describe("Edge cases", fun ()
  test.it("handles nil match value", fun ()
    fun get_result()
      match nil
      in nil
        "matched nil"
      else
        "other"
      end
    end

    test.assert_eq(get_result(), "matched nil")
  end)

  test.it("executes first matching in block", fun ()
    fun get_result()
      match 1
      in 1
        "first"
      in 1
        "second"
      end
    end

    test.assert_eq(get_result(), "first")
  end)

  test.it("works with complex expressions", fun ()
    fun get_result(x)
      match x * 2
      in 10
        "matched"
      else
        "no match"
      end
    end

    test.assert_eq(get_result(5), "matched")
  end)

  test.it("matches array literals", fun ()
    fun get_result()
      match [1, 2, 3]
      in [1, 2, 3]
        "array matched"
      else
        "no match"
      end
    end

    test.assert_eq(get_result(), "array matched")
  end)

  test.it("distinguishes comma-separated values from arrays", fun ()
    fun test1(x)
      match x
      in 1, 2, 3
        "found"
      else
        "not found"
      end
    end

    fun test2(x)
      match x
      in [1, 2, 3]
        "found"
      else
        "not found"
      end
    end

    test.assert_eq(test1(2), "found")
    test.assert_eq(test2(2), "not found")
  end)
end)

test.describe("Control flow inside match", fun ()
  test.it("allows return to exit function", fun ()
    fun test_return(x)
      let before = "before"
      match x
      in 0
        return "zero"
      in 1
        return "one"
      end
      "unreachable"
    end

    test.assert_eq(test_return(0), "zero")
    test.assert_eq(test_return(1), "one")
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

    test.assert_eq(results, [1, 2])
  end)

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

    test.assert_eq(results, [1, 3, 5])
  end)
end)

test.describe("Real-world examples", fun ()
  test.it("HTTP status code handler", fun ()
    fun handle_status(code)
      match code
      in 200, 201, 204
        "success"
      in 400, 401, 403
        "client_error"
      in 404
        "not_found"
      in 500, 502, 503
        "server_error"
      else
        "unknown"
      end
    end

    test.assert_eq(handle_status(200), "success")
    test.assert_eq(handle_status(404), "not_found")
    test.assert_eq(handle_status(500), "server_error")
    test.assert_eq(handle_status(999), "unknown")
  end)

  test.it("command dispatcher", fun ()
    fun dispatch(cmd)
      match cmd
      in "help", "h", "?"
        "show_help"
      in "quit", "exit", "q"
        "exit_program"
      in "list", "ls"
        "list_items"
      else
        "unknown_command"
      end
    end

    test.assert_eq(dispatch("help"), "show_help")
    test.assert_eq(dispatch("?"), "show_help")
    test.assert_eq(dispatch("quit"), "exit_program")
    test.assert_eq(dispatch("ls"), "list_items")
    test.assert_eq(dispatch("foo"), "unknown_command")
  end)

  test.it("state machine", fun ()
    fun process_state(state)
      match state
      in "pending"
        "processing"
      in "approved"
        "complete"
      in "rejected"
        "failed"
      else
        "invalid"
      end
    end

    test.assert_eq(process_state("pending"), "processing")
    test.assert_eq(process_state("approved"), "complete")
    test.assert_eq(process_state("rejected"), "failed")
    test.assert_eq(process_state("foo"), "invalid")
  end)
end)

test.describe("Multi-line value lists", fun ()
  test.it("supports newlines in comma-separated values", fun ()
    fun get_grade(grade)
      match grade
      in 90, 91, 92,
         93, 94, 95,
         96, 97, 98,
         99, 100
        "A"
      in 80, 81, 82,
         83, 84, 85
        "B"
      else
        "F"
      end
    end

    test.assert_eq(get_grade(95), "A")
  end)
end)

test.describe("Match with side effects", fun ()
  test.it("evaluates match expression only once", fun ()
    let counter = 0
    fun increment_and_return()
      counter = counter + 1
      counter
    end

    fun test_match()
      match increment_and_return()
      in 1
        "matched"
      else
        "not matched"
      end
    end

    test_match()
    test.assert_eq(counter, 1)
  end)

  test.it("evaluates in expressions lazily", fun ()
    let eval_count = 0
    fun track_eval(val)
      eval_count = eval_count + 1
      val
    end

    fun test_match(x)
      match x
      in track_eval(1), track_eval(2), track_eval(3)
        "found"
      else
        "not found"
      end
    end

    test_match(2)
    test.assert_eq(eval_count, 2)
  end)
end)
