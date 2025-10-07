# Dictionary Basic Tests
# Tests fundamental dictionary operations

use "std/test" as test

test.module("Dictionary Tests")

test.describe("Dictionary Creation", fun ()
    test.it("creates empty dictionary", fun ()
        let empty = {}
        test.assert_eq(empty.len(), 0, nil)
    end)

    test.it("creates dictionary with string keys", fun ()
        let d = {"name": "Quest", "version": 1}
        test.assert_eq(d.len(), 2, nil)
    end)

    test.it("creates dictionary with mixed value types", fun ()
        let mixed = {"num": 42, "str": "hello", "bool": true, "nil": nil}
        test.assert_eq(mixed.len(), 4, nil)
    end)

    test.it("creates dictionary with nested values", fun ()
        let nested = {"user": {"name": "Alice", "age": 30}}
        test.assert_eq(nested.len(), 1, nil)
    end)
end)

test.describe("Dictionary Access", fun ()
    let person = {"name": "Alice", "age": 30, "city": "NYC"}

    test.it("accesses values by key with brackets", fun ()
        test.assert_eq(person["name"], "Alice")        test.assert_eq(person["age"], 30)        test.assert_eq(person["city"], "NYC")    end)

    test.it("uses get() method", fun ()
        test.assert_eq(person.get("name"), "Alice", nil)
        test.assert_eq(person.get("age"), 30, nil)
    end)

    test.it("returns nil for missing keys", fun ()
        test.assert_nil(person["missing"])        test.assert_nil(person.get("nothere"), nil)
    end)
end)

test.describe("Dictionary Modification", fun ()
    test.it("sets values with brackets", fun ()
        let d = {"x": 1}
        d["x"] = 10
        test.assert_eq(d["x"], 10)    end)

    test.it("adds new keys with brackets", fun ()
        let d = {"a": 1}
        d["b"] = 2
        test.assert_eq(d["b"], 2)        test.assert_eq(d.len(), 2, nil)
    end)

    test.it("uses set() method", fun ()
        let d = {"x": 1}
        d = d.set("x", 100)
        test.assert_eq(d["x"], 100)    end)

    test.it("set() adds new keys", fun ()
        let d = {}
        d = d.set("new", "value")
        test.assert_eq(d["new"], "value")    end)
end)

test.describe("Dictionary Query Methods", fun ()
    let data = {"name": "Quest", "version": 1, "active": true}

    test.it("checks if key exists with contains()", fun ()
        test.assert(data.contains("name"), nil)
        test.assert(data.contains("version"), nil)
        test.assert(not data.contains("missing"), nil)
    end)

    test.it("gets all keys", fun ()
        let keys = data.keys()
        test.assert_eq(keys.len(), 3, nil)
        test.assert(keys.contains("name"), nil)
        test.assert(keys.contains("version"), nil)
        test.assert(keys.contains("active"), nil)
    end)

    test.it("gets all values", fun ()
        let values = data.values()
        test.assert_eq(values.len(), 3, nil)
        test.assert(values.contains("Quest"), nil)
        test.assert(values.contains(1), nil)
        test.assert(values.contains(true), nil)
    end)

    test.it("gets length", fun ()
        test.assert_eq(data.len(), 3, nil)
    end)
end)

test.describe("Dictionary Remove Operations", fun ()
    test.it("removes keys with remove()", fun ()
        let d = {"a": 1, "b": 2, "c": 3}
        d = d.remove("b")
        test.assert_eq(d.len(), 2, nil)
        test.assert(not d.contains("b"), nil)
        test.assert_nil(d["b"])    end)

    test.it("remove() handles missing keys", fun ()
        let d = {"a": 1}
        d = d.remove("nothere")
        test.assert_eq(d.len(), 1, nil)
    end)
end)

