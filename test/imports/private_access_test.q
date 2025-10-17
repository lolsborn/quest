"""
Test private member access restrictions (QEP-043)
"""

use "std/test" {module, describe, it, assert_eq, assert_raises}

module("Private Member Access")

describe("Private member imports", fun ()
  it("allows importing public functions", fun ()
    use "test/imports/module_with_private" {public_function}
    assert_eq(public_function(), "I am public")
  end)

  it("blocks importing private functions", fun ()
    assert_raises(ImportErr, fun ()
      use "test/imports/module_with_private" {private_function}
    end)
  end)

  it("allows importing public types", fun ()
    use "test/imports/module_with_private" {PublicType}
    let obj = PublicType.new(field: 10)
    assert_eq(obj.field, 10)
  end)

  it("blocks importing private types", fun ()
    assert_raises(ImportErr, fun ()
      use "test/imports/module_with_private" {PrivateType}
    end)
  end)

  it("allows importing public constants", fun ()
    use "test/imports/module_with_private" {PUBLIC_CONSTANT}
    assert_eq(PUBLIC_CONSTANT, 42)
  end)

  it("blocks importing private constants", fun ()
    assert_raises(ImportErr, fun ()
      use "test/imports/module_with_private" {PRIVATE_CONSTANT}
    end)
  end)

  it("allows public functions to access private members internally", fun ()
    use "test/imports/module_with_private" {uses_private}
    # Public function can call private function internally
    assert_eq(uses_private(), "I am private (via public)")
  end)
end)

describe("Module alias access", fun ()
  it("allows public member access via module prefix", fun ()
    use "test/imports/module_with_private" as priv
    assert_eq(priv.public_function(), "I am public")
  end)

  it("blocks private member access via module prefix", fun ()
    use "test/imports/module_with_private" as priv
    # Private members should not be accessible even with module prefix
    assert_raises(AttrErr, fun ()
      priv.private_function()
    end)
  end)
end)
