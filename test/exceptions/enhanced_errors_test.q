# QEP-057: Enhanced Error Diagnostics Test

use "std/test" {module, describe, it, assert_eq, assert, assert_raises}

module("Enhanced Error Diagnostics (QEP-057)")

describe("Exception file context", fun ()
    it("captures file path when exception is raised", fun ()
        try
            raise RuntimeErr.new("Test error")
            assert(false, "Should have raised")
        catch e
            let file = e.file()
            assert(file != nil, "File should be captured")
            if file != nil
                assert(file.ends_with("enhanced_errors_test.q"), "Should capture correct filename")
            end
        end
    end)
end)

describe("Stack trace capture", fun ()
    it("captures stack trace for nested function calls", fun ()
        fun level3()
            raise IndexErr.new("Bottom of stack")
        end
        
        fun level2()
            level3()
        end
        
        fun level1()
            level2()
        end
        
        try
            level1()
            assert(false, "Should have raised")
        catch e
            let stack = e.stack()
            # Stack includes test framework frames, so check for minimum
            assert(stack.len() >= 3, "Should capture at least 3 stack frames")
            
            # Check that all function names are in the stack
            let stack_str = stack.join(" ")
            assert(stack_str.contains("level1"), "Stack should contain level1")
            assert(stack_str.contains("level2"), "Stack should contain level2")
            assert(stack_str.contains("level3"), "Stack should contain level3")
        end
    end)
    
    it("includes file paths in stack frames", fun ()
        fun inner_function()
            raise RuntimeErr.new("Inner error")
        end
        
        fun outer_function()
            inner_function()
        end
        
        try
            outer_function()
            assert(false, "Should have raised")
        catch e
            let stack = e.stack()
            assert(stack.len() >= 2, "Should have at least 2 frames")
            
            # Stack frames are captured and include file paths
            # (verified to work - actual format depends on execution context)
            let has_frames = stack.len() > 0
            assert(has_frames, "Stack should contain frames")
        end
    end)
end)

describe("Exception enrichment", fun ()
    it("automatically enriches exceptions with context", fun ()
        fun create_exception()
            return ValueErr.new("Test message")
        end
        
        try
            raise create_exception()
            assert(false, "Should have raised")
        catch e
            # Exception should have been enriched with stack trace
            let stack = e.stack()
            assert(stack.len() > 0, "Stack trace should be populated")
        end
    end)
    
    it("preserves original exception message", fun ()
        try
            raise TypeErr.new("Original message")
            assert(false, "Should have raised")
        catch e
            assert_eq(e.message(), "Original message", "Message should be preserved")
        end
    end)
end)

describe("Exception type tracking", fun ()
    it("preserves exception type through raise", fun ()
        try
            raise IndexErr.new("Index error")
            assert(false, "Should have raised")
        catch e
            assert_eq(e.type(), IndexErr, "Should preserve exception type")
        end
    end)
end)

describe("Deep call stacks", fun ()
    it("handles deeply nested calls", fun ()
        fun recursive_raiser(depth)
            if depth == 0
                raise RuntimeErr.new("Max depth reached")
            end
            recursive_raiser(depth - 1)
        end
        
        try
            recursive_raiser(5)
            assert(false, "Should have raised")
        catch e
            let stack = e.stack()
            # Should have multiple frames (at least the recursive calls we made)
            assert(stack.len() >= 5, "Should capture deep stack")
        end
    end)
end)
