
# Bug Description:
#  When mutating type fields inside instance methods (e.g., self.pos = self.pos + 1),
#  the mutations didn't persist. The field would appear updated inside the method but
#  revert to the original value after the method returned.
#
# Root Cause:
#  The evaluator only updated the struct in the outer scope when methods returned nil,
#  but mutations should persist regardless of the return value.
#
# Fix:
#  Modified main.rs:2111-2114 to always update the struct after method calls,
#  not just when return value is nil.
use "std/test" { module, describe, it, assert_eq }

module("Bug 010: Mutable Type Fields")

describe("Mutable struct fields", fun ()
  it("increments field value", fun ()
    type Counter
      pub count: Int

      fun self.create()
        Counter.new(count: 0)
      end

      fun increment()
        self.count = self.count + 1
        self.count
      end
    end

    let c = Counter.create()
    assert_eq(c.count, 0, "Initial count should be 0")

    let result = c.increment()
    assert_eq(result, 1, "Method should return 1")
    assert_eq(c.count, 1, "Field should be updated to 1")
  end)

  it("persists mutations across multiple calls", fun ()
    type Counter
      pub count: Int

      fun self.create()
        Counter.new(count: 0)
      end

      fun increment()
        self.count = self.count + 1
      end
    end

    let c = Counter.create()
    c.increment()
    c.increment()
    c.increment()
    assert_eq(c.count, 3, "Count should be 3 after three increments")
  end)

  it("maintains separate state for multiple instances", fun ()
    type Counter
      pub count: Int

      fun self.create()
        Counter.new(count: 0)
      end

      fun increment()
        self.count = self.count + 1
      end
    end

    let c1 = Counter.create()
    let c2 = Counter.create()

    c1.increment()
    c1.increment()
    c2.increment()

    assert_eq(c1.count, 2, "c1 should be 2")
    assert_eq(c2.count, 1, "c2 should be 1")
  end)

  it("works with methods that return values", fun ()
    type Parser
      pub text: Str
      pub pos: Int

      fun self.create(text)
        Parser.new(text: text, pos: 0)
      end

      fun next_char()
        if self.pos >= self.text.len()
          nil
        else
          let ch = self.text.slice(self.pos, self.pos + 1)
          self.pos = self.pos + 1
          ch
        end
      end
    end

    let p = Parser.create("hello")
    assert_eq(p.next_char(), "h", "First char should be h")
    assert_eq(p.pos, 1, "Position should advance to 1")
    assert_eq(p.next_char(), "e", "Second char should be e")
    assert_eq(p.pos, 2, "Position should advance to 2")
  end)

  it("works with compound assignment operators", fun ()
    type Value
      pub num: Int

      fun self.create(n)
        Value.new(num: n)
      end

      fun add(x)
        self.num += x
      end

      fun multiply(x)
        self.num *= x
      end
    end

    let v = Value.create(10)
    v.add(5)
    assert_eq(v.num, 15, "After add(5)")

    v.multiply(2)
    assert_eq(v.num, 30, "After multiply(2)")
  end)
end)
