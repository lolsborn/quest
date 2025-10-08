#!/usr/bin/env quest
# Test for Bug #016: Type mutations should persist through function calls

use "std/test"

test.module("Type Mutations (Bug-016)")

type Counter
  pub count: Int
  
  fun increment()
    self.count = self.count + 1
  end
  
  fun add(n: Int)
    self.count = self.count + n
  end
end

test.describe("Type mutations in function calls", fun ()
  test.it("persists mutations in direct method calls", fun ()
    let c = Counter.new(count: 0)
    c.increment()
    test.assert_eq(c.count, 1)
  end)

  test.it("persists mutations when passed to non-recursive function", fun ()
    fun mutate_once(counter)
      counter.increment()
    end

    let c = Counter.new(count: 0)
    mutate_once(c)
    test.assert_eq(c.count, 1)
  end)

  test.it("persists mutations in recursive function calls", fun ()
    fun recursive_increment(counter, n)
      if n > 0
        counter.increment()
        recursive_increment(counter, n - 1)
      end
    end

    let c = Counter.new(count: 0)
    recursive_increment(c, 5)
    test.assert_eq(c.count, 5)
  end)

  test.it("persists mutations in nested function calls", fun ()
    fun inner(counter)
      counter.increment()
    end

    fun outer(counter)
      inner(counter)
      inner(counter)
    end

    let c = Counter.new(count: 0)
    outer(c)
    test.assert_eq(c.count, 2)
  end)

  test.it("works with methods that take parameters", fun ()
    fun add_recursive(counter, values, index)
      if index < values.len()
        counter.add(values[index])
        add_recursive(counter, values, index + 1)
      end
    end

    let c = Counter.new(count: 0)
    add_recursive(c, [1, 2, 3], 0)
    test.assert_eq(c.count, 6)
  end)

  test.it("handles multiple struct parameters", fun ()
    fun increment_both(c1, c2)
      c1.increment()
      c2.increment()
    end

    let counter_a = Counter.new(count: 0)
    let counter_b = Counter.new(count: 0)
    increment_both(counter_a, counter_b)
    test.assert_eq(counter_a.count, 1)
    test.assert_eq(counter_b.count, 1)
  end)

  test.it("shares references when struct stored in array", fun ()
    let c = Counter.new(count: 0)
    let arr = [c]
    c.increment()
    test.assert_eq(arr[0].count, 1)
  end)

  test.it("shares references when struct stored in dict", fun ()
    let c = Counter.new(count: 0)
    let d = {"counter": c}
    c.increment()
    test.assert_eq(d["counter"].count, 1)
  end)

  test.it("mutations persist when struct returned from function", fun ()
    fun create_and_modify()
      let c = Counter.new(count: 0)
      c.increment()
      c
    end

    let result = create_and_modify()
    test.assert_eq(result.count, 1)
  end)

  test.it("tail recursion preserves mutations", fun ()
    fun tail_recursive_add(counter, n, acc)
      if n == 0
        acc
      else
        counter.increment()
        tail_recursive_add(counter, n - 1, acc + 1)
      end
    end

    let c = Counter.new(count: 0)
    let result = tail_recursive_add(c, 4, 0)
    test.assert_eq(c.count, 4)
    test.assert_eq(result, 4)
  end)
end)

test.describe("Reference semantics verification", fun ()
  test.it("multiple variables reference the same struct", fun ()
    let c1 = Counter.new(count: 0)
    let c2 = c1
    c1.increment()
    test.assert_eq(c2.count, 1)
  end)

  test.it("function parameters share reference with caller", fun ()
    fun get_count(counter)
      counter.count
    end

    let c = Counter.new(count: 5)
    test.assert_eq(get_count(c), 5)
    c.increment()
    test.assert_eq(get_count(c), 6)
  end)

  test.it("mutations visible across all references", fun ()
    let c = Counter.new(count: 0)
    let refs = [c, c, c]

    refs[0].increment()
    test.assert_eq(refs[1].count, 1)
    test.assert_eq(refs[2].count, 1)
    test.assert_eq(c.count, 1)
  end)
end)
