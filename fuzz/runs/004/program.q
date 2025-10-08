# Fuzz Test 004: Variadic Parameters + Keyword Arguments + Default Parameters
# Tests comprehensive combinations of *args, **kwargs, and default params
# Focus on edge cases, order variations, and complex nested scenarios

puts("=== FUZZ TEST 004: Advanced Parameter Combinations ===")
puts("")

# =============================================================================
# Section 1: Basic *args tests
# =============================================================================
puts("--- Section 1: Basic *args ---")

fun test_varargs_only(*args)
    return args.len()
end

puts("Empty args: " .. test_varargs_only().str())
puts("One arg: " .. test_varargs_only(1).str())
puts("Five args: " .. test_varargs_only(1, 2, 3, 4, 5).str())
puts("Ten args: " .. test_varargs_only(1, 2, 3, 4, 5, 6, 7, 8, 9, 10).str())

# Test with different types
fun test_varargs_types(*items)
    let result = ""
    let i = 0
    while i < items.len()
        let item = items[i]
        if item == nil
            result = result .. "nil,"
        else
            result = result .. item.cls() .. ","
        end
        i = i + 1
    end
    return result
end

puts("Mixed types: " .. test_varargs_types(42, "hello", 3.14, true, nil))

# =============================================================================
# Section 2: Required + *args
# =============================================================================
puts("")
puts("--- Section 2: Required + *args ---")

fun test_required_varargs(first, *rest)
    return "first=" .. first.str() .. " rest_len=" .. rest.len().str()
end

puts(test_required_varargs(1))
puts(test_required_varargs(1, 2))
puts(test_required_varargs(1, 2, 3, 4, 5))

fun test_multi_required_varargs(a, b, c, *extra)
    let sum = a + b + c
    let i = 0
    while i < extra.len()
        sum = sum + extra[i]
        i = i + 1
    end
    return sum
end

puts("Sum with required: " .. test_multi_required_varargs(1, 2, 3).str())
puts("Sum with extra: " .. test_multi_required_varargs(1, 2, 3, 4, 5, 6).str())

# =============================================================================
# Section 3: Default params + *args
# =============================================================================
puts("")
puts("--- Section 3: Default + *args ---")

fun test_default_varargs(base = 10, *multipliers)
    let result = base
    let i = 0
    while i < multipliers.len()
        result = result * multipliers[i]
        i = i + 1
    end
    return result
end

puts("Default only: " .. test_default_varargs().str())
puts("With base: " .. test_default_varargs(5).str())
puts("With multipliers: " .. test_default_varargs(5, 2, 3).str())
puts("Default base with multipliers: " .. test_default_varargs(10, 2, 2, 2).str())

fun test_multi_defaults_varargs(x = 1, y = 2, z = 3, *rest)
    let sum = x + y + z
    let i = 0
    while i < rest.len()
        sum = sum + rest[i]
        i = i + 1
    end
    return sum
end

puts("All defaults: " .. test_multi_defaults_varargs().str())
puts("One override: " .. test_multi_defaults_varargs(10).str())
puts("Two overrides: " .. test_multi_defaults_varargs(10, 20).str())
puts("Three overrides: " .. test_multi_defaults_varargs(10, 20, 30).str())
puts("With varargs: " .. test_multi_defaults_varargs(10, 20, 30, 40, 50).str())

# =============================================================================
# Section 4: Required + Default + *args
# =============================================================================
puts("")
puts("--- Section 4: Required + Default + *args ---")

fun test_full_combo(required, optional = 100, *extra)
    let result = required + optional
    let i = 0
    while i < extra.len()
        result = result + extra[i]
        i = i + 1
    end
    return result
end

puts("Just required: " .. test_full_combo(1).str())
puts("Required + optional: " .. test_full_combo(1, 2).str())
puts("All three types: " .. test_full_combo(1, 2, 3, 4, 5).str())

# =============================================================================
# Section 5: Basic **kwargs tests
# =============================================================================
puts("")
puts("--- Section 5: Basic **kwargs ---")

fun test_kwargs_only(**options)
    return "options_count=" .. options.len().str()
end

puts(test_kwargs_only())
puts(test_kwargs_only(a: 1))
puts(test_kwargs_only(a: 1, b: 2, c: 3))

fun test_kwargs_access(**kw)
    let keys = kw.keys()
    let result = ""
    let i = 0
    while i < keys.len()
        let k = keys[i]
        result = result .. k .. "=" .. kw[k].str() .. " "
        i = i + 1
    end
    return result
end

puts("Kwargs access: " .. test_kwargs_access(name: "Alice", age: 30, city: "NYC"))

# =============================================================================
# Section 6: Required + **kwargs
# =============================================================================
puts("")
puts("--- Section 6: Required + **kwargs ---")

fun test_required_kwargs(host, port, **options)
    let result = "host=" .. host .. " port=" .. port.str()
    result = result .. " options=" .. options.len().str()
    return result
