# Fuzz Test 006: Decorators with Varargs, Kwargs, and Named Arguments
# Tests interaction between QEP-003 (decorators), QEP-034 (varargs/kwargs), QEP-035 (named args)
# Focus: Complex parameter passing through decorator chains

use "std/test"

test.module("Decorator Parameter Passing Fuzz")

# ============================================================================
# Custom Decorators for Testing
# ============================================================================

# Decorator that logs all arguments
type LogArgs
    func
    call_count: Int

    fun _call(*args, **kwargs)
        self.call_count = self.call_count + 1
        let count_str = self.call_count.str()
        let args_len = args.len().str()
        let kwargs_len = kwargs.len().str()
        puts("[LogArgs " .. count_str .. "] Positional args: " .. args_len .. ", Keyword args: " .. kwargs_len)

        # Print each positional arg
        let i = 0
        while i < args.len()
            let idx = i.str()
            let val = args[i].str()
            puts("  args[" .. idx .. "] = " .. val)
            i = i + 1
        end

        # Print each keyword arg
        let keys = kwargs.keys()
        let j = 0
        while j < keys.len()
            let key = keys[j]
            let val = kwargs[key].str()
            puts("  kwargs[" .. key .. "] = " .. val)
            j = j + 1
        end

        return self.func(*args, **kwargs)
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

# Decorator that doubles numeric arguments
type DoubleArgs
    func

    fun _call(*args, **kwargs)
        puts("[DoubleArgs] Doubling numeric arguments")

        # Double positional args if they're numbers
        let doubled_args = []
        let i = 0
        while i < args.len()
            let arg = args[i]
            if arg.is("Int") or arg.is("Float")
                doubled_args.push(arg * 2)
            else
                doubled_args.push(arg)
            end
            i = i + 1
        end

        # Double keyword args if they're numbers
        let doubled_kwargs = {}
        let keys = kwargs.keys()
        let j = 0
        while j < keys.len()
            let key = keys[j]
            let val = kwargs[key]
            if val.is("Int") or val.is("Float")
                doubled_kwargs[key] = val * 2
            else
                doubled_kwargs[key] = val
            end
            j = j + 1
        end

        return self.func(*doubled_args, **doubled_kwargs)
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

# Decorator that adds a prefix to string results
type PrefixResult
    func
    prefix: Str

    fun _call(*args, **kwargs)
        let result = self.func(*args, **kwargs)
        if result.is("Str")
            return self.prefix .. result
        end
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

# ============================================================================
# Test Functions with Various Parameter Combinations
# ============================================================================

test.describe("Basic decorator with varargs", fun ()
    test.it("logs and forwards varargs correctly", fun ()
        @LogArgs.new(call_count: 0)
        fun sum_all(*numbers)
            let total = 0
            let i = 0
            while i < numbers.len()
                total = total + numbers[i]
                i = i + 1
            end
            return total
        end

        let result1 = sum_all(1, 2, 3)
        test.assert_eq(result1, 6)

        let result2 = sum_all(10, 20, 30, 40)
        test.assert_eq(result2, 100)

        let result3 = sum_all()
        test.assert_eq(result3, 0)
    end)
end)

test.describe("Decorator with kwargs", fun ()
    test.it("logs and forwards kwargs correctly", fun ()
        @LogArgs.new(call_count: 0)
        fun config(**options)
            let count = options.len()
            let count_str = count.str()
            return "Configured with " .. count_str .. " options"
        end

        let result1 = config(host: "localhost", port: 8080, debug: true)
        test.assert_eq(result1, "Configured with 3 options")

        let result2 = config(timeout: 30)
        test.assert_eq(result2, "Configured with 1 options")

        let result3 = config()
        test.assert_eq(result3, "Configured with 0 options")
    end)
end)

test.describe("Decorator with mixed parameters", fun ()
    test.it("handles required, optional, varargs, and kwargs", fun ()
        @LogArgs.new(call_count: 0)
        fun complex(required, optional = 42, *args, **kwargs)
            let parts = []
            parts.push("required=" .. required.str())
            parts.push("optional=" .. optional.str())
            parts.push("args_len=" .. args.len().str())
            parts.push("kwargs_len=" .. kwargs.len().str())
            return parts.join(", ")
        end

        let result1 = complex("test")
        test.assert(result1.contains("required=test"))
        test.assert(result1.contains("optional=42"))

        let result2 = complex("test", 99)
        test.assert(result2.contains("optional=99"))

        let result3 = complex("test", 99, "extra1", "extra2")
        test.assert(result3.contains("args_len=2"))

        let result4 = complex("test", extra_key: "value")
        test.assert(result4.contains("kwargs_len=1"))

        let result5 = complex("test", 99, "a", "b", key1: "v1", key2: "v2")
        test.assert(result5.contains("args_len=2"))
        test.assert(result5.contains("kwargs_len=2"))
    end)
end)

