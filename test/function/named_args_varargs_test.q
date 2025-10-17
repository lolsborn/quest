# QEP-035: Named Arguments with Varargs/Kwargs Integration

use "std/test" { module, describe, it, assert_eq }

module("QEP-035: Named Args + Varargs/Kwargs")

describe("Named args with *args", fun ()
    it("combines positional params with varargs", fun ()
        fun printf(format, *args)
            let result = format
            for arg in args
                result = result .. " " .. arg.str()
            end
            result
        end

        # Positional for format, rest go to args
        let result = printf("Values:", 1, 2, 3)
        assert_eq(result, "Values: 1 2 3")
    end)

    it("all named, empty varargs", fun ()
        fun make_list(prefix, separator, *items)
            prefix .. separator
        end

        let result = make_list(prefix: "[", separator: "]")
        assert_eq(result, "[]")
    end)
end)

describe("Named args with **kwargs", fun ()
    it("collects extra keyword args into kwargs dict", fun ()
        fun connect(host, port = 8080, **options)
            let opts_count = options.len()
            host .. ":" .. port.str() .. " (" .. opts_count.str() .. " options)"
        end

        let result = connect(host: "localhost", ssl: true, timeout: 30, debug: false)
        assert_eq(result, "localhost:8080 (3 options)")
    end)

    it("kwargs captures unmatched named args", fun ()
        fun test_func(a, b, **kwargs)
            let kw_count = kwargs.len()
            a + b + kw_count
        end

        let result = test_func(a: 10, b: 20, extra1: "x", extra2: "y", extra3: "z")
        assert_eq(result, 33)  # 10 + 20 + 3
    end)
end)

describe("Full signature: required, optional, *args, **kwargs", fun ()
    it("handles all parameter types together", fun ()
        fun full_sig(a, b = 1, *args, **kwargs)
            let args_len = args.len()
            let kwargs_len = kwargs.len()
            a + b + args_len + kwargs_len
        end

        # Only required (named)
        assert_eq(full_sig(a: 10), 11, "a=10, b=1, args=[], kwargs={}")

        # Required + optional (named)
        assert_eq(full_sig(a: 10, b: 5), 15, "a=10, b=5, args=[], kwargs={}")

        # All positional: required + optional + varargs
        assert_eq(full_sig(10, 5, 1, 2, 3), 18, "a=10, b=5, args=[1,2,3], kwargs={}")

        # Required + kwargs (all named)
        assert_eq(full_sig(a: 10, x: 1, y: 2), 13, "a=10, b=1, args=[], kwargs={x:1,y:2}")
    end)

    it("mixes positional and named with varargs/kwargs", fun ()
        fun wrapper(required, *args, **kwargs)
            let args_str = "args=" .. args.len().str()
            let kwargs_str = "kwargs=" .. kwargs.len().str()
            required.str() .. " " .. args_str .. " " .. kwargs_str
        end

        # Positional for required and varargs, named for kwargs
        let result = wrapper(100, 1, 2, opt1: "a", opt2: "b")
        assert_eq(result, "100 args=2 kwargs=2")
    end)
end)

describe("Named args with defaults and varargs", fun ()
    it("all positional with defaults and varargs", fun ()
        fun log_message(level = "INFO", prefix = "[LOG]", *parts)
            let message = prefix .. " " .. level .. ":"
            for part in parts
                message = message .. " " .. part.str()
            end
            message
        end

        let result = log_message("ERROR", "[APP]", "msg1", "msg2")
        assert_eq(result, "[APP] ERROR: msg1 msg2")
    end)

    it("uses named to skip middle defaults", fun ()
        fun flexible(a, b = 2, c = 3, *rest)
            a + b + c + rest.len()
        end

        # All positional
        assert_eq(flexible(1, 2, 10, 5, 6), 15, "a=1, b=2, c=10, rest=[5,6]")
    end)
end)
