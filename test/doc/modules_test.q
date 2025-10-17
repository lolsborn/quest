use "std/test" {it, describe, module, assert_eq, assert_neq, assert_type}

module("Module Docstrings")

describe("Module documentation", fun ()
  it("extracts docstring from module file", fun ()
    use "test/sample/_sample_module" as doc_module

    let doc = doc_module._doc()
    assert_eq(doc, "\nThis is a sample module for testing module docstrings.\nIt contains test functions and values.\n")
  end)

  it("returns default doc when module has no docstring", fun ()
    use "test/sample/_hello" as hello

    let doc = hello._doc()
    # Should have default format
    assert_eq(doc, "Module: hello")
  end)
end)

describe("Built-in module methods", fun ()
  it("_str returns module representation", fun ()
    use "test/sample/_sample_module" as doc_module

    let result_str = doc_module.str()
    assert_eq(result_str, "<module doc_module>")
  end)

  it("_rep returns module representation", fun ()
    use "test/sample/_sample_module" as doc_module

    let result_rep = doc_module._rep()
    assert_eq(result_rep, "<module doc_module>")
  end)

  it("_id returns unique identifier", fun ()
    use "test/sample/_sample_module" as doc1
    use "test/sample/_hello" as hello1

    # Different modules should have different IDs
    assert_neq(doc1._id(), hello1._id())
  end)
end)

describe("Standard library modules", fun ()
  it("can access _doc on standard library modules", fun ()
    use "std/math" as math

    # Math module might not have a docstring, but should have _doc method
    let doc = math._doc()
    assert_type(doc, "Str")  end)

  it("can access _doc on test module", fun ()
    use "std/test" as test_module

    let doc = test_module._doc()
    assert_type(doc, "Str")  end)
end)