end

puts(test_required_kwargs(host: "localhost", port: 8080))
puts(test_required_kwargs(host: "localhost", port: 8080, ssl: true))
puts(test_required_kwargs(host: "localhost", port: 8080, ssl: true, timeout: 60, debug: true))

# =============================================================================
# Section 7: Default + **kwargs
# =============================================================================
puts("")
puts("--- Section 7: Default + **kwargs ---")

fun test_default_kwargs(level = "INFO", format = "json", **extra)
    let result = "level=" .. level .. " format=" .. format
    result = result .. " extra=" .. extra.len().str()
    return result
end

puts(test_default_kwargs())
puts(test_default_kwargs(level: "DEBUG"))
puts(test_default_kwargs(level: "DEBUG", format: "text"))
puts(test_default_kwargs(level: "DEBUG", format: "text", timestamp: true, color: false))

# =============================================================================
# Section 8: *args + **kwargs
# =============================================================================
puts("")
puts("--- Section 8: *args + **kwargs ---")

fun test_args_kwargs(*args, **kwargs)
    let result = "args=" .. args.len().str() .. " kwargs=" .. kwargs.len().str()
    return result
end

puts(test_args_kwargs())
puts(test_args_kwargs(1, 2, 3))
puts(test_args_kwargs(a: 1, b: 2))
puts(test_args_kwargs(1, 2, 3, a: 10, b: 20, c: 30))

# =============================================================================
# Section 9: Required + *args + **kwargs
# =============================================================================
puts("")
puts("--- Section 9: Required + *args + **kwargs ---")

fun test_req_args_kwargs(command, *args, **kwargs)
    let result = "cmd=" .. command
    result = result .. " args=" .. args.len().str()
    result = result .. " kwargs=" .. kwargs.len().str()
    return result
end

puts(test_req_args_kwargs(command: "run"))
puts(test_req_args_kwargs("run", "file1.txt", "file2.txt"))
puts(test_req_args_kwargs(command: "run", verbose: true))
puts(test_req_args_kwargs("run", "file1.txt", "file2.txt", verbose: true, force: true))

# =============================================================================
# Section 10: Required + Default + *args + **kwargs (FULL COMBO)
# =============================================================================
puts("")
puts("--- Section 10: FULL COMBO ---")

fun test_all_params(cmd, mode = "default", *args, **kwargs)
    let result = "cmd=" .. cmd .. " mode=" .. mode
    result = result .. " args=" .. args.len().str()
    result = result .. " kwargs=" .. kwargs.len().str()
    return result
end

puts(test_all_params(cmd: "exec"))
puts(test_all_params(cmd: "exec", mode: "strict"))
puts(test_all_params("exec", "default", "arg1", "arg2"))
puts(test_all_params("exec", "strict", "arg1", "arg2"))
puts(test_all_params(cmd: "exec", timeout: 30))
puts(test_all_params("exec", "strict", "arg1", "arg2", timeout: 30, retry: 3))

# =============================================================================
# Section 11: Lambdas with advanced params
# =============================================================================
puts("")
puts("--- Section 11: Lambdas ---")

let lambda_varargs = fun (*nums)
    let sum = 0
    let i = 0
    while i < nums.len()
        sum = sum + nums[i]
        i = i + 1
    end
    sum
end

puts("Lambda varargs: " .. lambda_varargs(1, 2, 3, 4, 5).str())

# BUG: **kwargs in lambdas doesn't work
# let lambda_kwargs = fun (**opts)
#     opts.len()
# end
# puts("Lambda kwargs: " .. lambda_kwargs(a: 1, b: 2, c: 3).str())

# BUG: **kwargs in lambdas doesn't work
# let lambda_both = fun (*args, **kwargs)
#     args.len() + kwargs.len()
# end
# puts("Lambda both: " .. lambda_both(1, 2, x: 10, y: 20).str())

# =============================================================================
# Section 12: Nested calls with parameter forwarding
# =============================================================================
puts("")
puts("--- Section 12: Nested forwarding ---")

fun outer(*args, **kwargs)
    return inner(*args, **kwargs)
end

fun inner(*items, **options)
    return "items=" .. items.len().str() .. " options=" .. options.len().str()
end

puts(outer(1, 2, 3, a: 10, b: 20))

# =============================================================================
# Section 13: Type methods with advanced params
# =============================================================================
puts("")
puts("--- Section 13: Type methods ---")

type Logger
    name

    fun log(level, message, *tags, **metadata)
        let result = "[" .. self.name .. "] " .. level .. ": " .. message
        result = result .. " tags=" .. tags.len().str()
        result = result .. " meta=" .. metadata.len().str()
        return result
    end

    static fun create(name = "default", *extra, **config)
        let result = "name=" .. name
        result = result .. " extra=" .. extra.len().str()
        result = result .. " config=" .. config.len().str()
        return result
    end
end

