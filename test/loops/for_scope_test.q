use "std/test" as test

test.module("Loop Tests - For Loop Scoping")

test.describe("Per-Iteration Scoping - Basic", fun ()

test.it("allows let declarations in loop body", fun ()
    let results = []
    for i in [1, 2, 3]
        let doubled = i * 2
        results.push(doubled)
    end
    test.assert_eq(results.len(), 3)
    test.assert_eq(results[0], 2)
    test.assert_eq(results[2], 6)
end)

test.it("allows multiple let declarations per iteration", fun ()
    let results = []
    for i in [1, 2, 3]
        let x = i
        let y = x * 2
        let z = y + 1
        results.push(z)
    end
    test.assert_eq(results[0], 3)
    test.assert_eq(results[2], 7)
end)

test.it("variable shadowing works correctly", fun ()
    let x = 100
    for i in [1, 2, 3]
        let x = i * 10
        test.assert(x == i * 10, "inner x should be scaled")
    end
    test.assert_eq(x, 100, "outer x unchanged")
end)

test.it("range loops work with let", fun ()
    let results = []
    for i in 1 to 3
        let squared = i * i
        results.push(squared)
    end
    test.assert_eq(results[0], 1)
    test.assert_eq(results[2], 9)
end)

test.it("dict iteration works with let", fun ()
    let d = {"a": 1, "b": 2}
    let count = 0
    for key in d
        let temp = key
        count = count + 1
    end
    test.assert_eq(count, 2)
end)

test.it("break with per-iteration scope", fun ()
    let results = []
    for i in 0 to 10
        let squared = i * i
        if squared > 20
            break
        end
        results.push(squared)
    end
    test.assert_eq(results.len(), 5)
    test.assert_eq(results[4], 16)
end)

test.it("continue with per-iteration scope", fun ()
    let results = []
    for i in 0 to 5
        let doubled = i * 2
        if i == 2
            continue
        end
        results.push(doubled)
    end
    test.assert_eq(results.len(), 5)
    test.assert_eq(results[2], 6)
end)

test.it("nested loops with let", fun ()
    let count = 0
    for i in 0 to 1
        let outer = i
        for j in 0 to 1
            let inner = j
            count = count + 1
        end
    end
    test.assert_eq(count, 4)
end)

test.it("self mutations propagate in loops", fun ()
    type Counter
        pub count: Int = 0
        fun add(n)
            self.count = self.count + n
        end
    end

    let c = Counter.new()
    for i in [1, 2, 3]
        let amount = i
        c.add(amount)
    end
    test.assert_eq(c.count, 6)
end)

end)
