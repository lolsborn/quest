use "std/test" as test
use "std/encoding/json" as json

test.module("JSON Encoding Tests")

test.describe("JSON Stringify - Basic Types", fun ()
    test.it("stringifies integer", fun ()
        let result = json.stringify(42)
        test.assert_eq(result, "42")    end)

    test.it("stringifies float", fun ()
        let result = json.stringify(3.14)
        test.assert_eq(result, "3.14")    end)

    test.it("stringifies string", fun ()
        let result = json.stringify("hello")
        test.assert_eq(result, "\"hello\"")    end)

    test.it("stringifies boolean true", fun ()
        let result = json.stringify(true)
        test.assert_eq(result, "true")    end)

    test.it("stringifies boolean false", fun ()
        let result = json.stringify(false)
        test.assert_eq(result, "false")    end)

    test.it("stringifies nil", fun ()
        let result = json.stringify(nil)
        test.assert_eq(result, "null")    end)
end)

test.describe("JSON Stringify - Objects", fun ()
    test.it("stringifies empty object", fun ()
        let result = json.stringify({})
        test.assert_eq(result, "{}")    end)

    test.it("stringifies simple object", fun ()
        let result = json.stringify({"name": "Alice"})
        test.assert(result.count("name") > 0)
        test.assert(result.count("Alice") > 0)
    end)

    test.it("stringifies object with multiple fields", fun ()
        let result = json.stringify({"name": "Bob", "age": 30, "active": true})
        test.assert(result.count("name") > 0)
        test.assert(result.count("Bob") > 0)
        test.assert(result.count("age") > 0)
        test.assert(result.count("30") > 0)
        test.assert(result.count("active") > 0)
    end)

    test.it("stringifies nested object", fun ()
        let data = {"user": {"name": "Charlie", "age": 25}}
        let result = json.stringify(data)
        test.assert(result.count("user") > 0)
        test.assert(result.count("name") > 0)
        test.assert(result.count("Charlie") > 0)
    end)

    test.it("stringifies deeply nested object", fun ()
        let data = {"level1": {"level2": {"level3": {"value": 42}}}}
        let result = json.stringify(data)
        test.assert(result.count("level1") > 0)
        test.assert(result.count("level2") > 0)
        test.assert(result.count("level3") > 0)
        test.assert(result.count("value") > 0)
    end)
end)

test.describe("JSON Stringify - Arrays", fun ()
    test.it("stringifies empty array", fun ()
        let result = json.stringify([])
        test.assert_eq(result, "[]")    end)

    test.it("stringifies simple array", fun ()
        let result = json.stringify([1, 2, 3])
        test.assert(result.count("1") > 0)
        test.assert(result.count("2") > 0)
        test.assert(result.count("3") > 0)
    end)

    test.it("stringifies array of strings", fun ()
        let result = json.stringify(["apple", "banana", "cherry"])
        test.assert(result.count("apple") > 0)
        test.assert(result.count("banana") > 0)
        test.assert(result.count("cherry") > 0)
    end)

    test.it("stringifies array of objects", fun ()
        let data = [{"id": 1}, {"id": 2}]
        let result = json.stringify(data)
        test.assert(result.count("id") > 0)
    end)

    test.it("stringifies nested arrays", fun ()
        let data = [[1, 2], [3, 4], [5, 6]]
        let result = json.stringify(data)
        test.assert(result.count("1") > 0)
        test.assert(result.count("6") > 0)
    end)
end)

test.describe("JSON Parse - Basic Types", fun ()
    test.it("parses number", fun ()
        let result = json.parse("42")
        test.assert_eq(result, 42)    end)

    test.it("parses string", fun ()
        let result = json.parse("\"hello\"")
        test.assert_eq(result, "hello")    end)

    test.it("parses boolean true", fun ()
        let result = json.parse("true")
        test.assert_eq(result, true)    end)

    test.it("parses boolean false", fun ()
        let result = json.parse("false")
        test.assert_eq(result, false)    end)

    test.it("parses null as nil", fun ()
        let result = json.parse("null")
        test.assert_eq(result, nil)    end)
end)

test.describe("JSON Parse - Objects", fun ()
    test.it("parses empty object", fun ()
        let result = json.parse("{}")
        # Check it's a dict by checking we can access keys
        test.assert_eq(result.keys().len(), 0)
    end)

    test.it("parses simple object", fun ()
        let result = json.parse("{\"name\": \"Alice\"}")
        test.assert_eq(result["name"], "Alice")    end)

    test.it("parses object with multiple fields", fun ()
        let result = json.parse("{\"name\": \"Bob\", \"age\": 30}")
        test.assert_eq(result["name"], "Bob")        test.assert_eq(result["age"], 30)    end)

    test.it("parses nested object", fun ()
        let result = json.parse("{\"user\": {\"name\": \"Charlie\"}}")
        test.assert_eq(result["user"]["name"], "Charlie")    end)

    test.it("parses object with different value types", fun ()
        let result = json.parse("{\"str\": \"text\", \"num\": 42, \"bool\": true}")
        test.assert_eq(result["str"], "text")        test.assert_eq(result["num"], 42)        test.assert_eq(result["bool"], true)    end)
end)

