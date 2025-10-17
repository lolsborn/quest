use "std/test" { module, describe, it, assert_eq, assert_raises }

module("Dict Unpacking Override (QEP-035)")

describe("Last value wins behavior", fun ()
  it("should allow explicit named args to override unpacked dict values", fun ()
    fun test_fn(a, b, c)
      a .. "," .. b.str() .. "," .. c.str()
    end

    let args_dict = {a: 1, b: 2, c: 3}

    # Override b with explicit named arg (last value wins)
    let result = test_fn(**args_dict, b: 5)
    assert_eq(result, "1,5,3")
  end)

  it("should allow unpacked dict to override earlier named args", fun ()
    fun test_fn(a, b, c)
      a .. "," .. b.str() .. "," .. c.str()
    end

    let args_dict = {b: 10, c: 20}

    # Dict unpacking overrides earlier named arg (last value wins)
    let result = test_fn(a: 1, b: 2, **args_dict, c: 30)
    assert_eq(result, "1,10,30")
  end)

  it("should handle multiple overrides with last value winning", fun ()
    fun test_fn(x, y)
      x.str() .. "," .. y.str()
    end

    let dict1 = {x: 1, y: 2}
    let dict2 = {y: 3}

    # Multiple dict unpacks and explicit override
    let result = test_fn(**dict1, **dict2, y: 99)
    assert_eq(result, "1,99")
  end)

  it("should still reject duplicate explicit keyword arguments", fun ()
    fun test_fn(a, b)
      a .. "," .. b.str()
    end

    # Duplicate explicit keywords should be rejected
    assert_raises(ArgErr, fun ()
      test_fn(a: "foo", b: 2, b: 3)
    end, "Should reject duplicate explicit keywords")
  end)
end)