test.describe("Stacked decorators with varargs", fun ()
    test.it("applies decorators bottom-to-top with varargs", fun ()
        @PrefixResult.new(prefix: "RESULT: ")
        @LogArgs.new(call_count: 0)
        fun join_strings(*strings)
            return strings.join("-")
        end

        let result = join_strings("a", "b", "c")
        test.assert_eq(result, "RESULT: a-b-c")
    end)
end)

test.describe("DoubleArgs decorator", fun ()
    test.it("doubles numeric positional arguments", fun ()
        @DoubleArgs.new()
        fun add_three(a, b, c)
            return a + b + c
        end

        # Input: 1, 2, 3 -> After doubling: 2, 4, 6 -> Sum: 12
        let result = add_three(1, 2, 3)
        test.assert_eq(result, 12)
    end)

    test.it("doubles numeric keyword arguments", fun ()
        @DoubleArgs.new()
        fun multiply(x, y)
            return x * y
        end

        # Input: x=3, y=4 -> After doubling: x=6, y=8 -> Product: 48
        let result = multiply(x: 3, y: 4)
        test.assert_eq(result, 48)
    end)

    test.it("preserves non-numeric arguments", fun ()
        @DoubleArgs.new()
        fun process(num, text)
            let num_str = num.str()
            return text .. ": " .. num_str
        end

        # Input: 5, "value" -> After doubling: 10, "value"
        let result = process(5, "value")
        test.assert_eq(result, "value: 10")
    end)
end)

test.describe("Named arguments through decorators", fun ()
    test.it("forwards named arguments correctly", fun ()
        @LogArgs.new(call_count: 0)
        fun greet(greeting, name, punctuation)
            return greeting .. ", " .. name .. punctuation
        end

        # All named, reordered
        let result1 = greet(name: "Alice", punctuation: "!", greeting: "Hello")
        test.assert_eq(result1, "Hello, Alice!")

        # Mixed positional and named
        let result2 = greet("Hi", name: "Bob", punctuation: ".")
        test.assert_eq(result2, "Hi, Bob.")
    end)
end)

test.describe("Named arguments with defaults through decorators", fun ()
    test.it("skips optional parameters with named args", fun ()
        @LogArgs.new(call_count: 0)
        fun connect(host, port = 8080, timeout = 30, ssl = false, debug = false)
            let parts = []
            parts.push("host=" .. host)
            parts.push("port=" .. port.str())
            parts.push("timeout=" .. timeout.str())
            parts.push("ssl=" .. ssl.str())
            parts.push("debug=" .. debug.str())
            return parts.join(", ")
        end

        # Skip middle parameters
        let result1 = connect("localhost", ssl: true)
        test.assert(result1.contains("host=localhost"))
        test.assert(result1.contains("port=8080"))
        test.assert(result1.contains("ssl=true"))

        # Skip multiple parameters
        let result2 = connect("example.com", debug: true, timeout: 60)
        test.assert(result2.contains("timeout=60"))
        test.assert(result2.contains("debug=true"))
    end)
end)

test.describe("Decorator chains with complex parameters", fun ()
    test.it("handles three decorators with varargs and kwargs", fun ()
        @PrefixResult.new(prefix: "[OUTPUT] ")
        @DoubleArgs.new()
        @LogArgs.new(call_count: 0)
        fun compute(base, *multipliers, **options)
            let result = base
            let i = 0
            while i < multipliers.len()
                result = result * multipliers[i]
                i = i + 1
            end

            if options.contains("add")
                result = result + options["add"]
            end

            let result_str = result.str()
            return "Computed: " .. result_str
        end

        # Input: base=2, multipliers=[3, 4], add=10
        # After DoubleArgs: base=4, multipliers=[6, 8], add=20
        # Computation: 4 * 6 * 8 = 192, + 20 = 212
        let result = compute(2, 3, 4, add: 10)
        test.assert(result.contains("[OUTPUT]"))
        test.assert(result.contains("212"))
    end)
end)

test.describe("Edge cases with decorators", fun ()
    test.it("handles empty varargs through decorators", fun ()
        @LogArgs.new(call_count: 0)
        fun maybe_sum(base, *extras)
            let total = base
            let i = 0
            while i < extras.len()
                total = total + extras[i]
                i = i + 1
            end
            return total
        end

        let result = maybe_sum(100)
        test.assert_eq(result, 100)
    end)

    test.it("handles empty kwargs through decorators", fun ()
        @LogArgs.new(call_count: 0)
        fun maybe_config(required, **opts)
            let count = opts.len().str()
            return required .. ": " .. count .. " options"
        end

        let result = maybe_config("test")
        test.assert_eq(result, "test: 0 options")
    end)

    test.it("handles only varargs function through decorators", fun ()
        @DoubleArgs.new()
        fun only_varargs(*values)
            let sum = 0
            let i = 0
            while i < values.len()
                sum = sum + values[i]
                i = i + 1
            end
            return sum
        end

        # Input: 1, 2, 3, 4, 5 -> After doubling: 2, 4, 6, 8, 10 -> Sum: 30
        let result = only_varargs(1, 2, 3, 4, 5)
        test.assert_eq(result, 30)
    end)

    test.it("handles only kwargs function through decorators", fun ()
        @LogArgs.new(call_count: 0)
        fun only_kwargs(**data)
            let keys = data.keys()
            return keys.len()
        end

        let result = only_kwargs(a: 1, b: 2, c: 3, d: 4, e: 5)
        test.assert_eq(result, 5)
    end)
end)

