"""
Decorator Named Arguments Examples (QEP-003)

This example demonstrates using named arguments with decorators for
more readable and flexible decorator configuration.
"""

# =============================================================================
# Decorator Definitions
# =============================================================================

type prefix_decorator
"""
Adds a configurable prefix to results.
"""
    fun: func
    prefix: Str

    fun _call(arg)
        let f = self.func
        let result = f(arg)
        return self.prefix .. result
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

type wrap_decorator
"""
Wraps results with configurable left and right strings.
"""
    fun: func
    left: Str
    right: Str

    fun _call(arg)
        let f = self.func
        let result = f(arg)
        return self.left .. result .. self.right
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

type multiplier_decorator
"""
Multiplies numeric results by a configurable factor.
"""
    fun: func
    factor: Int

    fun _call(arg)
        let f = self.func
        let result = f(arg)
        return result.times(self.factor)
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
# Example 1: Single Named Argument
# =============================================================================

puts("==================================================")
puts("Example 1: Single Named Argument")
puts("==================================================")
puts("")

@prefix_decorator(prefix: "Dr. ")
fun doctor_name(name)
    return name
end

@prefix_decorator(prefix: "Prof. ")
fun professor_name(name)
    return name
end

puts("Doctor: " .. doctor_name("Smith"))
puts("Professor: " .. professor_name("Johnson"))
puts("")

# =============================================================================
# Example 2: Multiple Named Arguments
# =============================================================================

puts("==================================================")
puts("Example 2: Multiple Named Arguments")
puts("==================================================")
puts("")

@wrap_decorator(left: "[", right: "]")
fun bracket(text)
    return text
end

@wrap_decorator(left: "<", right: ">")
fun angle(text)
    return text
end

@wrap_decorator(left: "{", right: "}")
fun brace(text)
    return text
end

puts("Brackets: " .. bracket("content"))
puts("Angles: " .. angle("tag"))
puts("Braces: " .. brace("json"))
puts("")

# =============================================================================
# Example 3: Stacked Decorators with Named Arguments
# =============================================================================

puts("==================================================")
puts("Example 3: Stacked Decorators with Named Args")
puts("==================================================")
puts("")

@prefix_decorator(prefix: "==> ")
@wrap_decorator(left: "[", right: "]")
fun format_message(msg)
    return msg
end

puts(format_message("Important"))
puts(format_message("Notice"))
puts("")

# =============================================================================
# Example 4: HTML Tag Generation
# =============================================================================

puts("==================================================")
puts("Example 4: HTML Tag Generation")
puts("==================================================")
puts("")

@wrap_decorator(left: "<b>", right: "</b>")
fun bold(text)
    return text
end

@wrap_decorator(left: "<i>", right: "</i>")
fun italic(text)
    return text
end

@wrap_decorator(left: "<code>", right: "</code>")
fun code(text)
    return text
end

puts("Bold: " .. bold("important"))
puts("Italic: " .. italic("emphasis"))
puts("Code: " .. code("function()"))
puts("")

# =============================================================================
# Example 5: Markdown Formatting
# =============================================================================

puts("==================================================")
puts("Example 5: Markdown Formatting")
puts("==================================================")
puts("")

@wrap_decorator(left: "**", right: "**")
fun md_bold(text)
    return text
end

@wrap_decorator(left: "*", right: "*")
fun md_italic(text)
    return text
end

@wrap_decorator(left: "`", right: "`")
fun md_code(text)
    return text
end

puts("Markdown bold: " .. md_bold("text"))
puts("Markdown italic: " .. md_italic("text"))
puts("Markdown code: " .. md_code("var x"))
puts("")

# =============================================================================
# Example 6: Numeric Multipliers
# =============================================================================

puts("==================================================")
puts("Example 6: Numeric Multipliers")
puts("==================================================")
puts("")

@multiplier_decorator(factor: 2)
fun double(x)
    return x.plus(5)
end

@multiplier_decorator(factor: 3)
fun triple(x)
    return x.plus(10)
end

@multiplier_decorator(factor: 10)
fun times_ten(x)
    return x
end

puts("double(5) = " .. double(5)._str())      # (5 + 5) * 2 = 20
puts("triple(10) = " .. triple(10)._str())    # (10 + 10) * 3 = 60
puts("times_ten(7) = " .. times_ten(7)._str())  # 7 * 10 = 70
puts("")

# =============================================================================
# Example 7: Named Arguments in Any Order
# =============================================================================

puts("==================================================")
puts("Example 7: Named Arguments in Any Order")
puts("==================================================")
puts("")

@wrap_decorator(right: ")", left: "(")
fun paren1(text)
    return text
end

@wrap_decorator(left: "(", right: ")")
fun paren2(text)
    return text
end

puts("Right first: " .. paren1("content"))
puts("Left first: " .. paren2("content"))
puts("Both produce: (content)")
puts("")

# =============================================================================
# Example 8: Real-World Formatting
# =============================================================================

puts("==================================================")
puts("Example 8: Real-World Use Cases")
puts("==================================================")
puts("")

@prefix_decorator(prefix: "$")
fun price(amount)
    return amount._str()
end

@prefix_decorator(prefix: "@")
fun username(name)
    return name
end

@prefix_decorator(prefix: "#")
fun hashtag(tag)
    return tag
end

puts("Price: " .. price(99))
puts("Username: " .. username("alice"))
puts("Hashtag: " .. hashtag("coding"))
puts("")

puts("Named argument decorators complete!")
