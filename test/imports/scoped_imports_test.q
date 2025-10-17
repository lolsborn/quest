# QEP-043: Scoped Imports and Selective Imports Test Suite

use "std/test" { module, describe, it, assert_eq, assert_nil, assert_type, assert, assert_near }

  module("QEP-043: Scoped Imports")

# ==============================================================================
# Basic Selective Imports
# ==============================================================================

  describe("Basic selective imports", fun ()
    it("imports single function from module", fun ()
    use "std/math" {sin}

    # sin should work without prefix
    let result = sin(0)
    assert_eq(result, 0)
  end)

    it("imports multiple functions from module", fun ()
    use "std/math" {sin, cos, pi}

    # All three should work without prefix
    assert_eq(sin(0), 0)
    assert_eq(cos(0), 1)
    assert_near(pi, 3.14159, 0.001)
  end)
end)

# ==============================================================================
# Import Renaming (as clause)
# ==============================================================================

  describe("Import renaming with 'as' clause", fun ()
    it("renames imported function", fun ()
    use "std/hash" {md5 as hash_md5}

    # Should work with renamed alias
    let result = hash_md5("test")
    assert_eq(result.len(), 32)  # MD5 is 32 hex chars
  end)

    it("renames multiple imports", fun ()
    use "std/hash" {md5 as hash_md5, sha256 as hash_sha256}

    let md5_result = hash_md5("test")
    let sha256_result = hash_sha256("test")

    assert_eq(md5_result.len(), 32)
    assert_eq(sha256_result.len(), 64)  # SHA256 is 64 hex chars
  end)
end)

# ==============================================================================
# Module Alias + Selective Imports
# ==============================================================================

  describe("Module alias with selective imports", fun ()
    it("combines module alias and selective imports", fun ()
    use "std/hash" as hash {md5}

    # Imported function works without prefix
    let result1 = md5("test")
    assert_eq(result1.len(), 32)

    # Other functions need prefix
    let result2 = hash.sha256("test")
    assert_eq(result2.len(), 64)
  end)

    it("selective imports with renamed alias", fun ()
    use "std/hash" as hash {md5 as my_md5}

    # Renamed import works
    let result1 = my_md5("test")
    assert_eq(result1.len(), 32)

    # Original name via module alias still works
    let result2 = hash.md5("test")
    assert_eq(result2.len(), 32)
  end)
end)

# ==============================================================================
# Name Conflict Detection
# ==============================================================================

  describe("Name conflict detection", fun ()
    it("allows renamed import to avoid conflict", fun ()
    let parse = "my_parser"

    # Renaming should avoid conflict
    use "std/encoding/json" {parse as json_parse}

    # Both should exist
    assert_eq(parse, "my_parser")

    let data = json_parse('{"x": 10}')
    assert_eq(data["x"], 10)
  end)
end)

# ==============================================================================
# Only Public Members Can Be Imported
# ==============================================================================

  describe("Public member access", fun ()
    it("imports public functions from built-in modules", fun ()
    use "std/hash" {md5, sha256}

    # Should work fine
    assert_eq(md5("test").len(), 32)
    assert_eq(sha256("test").len(), 64)
  end)
end)

# ==============================================================================
# Selective Imports Without Module Alias
# ==============================================================================

  describe("Selective imports without module alias", fun ()
    it("imports without binding module name", fun ()
    use "std/math" {sin, cos}

    # Functions work
    assert_eq(sin(0), 0)
    assert_eq(cos(0), 1)
  end)
end)

# ==============================================================================
# Complex Scenarios
# ==============================================================================

  describe("Complex import scenarios", fun ()
    it("imports from multiple modules", fun ()
    use "std/encoding/json" {parse, stringify}
    use "std/hash" {md5, sha256}

    let data = parse('{"name": "Alice"}')
    let json_str = stringify(data)
    let hash1 = md5(json_str)
    let hash2 = sha256(json_str)

    assert_eq(hash1.len(), 32)
    assert_eq(hash2.len(), 64)
  end)

    it("mixes traditional and selective imports", fun ()
    use "std/encoding/json" as json
    use "std/hash" {md5}

    # json needs prefix
    let data = json.parse('{"x": 1}')

    # md5 doesn't need prefix
    let hash = md5("test")

    assert_eq(data["x"], 1)
    assert_eq(hash.len(), 32)
  end)

    it("handles multiple selective imports from same module", fun ()
    use "std/math" {sin}
    use "std/math" {cos}

    # Both should work
    assert_eq(sin(0), 0)
    assert_eq(cos(0), 1)
  end)
end)

# ==============================================================================
# JSON Processing Use Case
# ==============================================================================

  describe("Real-world use case: JSON processing", fun ()
    it("processes JSON without prefixes", fun ()
    use "std/encoding/json" {parse, stringify}

    let json_str = '{"name": "Bob", "age": 30}'
    let data = parse(json_str)

    data["age"] = 31

    let output = stringify(data)
    assert(output.contains("Bob"), "Output should contain 'Bob'")
    assert(output.contains("31"), "Output should contain '31'")
  end)
end)

# ==============================================================================
# Math Functions Use Case
# ==============================================================================

  describe("Real-world use case: Math calculations", fun ()
    it("performs calculations without prefixes", fun ()
    use "std/math" {sin, cos, pi}

    # Calculate circumference
    let radius = 5
    let circumference = 2 * pi * radius

    assert_near(circumference, 31.4159, 0.01)

    # Trig calculations
    let angle = pi / 4  # 45 degrees in radians
    assert_near(sin(angle), 0.707, 0.01)
    assert_near(cos(angle), 0.707, 0.01)
  end)
end)

# ==============================================================================
# Edge Cases
# ==============================================================================

  describe("Edge cases", fun ()
    it("preserves module behavior for non-selective imports", fun ()
    use "std/math" as math

    # Traditional module access should still work
    assert_eq(math.sin(0), 0)
    assert_eq(math.cos(0), 1)
  end)

    it("imports work in nested function scopes", fun ()
    use "std/math" {sin}

    fun outer()
      fun inner()
        # sin should be accessible here (file-scoped import)
        return sin(0)
      end
      return inner()
    end

    assert_eq(outer(), 0)
  end)
end)
