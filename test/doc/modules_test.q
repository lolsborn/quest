use "std/test" as test

test.module("Module Docstrings")

test.describe("Module documentation", fun ()
    test.it("extracts docstring from module file", fun ()
        use "test/sample/_sample_module" as doc_module

        let doc = doc_module._doc()
    end)

    test.it("returns default doc when module has no docstring", fun ()
        use "test/sample/_hello" as hello

        let doc = hello._doc()
        # Should have default format
    end)
end)

test.describe("Built-in module methods", fun ()
    test.it("_str returns module representation", fun ()
        use "test/sample/_sample_module" as doc_module

        let result_str = doc_module.str()
    end)

    test.it("_rep returns module representation", fun ()
        use "test/sample/_sample_module" as doc_module

        let result_rep = doc_module._rep()
    end)

    test.it("_id returns unique identifier", fun ()
        use "test/sample/_sample_module" as doc1
        use "test/sample/_hello" as hello1

        # Different modules should have different IDs
        test.assert_neq(doc1._id(), hello1._id())
    end)
end)

test.describe("Standard library modules", fun ()
    test.it("can access _doc on standard library modules", fun ()
        use "std/math" as math

        # Math module might not have a docstring, but should have _doc method
        let doc = math._doc()
        test.assert_type(doc, "Str")    end)

    test.it("can access _doc on test module", fun ()
        use "std/test" as test_module

        let doc = test_module._doc()
        test.assert_type(doc, "Str")    end)
end)