let log = Logger.new(name: "app")
puts(log.log(level: "INFO", message: "Started"))
puts(log.log("INFO", "Processing", "urgent", "critical", user: "alice", session: 123))

puts(Logger.create())
puts(Logger.create(name: "custom"))
puts(Logger.create("custom", "opt1", "opt2", debug: true, color: false))

# =============================================================================
# Section 14: Edge cases - Empty collections
# =============================================================================
puts("")
puts("--- Section 14: Edge cases ---")

fun test_empty_behavior(*args, **kwargs)
    # Access empty arrays/dicts
    let args_is_empty = args.len() == 0
    let kwargs_is_empty = kwargs.len() == 0
    return "args_empty=" .. args_is_empty.str() .. " kwargs_empty=" .. kwargs_is_empty.str()
end

puts(test_empty_behavior())
puts(test_empty_behavior(1))
puts(test_empty_behavior(x: 1))

# =============================================================================
# Section 15: Large varargs (stress test)
# =============================================================================
puts("")
puts("--- Section 15: Large varargs ---")

fun sum_many(*numbers)
    let total = 0
    let i = 0
    while i < numbers.len()
        total = total + numbers[i]
        i = i + 1
    end
    return total
end

# Call with 50 arguments
puts("Sum 1-50: " .. sum_many(
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
    11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
    21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
    31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50
).str())

# =============================================================================
# Section 16: Many kwargs (stress test)
# =============================================================================
puts("")
puts("--- Section 16: Many kwargs ---")

fun count_options(**opts)
    return opts.len()
end

puts("20 kwargs: " .. count_options(
    a: 1, b: 2, c: 3, d: 4, e: 5,
    f: 6, g: 7, h: 8, i: 9, j: 10,
    k: 11, l: 12, m: 13, n: 14, o: 15,
    p: 16, q: 17, r: 18, s: 19, t: 20
).str())

# =============================================================================
# Section 17: Mixed types in varargs
# =============================================================================
puts("")
puts("--- Section 17: Mixed types ---")

fun describe_args(*items)
    let result = ""
    let i = 0
    while i < items.len()
        if i > 0
            result = result .. ", "
        end
        let item = items[i]
        if item == nil
            result = result .. "nil"
        else
            result = result .. item.cls()
        end
        i = i + 1
    end
    return result
end

puts("Types: " .. describe_args(42, "hello", 3.14, true, nil, [1, 2], {a: 1}))

# =============================================================================
# Section 18: Default param evaluation order
# =============================================================================
puts("")
puts("--- Section 18: Default evaluation ---")

# BUG: Function calls in default params cause parse error
# fun test_evaluation_order(a = increment(), b = increment(), c = increment())
#     return "a=" .. a.str() .. " b=" .. b.str() .. " c=" .. c.str()
# end

# Simplified test with constant defaults
fun test_simple_defaults(a = 1, b = 2, c = 3)
    return "a=" .. a.str() .. " b=" .. b.str() .. " c=" .. c.str()
end

puts("All defaults: " .. test_simple_defaults())
puts("One override: " .. test_simple_defaults(10))
puts("Two overrides: " .. test_simple_defaults(10, 20))

# =============================================================================
# Section 19: Recursive functions with varargs
# =============================================================================
puts("")
puts("--- Section 19: Recursive varargs ---")

fun sum_recursive(*nums)
    if nums.len() == 0
        return 0
    end
    if nums.len() == 1
        return nums[0]
    end
    # Split into first and rest
    let first = nums[0]
    let rest = []
    let i = 1
    while i < nums.len()
        rest.push(nums[i])
        i = i + 1
    end
    return first + sum_recursive(*rest)
end

puts("Recursive sum: " .. sum_recursive(1, 2, 3, 4, 5, 6, 7, 8, 9, 10).str())

# =============================================================================
# Section 20: Complex real-world example
# =============================================================================
puts("")
puts("--- Section 20: Real-world example ---")

type APIClient
    base_url
    timeout

    fun request(method, path, headers = {}, params = {}, *middleware, **options)
        let result = method .. " " .. self.base_url .. path
        result = result .. " headers=" .. headers.len().str()
        result = result .. " params=" .. params.len().str()
        result = result .. " middleware=" .. middleware.len().str()
        result = result .. " options=" .. options.len().str()
        return result
    end

    static fun build(url, timeout = 30, *plugins, **config)
        let client = APIClient.new(base_url: url, timeout: timeout)
        let info = " plugins=" .. plugins.len().str() .. " config=" .. config.len().str()
        puts("Built client with" .. info)
        return client
    end
end

let client = APIClient.build("https://api.example.com", 30, retry: true, cache: true)
puts(client.request("GET", "/users"))
puts(client.request(
    "POST",
    "/users",
    {auth: "Bearer xyz"},
    {limit: 10},
    "log_middleware",
    "cache_middleware",
    retry: 3,
    timeout: 60,
    validate: true
))

puts("")
puts("=== FUZZ TEST 004 COMPLETE ===")
