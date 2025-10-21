# QEP-057: Line Number and File Context Tests

use "std/test" {module, describe, it, assert, assert_eq, assert_raises}

module("QEP-057: Error Context")

describe("File context in errors", fun ()
    it("captures file for Quest exceptions", fun ()
        try
            raise RuntimeErr.new("test error")
        catch e
            assert(e.file() != nil, "Should have file context")
            let file = e.file()
            if file != nil
                assert(file.contains(".q"), "Should be a Quest file")
            end
        end
    end)
    
    it("captures file for Rust TypeErr", fun ()
        try
            let _ = "string" + 5
        catch e
            assert(e.file() != nil, "Rust TypeErr should have file context")
        end
    end)
    
    it("captures file for Rust ArgErr", fun ()
        try
            let arr = [1]
            arr.push(2, 3)  # Wrong number of arguments
        catch e
            # Should have file even though error comes from Rust
            assert(e.file() != nil, "Rust ArgErr should have file context")
        end
    end)
end)

describe("Line numbers in errors", fun ()
    it("captures line number for exceptions", fun ()
        try
            raise RuntimeErr.new("test")
        catch e
            assert(e.line() != nil, "Should have line number")
            if e.line() != nil
                assert(e.line() > 0, "Line should be positive")
            end
        end
    end)
    
    it("captures line number for Rust errors", fun ()
        try
            let _ = "string" + 5
        catch e
            assert(e.line() != nil, "Rust errors should have line numbers")
        end
    end)
end)

describe("Stack traces", fun ()
    it("captures stack trace for nested calls", fun ()
        fun inner()
            raise RuntimeErr.new("from inner")
        end
        
        fun outer()
            inner()
        end
        
        try
            outer()
        catch e
            let stack = e.stack()
            # Stack includes test framework, so just check it's non-empty
            assert(stack.len() > 0, "Should have stack trace")
            
            # Check that our functions are in the stack
            let stack_str = stack.join(" ")
            assert(stack_str.contains("inner"), "Stack should contain 'inner'")
            assert(stack_str.contains("outer"), "Stack should contain 'outer'")
        end
    end)
    
    it("stack frames are captured and non-empty", fun ()
        fun make_error()
            raise ValueErr.new("test")
        end
        
        try
            make_error()
        catch e
            let stack = e.stack()
            # Stack should be captured (may include test framework frames)
            assert(stack.len() > 0, "Should capture stack frames")
        end
    end)
end)

describe("Combined context", fun ()
    it("shows file, line, and stack together", fun ()
        fun cause_error()
            raise IndexErr.new("combined context test")
        end
        
        try
            cause_error()
        catch e
            # All three should be present
            assert(e.file() != nil, "Should have file")
            assert(e.line() != nil, "Should have line")  
            assert(e.stack().len() > 0, "Should have stack")
        end
    end)
end)

describe("Error context for different exception types", fun ()
    it("works for RuntimeErr", fun ()
        try
            raise RuntimeErr.new("runtime")
        catch e
            assert(e.file() != nil, "RuntimeErr should have file")
            assert(e.line() != nil, "RuntimeErr should have line")
        end
    end)
    
    it("works for ValueErr", fun ()
        try
            raise ValueErr.new("value")
        catch e
            assert(e.file() != nil, "ValueErr should have file")
            assert(e.line() != nil, "ValueErr should have line")
        end
    end)
    
    it("works for TypeErr", fun ()
        try
            raise TypeErr.new("type")
        catch e
            assert(e.file() != nil, "TypeErr should have file")
            assert(e.line() != nil, "TypeErr should have line")
        end
    end)
    
    it("works for custom exceptions", fun ()
        try
            raise IndexErr.new("index")
        catch e
            assert(e.file() != nil, "IndexErr should have file")
            assert(e.line() != nil, "IndexErr should have line")
        end
    end)
end)
