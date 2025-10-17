use "std/test" {it, describe, module, assert_eq, assert_raises}
use "std/encoding/url"

module("std/encoding/url")

describe("encode", fun ()
  it("encodes spaces", fun ()
    let encoded = url.encode("Hello World")
    assert_eq(encoded, "Hello%20World")
  end)

  it("encodes special characters", fun ()
    let encoded = url.encode("Hello, World!")
    assert_eq(encoded, "Hello%2C%20World%21")
  end)
  it("preserves unreserved characters", fun ()
    let encoded = url.encode("abc123-_.~")
    assert_eq(encoded, "abc123-_.~")
  end)

  it("encodes UTF-8 characters", fun ()
    let encoded = url.encode("café")
    assert_eq(encoded, "caf%C3%A9")
  end)

  it("encodes empty string", fun ()
    let encoded = url.encode("")
    assert_eq(encoded, "")
  end)
end)

describe("encode_component", fun ()
  it("encodes with stricter rules", fun ()
    let encoded = url.encode_component("hello world")
    assert_eq(encoded, "hello%20world")
  end)

  it("preserves sub-delimiters", fun ()
    let encoded = url.encode_component("!*'()")
    assert_eq(encoded, "!*'()")
  end)
end)

describe("encode_path", fun ()
  it("preserves path separators", fun ()
    let encoded = url.encode_path("/api/users/John Doe")
    assert_eq(encoded, "/api/users/John%20Doe")
  end)

  it("encodes special characters in path", fun ()
    let encoded = url.encode_path("/path/with spaces/and,commas")
    assert_eq(encoded, "/path/with%20spaces/and%2Ccommas")
  end)
end)

describe("encode_query", fun ()
  it("preserves query delimiters", fun ()
    let encoded = url.encode_query("name=John Doe&age=30")
    assert_eq(encoded, "name=John%20Doe&age=30")
  end)

  it("encodes special characters in query", fun ()
    let encoded = url.encode_query("search=hello, world")
    assert_eq(encoded, "search=hello%2C%20world")
  end)
end)

describe("decode", fun ()
  it("decodes percent-encoded spaces", fun ()
    let decoded = url.decode("Hello%20World")
    assert_eq(decoded, "Hello World")
  end)

  it("decodes plus as space", fun ()
    let decoded = url.decode("Hello+World")
    assert_eq(decoded, "Hello World")
  end)

  it("decodes special characters", fun ()
    let decoded = url.decode("Hello%2C%20World%21")
    assert_eq(decoded, "Hello, World!")
  end)

  it("decodes UTF-8 characters", fun ()
    let decoded = url.decode("caf%C3%A9")
    assert_eq(decoded, "café")
  end)

  it("decodes empty string", fun ()
    let decoded = url.decode("")
    assert_eq(decoded, "")
  end)

  it("handles mixed encoding", fun ()
    let decoded = url.decode("hello%20world+test")
    assert_eq(decoded, "hello world test")
  end)
end)

describe("decode_component", fun ()
  it("decodes without treating plus as space", fun ()
    let decoded = url.decode_component("a%2Bb%3Dc")
    assert_eq(decoded, "a+b=c")
  end)

  it("preserves literal plus signs", fun ()
    let decoded = url.decode_component("hello+world")
    assert_eq(decoded, "hello+world")
  end)
end)

describe("build_query", fun ()
  it("builds query string from dict", fun ()
    let params = {"name": "John", "age": "30"}
    let query = url.build_query(params)
    # Order may vary, so just check that both keys are present
    assert_eq(query.contains("name=John"), true)
    assert_eq(query.contains("age=30"), true)
  end)

  it("encodes query values", fun ()
    let params = {"search": "Hello World"}
    let query = url.build_query(params)
    assert_eq(query, "search=Hello%20World")
  end)

  it("handles empty dict", fun ()
    let params = {}
    let query = url.build_query(params)
    assert_eq(query, "")
  end)

  it("encodes special characters in values", fun ()
    let params = {"msg": "Hello, World!"}
    let query = url.build_query(params)
    assert_eq(query, "msg=Hello%2C%20World%21")
  end)
end)

describe("parse_query", fun ()
  it("parses simple query string", fun ()
    let params = url.parse_query("name=John&age=30")
    assert_eq(params["name"], "John")
    assert_eq(params["age"], "30")
  end)

  it("parses with leading question mark", fun ()
    let params = url.parse_query("?name=John&age=30")
    assert_eq(params["name"], "John")
    assert_eq(params["age"], "30")
  end)

  it("decodes percent-encoded values", fun ()
    let params = url.parse_query("search=Hello%20World")
    assert_eq(params["search"], "Hello World")
  end)

  it("decodes plus as space", fun ()
    let params = url.parse_query("search=Hello+World")
    assert_eq(params["search"], "Hello World")
  end)

  it("handles empty query", fun ()
    let params = url.parse_query("")
    assert_eq(params.len(), 0)
  end)

  it("handles keys without values", fun ()
    let params = url.parse_query("key1&key2=value")
    assert_eq(params["key1"], "")
    assert_eq(params["key2"], "value")
  end)
end)

describe("error handling", fun ()
  it("raises error for invalid percent encoding", fun ()
    assert_raises(Err, fun ()
      url.decode("hello%2")
    end)
  end)

  it("raises error for invalid hex in percent encoding", fun ()
    assert_raises(Err, fun ()
      url.decode("hello%GG")
    end)
  end)
end)

describe("round trip", fun ()
  it("encodes and decodes correctly", fun ()
    let original = "Hello, World! 你好"
    let encoded = url.encode(original)
    let decoded = url.decode(encoded)
    assert_eq(decoded, original)
  end)

  it("query string round trip", fun ()
    let original = {"name": "John Doe", "city": "New York"}
    let query = url.build_query(original)
    let parsed = url.parse_query(query)
    assert_eq(parsed["name"], "John Doe")
    assert_eq(parsed["city"], "New York")
  end)
end)

describe("real-world examples", fun ()
  it("builds API query string", fun ()
    let params = {
      "q": "rust programming",
      "limit": "10",
      "sort": "relevance"
    }
    let query = url.build_query(params)
    # Just check it contains the expected parts (order may vary)
    assert_eq(query.contains("q=rust%20programming"), true)
    assert_eq(query.contains("limit=10"), true)
    assert_eq(query.contains("sort=relevance"), true)
  end)

  it("parses real query string", fun ()
    let query = "?search=hello+world&page=2&filter=active"
    let params = url.parse_query(query)
    assert_eq(params["search"], "hello world")
    assert_eq(params["page"], "2")
    assert_eq(params["filter"], "active")
  end)
end)
