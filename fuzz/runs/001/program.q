# Fuzz Test Session 001: Variadic Parameters, Named Arguments, and Default Parameters
# Focus: Comprehensive testing of QEP-034 (varargs, kwargs) and QEP-035 (named args)
# Tests parameter combinations, edge cases, and interaction with type system

use "std/test"

test.module("Variadic and Named Arguments Fuzzing")

# ============================================================================
# Test 1: Basic Varargs Collection
# ============================================================================

test.describe("Basic varargs collection", fun ()
    fun collect_all(*args)
        return args
    end

    test.it("collects zero arguments", fun ()
        let result = collect_all()
        test.assert_eq(result.len(), 0)
    end)

    test.it("collects single argument", fun ()
        let result = collect_all(42)
        test.assert_eq(result.len(), 1)
        test.assert_eq(result[0], 42)
    end)

    test.it("collects many arguments", fun ()
        let result = collect_all(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
        test.assert_eq(result.len(), 10)
        test.assert_eq(result[0], 1)
        test.assert_eq(result[9], 10)
    end)

    test.it("collects mixed types", fun ()
        let result = collect_all(1, "hello", 3.14, true, nil, [1,2,3])
        test.assert_eq(result.len(), 6)
        test.assert_eq(result[1], "hello")
        test.assert_eq(result[2], 3.14)
        test.assert_eq(result[3], true)
        test.assert_nil(result[4])
    end)
end)

# ============================================================================
# Test 2: Varargs with Required Parameters
# ============================================================================

test.describe("Varargs with required parameters", fun ()
    fun greet_many(greeting, *names)
        let result = greeting
        let i = 0
        while i < names.len()
            result = result .. " " .. names[i]
            i = i + 1
        end
        return result
    end

    test.it("works with just required param", fun ()
        let result = greet_many("Hello")
        test.assert_eq(result, "Hello")
    end)

    test.it("works with required and varargs", fun ()
        let result = greet_many("Hello", "Alice", "Bob", "Charlie")
        test.assert_eq(result, "Hello Alice Bob Charlie")
    end)

    test.it("preserves required param type", fun ()
        let result = greet_many("Hi", "World")
        test.assert_eq(result, "Hi World")
    end)
end)

# ============================================================================
# Test 3: Varargs with Default Parameters
# ============================================================================

test.describe("Varargs with default parameters", fun ()
    fun connect(host, port = 8080, *extra)
        let extras = ""
        let i = 0
        while i < extra.len()
            extras = extras .. extra[i].str()
            if i < extra.len() - 1
                extras = extras .. ","
            end
            i = i + 1
        end
        return host .. ":" .. port.str() .. "[" .. extras .. "]"
    end

    test.it("uses default with no extras", fun ()
        let result = connect("localhost")
        test.assert_eq(result, "localhost:8080[]")
    end)

    test.it("overrides default with no extras", fun ()
        let result = connect("localhost", 3000)
        test.assert_eq(result, "localhost:3000[]")
    end)

    test.it("works with extras", fun ()
        let result = connect("localhost", 3000, "ssl", "debug")
        test.assert_eq(result, "localhost:3000[ssl,debug]")
    end)

    test.it("uses default with extras", fun ()
        let result = connect("localhost", 8080, "log", "trace", "verbose")
        test.assert_eq(result, "localhost:8080[log,trace,verbose]")
    end)
end)

# ============================================================================
# Test 4: Named Arguments Basic
# ============================================================================

test.describe("Named arguments basic", fun ()
    fun make_person(name, age, city)
        return name .. " is " .. age.str() .. " from " .. city
    end

    test.it("all positional", fun ()
        let result = make_person("Alice", 30, "NYC")
        test.assert_eq(result, "Alice is 30 from NYC")
    end)

    test.it("all named in order", fun ()
        let result = make_person(name: "Alice", age: 30, city: "NYC")
        test.assert_eq(result, "Alice is 30 from NYC")
    end)

    test.it("all named reordered", fun ()
        let result = make_person(city: "NYC", name: "Alice", age: 30)
        test.assert_eq(result, "Alice is 30 from NYC")
    end)

    test.it("mixed positional and named", fun ()
        let result = make_person("Alice", age: 30, city: "NYC")
        test.assert_eq(result, "Alice is 30 from NYC")
    end)

    test.it("mixed with reordered named", fun ()
        let result = make_person("Alice", city: "NYC", age: 30)
        test.assert_eq(result, "Alice is 30 from NYC")
    end)
end)

# ============================================================================
# Test 5: Named Arguments with Defaults
# ============================================================================

test.describe("Named arguments skipping defaults", fun ()
    fun configure(host, port = 8080, timeout = 30, ssl = false, debug = false)
        let parts = []
        parts.push(host)
        parts.push(port.str())
        parts.push(timeout.str())
        parts.push(ssl.str())
        parts.push(debug.str())
        return parts[0] .. ":" .. parts[1] .. "," .. parts[2] .. "," .. parts[3] .. "," .. parts[4]
    end

    test.it("all defaults", fun ()
        let result = configure("localhost")
        test.assert_eq(result, "localhost:8080,30,false,false")
    end)

    test.it("skip middle params with named", fun ()
        let result = configure("localhost", ssl: true)
        test.assert_eq(result, "localhost:8080,30,true,false")
    end)

    test.it("skip multiple params", fun ()
        let result = configure("localhost", debug: true, ssl: true)
        test.assert_eq(result, "localhost:8080,30,true,true")
    end)

    test.it("override some, skip others", fun ()
        let result = configure("localhost", 9000, ssl: true)
        test.assert_eq(result, "localhost:9000,30,true,false")
    end)

    test.it("all named, different order", fun ()
        let result = configure(debug: true, host: "localhost", timeout: 60)
        test.assert_eq(result, "localhost:8080,60,false,true")
    end)
end)

# ============================================================================
# Test 6: Kwargs Collection
# ============================================================================

test.describe("Keyword arguments collection", fun ()
    fun gather_options(host, port = 8080, **options)
        let opt_list = []
        # Note: Dict iteration order may vary, so we just check presence
        return host .. ":" .. port.str() .. ":" .. options.len().str()
    end

    test.it("no extra kwargs", fun ()
        let result = gather_options("localhost")
        test.assert_eq(result, "localhost:8080:0")
    end)

    test.it("with extra kwargs", fun ()
        let result = gather_options(host: "localhost", ssl: true, timeout: 60, debug: true)
        test.assert_eq(result, "localhost:8080:3")
    end)

    test.it("positional with kwargs", fun ()
        let result = gather_options("localhost", 9000, ssl: true, debug: false)
        test.assert_eq(result, "localhost:9000:2")
    end)
end)

# ============================================================================
# Test 7: Full Parameter Combination (required, default, varargs, kwargs)
# ============================================================================

test.describe("All parameter types combined", fun ()
    fun full_combo(required, optional = "default", *args, **kwargs)
        let parts = []
        parts.push(required)
        parts.push(optional)
        parts.push(args.len().str())
        parts.push(kwargs.len().str())
        return parts[0] .. "," .. parts[1] .. "," .. parts[2] .. "," .. parts[3]
    end

    test.it("only required", fun ()
        let result = full_combo("req")
        test.assert_eq(result, "req,default,0,0")
    end)

    test.it("required and optional", fun ()
        let result = full_combo("req", "opt")
        test.assert_eq(result, "req,opt,0,0")
    end)

    test.it("required, optional, and varargs", fun ()
        let result = full_combo("req", "opt", "a", "b", "c")
        test.assert_eq(result, "req,opt,3,0")
    end)

    test.it("required with kwargs", fun ()
        let result = full_combo(required: "req", x: 1, y: 2)
        test.assert_eq(result, "req,default,0,2")
    end)

    test.it("everything combined", fun ()
        let result = full_combo("req", "opt", "a", "b", x: 1, y: 2, z: 3)
        test.assert_eq(result, "req,opt,2,3")
    end)
end)

# ============================================================================
# Test 8: Lambda Functions with Varargs
# ============================================================================

test.describe("Lambdas with varargs and defaults", fun ()
    test.it("lambda with varargs", fun ()
        let sum = fun (*nums)
            let total = 0
            let i = 0
            while i < nums.len()
                total = total + nums[i]
                i = i + 1
            end
            return total
        end

        test.assert_eq(sum(), 0)
        test.assert_eq(sum(1), 1)
        test.assert_eq(sum(1, 2, 3), 6)
        test.assert_eq(sum(1, 2, 3, 4, 5), 15)
    end)

    test.it("lambda with default and varargs", fun ()
        let multiply = fun (base = 1, *nums)
            let result = base
            let i = 0
            while i < nums.len()
                result = result * nums[i]
                i = i + 1
            end
            return result
        end

        test.assert_eq(multiply(), 1)
        test.assert_eq(multiply(2), 2)
        test.assert_eq(multiply(2, 3), 6)
        test.assert_eq(multiply(2, 3, 4), 24)
    end)
end)

# ============================================================================
# Test 9: Type Methods with Advanced Parameters
# ============================================================================

test.describe("Type methods with advanced parameters", fun ()
    type Calculator
        value: Int

        fun self.create(initial = 0)
            return Calculator.new(value: initial)
        end

        fun add(*nums)
            let total = self.value
            let i = 0
            while i < nums.len()
                total = total + nums[i]
                i = i + 1
            end
            return total
        end

        fun compute(op, a, b = 10)
            if op == "add"
                return a + b
            elif op == "mul"
                return a * b
            else
                return 0
            end
        end
    end

    test.it("static method with default", fun ()
        let calc1 = Calculator.create()
        test.assert_eq(calc1.value, 0)

        let calc2 = Calculator.create(100)
        test.assert_eq(calc2.value, 100)
    end)

    test.it("instance method with varargs", fun ()
        let calc = Calculator.create(5)
        test.assert_eq(calc.add(), 5)
        test.assert_eq(calc.add(1), 6)
        test.assert_eq(calc.add(1, 2, 3), 11)
    end)

    test.it("instance method with named args", fun ()
        let calc = Calculator.create()
        test.assert_eq(calc.compute(op: "add", a: 5, b: 3), 8)
        test.assert_eq(calc.compute(op: "mul", a: 5), 50)
        test.assert_eq(calc.compute("add", 7), 17)
    end)
end)

# ============================================================================
# Test 10: Deeply Nested Parameter Scenarios
# ============================================================================

test.describe("Deeply nested and complex scenarios", fun ()
    fun outer(a, *args, **kwargs)
        fun inner(b = 100, *more)
            let sum = a + b
            let i = 0
            while i < args.len()
                sum = sum + args[i]
                i = i + 1
            end
            let j = 0
            while j < more.len()
                sum = sum + more[j]
                j = j + 1
            end
            return sum
        end
        return inner
    end

    test.it("nested function with closures over varargs", fun ()
        let f = outer(10, 20, 30)
        test.assert_eq(f(), 160)  # 10 + 100 + 20 + 30
        test.assert_eq(f(5), 65)  # 10 + 5 + 20 + 30
        test.assert_eq(f(5, 1, 2), 68)  # 10 + 5 + 20 + 30 + 1 + 2
    end)

    test.it("passing varargs through multiple levels", fun ()
        fun level1(*nums)
            fun level2(multiplier = 2, *extra)
                let total = 0
                let i = 0
                while i < nums.len()
                    total = total + nums[i]
                    i = i + 1
                end
                let j = 0
                while j < extra.len()
                    total = total + extra[j]
                    j = j + 1
                end
                return total * multiplier
            end
            return level2
        end

        let f = level1(1, 2, 3)
        test.assert_eq(f(), 12)  # (1+2+3) * 2
        test.assert_eq(f(3), 18)  # (1+2+3) * 3
        test.assert_eq(f(1, 10), 16)  # (1+2+3+10) * 1
    end)
end)

# ============================================================================
# Test 11: Edge Cases and Boundary Conditions
# ============================================================================

test.describe("Edge cases and boundary conditions", fun ()
    test.it("many positional args", fun ()
        fun take_many(*args)
            return args.len()
        end

        let result = take_many(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20)
        test.assert_eq(result, 20)
    end)

    test.it("many named args", fun ()
        fun take_named(**kwargs)
            return kwargs.len()
        end

        let result = take_named(
            a: 1, b: 2, c: 3, d: 4, e: 5,
            f: 6, g: 7, h: 8, i: 9, j: 10,
            k: 11, l: 12, m: 13, n: 14, o: 15
        )
        test.assert_eq(result, 15)
    end)

    test.it("named args with complex expressions", fun ()
        fun compute(x, y, z = 0)
            return x + y + z
        end

        let a = 10
        let b = 20
        test.assert_eq(compute(x: a + 5, y: b * 2, z: a - 5), 60)
    end)

    test.it("varargs with large array-like inputs", fun ()
        fun sum_all(*nums)
            let total = 0
            let i = 0
            while i < nums.len()
                total = total + nums[i]
                i = i + 1
            end
            return total
        end

        # Pass many individual args
        let result = sum_all(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,
                            21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,
                            41,42,43,44,45,46,47,48,49,50)
        test.assert_eq(result, 1275)  # Sum of 1..50 = 50*51/2 = 1275
    end)
end)

# ============================================================================
# Test 12: Interaction with Other Features
# ============================================================================

test.describe("Interaction with decorators and other features", fun ()
    # Test that varargs/kwargs work with function objects
    test.it("varargs function as first-class value", fun ()
        fun make_adder(*base_nums)
            let base_sum = 0
            let i = 0
            while i < base_nums.len()
                base_sum = base_sum + base_nums[i]
                i = i + 1
            end

            fun adder(*more_nums)
                let total = base_sum
                let j = 0
                while j < more_nums.len()
                    total = total + more_nums[j]
                    j = j + 1
                end
                return total
            end
            return adder
        end

        let add_to_10 = make_adder(10)
        test.assert_eq(add_to_10(), 10)
        test.assert_eq(add_to_10(5), 15)
        test.assert_eq(add_to_10(5, 3, 2), 20)

        let add_to_100 = make_adder(50, 50)
        test.assert_eq(add_to_100(), 100)
        test.assert_eq(add_to_100(10), 110)
    end)

    test.it("named args with type constructors", fun ()
        type Point
            x: Int
            y: Int
            label: Str

            fun self.origin(x = 0, y = 0, label = "origin")
                return Point.new(x: x, y: y, label: label)
            end
        end

        let p1 = Point.origin()
        test.assert_eq(p1.x, 0)
        test.assert_eq(p1.y, 0)
        test.assert_eq(p1.label, "origin")

        let p2 = Point.origin(x: 10, y: 20)
        test.assert_eq(p2.x, 10)
        test.assert_eq(p2.y, 20)

        let p3 = Point.origin(label: "home", y: 5)
        test.assert_eq(p3.y, 5)
        test.assert_eq(p3.label, "home")
    end)
end)

puts("All fuzz tests completed!")
