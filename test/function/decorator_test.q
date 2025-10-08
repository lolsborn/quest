# QEP-003: Function Decorators Tests

use "std/test"

test.module("QEP-003: Function Decorators")

# =============================================================================
# Test Decorator Definitions
# =============================================================================

type print_decorator
    """Simple decorator that prints before/after function execution"""
    func

    fun _call(*args)
        puts("[BEFORE] Calling " .. self.func._name())
        let result = self.func(*args)
        puts("[AFTER] Called " .. self.func._name())
        return result
    end

    fun _name()
        return self.func._name()
    end

    fun _doc()
        return self.func._doc()
    end

    fun _id()
        return self.func._id()
    end
end

type uppercase_decorator
    """Decorator that converts string results to uppercase"""
    func

    fun _call(*args)
        let result = self.func(*args)
        return result.upper()
    end

    fun _name()
        return self.func._name()
    end

    fun _doc()
        return self.func._doc()
    end

    fun _id()
        return self.func._id()
    end
end

type exclamation_decorator
    """Adds exclamation marks to string results"""
    func

    fun _call(*args)
        let result = self.func(*args)
        return result .. "!!!"
    end

    fun _name()
        return self.func._name()
    end

    fun _doc()
        return self.func._doc()
    end

    fun _id()
        return self.func._id()
    end
end

type prefix_decorator
    """Adds a configurable prefix to results"""
    func
    prefix: Str

    fun _call(*args)
        let result = self.func(*args)
        return self.prefix .. result
    end

    fun _name()
        return self.func._name()
    end

    fun _doc()
        return self.func._doc()
    end

    fun _id()
        return self.func._id()
    end
end

type multiplier_decorator
    """Multiplies numeric results by a factor"""
    func
    factor: Int

    fun _call(*args)
        let result = self.func(*args)
        return result * self.factor
    end

    fun _name()
        return self.func._name()
    end

    fun _doc()
        return self.func._doc()
    end

    fun _id()
        return self.func._id()
    end
end

# =============================================================================
# Basic Decorator Tests
# =============================================================================

test.describe("Basic Decorators", fun ()
    test.it("applies single decorator", fun ()
        @uppercase_decorator
        fun greet(name)
            return "hello, " .. name
        end

        test.assert_eq(greet("alice"), "HELLO, ALICE")
    end)

    test.it("decorator preserves function name", fun ()
        @uppercase_decorator
        fun my_function(x)
            return x
        end

        test.assert_eq(my_function._name(), "my_function")
    end)

    test.it("decorator with no arguments works", fun ()
        @exclamation_decorator
        fun announce(msg)
            return msg
        end

        test.assert_eq(announce("hello"), "hello!!!")
    end)

    test.it("decorator forwards multiple arguments", fun ()
        @uppercase_decorator
        fun concat(a, b, c)
            return a .. " " .. b .. " " .. c
        end

        test.assert_eq(concat("one", "two", "three"), "ONE TWO THREE")
    end)
end)

# =============================================================================
# Stacked Decorators
# =============================================================================

test.describe("Stacked Decorators", fun ()
    test.it("applies two decorators (bottom to top)", fun ()
        @exclamation_decorator
        @uppercase_decorator
        fun say_hello(name)
            return "hello, " .. name
        end

        # uppercase first, then exclamation
        test.assert_eq(say_hello("bob"), "HELLO, BOB!!!")
    end)

    test.it("applies three decorators", fun ()
        @prefix_decorator(prefix: ">>> ")
        @exclamation_decorator
        @uppercase_decorator
        fun process(text)
            return text
        end

        # uppercase -> exclamation -> prefix
        test.assert_eq(process("test"), ">>> TEST!!!")
    end)

    test.it("decorator order matters", fun ()
        # Order 1: uppercase then exclamation
        @exclamation_decorator
        @uppercase_decorator
        fun f1(x)
            return x
        end

        # Order 2: exclamation then uppercase
        @uppercase_decorator
        @exclamation_decorator
        fun f2(x)
            return x
        end

        test.assert_eq(f1("test"), "TEST!!!")
        test.assert_eq(f2("test"), "TEST!!!")  # !!! gets uppercased too
    end)
end)

# =============================================================================
# Decorators with Arguments
# =============================================================================

test.describe("Decorators with Arguments", fun ()
    test.it("accepts named arguments", fun ()
        @prefix_decorator(prefix: "Dr. ")
        fun name(n)
            return n
        end

        test.assert_eq(name("Smith"), "Dr. Smith")
    end)

    test.it("different instances have different configs", fun ()
        @prefix_decorator(prefix: "Mr. ")
        fun mister(n)
            return n
        end

        @prefix_decorator(prefix: "Mrs. ")
        fun missus(n)
            return n
        end

        test.assert_eq(mister("Jones"), "Mr. Jones")
        test.assert_eq(missus("Smith"), "Mrs. Smith")
    end)

    test.it("numeric decorator arguments work", fun ()
        @multiplier_decorator(factor: 3)
        fun triple(x)
            return x
        end

        test.assert_eq(triple(5), 15)
        test.assert_eq(triple(10), 30)
    end)
end)

# =============================================================================
# Decorators with Varargs
# =============================================================================

test.describe("Decorators with Varargs", fun ()
    test.it("forwards varargs to decorated function", fun ()
        @uppercase_decorator
        fun join(*words)
            let result = ""
            for word in words
                if result != ""
                    result = result .. " "
                end
                result = result .. word
            end
            return result
        end

        test.assert_eq(join("hello", "world"), "HELLO WORLD")
        test.assert_eq(join("a", "b", "c", "d"), "A B C D")
    end)

    test.it("forwards mixed args and varargs", fun ()
        @uppercase_decorator
        fun greet_many(greeting, *names)
            let result = greeting
            for name in names
                result = result .. " " .. name
            end
            return result
        end

        test.assert_eq(greet_many("Hello", "Alice", "Bob"), "HELLO ALICE BOB")
    end)
end)

# =============================================================================
# Edge Cases
# =============================================================================

test.describe("Edge Cases", fun ()
    test.it("decorator on zero-arg function", fun ()
        @exclamation_decorator
        fun no_args()
            return "test"
        end

        test.assert_eq(no_args(), "test!!!")
    end)

    test.it("decorator returns nil", fun ()
        type nil_decorator
            func

            fun _call(*args)
                self.func(*args)
                return nil
            end

            fun _name()
                return self.func._name()
            end

            fun _doc()
                return self.func._doc()
            end

            fun _id()
                return self.func._id()
            end
        end

        @nil_decorator
        fun side_effect()
            return "result"
        end

        test.assert_nil(side_effect())
    end)
end)