test.describe("JSON Parse - Arrays", fun ()
    test.it("parses empty array", fun ()
        let result = json.parse("[]")
        test.assert_eq(result.len(), 0)
    end)

    test.it("parses simple array", fun ()
        let result = json.parse("[1, 2, 3]")
        test.assert_eq(result.len(), 3)
        test.assert_eq(result[0], 1)        test.assert_eq(result[1], 2)        test.assert_eq(result[2], 3)    end)

    test.it("parses array of strings", fun ()
        let result = json.parse("[\"a\", \"b\", \"c\"]")
        test.assert_eq(result[0], "a")        test.assert_eq(result[1], "b")        test.assert_eq(result[2], "c")    end)

    test.it("parses array of objects", fun ()
        let result = json.parse("[{\"id\": 1}, {\"id\": 2}]")
        test.assert_eq(result[0]["id"], 1)        test.assert_eq(result[1]["id"], 2)    end)

    test.it("parses nested arrays", fun ()
        let result = json.parse("[[1, 2], [3, 4]]")
        test.assert_eq(result[0][0], 1)        test.assert_eq(result[1][1], 4)    end)
end)

test.describe("JSON Round-Trip", fun ()
    test.it("round-trips simple object", fun ()
        let original = {"name": "test", "value": 123}
        let serialized = json.stringify(original)
        let parsed = json.parse(serialized)
        test.assert_eq(parsed["name"], "test")        test.assert_eq(parsed["value"], 123)    end)

    test.it("round-trips array", fun ()
        let original = [1, 2, 3, 4, 5]
        let serialized = json.stringify(original)
        let parsed = json.parse(serialized)
        test.assert_eq(parsed.len(), 5)
        test.assert_eq(parsed[0], 1)        test.assert_eq(parsed[4], 5)    end)

    test.it("round-trips nested structure", fun ()
        let original = {"users": [{"name": "Alice"}, {"name": "Bob"}]}
        let serialized = json.stringify(original)
        let parsed = json.parse(serialized)
        test.assert_eq(parsed["users"][0]["name"], "Alice")        test.assert_eq(parsed["users"][1]["name"], "Bob")    end)

    test.it("round-trips mixed types", fun ()
        let original = {"str": "text", "num": 42, "bool": true, "arr": [1, 2, 3]}
        let serialized = json.stringify(original)
        let parsed = json.parse(serialized)
        test.assert_eq(parsed["str"], "text")        test.assert_eq(parsed["num"], 42)        test.assert_eq(parsed["bool"], true)        test.assert_eq(parsed["arr"].len(), 3)
    end)
end)

test.describe("JSON Pretty Print", fun ()
    test.it("pretty prints simple object", fun ()
        let data = {"name": "Alice", "age": 30}
        let pretty = json.stringify_pretty(data)
        # Pretty printed JSON has newlines and indentation
        test.assert(pretty.len() > json.stringify(data).len())
    end)

    test.it("pretty prints nested object", fun ()
        let data = {"user": {"name": "Bob", "details": {"age": 25}}}
        let pretty = json.stringify_pretty(data)
        test.assert(pretty.count("\n") > 0)
    end)

    test.it("pretty prints array", fun ()
        let data = [1, 2, 3, 4, 5]
        let pretty = json.stringify_pretty(data)
        test.assert(pretty.count("\n") > 0)
    end)
end)

test.describe("JSON Edge Cases", fun ()
    test.it("handles empty string", fun ()
        let result = json.stringify("")
        test.assert_eq(result, "\"\"")    end)

    test.it("handles string with quotes", fun ()
        let original = {"text": "She said \"hello\""}
        let serialized = json.stringify(original)
        let parsed = json.parse(serialized)
        test.assert(parsed["text"].count("hello") > 0)
    end)

    test.it("handles string with special characters", fun ()
        let original = {"text": "line1\nline2"}
        let serialized = json.stringify(original)
        let parsed = json.parse(serialized)
        test.assert(parsed["text"].count("line1") > 0)
    end)

    test.it("handles large numbers", fun ()
        let original = {"big": 999999999}
        let serialized = json.stringify(original)
        let parsed = json.parse(serialized)
        test.assert_eq(parsed["big"], 999999999)    end)

    test.it("handles negative numbers", fun ()
        let original = {"neg": -42}
        let serialized = json.stringify(original)
        let parsed = json.parse(serialized)
        test.assert_eq(parsed["neg"], -42)    end)

    test.it("handles floating point numbers", fun ()
        let original = {"float": 3.14}
        let serialized = json.stringify(original)
        let parsed = json.parse(serialized)
        test.assert_near(parsed["float"], 3.14, 0.01)    end)
end)
