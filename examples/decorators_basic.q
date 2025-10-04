"""
Basic Decorator Examples (QEP-003)

This example demonstrates the foundational decorator system in Quest.
"""

# =============================================================================
# Simple Print Decorator
# =============================================================================

type print_decorator
"""
Prints before and after function execution.
"""
    fun: func

    fun _call(arg)
        let f = self.func
        let fname = f._name()
        puts("[BEFORE] Calling " .. fname)
        let result = f(arg)
        puts("[AFTER] Called " .. fname)
        return result
    end

    fun _name()
        let f = self.func
        return f._name()
    end

    fun _doc()
        let f = self.func
        return f._doc()
    end

    fun _id()
        let f = self.func
        return f._id()
    end
end

# =============================================================================
# Exclamation Decorator
# =============================================================================

type exclamation_decorator
"""
Adds exclamation marks to string results.
"""
    fun: func

    fun _call(arg)
        let f = self.func
        let result = f(arg)
        return result .. "!!!"
    end

    fun _name()
        let f = self.func
        return f._name()
    end

    fun _doc()
        let f = self.func
        return f._doc()
    end

    fun _id()
        let f = self.func
        return f._id()
    end
end

# =============================================================================
# Uppercase Result Decorator
# =============================================================================

type uppercase_decorator
"""
Converts string results to uppercase.
"""
    fun: func

    fun _call(arg)
        let f = self.func
        let result = f(arg)
        return result.upper()
    end

    fun _name()
        let f = self.func
        return f._name()
    end

    fun _doc()
        let f = self.func
        return f._doc()
    end

    fun _id()
        let f = self.func
        return f._id()
    end
end

# =============================================================================
# Example 1: Single Decorator
# =============================================================================

puts("==================================================")
puts("Example 1: Single Decorator")
puts("==================================================")
puts("")

@print_decorator
fun greet(name)
    return "Hello, " .. name
end

let result1 = greet("Alice")
puts("Result: " .. result1)
puts("")

# =============================================================================
# Example 2: Exclamation Decorator
# =============================================================================

puts("==================================================")
puts("Example 2: Exclamation Decorator")
puts("==================================================")
puts("")

@exclamation_decorator
fun announce(message)
    return message
end

let result2 = announce("Quest decorators are working")
puts("Result: " .. result2)
puts("")

# =============================================================================
# Example 3: Stacked Decorators (Bottom to Top)
# =============================================================================

puts("==================================================")
puts("Example 3: Stacked Decorators")
puts("==================================================")
puts("")

@print_decorator
@uppercase_decorator
fun say_hello(name)
    return "hello, " .. name
end

let result3 = say_hello("Bob")
puts("Result: " .. result3)
puts("")

# =============================================================================
# Example 4: Triple Stack
# =============================================================================

puts("==================================================")
puts("Example 4: Triple Stacked Decorators")
puts("==================================================")
puts("")

@print_decorator
@exclamation_decorator
@uppercase_decorator
fun process_name(name)
    return "welcome, " .. name
end

let result4 = process_name("Charlie")
puts("Result: " .. result4)
puts("")

# =============================================================================
# Example 5: Function Without Decorator
# =============================================================================

puts("==================================================")
puts("Example 5: Plain Function (No Decorator)")
puts("==================================================")
puts("")

fun plain_function(x)
    return "Plain: " .. x
end

let result5 = plain_function("test")
puts("Result: " .. result5)
puts("")

puts("Decorator examples complete!")
