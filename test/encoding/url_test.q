use "std/test"
use "std/encoding/url"

test.module("std/encoding/url")

test.describe("encode", fun ()
    test.it("encodes spaces", fun ()
        let encoded = url.encode("Hello World")
        test.assert_eq(encoded, "Hello%20World", nil)
    end)

    test.it("encodes special characters", fun ()
        let encoded = url.encode("Hello, World!")
        test.assert_eq(encoded, "Hello%2C%20World%21", nil)
    end)

    test.it("preserves unreserved characters", fun ()
        let encoded = url.encode("abc123-_.~")
        test.assert_eq(encoded, "abc123-_.~", nil)
    end)

    test.it("encodes UTF-8 characters", fun ()
        let encoded = url.encode("café")
        test.assert_eq(encoded, "caf%C3%A9", nil)
    end)

    test.it("encodes empty string", fun ()
        let encoded = url.encode("")
        test.assert_eq(encoded, "", nil)
    end)
end)

test.describe("encode_component", fun ()
    test.it("encodes with stricter rules", fun ()
        let encoded = url.encode_component("hello world")
        test.assert_eq(encoded, "hello%20world", nil)
    end)

    test.it("preserves sub-delimiters", fun ()
        let encoded = url.encode_component("!*'()")
        test.assert_eq(encoded, "!*'()", nil)
    end)
end)

test.describe("encode_path", fun ()
    test.it("preserves path separators", fun ()
        let encoded = url.encode_path("/api/users/John Doe")
        test.assert_eq(encoded, "/api/users/John%20Doe", nil)
    end)

    test.it("encodes special characters in path", fun ()
        let encoded = url.encode_path("/path/with spaces/and,commas")
        test.assert_eq(encoded, "/path/with%20spaces/and%2Ccommas", nil)
    end)
end)

test.describe("encode_query", fun ()
    test.it("preserves query delimiters", fun ()
        let encoded = url.encode_query("name=John Doe&age=30")
        test.assert_eq(encoded, "name=John%20Doe&age=30", nil)
    end)

    test.it("encodes special characters in query", fun ()
        let encoded = url.encode_query("search=hello, world")
        test.assert_eq(encoded, "search=hello%2C%20world", nil)
    end)
end)

test.describe("decode", fun ()
    test.it("decodes percent-encoded spaces", fun ()
        let decoded = url.decode("Hello%20World")
        test.assert_eq(decoded, "Hello World", nil)
    end)

    test.it("decodes plus as space", fun ()
        let decoded = url.decode("Hello+World")
        test.assert_eq(decoded, "Hello World", nil)
    end)

    test.it("decodes special characters", fun ()
        let decoded = url.decode("Hello%2C%20World%21")
        test.assert_eq(decoded, "Hello, World!", nil)
    end)

    test.it("decodes UTF-8 characters", fun ()
        let decoded = url.decode("caf%C3%A9")
        test.assert_eq(decoded, "café", nil)
    end)

    test.it("decodes empty string", fun ()
        let decoded = url.decode("")
        test.assert_eq(decoded, "", nil)
    end)

    test.it("handles mixed encoding", fun ()
        let decoded = url.decode("hello%20world+test")
        test.assert_eq(decoded, "hello world test", nil)
    end)
end)

test.describe("decode_component", fun ()
    test.it("decodes without treating plus as space", fun ()
        let decoded = url.decode_component("a%2Bb%3Dc")
        test.assert_eq(decoded, "a+b=c", nil)
    end)

    test.it("preserves literal plus signs", fun ()
        let decoded = url.decode_component("hello+world")
        test.assert_eq(decoded, "hello+world", nil)
    end)
end)

test.describe("build_query", fun ()
    test.it("builds query string from dict", fun ()
        let params = {"name": "John", "age": "30"}
        let query = url.build_query(params)
        # Order may vary, so just check that both keys are present
        test.assert_eq(query.contains("name=John"), true, nil)
        test.assert_eq(query.contains("age=30"), true, nil)
    end)

    test.it("encodes query values", fun ()
        let params = {"search": "Hello World"}
        let query = url.build_query(params)
        test.assert_eq(query, "search=Hello%20World", nil)
    end)

    test.it("handles empty dict", fun ()
        let params = {}
        let query = url.build_query(params)
        test.assert_eq(query, "", nil)
    end)

    test.it("encodes special characters in values", fun ()
        let params = {"msg": "Hello, World!"}
        let query = url.build_query(params)
        test.assert_eq(query, "msg=Hello%2C%20World%21", nil)
    end)
end)

test.describe("parse_query", fun ()
    test.it("parses simple query string", fun ()
        let params = url.parse_query("name=John&age=30")
        test.assert_eq(params["name"], "John", nil)
        test.assert_eq(params["age"], "30", nil)
    end)

    test.it("parses with leading question mark", fun ()
        let params = url.parse_query("?name=John&age=30")
        test.assert_eq(params["name"], "John", nil)
        test.assert_eq(params["age"], "30", nil)
    end)

    test.it("decodes percent-encoded values", fun ()
        let params = url.parse_query("search=Hello%20World")
        test.assert_eq(params["search"], "Hello World", nil)
    end)

    test.it("decodes plus as space", fun ()
        let params = url.parse_query("search=Hello+World")
        test.assert_eq(params["search"], "Hello World", nil)
    end)

    test.it("handles empty query", fun ()
        let params = url.parse_query("")
        test.assert_eq(params.len(), 0, nil)
    end)

    test.it("handles keys without values", fun ()
        let params = url.parse_query("key1&key2=value")
        test.assert_eq(params["key1"], "", nil)
        test.assert_eq(params["key2"], "value", nil)
    end)
end)

test.describe("error handling", fun ()
    test.it("raises error for invalid percent encoding", fun ()
        test.assert_raises("Invalid percent encoding", fun ()
            url.decode("hello%2")
        end, nil)
    end)

    test.it("raises error for invalid hex in percent encoding", fun ()
        test.assert_raises("Invalid hex digit in percent encoding", fun ()
            url.decode("hello%GG")
        end, nil)
    end)
end)

test.describe("round trip", fun ()
    test.it("encodes and decodes correctly", fun ()
        let original = "Hello, World! 你好"
        let encoded = url.encode(original)
        let decoded = url.decode(encoded)
        test.assert_eq(decoded, original, nil)
    end)

    test.it("query string round trip", fun ()
        let original = {"name": "John Doe", "city": "New York"}
        let query = url.build_query(original)
        let parsed = url.parse_query(query)
        test.assert_eq(parsed["name"], "John Doe", nil)
        test.assert_eq(parsed["city"], "New York", nil)
    end)
end)

test.describe("real-world examples", fun ()
    test.it("builds API query string", fun ()
        let params = {
            "q": "rust programming",
            "limit": "10",
            "sort": "relevance"
        }
        let query = url.build_query(params)
        # Just check it contains the expected parts (order may vary)
        test.assert_eq(query.contains("q=rust%20programming"), true, nil)
        test.assert_eq(query.contains("limit=10"), true, nil)
        test.assert_eq(query.contains("sort=relevance"), true, nil)
    end)

    test.it("parses real query string", fun ()
        let query = "?search=hello+world&page=2&filter=active"
        let params = url.parse_query(query)
        test.assert_eq(params["search"], "hello world", nil)
        test.assert_eq(params["page"], "2", nil)
        test.assert_eq(params["filter"], "active", nil)
    end)
end)
