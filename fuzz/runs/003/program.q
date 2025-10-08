# Fuzz Test 003: Typed Exception System Stress Test
# Tests exception handling with typed exceptions, hierarchies,
# stack traces, nested try/catch, and interaction with functions,
# closures, user types, and control flow

use "std/test"

test.module("Exception System Fuzz Test")

# Test 1: Basic exception type hierarchy
test.describe("Exception Type Hierarchy", fun ()
    test.it("catches specific exception types", fun ()
        let caught = false
        try
            raise IndexErr.new("array index 10 out of bounds")
        catch e: IndexErr
            caught = true
            test.assert(e.message().contains("out of bounds"))
        end
        test.assert(caught)
    end)

    test.it("catches base Err type for all exceptions", fun ()
        let caught = false
        try
            raise ValueErr.new("invalid value: -1")
        catch e: Err
            caught = true
            test.assert_eq(e.type(), "ValueErr")
        end
        test.assert(caught)
    end)

    test.it("respects catch order with hierarchical types", fun ()
        let which = ""
        try
            raise TypeErr.new("expected str, got int")
        catch e: IndexErr
            which = "index"
        catch e: TypeErr
            which = "type"
        catch e: Err
            which = "base"
        end
        test.assert_eq(which, "type")
    end)

    test.it("falls through to base handler if specific not matched", fun ()
        let which = ""
        try
            raise KeyErr.new("key 'foo' not found")
        catch e: IndexErr
            which = "index"
        catch e: TypeErr
            which = "type"
        catch e: Err
            which = "base"
        end
        test.assert_eq(which, "base")
    end)
end)

# Test 2: Stack traces and error propagation
test.describe("Stack Traces and Propagation", fun ()
    fun level3()
        raise RuntimeErr.new("error at level 3")
    end

    fun level2()
        level3()
    end

    fun level1()
        level2()
    end

    test.it("propagates exceptions through call stack", fun ()
        let caught = false
        try
            level1()
        catch e: RuntimeErr
            caught = true
            let stack = e.stack()
            test.assert(stack.len() > 0)
        end
        test.assert(caught)
    end)

    test.it("captures exception in deeply nested functions", fun ()
        let caught_message = ""
        try
            level1()
        catch e: Err
            caught_message = e.message()
        end
        test.assert_eq(caught_message, "error at level 3")
    end)
end)

# Test 3: Nested try/catch blocks
test.describe("Nested Try/Catch", fun ()
    test.it("handles nested exceptions independently", fun ()
        let outer = false
        let inner = false

        try
            outer = true
            try
                inner = true
                raise IndexErr.new("inner error")
            catch e: IndexErr
                test.assert_eq(e.message(), "inner error")
            end
            raise TypeErr.new("outer error")
        catch e: TypeErr
            test.assert_eq(e.message(), "outer error")
        end

        test.assert(outer)
        test.assert(inner)
    end)

    test.it("allows inner exception to propagate if not caught", fun ()
        let caught_outer = false
        try
            try
                raise ValueErr.new("value error")
            catch e: IndexErr
                # Won't catch ValueErr
            end
        catch e: ValueErr
            caught_outer = true
        end
        test.assert(caught_outer)
    end)

    test.it("handles multiple exception types in nested blocks", fun ()
        let results = []

        try
            try
                raise IndexErr.new("index")
            catch e: IndexErr
                results.push("inner-index")
                raise TypeErr.new("type")
            end
        catch e: TypeErr
            results.push("outer-type")
        end

        test.assert_eq(results.len(), 2)
        test.assert_eq(results[0], "inner-index")
        test.assert_eq(results[1], "outer-type")
    end)
end)

# Test 4: Exceptions with ensure blocks
test.describe("Ensure Blocks", fun ()
    test.it("executes ensure block on normal completion", fun ()
        let ensure_ran = false
        try
            let x = 42
        ensure
            ensure_ran = true
        end
        test.assert(ensure_ran)
    end)

    test.it("executes ensure block when exception caught", fun ()
        let ensure_ran = false
        try
            raise RuntimeErr.new("test")
        catch e: Err
            # Catch it
        ensure
            ensure_ran = true
        end
        test.assert(ensure_ran)
    end)

    test.it("executes ensure with nested try blocks", fun ()
        let outer_ensure = false
        let inner_ensure = false

        try
            try
                raise IndexErr.new("test")
            ensure
                inner_ensure = true
            end
        catch e: Err
            # Catch outer
        ensure
            outer_ensure = true
        end

        test.assert(inner_ensure)
        test.assert(outer_ensure)
    end)
end)

# Test 5: Exceptions in loops and control flow
test.describe("Exceptions in Control Flow", fun ()
    test.it("handles exceptions in while loop", fun ()
        let i = 0
        let caught_count = 0

        while i < 5
            try
                if i == 2
                    raise ValueErr.new("at i=2")
                end
            catch e: ValueErr
                caught_count = caught_count + 1
            end
            i = i + 1
        end

        test.assert_eq(caught_count, 1)
        test.assert_eq(i, 5)
    end)

    test.it("handles exceptions in for loop", fun ()
        let caught_count = 0
        let items = [1, 2, 3, 4, 5]

        for item in items
            try
                if item == 3
                    raise IndexErr.new("item 3")
                end
            catch e: IndexErr
                caught_count = caught_count + 1
            end
        end

        test.assert_eq(caught_count, 1)
    end)

    test.it("handles exceptions in if/elif/else", fun ()
        let results = []

        let x = 2
        try
            if x == 1
                raise IndexErr.new("one")
            elif x == 2
                raise TypeErr.new("two")
            else
                raise ValueErr.new("other")
            end
        catch e: TypeErr
            results.push("caught-two")
        end

        test.assert_eq(results.len(), 1)
        test.assert_eq(results[0], "caught-two")
    end)
end)