test.describe("Decorator with type methods", fun ()
    test.it("decorates instance methods with varargs", fun ()
        type Calculator
            multiplier: Int

            @LogArgs.new(call_count: 0)
            fun sum_and_multiply(*numbers)
                let sum = 0
                let i = 0
                while i < numbers.len()
                    sum = sum + numbers[i]
                    i = i + 1
                end
                return sum * self.multiplier
            end
        end

        let calc = Calculator.new(multiplier: 10)
        let result = calc.sum_and_multiply(1, 2, 3, 4, 5)
        test.assert_eq(result, 150)  # (1+2+3+4+5) * 10
    end)

    test.it("decorates static methods with kwargs", fun ()
        type Factory
            @LogArgs.new(call_count: 0)
            static fun create(**options)
                let name = "default"
                if options.contains("name")
                    name = options["name"]
                end
                return "Created: " .. name
            end
        end

        let result = Factory.create(name: "custom", version: 2)
        test.assert_eq(result, "Created: custom")
    end)
end)

test.describe("Stress test: Deep decorator chains", fun ()
    test.it("handles five decorators stacked", fun ()
        let log1 = LogArgs.new(call_count: 0)
        let log2 = LogArgs.new(call_count: 0)
        let log3 = LogArgs.new(call_count: 0)

        type Wrapper1
            func
            fun _call(*args, **kwargs)
                puts("[Wrapper1]")
                return self.func(*args, **kwargs)
            end
            fun _name() return self.func._name() end
            fun _doc() return self.func._doc() end
            fun _id() return self.func._id() end
        end

        type Wrapper2
            func
            fun _call(*args, **kwargs)
                puts("[Wrapper2]")
                return self.func(*args, **kwargs)
            end
            fun _name() return self.func._name() end
            fun _doc() return self.func._doc() end
            fun _id() return self.func._id() end
        end

        @Wrapper2.new()
        @Wrapper1.new()
        @log3
        @log2
        @log1
        fun deeply_wrapped(x, *args, **kwargs)
            let args_len = args.len().str()
            let kwargs_len = kwargs.len().str()
            let x_str = x.str()
            return "x=" .. x_str .. ", args=" .. args_len .. ", kwargs=" .. kwargs_len
        end

        let result = deeply_wrapped(42, 1, 2, 3, opt1: "a", opt2: "b")
        test.assert(result.contains("x=42"))
        test.assert(result.contains("args=3"))
        test.assert(result.contains("kwargs=2"))
    end)
end)

test.describe("Array and dict unpacking through decorators", fun ()
    test.it("unpacks arrays as varargs through decorators", fun ()
        @DoubleArgs.new()
        fun triple_add(a, b, c)
            return a + b + c
        end

        let args = [5, 10, 15]
        # After doubling: [10, 20, 30] -> Sum: 60
        let result = triple_add(*args)
        test.assert_eq(result, 60)
    end)

    test.it("unpacks dicts as kwargs through decorators", fun ()
        @LogArgs.new(call_count: 0)
        fun build_url(protocol, host, port)
            let port_str = port.str()
            return protocol .. "://" .. host .. ":" .. port_str
        end

        let params = {protocol: "https", host: "example.com", port: 443}
        let result = build_url(**params)
        test.assert_eq(result, "https://example.com:443")
    end)

    test.it("mixes unpacking with regular args through decorators", fun ()
        @DoubleArgs.new()
        fun complex_calc(a, b, c, d)
            return a + b + c + d
        end

        let some_args = [3, 4]
        # Input: 1, 2, *[3, 4] -> After doubling: 2, 4, 6, 8 -> Sum: 20
        let result = complex_calc(1, 2, *some_args)
        test.assert_eq(result, 20)
    end)
end)

test.describe("Decorator with lambda functions", fun ()
    test.it("decorates lambdas with varargs", fun ()
        let log = LogArgs.new(call_count: 0)

        # Can't use @decorator syntax on lambdas, use manual wrapping
        let sum_lambda = fun (*nums)
            let total = 0
            let i = 0
            while i < nums.len()
                total = total + nums[i]
                i = i + 1
            end
            return total
        end

        # Manually wrap the lambda
        let wrapped = log
        wrapped.func = sum_lambda

        let result = wrapped._call(10, 20, 30)
        test.assert_eq(result, 60)
    end)
end)

puts("\n=== Fuzz Test 006 Complete ===")
puts("Tested decorators with:")
puts("  - Varargs (*args)")
puts("  - Keyword arguments (**kwargs)")
puts("  - Named arguments")
puts("  - Default parameters")
puts("  - Mixed parameter types")
puts("  - Decorator chains")
puts("  - Type methods (instance and static)")
puts("  - Array/dict unpacking")
puts("  - Edge cases")
