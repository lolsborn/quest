use "std/test" {it, describe, module, assert_eq, assert, assert_near}
use "std/encoding/json" as json

module("JSON Encoding Tests")

describe("JSON Stringify - Basic Types", fun ()
  it("stringifies integer", fun ()
    let result = json.stringify(42)
    assert_eq(result, "42")
  end)

  it("stringifies float", fun ()
    let result = json.stringify(3.14)
    assert_eq(result, "3.14")
  end)
   
  it("stringifies string", fun ()
    let result = json.stringify("hello")
    assert_eq(result, "\"hello\"")
  end)

  it("stringifies boolean true", fun ()
    let result = json.stringify(true)
    assert_eq(result, "true")
  end)

  it("stringifies boolean false", fun ()
    let result = json.stringify(false)
    assert_eq(result, "false")
  end)

  it("stringifies nil", fun ()
    let result = json.stringify(nil)
    assert_eq(result, "null")  end)
end)

describe("JSON Stringify - Objects", fun ()
  it("stringifies empty object", fun ()
    let result = json.stringify({})
    assert_eq(result, "{}")
  end)

  it("stringifies simple object", fun ()
    let result = json.stringify({"name": "Alice"})
    assert(result.count("name") > 0)
    assert(result.count("Alice") > 0)
  end)

  it("stringifies object with multiple fields", fun ()
    let result = json.stringify({"name": "Bob", "age": 30, "active": true})
    assert(result.count("name") > 0)
    assert(result.count("Bob") > 0)
    assert(result.count("age") > 0)
    assert(result.count("30") > 0)
    assert(result.count("active") > 0)
  end)

  it("stringifies nested object", fun ()
    let data = {"user": {"name": "Charlie", "age": 25}}
    let result = json.stringify(data)
    assert(result.count("user") > 0)
    assert(result.count("name") > 0)
    assert(result.count("Charlie") > 0)
  end)

  it("stringifies deeply nested object", fun ()
    let data = {"level1": {"level2": {"level3": {"value": 42}}}}
    let result = json.stringify(data)
    assert(result.count("level1") > 0)
    assert(result.count("level2") > 0)
    assert(result.count("level3") > 0)
    assert(result.count("value") > 0)
  end)
end)

describe("JSON Stringify - Arrays", fun ()
  it("stringifies empty array", fun ()
    let result = json.stringify([])
    assert_eq(result, "[]")
  end)

  it("stringifies simple array", fun ()
    let result = json.stringify([1, 2, 3])
    assert(result.count("1") > 0)
    assert(result.count("2") > 0)
    assert(result.count("3") > 0)
  end)

  it("stringifies array of strings", fun ()
    let result = json.stringify(["apple", "banana", "cherry"])
    assert(result.count("apple") > 0)
    assert(result.count("banana") > 0)
    assert(result.count("cherry") > 0)
  end)

  it("stringifies array of objects", fun ()
    let data = [{"id": 1}, {"id": 2}]
    let result = json.stringify(data)
    assert(result.count("id") > 0)
  end)

  it("stringifies nested arrays", fun ()
    let data = [[1, 2], [3, 4], [5, 6]]
    let result = json.stringify(data)
    assert(result.count("1") > 0)
    assert(result.count("6") > 0)
  end)
end)

describe("JSON Parse - Basic Types", fun ()
  it("parses number", fun ()
    let result = json.parse("42")
    assert_eq(result, 42)
  end)

  it("parses string", fun ()
    let result = json.parse("\"hello\"")
    assert_eq(result, "hello")
  end)

  it("parses boolean true", fun ()
    let result = json.parse("true")
    assert_eq(result, true)
  end)

  it("parses boolean false", fun ()
    let result = json.parse("false")
    assert_eq(result, false)
  end)

  it("parses null as nil", fun ()
    let result = json.parse("null")
    assert_eq(result, nil)  end)
end)

describe("JSON Parse - Objects", fun ()
  it("parses empty object", fun ()
    let result = json.parse("{}")
    # Check it's a dict by checking we can access keys
    assert_eq(result.keys().len(), 0)
  end)

  it("parses simple object", fun ()
    let result = json.parse("{\"name\": \"Alice\"}")
    assert_eq(result["name"], "Alice")
  end)

  it("parses object with multiple fields", fun ()
    let result = json.parse("{\"name\": \"Bob\", \"age\": 30}")
    assert_eq(result["name"], "Bob")
    assert_eq(result["age"], 30)
  end)    

  it("parses nested object", fun ()
    let result = json.parse("{\"user\": {\"name\": \"Charlie\"}}")
    assert_eq(result["user"]["name"], "Charlie")
  end)

  it("parses object with different value types", fun ()
    let result = json.parse("{\"str\": \"text\", \"num\": 42, \"bool\": true}")
    assert_eq(result["str"], "text")
    assert_eq(result["num"], 42)
    assert_eq(result["bool"], true)
  end)
end)

