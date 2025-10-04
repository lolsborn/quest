# test - Test discovery / runner

The `test` module provides a testing framework for Quest with assertions, test organization, and reporting.

## Test Definition

### `test.describe(name, fn)`
Define a test suite/group

**Parameters:**
- `name` - Suite name (Str)
- `fn` - Function containing tests

**Example:**
```quest
test.describe("String operations", fun ()
    test.it("concatenates strings", fun ()
        test.assert_eq("hello" + " world", "hello world")
    end)

    test.it("converts to uppercase", fun ()
        test.assert_eq("hello".upper(), "HELLO")
    end)
end)
```

### `test.it(name, fn)`
Define a single test case

**Parameters:**
- `name` - Test name/description (Str)
- `fn` - Test function to execute

**Example:**
```quest
test.it("adds numbers correctly", fun ()
    test.assert_eq(2 + 2, 4)
end)
```

### `test.before(fn)`
Run setup function before each test in current suite

**Parameters:**
- `fn` - Setup function

**Example:**
```quest
test.describe("Database tests", fun ()
    test.before(fun ()
        db.connect()
        db.clear()
    end)

    test.it("inserts records", fun ()
        db.insert("users", {"name": "Alice"})
        test.assert_eq(db.count("users"), 1)
    end)
end)
```

### `test.after(fn)`
Run teardown function after each test in current suite

**Parameters:**
- `fn` - Teardown function

**Example:**
```quest
test.describe("File tests", fun ()
    test.after(fun ()
        io.remove("test_output.txt")
    end)

    test.it("writes to file", fun ()
        io.write("test_output.txt", "data")
        test.assert(io.exists("test_output.txt"))
    end)
end)
```

### `test.before_all(fn)`
Run setup once before all tests in suite

**Parameters:**
- `fn` - Setup function

### `test.after_all(fn)`
Run teardown once after all tests in suite

**Parameters:**
- `fn` - Teardown function

## Assertions

### `test.assert(condition, message = nil)`
Assert that condition is true

**Parameters:**
- `condition` - Boolean condition (Bool)
- `message` - Optional failure message (Str)

**Raises:** AssertionError if condition is false

**Example:**
```quest
test.assert(5 > 3)
test.assert(user.is_admin(), "User must be admin")
```

### `test.assert_eq(actual, expected, message = nil)`
Assert that two values are equal

**Parameters:**
- `actual` - Actual value
- `expected` - Expected value
- `message` - Optional failure message (Str)

**Example:**
```quest
test.assert_eq(2 + 2, 4)
test.assert_eq("hello".len(), 5, "Wrong string length")
```

### `test.assert_neq(actual, expected, message = nil)`
Assert that two values are not equal

**Parameters:**
- `actual` - Actual value
- `expected` - Value that should not match
- `message` - Optional failure message (Str)

**Example:**
```quest
test.assert_neq(result, nil)
test.assert_neq(user_id, previous_id)
```

### `test.assert_gt(actual, expected, message = nil)`
Assert that actual is greater than expected

**Parameters:**
- `actual` - Actual value (Num)
- `expected` - Expected threshold (Num)
- `message` - Optional failure message (Str)

**Example:**
```quest
test.assert_gt(score, 100)
```

### `test.assert_lt(actual, expected, message = nil)`
Assert that actual is less than expected

**Parameters:**
- `actual` - Actual value (Num)
- `expected` - Expected threshold (Num)
- `message` - Optional failure message (Str)

### `test.assert_gte(actual, expected, message = nil)`
Assert that actual is greater than or equal to expected

### `test.assert_lte(actual, expected, message = nil)`
Assert that actual is less than or equal to expected

### `test.assert_nil(value, message = nil)`
Assert that value is nil

**Parameters:**
- `value` - Value to check
- `message` - Optional failure message (Str)

**Example:**
```quest
test.assert_nil(optional_param)
```

### `test.assert_not_nil(value, message = nil)`
Assert that value is not nil

