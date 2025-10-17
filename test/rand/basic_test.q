use "std/test" { module, describe, it, assert_eq, assert_gte, assert_lte, assert_lt, assert_gt, assert_neq, assert_type, assert_raises }
use "std/rand"

module("std/rand")

describe("rand.secure", fun ()
  it("creates secure RNG", fun ()
    let rng = rand.secure()
    assert_type(rng, "RNG")
  end)

  it("generates integers in range", fun ()
    let rng = rand.secure()
    let val = 0
    for i in 0 to 99
      val = rng.int(1, 10)
      assert_gte(val, 1)
      assert_lte(val, 10)
    end
  end)

  it("generates floats in range", fun ()
    let rng = rand.secure()
    let val = 0.0
    for i in 0 to 99
      val = rng.float()
      assert_gte(val, 0.0)
      assert_lt(val, 1.0)
    end
  end)

  it("generates floats in custom range", fun ()
    let rng = rand.secure()
    let val = 0.0
    for i in 0 to 99
      val = rng.float(-10.0, 10.0)
      assert_gte(val, -10.0)
      assert_lt(val, 10.0)
    end
  end)

  it("generates booleans", fun ()
    let rng = rand.secure()
    let true_count = 0
    let false_count = 0

    for i in 0 to 99
      if rng.bool()
        true_count = true_count + 1
      else
        false_count = false_count + 1
      end
    end

    # Should have both true and false in 100 iterations
    assert_gt(true_count, 0)
    assert_gt(false_count, 0)
    assert_eq(true_count + false_count, 100)
  end)

  it("generates bytes", fun ()
    let rng = rand.secure()
    let data = rng.bytes(32)
    assert_eq(data.len(), 32)
  end)

  it("generates different values", fun ()
    let rng = rand.secure()
    let val1 = rng.int(1, 1000000)
    let val2 = rng.int(1, 1000000)
    let val3 = rng.int(1, 1000000)

    # Very unlikely all three are the same
    let same_count = 0
    if val1 == val2
      same_count = same_count + 1
    end
    if val2 == val3
      same_count = same_count + 1
    end

    # At least one pair should be different
    assert_lt(same_count, 2)
  end)
end)

describe("rand.fast", fun ()
  it("creates fast RNG", fun ()
    let rng = rand.fast()
    assert_type(rng, "RNG")
  end)

  it("generates integers in range", fun ()
    let rng = rand.fast()
    let val = 0
    for i in 0 to 99
      val = rng.int(1, 10)
      assert_gte(val, 1)
      assert_lte(val, 10)
    end
  end)

  it("generates floats", fun ()
    let rng = rand.fast()
    let val = 0.0
    for i in 0 to 99
      val = rng.float()
      assert_gte(val, 0.0)
      assert_lt(val, 1.0)
    end
  end)
end)

describe("rand.seed", fun ()
  it("creates seeded RNG with integer seed", fun ()
    let rng = rand.seed(42)
    assert_type(rng, "RNG")
  end)

  it("creates seeded RNG with string seed", fun ()
    let rng = rand.seed("test")
    assert_type(rng, "RNG")
  end)

  it("is deterministic with same integer seed", fun ()
    let rng1 = rand.seed(42)
    let rng2 = rand.seed(42)

    for i in 0 to 9
      assert_eq(rng1.int(1, 100), rng2.int(1, 100))
    end
  end)

  it("is deterministic with same string seed", fun ()
    let rng1 = rand.seed("test")
    let rng2 = rand.seed("test")

    for i in 0 to 9
      assert_eq(rng1.int(1, 100), rng2.int(1, 100))
    end
  end)

  it("produces different sequences for different seeds", fun ()
    let rng1 = rand.seed(42)
    let rng2 = rand.seed(43)

    let val1 = rng1.int(1, 1000000)
    let val2 = rng2.int(1, 1000000)

    # Very unlikely to be the same
    assert_neq(val1, val2)
  end)
end)

describe("rng.int", fun ()
  it("handles single value range", fun ()
    let rng = rand.seed(42)
    let val = rng.int(5, 5)
    assert_eq(val, 5)
  end)

  it("handles negative ranges", fun ()
    let rng = rand.secure()
    let val = 0
    for i in 0 to 49
      val = rng.int(-10, -5)
      assert_gte(val, -10)
      assert_lte(val, -5)
    end
  end)

  it("raises error when min > max", fun ()
    let rng = rand.secure()
    assert_raises(ValueErr, fun ()
      rng.int(10, 5)
    end)
  end)
end)

describe("rng.float", fun ()
  it("generates values in default range", fun ()
    let rng = rand.secure()
    let val = 0.0
    for i in 0 to 49
      val = rng.float()
      assert_gte(val, 0.0)
      assert_lt(val, 1.0)
    end
  end)

  it("generates values in custom range", fun ()
    let rng = rand.secure()
    let val = 0.0
    for i in 0 to 49
      val = rng.float(5.0, 10.0)
      assert_gte(val, 5.0)
      assert_lt(val, 10.0)
    end
  end)

  it("raises error when min > max", fun ()
    let rng = rand.secure()
    assert_raises(ValueErr, fun ()
      rng.float(10.0, 5.0)
    end)
  end)
end)