test.describe("Dictionary Iteration", fun ()
    test.it("iterates with each()", fun ()
        let d = {"a": 1, "b": 2, "c": 3}
        let sum = 0
        d.each(fun (key, value) sum = sum + value end)
        test.assert_eq(sum, 6)    end)

    test.it("each() receives both key and value", fun ()
        let d = {"x": 10, "y": 20}
        let keys_seen = []
        d.each(fun (key, value) keys_seen.push(key) end)
        test.assert_eq(keys_seen.len(), 2, nil)
    end)

    test.it("iterates over keys with keys().each()", fun ()
        let d = {"a": 1, "b": 2, "c": 3}
        let sum = 0
        d.keys().each(fun (key) sum = sum + d[key] end)
        test.assert_eq(sum, 6)    end)

    test.it("iterates over values with values().each()", fun ()
        let d = {"x": 10, "y": 20, "z": 30}
        let total = 0
        d.values().each(fun (value) total = total + value end)
        test.assert_eq(total, 60)    end)
end)

test.describe("Dictionary with Different Value Types", fun ()
    test.it("stores numbers", fun ()
        let d = {"int": 42, "float": 3.14}
        test.assert_eq(d["int"], 42)        test.assert_near(d["float"], 3.14, 0.01)    end)

    test.it("stores strings", fun ()
        let d = {"greeting": "hello", "name": "world"}
        test.assert_eq(d["greeting"], "hello")    end)

    test.it("stores booleans", fun ()
        let d = {"yes": true, "no": false}
        test.assert(d["yes"])        test.assert(not d["no"])    end)

    test.it("stores nil", fun ()
        let d = {"empty": nil}
        test.assert_nil(d["empty"])    end)

    test.it("stores arrays", fun ()
        let d = {"numbers": [1, 2, 3], "words": ["a", "b"]}
        test.assert_eq(d["numbers"].len(), 3, nil)
        test.assert_eq(d["words"][0], "a")    end)

    test.it("stores nested dictionaries", fun ()
        let d = {"user": {"name": "Alice", "age": 30}}
        test.assert_eq(d["user"]["name"], "Alice")        test.assert_eq(d["user"]["age"], 30)    end)
end)

test.describe("Dictionary Edge Cases", fun ()
    test.it("handles empty dictionary operations", fun ()
        let empty = {}
        test.assert_eq(empty.len(), 0, nil)
        test.assert_eq(empty.keys().len(), 0, nil)
        test.assert_eq(empty.values().len(), 0, nil)
        test.assert(not empty.contains("anything"), nil)
    end)

    test.it("handles single entry", fun ()
        let single = {"only": "one"}
        test.assert_eq(single.len(), 1, nil)
        test.assert_eq(single["only"], "one")    end)

    test.it("overwrites existing keys", fun ()
        let d = {"x": 1}
        d["x"] = 2
        d["x"] = 3
        test.assert_eq(d["x"], 3)        test.assert_eq(d.len(), 1, nil)
    end)

    test.it("handles keys with special characters", fun ()
        let d = {"key-with-dash": 1, "key_with_underscore": 2}
        test.assert_eq(d["key-with-dash"], 1)        test.assert_eq(d["key_with_underscore"], 2)    end)
end)

test.describe("Dictionary Key Types", fun ()
    test.it("uses string keys", fun ()
        let d = {"name": "value"}
        test.assert_eq(d["name"], "value")    end)

    test.it("handles empty string keys", fun ()
        let d = {"": "empty key"}
        test.assert_eq(d[""], "empty key")    end)

    test.it("handles numeric string keys", fun ()
        let d = {"123": "numeric string", "3.14": "float string"}
        test.assert_eq(d["123"], "numeric string")        test.assert_eq(d["3.14"], "float string")    end)
end)

test.describe("Dictionary Key Checking", fun ()
    let person = {"name": "Alice", "age": 30, "city": "NYC"}

    test.it("contains() checks if key exists", fun ()
        test.assert(person.contains("name"), "should contain 'name' key")
        test.assert(person.contains("age"), "should contain 'age' key")
        test.assert_eq(person.contains("email"), false, "should not contain 'email' key")
    end)

    test.it("contains() works with empty dict", fun ()
        let empty = {}
        test.assert_eq(empty.contains("any"), false, "empty dict should not contain any key")
    end)

    test.it("contains() returns true for keys with nil values", fun ()
        let d = {"key": nil}
        test.assert(d.contains("key"), "should contain key even if value is nil")
    end)
end)