**Example:**
```quest
test.assert_not_nil(result, "Result should not be nil")
```

### `test.assert_type(value, type_name, message = nil)`
Assert that value is of specific type

**Parameters:**
- `value` - Value to check
- `type_name` - Expected type name (Str): "Num", "Str", "Bool", "List", etc.
- `message` - Optional failure message (Str)

**Example:**
```quest
test.assert_type(result, "Num")
test.assert_type(names, "List")
```

### `test.assert_contains(collection, item, message = nil)`
Assert that collection contains item

**Parameters:**
- `collection` - List or string to search
- `item` - Item to find
- `message` - Optional failure message (Str)

**Example:**
```quest
test.assert_contains([1, 2, 3], 2)
test.assert_contains("hello world", "world")
```

### `test.assert_not_contains(collection, item, message = nil)`
Assert that collection does not contain item

**Example:**
```quest
test.assert_not_contains(banned_users, user_id)
```

### `test.assert_len(collection, expected_len, message = nil)`
Assert that collection has expected length

**Parameters:**
- `collection` - List or string
- `expected_len` - Expected length (Num)
- `message` - Optional failure message (Str)

**Example:**
```quest
test.assert_len(results, 10)
test.assert_len("hello", 5)
```

### `test.assert_empty(collection, message = nil)`
Assert that collection is empty

**Example:**
```quest
test.assert_empty([])
test.assert_empty("")
```

### `test.assert_not_empty(collection, message = nil)`
Assert that collection is not empty

### `test.assert_raises(fn, error_type = nil, message = nil)`
Assert that function raises an error

**Parameters:**
- `fn` - Function to execute
- `error_type` - Optional expected error type (Str)
- `message` - Optional failure message (Str)

**Example:**
```quest
test.assert_raises(fun ()
    1 / 0
end)

test.assert_raises(fun ()
    io.read("nonexistent.txt")
end, "FileNotFoundError")
```

### `test.assert_matches(text, pattern, message = nil)`
Assert that text matches regex pattern

**Parameters:**
- `text` - Text to match (Str)
- `pattern` - Regex pattern (Str)
- `message` - Optional failure message (Str)

**Example:**
```quest
test.assert_matches(email, "^[a-z]+@[a-z]+\\.[a-z]+$")
```

### `test.assert_near(actual, expected, tolerance = 0.0001, message = nil)`
Assert that numbers are approximately equal (for floating point)

**Parameters:**
- `actual` - Actual value (Num)
- `expected` - Expected value (Num)
- `tolerance` - Acceptable difference (Num, default 0.0001)
- `message` - Optional failure message (Str)

**Example:**
```quest
test.assert_near(math.pi, 3.14159, 0.00001)
test.assert_near(result, 2.5, 0.1)
```

## Test Control

### `test.skip(reason = nil)`
Skip current test

**Parameters:**
- `reason` - Optional reason for skipping (Str)

**Example:**
```quest
test.it("integration test", fun ()
    if !has_network()
        test.skip("No network connection")
    end

    # test code...
end)
```

### `test.skip_if(condition, reason = nil)`
Skip test if condition is true

**Parameters:**
- `condition` - Boolean condition (Bool)
- `reason` - Optional reason (Str)

**Example:**
```quest
test.it("runs on Unix only", fun ()
    test.skip_if(sys.platform() == "windows", "Unix only")
    # test code...
end)
```

### `test.fail(message)`
Explicitly fail the test

**Parameters:**
- `message` - Failure message (Str)

**Example:**
```quest
test.it("validates behavior", fun ()
    if weird_edge_case()
        test.fail("Unexpected edge case encountered")
    end
end)
```

## Test Running

### `test.run()`
Run all defined tests and print results

**Returns:** Exit code (Num): 0 if all pass, 1 if any fail

**Example:**
```quest
# At end of test file
test.run()
```

### `test.run_file(path)`
Load and run tests from file

