# Dictionary Basic Tests
# Tests fundamental dictionary operations

use "std/test" {it, describe, module, assert_eq, assert_neq, assert_type, assert, assert_nil}

module("Dictionary Tests")

describe("Dictionary Creation", fun ()
  it("creates empty dictionary", fun ()
    let empty = {}
    assert_eq(empty.len(), 0)
  end)

  it("creates dictionary with string keys", fun ()
    let d = {"name": "Quest", "version": 1}
    assert_eq(d.len(), 2)
  end)

  it("creates dictionary with mixed value types", fun ()
    let mixed = {"num": 42, "str": "hello", "bool": true, "nil": nil}
    assert_eq(mixed.len(), 4)
  end)

  it("creates dictionary with nested values", fun ()
    let nested = {"user": {"name": "Alice", "age": 30}}
    assert_eq(nested.len(), 1)
  end)
end)

describe("Dictionary Access", fun ()
  let person = {"name": "Alice", "age": 30, "city": "NYC"}

  it("accesses values by key with brackets", fun ()
    assert_eq(person["name"], "Alice")
    assert_eq(person["age"], 30)
    assert_eq(person["city"], "NYC")
  end)

  it("uses get() method", fun ()
    assert_eq(person.get("name"), "Alice")
    assert_eq(person.get("age"), 30)
  end)

  it("returns nil for missing keys", fun ()
    assert_nil(person["missing"])
    assert_nil(person.get("nothere"))
  end)
end)

describe("Dictionary Modification", fun ()
  it("sets values with brackets", fun ()
    let d = {"x": 1}
    d["x"] = 10
    assert_eq(d["x"], 10)
  end)

  it("adds new keys with brackets", fun ()
    let d = {"a": 1}
    d["b"] = 2
    assert_eq(d["b"], 2)
    assert_eq(d.len(), 2)
  end)

  it("uses set() method", fun ()
    let d = {"x": 1}
    d = d.set("x", 100)
    assert_eq(d["x"], 100)
  end)

  it("set() adds new keys", fun ()
    let d = {}
    d = d.set("new", "value")
    assert_eq(d["new"], "value")
  end)
end)

describe("Dictionary Query Methods", fun ()
  let data = {"name": "Quest", "version": 1, "active": true}

  it("checks if key exists with contains()", fun ()
    assert(data.contains("name"))
    assert(data.contains("version"))
    assert(not data.contains("missing"))
  end)

  it("gets all keys", fun ()
    let keys = data.keys()
    assert_eq(keys.len(), 3)
    assert(keys.contains("name"))
    assert(keys.contains("version"))
    assert(keys.contains("active"))
  end)

  it("gets all values", fun ()
    let values = data.values()
    assert_eq(values.len(), 3)
    assert(values.contains("Quest"))
    assert(values.contains(1))
    assert(values.contains(true))
  end)

  it("gets length", fun ()
    assert_eq(data.len(), 3)
  end)
end)

describe("Dictionary Remove Operations", fun ()
  it("removes keys with remove()", fun ()
    let d = {"a": 1, "b": 2, "c": 3}
    d = d.remove("b")
    assert_eq(d.len(), 2)
    assert(not d.contains("b"))
    assert_nil(d["b"])
  end)

  it("remove() handles missing keys", fun ()
    let d = {"a": 1}
    d = d.remove("nothere")
    assert_eq(d.len(), 1)
  end)
end)

describe("Dictionary Iteration", fun ()
  it("iterates with each()", fun ()
    let d = {"a": 1, "b": 2, "c": 3}
    let sum = 0
    d.each(fun (key, value) sum = sum + value end)
    assert_eq(sum, 6)
  end)

  it("each() receives both key and value", fun ()
    let d = {"x": 10, "y": 20}
    let keys_seen = []
    d.each(fun (key, value) keys_seen.push(key) end)
    assert_eq(keys_seen.len(), 2)
  end)

  it("iterates over keys with keys().each()", fun ()
    let d = {"a": 1, "b": 2, "c": 3}
    let sum = 0
    d.keys().each(fun (key) sum = sum + d[key] end)
    assert_eq(sum, 6)
  end)

  it("iterates over values with values().each()", fun ()
    let d = {"x": 10, "y": 20, "z": 30}
    let total = 0
    d.values().each(fun (value) total = total + value end)
    assert_eq(total, 60) 
  end)
end)

describe("Dictionary with Different Value Types", fun ()
  it("stores numbers", fun ()
    let d = {"int": 42, "float": 3.14}
    assert_eq(d["int"], 42)
    assert_eq(d["float"], 3.14)
  end)

  it("stores strings", fun ()
    let d = {"greeting": "hello", "name": "world"}
    assert_eq(d["greeting"], "hello")
    assert_eq(d["name"], "world")
  end)
  it("stores booleans", fun ()
    let d = {"yes": true, "no": false}
    assert(d["yes"])
    assert(not d["no"])
  end)

  it("stores nil", fun ()
    let d = {"empty": nil}
    assert_nil(d["empty"])
  end)
  it("stores arrays", fun ()
    let d = {"numbers": [1, 2, 3], "words": ["a", "b"]}
    assert_eq(d["numbers"].len(), 3)
    assert_eq(d["words"][0], "a")
  end)
  it("stores nested dictionaries", fun ()
    let d = {"user": {"name": "Alice", "age": 30}}
    assert_eq(d["user"]["name"], "Alice")
    assert_eq(d["user"]["age"], 30)
  end)
end)

describe("Dictionary Edge Cases", fun ()
  it("handles empty dictionary operations", fun ()
    let empty = {}
    assert_eq(empty.len(), 0)
    assert_eq(empty.keys().len(), 0)
    assert_eq(empty.values().len(), 0)
    assert(not empty.contains("anything"))
  end)

  it("handles single entry", fun ()
    let single = {"only": "one"}
    assert_eq(single.len(), 1)
    assert_eq(single["only"], "one") 
  end)

  it("overwrites existing keys", fun ()
    let d = {"x": 1}
    d["x"] = 2
    d["x"] = 3
    assert_eq(d["x"], 3)
    assert_eq(d.len(), 1)
  end)

  it("handles keys with special characters", fun ()
    let d = {"key-with-dash": 1, "key_with_underscore": 2}
    assert_eq(d["key-with-dash"], 1)
    assert_eq(d["key_with_underscore"], 2)
  end)
end)

describe("Dictionary Key Types", fun ()
  it("uses string keys", fun ()
    let d = {"name": "value"}
    assert_eq(d["name"], "value")  end)

  it("handles empty string keys", fun ()
    let d = {"": "empty key"}
    assert_eq(d[""], "empty key")  end)

  it("handles numeric string keys", fun ()
    let d = {"123": "numeric string", "3.14": "float string"}
    assert_eq(d["123"], "numeric string")
    assert_eq(d["3.14"], "float string")
  end)
end)

describe("Dictionary Key Checking", fun ()
  let person = {"name": "Alice", "age": 30, "city": "NYC"}

  it("contains() checks if key exists", fun ()
    assert(person.contains("name"), "should contain 'name' key")
    assert(person.contains("age"), "should contain 'age' key")
    assert_eq(person.contains("email"), false, "should not contain 'email' key")
  end)

  it("contains() works with empty dict", fun ()
    let empty = {}
    assert_eq(empty.contains("any"), false, "empty dict should not contain any key")
  end)

  it("contains() returns true for keys with nil values", fun ()
    let d = {"key": nil}
    assert(d.contains("key"), "should contain key even if value is nil")
  end)
end)
