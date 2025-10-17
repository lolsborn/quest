"""
Test circular import detection (QEP-043)
"""

use "std/test" {module, describe, it, assert_raises}

module("Circular Import Detection")

describe("Circular imports", fun ()
  it("detects direct circular imports", fun ()
    # Attempting to load circular_a will trigger:
    # circular_a -> circular_b -> circular_a (cycle!)
    assert_raises(ImportErr, fun ()
      use "test/imports/circular_a"
    end)
  end)

  it("detects circular imports via selective imports", fun ()
    # Even with selective imports, circular dependencies should be detected
    assert_raises(ImportErr, fun ()
      use "test/imports/circular_a" {func_a}
    end)
  end)
end)