**Parameters:**
- `path` - Path to test file (Str)

**Returns:** Exit code (Num)

**Example:**
```quest
test.run_file("tests/string_test.q")
```

### `test.run_dir(path)`
Run all test files in directory

**Parameters:**
- `path` - Directory path (Str)

**Returns:** Exit code (Num)

**Example:**
```quest
# Run all tests in tests/ directory
test.run_dir("tests")
```

## Test Output

### `test.set_reporter(reporter)`
Set output reporter style

**Parameters:**
- `reporter` - Reporter name (Str): "default", "verbose", "minimal", "json", "tap"

**Example:**
```quest
test.set_reporter("verbose")
test.run()
```

### `test.set_color(enabled)`
Enable or disable colored output

**Parameters:**
- `enabled` - Whether to use colors (Bool)

## Mocking and Stubbing

### `test.stub(obj, method, replacement)`
Replace method with stub for testing

**Parameters:**
- `obj` - Object to stub
- `method` - Method name (Str)
- `replacement` - Replacement function

**Returns:** Stub handle for cleanup

**Example:**
```quest
test.it("mocks API call", fun ()
    let stub = test.stub(api, "fetch", fun (url)
        return {"status": 200, "data": "mock"}
    end)

    let result = api.fetch("http://example.com")
    test.assert_eq(result.status, 200)

    stub.restore()
end)
```

### `test.spy(fn)`
Create spy that tracks function calls

**Parameters:**
- `fn` - Function to spy on

**Returns:** Spy object with call tracking

**Example:**
```quest
let spy = test.spy(callback)
do_something(spy)

test.assert(spy.called())
test.assert_eq(spy.call_count(), 2)
test.assert_eq(spy.calls[0].args, [1, 2, 3])
```

## Test Fixtures

### `test.fixture(name, fn)`
Define reusable test fixture

**Parameters:**
- `name` - Fixture name (Str)
- `fn` - Function that returns fixture data

**Example:**
```quest
test.fixture("sample_users", fun ()
    return [
        {"name": "Alice", "age": 30},
        {"name": "Bob", "age": 25}
    ]
end)

test.it("processes users", fun ()
    let users = test.use_fixture("sample_users")
    test.assert_len(users, 2)
end)
```

## Benchmarking

### `test.benchmark(name, fn, iterations = 1000)`
Benchmark function execution time

**Parameters:**
- `name` - Benchmark name (Str)
- `fn` - Function to benchmark
- `iterations` - Number of iterations (Num, default 1000)

**Example:**
```quest
test.benchmark("string concatenation", fun ()
    let s = ""
    for i in 1..100
        s = s + "x"
    end
end, 1000)
```

## Complete Example

```quest
# tests/calculator_test.q

test.describe("Calculator", fun ()
    test.describe("addition", fun ()
        test.it("adds positive numbers", fun ()
            test.assert_eq(calc.add(2, 3), 5)
        end)

        test.it("adds negative numbers", fun ()
            test.assert_eq(calc.add(-2, -3), -5)
        end)

        test.it("handles zero", fun ()
            test.assert_eq(calc.add(0, 5), 5)
            test.assert_eq(calc.add(5, 0), 5)
        end)
    end)

    test.describe("division", fun ()
        test.it("divides numbers", fun ()
            test.assert_eq(calc.div(10, 2), 5)
        end)

        test.it("handles decimal results", fun ()
            test.assert_near(calc.div(7, 3), 2.333, 0.01)
        end)

        test.it("raises error on division by zero", fun ()
            test.assert_raises(fun ()
                calc.div(5, 0)
            end, "DivisionByZeroError")
        end)
    end)
end)

# Run all tests
test.run()
```

## Command Line Usage

```bash
# Run single test file
quest tests/calculator_test.q

# Run all tests in directory
quest -test tests/

# Run with verbose output
quest -test -verbose tests/

# Run specific test
quest -test -only "Calculator addition" tests/calculator_test.q
```