describe("JSON Parse - Arrays", fun ()
  it("parses empty array", fun ()
    let result = json.parse("[]")
    assert_eq(result.len(), 0)
  end)

  it("parses simple array", fun ()
    let result = json.parse("[1, 2, 3]")
    assert_eq(result.len(), 3)
    assert_eq(result[0], 1)
    assert_eq(result[1], 2)
    assert_eq(result[2], 3)
  end)

  it("parses array of strings", fun ()
    let result = json.parse("[\"a\", \"b\", \"c\"]")
    assert_eq(result[0], "a")
    assert_eq(result[1], "b")
    assert_eq(result[2], "c")
  end)

  it("parses array of objects", fun ()
    let result = json.parse("[{\"id\": 1}, {\"id\": 2}]")
    assert_eq(result[0]["id"], 1)
    assert_eq(result[1]["id"], 2)
  end)

  it("parses nested arrays", fun ()
    let result = json.parse("[[1, 2], [3, 4]]")
    assert_eq(result[0][0], 1)
    assert_eq(result[1][1], 4)
  end)
end)

describe("JSON Round-Trip", fun ()
  it("round-trips simple object", fun ()
    let original = {"name": "test", "value": 123}
    let serialized = json.stringify(original)
    let parsed = json.parse(serialized)
    assert_eq(parsed["name"], "test")
    assert_eq(parsed["value"], 123)
  end)

  it("round-trips array", fun ()
    let original = [1, 2, 3, 4, 5]
    let serialized = json.stringify(original)
    let parsed = json.parse(serialized)
    assert_eq(parsed.len(), 5)
    assert_eq(parsed[0], 1)
    assert_eq(parsed[4], 5)
  end)

  it("round-trips nested structure", fun ()
    let original = {"users": [{"name": "Alice"}, {"name": "Bob"}]}
    let serialized = json.stringify(original)
    let parsed = json.parse(serialized)
    assert_eq(parsed["users"][0]["name"], "Alice")
    assert_eq(parsed["users"][1]["name"], "Bob")
  end)

  it("round-trips mixed types", fun ()
    let original = {"str": "text", "num": 42, "bool": true, "arr": [1, 2, 3]}
    let serialized = json.stringify(original)
    let parsed = json.parse(serialized)
    assert_eq(parsed["str"], "text")
    assert_eq(parsed["num"], 42)
    assert_eq(parsed["bool"], true)
    assert_eq(parsed["arr"].len(), 3)
  end)
end)

describe("JSON Pretty Print", fun ()
  it("pretty prints simple object", fun ()
    let data = {"name": "Alice", "age": 30}
    let pretty = json.stringify_pretty(data)
    # Pretty printed JSON has newlines and indentation
    assert(pretty.len() > json.stringify(data).len())
  end)

  it("pretty prints nested object", fun ()
    let data = {"user": {"name": "Bob", "details": {"age": 25}}}
    let pretty = json.stringify_pretty(data)
    assert(pretty.count("\n") > 0)
  end)

  it("pretty prints array", fun ()
    let data = [1, 2, 3, 4, 5]
    let pretty = json.stringify_pretty(data)
    assert(pretty.count("\n") > 0)
  end)
end)

describe("JSON Edge Cases", fun ()
  it("handles empty string", fun ()
    let result = json.stringify("")
    assert_eq(result, "\"\"")
  end)

  it("handles string with quotes", fun ()
    let original = {"text": "She said \"hello\""}
    let serialized = json.stringify(original)
    let parsed = json.parse(serialized)
    assert(parsed["text"].count("hello") > 0)
  end)

  it("handles string with special characters", fun ()
    let original = {"text": "line1\nline2"}
    let serialized = json.stringify(original)
    let parsed = json.parse(serialized)
    assert(parsed["text"].count("line1") > 0)
  end)

  it("handles large numbers", fun ()
    let original = {"big": 999999999}
    let serialized = json.stringify(original)
    let parsed = json.parse(serialized)
    assert_eq(parsed["big"], 999999999)
  end)

  it("handles negative numbers", fun ()
    let original = {"neg": -42}
    let serialized = json.stringify(original)
    let parsed = json.parse(serialized)
    assert_eq(parsed["neg"], -42)
  end)

  it("handles floating point numbers", fun ()
    let original = {"float": 3.14}
    let serialized = json.stringify(original)
    let parsed = json.parse(serialized)
    assert_near(parsed["float"], 3.14, 0.01) 
  end)
end)
