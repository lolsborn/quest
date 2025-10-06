# Test qualified type names from modules
use "std/test" as test
use "std/process" as process

test.module("Qualified Type Names")

test.describe("Module type exports", fun ()
    test.it("exports Process type", fun ()
        # Check that Process is available from the module
        test.assert(process.Process != nil, "Process type should be exported")
    end)

    test.it("exports ProcessResult type", fun ()
        # Check that ProcessResult is available from the module
        test.assert(process.ProcessResult != nil, "ProcessResult type should be exported")
    end)
end)

test.describe("Using qualified types in type declarations", fun ()
    test.it("allows qualified type in field declaration", fun ()
        type ProcessWrapper
            pub name: Str
            pub proc: process.Process?
        end

        let pw = ProcessWrapper.new(name: "test")
        test.assert_eq(pw.name, "test", nil)
        test.assert_nil(pw.proc, "proc should be nil when not provided")
    end)

    test.it("works with non-optional qualified types", fun ()
        type ProcessResult
            pub result: process.ProcessResult
        end

        # Note: We can't easily test this without actually running a process,
        # but the type declaration should parse successfully
        test.assert(true, "Type declaration with qualified type succeeded")
    end)
end)

test.describe("Built-in types still work", fun ()
    test.it("allows built-in types alongside qualified types", fun ()
        type MixedTypes
            pub simple: Int
            pub qualified: process.Process?
            pub text: Str
        end

        let mt = MixedTypes.new(simple: 42, text: "hello")
        test.assert_eq(mt.simple, 42, nil)
        test.assert_eq(mt.text, "hello", nil)
        test.assert_nil(mt.qualified, nil)
    end)
end)
