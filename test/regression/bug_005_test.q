# Regression Test: Bug 005 - Literal Keyword Prefix Identifiers
# 
# Bug Description:
#  Identifiers that start with the literal keywords `nil`, `true`, or `false`
#  (without an underscore separator) failed to parse, while identifiers starting
#  with other keywords worked fine.
# 
#  Examples that failed:
#   - let nilable = 1
#   - let truely = 2
#   - let falsey = 3
# 
# Solution:
#  Fixed the grammar in quest.pest to allow literal keywords to be prefixes of
#  longer identifiers, treating them the same way as control flow keywords.
# 
# Status: Fixed - 2025-10-03


use "std/test" { module, describe, it, assert_eq, assert_nil  }

module("Regression: Bug 005 - Literal Keyword Prefix Identifiers")

describe("Identifiers starting with literal keywords", fun ()
  it("allows identifiers starting with 'nil'", fun ()
    let nilable = 1
    assert_eq(nilable, 1)
 end)

  it("allows identifiers starting with 'true'", fun ()
    let truely = 2
    assert_eq(truely, 2)
  end)

  it("allows identifiers starting with 'false'", fun ()
    let falsey = 3
    assert_eq(falsey, 3)
  end)

  it("still allows underscore-separated identifiers", fun ()
    let nil_value = 4
    let true_flag = 5
    let false_flag = 6
    assert_eq(nil_value, 4)
    assert_eq(true_flag, 5)
    assert_eq(false_flag, 6)
  end)

  it("preserves actual literal keyword behavior", fun ()
    let x = nil
    let y = true
    let z = false
    assert_nil(x)
    assert_eq(y, true)
    assert_eq(z, false)
  end)
end)
