# QEP-043: Scoped Imports and Selective Imports Test Suite

use "std/test"

test.module("QEP-043: Scoped Imports")

# ==============================================================================
# Basic Selective Imports
# ==============================================================================

test.describe("Basic selective imports", fun ()
    test.it("imports single function from module", fun ()
        use "std/math" {sin}

        # sin should work without prefix
        let result = sin(0)
        test.assert_eq(result, 0)
    end)

    test.it("imports multiple functions from module", fun ()
        use "std/math" {sin, cos, pi}

        # All three should work without prefix
        test.assert_eq(sin(0), 0)
        test.assert_eq(cos(0), 1)
        test.assert_near(pi, 3.14159, 0.001)
    end)
end)

# ==============================================================================
# Import Renaming (as clause)
# ==============================================================================

test.describe("Import renaming with 'as' clause", fun ()
    test.it("renames imported function", fun ()
        use "std/hash" {md5 as hash_md5}

        # Should work with renamed alias
        let result = hash_md5("test")
        test.assert_eq(result.len(), 32)  # MD5 is 32 hex chars
    end)

    test.it("renames multiple imports", fun ()
        use "std/hash" {md5 as hash_md5, sha256 as hash_sha256}

        let md5_result = hash_md5("test")
        let sha256_result = hash_sha256("test")

        test.assert_eq(md5_result.len(), 32)
        test.assert_eq(sha256_result.len(), 64)  # SHA256 is 64 hex chars
    end)
end)

# ==============================================================================
# Module Alias + Selective Imports
# ==============================================================================

test.describe("Module alias with selective imports", fun ()
    test.it("combines module alias and selective imports", fun ()
        use "std/hash" as hash {md5}

        # Imported function works without prefix
        let result1 = md5("test")
        test.assert_eq(result1.len(), 32)

        # Other functions need prefix
        let result2 = hash.sha256("test")
        test.assert_eq(result2.len(), 64)
    end)

    test.it("selective imports with renamed alias", fun ()
        use "std/hash" as hash {md5 as my_md5}

        # Renamed import works
        let result1 = my_md5("test")
        test.assert_eq(result1.len(), 32)

        # Original name via module alias still works
        let result2 = hash.md5("test")
        test.assert_eq(result2.len(), 32)
    end)
end)

# ==============================================================================
# Name Conflict Detection
# ==============================================================================

test.describe("Name conflict detection", fun ()
    test.it("allows renamed import to avoid conflict", fun ()
        let parse = "my_parser"

        # Renaming should avoid conflict
        use "std/encoding/json" {parse as json_parse}

        # Both should exist
        test.assert_eq(parse, "my_parser")

        let data = json_parse('{"x": 10}')
        test.assert_eq(data["x"], 10)
    end)
end)

# ==============================================================================
# Only Public Members Can Be Imported
# ==============================================================================

test.describe("Public member access", fun ()
    test.it("imports public functions from built-in modules", fun ()
        use "std/hash" {md5, sha256}

        # Should work fine
        test.assert_eq(md5("test").len(), 32)
        test.assert_eq(sha256("test").len(), 64)
    end)
end)

# ==============================================================================
# Selective Imports Without Module Alias
# ==============================================================================

test.describe("Selective imports without module alias", fun ()
    test.it("imports without binding module name", fun ()
        use "std/math" {sin, cos}

        # Functions work
        test.assert_eq(sin(0), 0)
        test.assert_eq(cos(0), 1)
    end)
end)

# ==============================================================================
# Complex Scenarios
# ==============================================================================

test.describe("Complex import scenarios", fun ()
    test.it("imports from multiple modules", fun ()
        use "std/encoding/json" {parse, stringify}
        use "std/hash" {md5, sha256}

        let data = parse('{"name": "Alice"}')
        let json_str = stringify(data)
        let hash1 = md5(json_str)
        let hash2 = sha256(json_str)

        test.assert_eq(hash1.len(), 32)
        test.assert_eq(hash2.len(), 64)
    end)

    test.it("mixes traditional and selective imports", fun ()
        use "std/encoding/json" as json
        use "std/hash" {md5}

        # json needs prefix
        let data = json.parse('{"x": 1}')

        # md5 doesn't need prefix
        let hash = md5("test")

        test.assert_eq(data["x"], 1)
        test.assert_eq(hash.len(), 32)
    end)

    test.it("handles multiple selective imports from same module", fun ()
        use "std/math" {sin}
        use "std/math" {cos}

        # Both should work
        test.assert_eq(sin(0), 0)
        test.assert_eq(cos(0), 1)
    end)
end)

# ==============================================================================
# JSON Processing Use Case
# ==============================================================================

test.describe("Real-world use case: JSON processing", fun ()
    test.it("processes JSON without prefixes", fun ()
        use "std/encoding/json" {parse, stringify}

        let json_str = '{"name": "Bob", "age": 30}'
        let data = parse(json_str)

        data["age"] = 31

        let output = stringify(data)
        test.assert(output.contains("Bob"), "Output should contain 'Bob'")
        test.assert(output.contains("31"), "Output should contain '31'")
    end)
end)

# ==============================================================================
# Math Functions Use Case
# ==============================================================================

test.describe("Real-world use case: Math calculations", fun ()
    test.it("performs calculations without prefixes", fun ()
        use "std/math" {sin, cos, pi}

        # Calculate circumference
        let radius = 5
        let circumference = 2 * pi * radius

        test.assert_near(circumference, 31.4159, 0.01)

        # Trig calculations
        let angle = pi / 4  # 45 degrees in radians
        test.assert_near(sin(angle), 0.707, 0.01)
        test.assert_near(cos(angle), 0.707, 0.01)
    end)
end)

# ==============================================================================
# Edge Cases
# ==============================================================================

test.describe("Edge cases", fun ()
    test.it("preserves module behavior for non-selective imports", fun ()
        use "std/math" as math

        # Traditional module access should still work
        test.assert_eq(math.sin(0), 0)
        test.assert_eq(math.cos(0), 1)
    end)

    test.it("imports work in nested function scopes", fun ()
        use "std/math" {sin}

        fun outer()
            fun inner()
                # sin should be accessible here (file-scoped import)
                return sin(0)
            end
            return inner()
        end

        test.assert_eq(outer(), 0)
    end)
end)