# Test 6: Exceptions with functions and closures
test.describe("Exceptions with Functions", fun ()
    test.it("catches exceptions from lambda", fun ()
        let thrower = fun (x)
            if x < 0
                raise ValueErr.new("negative value")
            end
            x * 2
        end

        let result = 0
        try
            result = thrower(-5)
        catch e: ValueErr
            result = 999
        end

        test.assert_eq(result, 999)
    end)

    test.it("handles exceptions in closures", fun ()
        let outer_var = 42

        let make_thrower = fun (threshold)
            fun (val)
                if val > threshold
                    raise RuntimeErr.new("exceeds threshold")
                end
                outer_var + val
            end
        end

        let thrower = make_thrower(10)
        let result = 0

        try
            result = thrower(20)
        catch e: RuntimeErr
            result = -1
        end

        test.assert_eq(result, -1)
    end)

    test.it("propagates exceptions through higher-order functions", fun ()
        let mapper = fun (arr, f)
            let result = []
            for item in arr
                result.push(f(item))
            end
            result
        end

        let caught = false
        try
            mapper([1, 2, 3], fun (x)
                if x == 2
                    raise IndexErr.new("bad index")
                end
                x * 10
            end)
        catch e: IndexErr
            caught = true
        end

        test.assert(caught)
    end)
end)

# Test 7: Exceptions with user-defined types
test.describe("Exceptions with User Types", fun ()
    type Calculator
        value: Int

        fun divide(x)
            if x == 0
                raise ValueErr.new("division by zero")
            end
            self.value / x
        end

        fun safe_divide(x)
            try
                return self.divide(x)
            catch e: ValueErr
                return -1
            end
        end

        static fun validate(x)
            if x < 0
                raise ArgErr.new("Calculator requires non-negative value")
            end
            Calculator.new(value: x)
        end
    end

    test.it("handles exceptions in instance methods", fun ()
        let calc = Calculator.new(value: 100)

        let caught = false
        try
            calc.divide(0)
        catch e: ValueErr
            caught = true
        end

        test.assert(caught)
    end)

    test.it("handles exceptions in methods with internal try/catch", fun ()
        let calc = Calculator.new(value: 100)
        let result = calc.safe_divide(0)
        test.assert_eq(result, -1)
    end)

    test.it("handles exceptions in static methods", fun ()
        let caught = false
        try
            Calculator.validate(-5)
        catch e: ArgErr
            caught = true
        end
        test.assert(caught)
    end)
end)

# Test 8: All exception types
test.describe("All Built-in Exception Types", fun ()
    test.it("raises and catches IndexErr", fun ()
        let caught = false
        try
            raise IndexErr.new("index error")
        catch e: IndexErr
            caught = true
            test.assert_eq(e.type(), "IndexErr")
        end
        test.assert(caught)
    end)

    test.it("raises and catches TypeErr", fun ()
        let caught = false
        try
            raise TypeErr.new("type error")
        catch e: TypeErr
            caught = true
            test.assert_eq(e.type(), "TypeErr")
        end
        test.assert(caught)
    end)

    test.it("raises and catches ValueErr", fun ()
        let caught = false
        try
            raise ValueErr.new("value error")
        catch e: ValueErr
            caught = true
            test.assert_eq(e.type(), "ValueErr")
        end
        test.assert(caught)
    end)

    test.it("raises and catches ArgErr", fun ()
        let caught = false
        try
            raise ArgErr.new("arg error")
        catch e: ArgErr
            caught = true
            test.assert_eq(e.type(), "ArgErr")
        end
        test.assert(caught)
    end)

    test.it("raises and catches AttrErr", fun ()
        let caught = false
        try
            raise AttrErr.new("attr error")
        catch e: AttrErr
            caught = true
            test.assert_eq(e.type(), "AttrErr")
        end
        test.assert(caught)
    end)

    test.it("raises and catches NameErr", fun ()
        let caught = false
        try
            raise NameErr.new("name error")
        catch e: NameErr
            caught = true
            test.assert_eq(e.type(), "NameErr")
        end
        test.assert(caught)
    end)

    test.it("raises and catches RuntimeErr", fun ()
        let caught = false
        try
            raise RuntimeErr.new("runtime error")
        catch e: RuntimeErr
            caught = true
            test.assert_eq(e.type(), "RuntimeErr")
        end
        test.assert(caught)
    end)

    test.it("raises and catches IOErr", fun ()
        let caught = false
        try
            raise IOErr.new("io error")
        catch e: IOErr
            caught = true
            test.assert_eq(e.type(), "IOErr")
        end
        test.assert(caught)
    end)

    test.it("raises and catches ImportErr", fun ()
        let caught = false
        try
            raise ImportErr.new("import error")
        catch e: ImportErr
            caught = true
            test.assert_eq(e.type(), "ImportErr")
        end
        test.assert(caught)
    end)

    test.it("raises and catches KeyErr", fun ()
        let caught = false
        try
            raise KeyErr.new("key error")
        catch e: KeyErr
            caught = true
            test.assert_eq(e.type(), "KeyErr")
        end
        test.assert(caught)
    end)
end)