describe("rng.bytes", fun ()
  it("generates correct number of bytes", fun ()
    let rng = rand.secure()
    assert_eq(rng.bytes(0).len(), 0)
    assert_eq(rng.bytes(1).len(), 1)
    assert_eq(rng.bytes(16).len(), 16)
    assert_eq(rng.bytes(32).len(), 32)
  end)

  it("generates different byte sequences", fun ()
    let rng = rand.secure()
    let b1 = rng.bytes(16)
    let b2 = rng.bytes(16)

    # Very unlikely to be identical
    assert_neq(b1, b2)
  end)
end)

describe("rng.choice", fun ()
  it("picks element from array", fun ()
    let rng = rand.secure()
    let arr = [1, 2, 3, 4, 5]
    let choice = 0

    for i in 0 to 19
      choice = rng.choice(arr)
      assert_eq(arr.contains(choice), true)
    end
  end)

  it("works with different types", fun ()
    let rng = rand.seed(42)
    let strings = ["a", "b", "c"]
    let choice = rng.choice(strings)
    assert_type(choice, "Str")
  end)

  it("raises error for empty array", fun ()
    let rng = rand.secure()
    assert_raises(RuntimeErr, fun ()
      rng.choice([])
    end)
  end)
end)

describe("rng.shuffle", fun ()
  it("shuffles array in place", fun ()
    let rng = rand.seed(42)
    let arr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    let original = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

    rng.shuffle(arr)

    # Array should contain same elements
    assert_eq(arr.len(), 10)
    for elem in original
      assert_eq(arr.contains(elem), true)
    end

    # Array should be in different order (very likely)
    let same_order = true
    for i in 0 to 9
      if arr[i] != original[i]
        same_order = false
      end
    end
    assert_eq(same_order, false)
  end)

  it("is deterministic with seed", fun ()
    let arr1 = [1, 2, 3, 4, 5]
    let arr2 = [1, 2, 3, 4, 5]

    let rng1 = rand.seed(42)
    let rng2 = rand.seed(42)

    rng1.shuffle(arr1)
    rng2.shuffle(arr2)

    # Should produce identical shuffles
    for i in 0 to 4
      assert_eq(arr1[i], arr2[i])
    end
  end)
end)

describe("rng.sample", fun ()
  it("samples k elements", fun ()
    let rng = rand.secure()
    let arr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    let sample = rng.sample(arr, 3)

    assert_eq(sample.len(), 3)

    # All sampled elements should be from original array
    for elem in sample
      assert_eq(arr.contains(elem), true)
    end
  end)

  it("samples without replacement", fun ()
    let rng = rand.secure()
    let arr = [1, 2, 3, 4, 5]
    let sample = rng.sample(arr, 5)

    # All elements should be unique
    assert_eq(sample.len(), 5)
    for elem in arr
      assert_eq(sample.contains(elem), true)
    end
  end)

  it("is deterministic with seed", fun ()
    let arr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

    let rng1 = rand.seed(42)
    let sample1 = rng1.sample(arr, 3)

    let rng2 = rand.seed(42)
    let sample2 = rng2.sample(arr, 3)

    # Should produce identical samples
    for i in 0 to 2
      assert_eq(sample1[i], sample2[i])
    end
  end)

  it("raises error when k > array length", fun ()
    let rng = rand.secure()
    assert_raises(ValueErr, fun ()
      rng.sample([1, 2, 3], 5)
    end)
  end)
end)

describe("error handling", fun ()
  it("raises error for int with min > max", fun ()
    let rng = rand.secure()
    assert_raises(ValueErr, fun ()
      rng.int(10, 5)
    end)
  end)

  it("raises error for float with min > max", fun ()
    let rng = rand.secure()
    assert_raises(ValueErr, fun ()
      rng.float(10.0, 5.0)
    end)
  end)

  it("raises error for negative bytes count", fun ()
    let rng = rand.secure()
    assert_raises(ValueErr, fun ()
      rng.bytes(-1)
    end)
  end)
end)

describe("real-world examples", fun ()
  it("generates secure token", fun ()
    let rng = rand.secure()
    let token = rng.bytes(32)
    assert_eq(token.len(), 32)
  end)

  it("simulates dice rolls", fun ()
    let rng = rand.secure()
    let rolls = []

    for i in 0 to 99
      rolls.push(rng.int(1, 6))
    end

    # Check we got various values (not all the same)
    let count_1 = 0
    let count_6 = 0
    for roll in rolls
      if roll == 1
        count_1 = count_1 + 1
      end
      if roll == 6
        count_6 = count_6 + 1
      end
    end

    # Very likely to roll at least one 1 and one 6 in 100 rolls
    assert_gt(count_1, 0)
    assert_gt(count_6, 0)
  end)

  it("shuffles a deck of cards", fun ()
    let rng = rand.seed("deck1")
    let deck = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    rng.shuffle(deck)

    # Deck should still contain all cards
    assert_eq(deck.len(), 10)
    for i in 1 to 10
      assert_eq(deck.contains(i), true)
    end
  end)

  it("picks lottery numbers", fun ()
    let rng = rand.secure()
    let numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
    let lottery = rng.sample(numbers, 6)

    assert_eq(lottery.len(), 6)

    # All numbers should be unique
    for i in 0 to 5
      for j in 0 to 5
        if i != j
          assert_neq(lottery[i], lottery[j])
        end
      end
    end
  end)
end)
