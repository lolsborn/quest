use "std/test"

test.module("Type Self Mutation")

test.describe("Basic field mutation", fun ()
    test.it("can mutate int field with assignment", fun ()
        type Counter
            value: Int = 0

            fun set(n)
                self.value = n
            end

            fun get()
                return self.value
            end
        end

        let c = Counter.new()
        test.assert_eq(c.get(), 0, nil)

        c.set(42)
        test.assert_eq(c.get(), 42, nil)
    end)

    test.it("can mutate int field with compound assignment", fun ()
        type Counter
            value: Int = 0

            fun increment()
                self.value += 1
            end

            fun add(n)
                self.value += n
            end

            fun get()
                return self.value
            end
        end

        let c = Counter.new()
        c.increment()
        test.assert_eq(c.get(), 1, nil)

        c.add(5)
        test.assert_eq(c.get(), 6, nil)
    end)

    test.it("can mutate string field", fun ()
        type Person
            name: Str = "Unknown"

            fun rename(new_name)
                self.name = new_name
            end

            fun get_name()
                return self.name
            end
        end

        let p = Person.new()
        test.assert_eq(p.get_name(), "Unknown", nil)

        p.rename("Alice")
        test.assert_eq(p.get_name(), "Alice", nil)
    end)

    test.it("mutations persist across multiple method calls", fun ()
        type Counter
            value: Int = 0

            fun increment()
                self.value += 1
            end

            fun get()
                return self.value
            end
        end

        let c = Counter.new()
        c.increment()
        c.increment()
        c.increment()
        test.assert_eq(c.get(), 3, nil)
    end)
end)

test.describe("Multiple field mutations", fun ()
    test.it("can mutate multiple fields independently", fun ()
        type Person
            name: Str = "Unknown"
            age: Int = 0

            fun set_name(n)
                self.name = n
            end

            fun set_age(a)
                self.age = a
            end

            fun birthday()
                self.age += 1
            end

            fun get_name()
                return self.name
            end

            fun get_age()
                return self.age
            end
        end

        let p = Person.new()
        p.set_name("Alice")
        p.set_age(25)

        test.assert_eq(p.get_name(), "Alice", nil)
        test.assert_eq(p.get_age(), 25, nil)

        p.birthday()
        test.assert_eq(p.get_age(), 26, nil)
        test.assert_eq(p.get_name(), "Alice", "name should not change")
    end)

    test.it("can mutate multiple fields in one method", fun ()
        type Person
            name: Str = "Unknown"
            age: Int = 0

            fun update(new_name, new_age)
                self.name = new_name
                self.age = new_age
            end

            fun get_name()
                return self.name
            end

            fun get_age()
                return self.age
            end
        end

        let p = Person.new()
        p.update("Bob", 30)

        test.assert_eq(p.get_name(), "Bob", nil)
        test.assert_eq(p.get_age(), 30, nil)
    end)
end)

test.describe("Private field access from methods", fun ()
    test.it("methods can access private fields via self", fun ()
        type BankAccount
            balance: Int = 0

            fun deposit(amount)
                self.balance += amount
            end

            fun withdraw(amount)
                self.balance -= amount
            end

            fun get_balance()
                return self.balance
            end
        end

        let account = BankAccount.new()
        account.deposit(100)
        test.assert_eq(account.get_balance(), 100, nil)

        account.withdraw(30)
        test.assert_eq(account.get_balance(), 70, nil)
    end)

    test.it("methods can access private fields but external code cannot", fun ()
        type Secret
            value: Int = 42
            pub public_value: Int = 100

            fun get()
                return self.value
            end

            fun get_public()
                return self.public_value
            end
        end

        let s = Secret.new()
        # Methods can access private fields
        test.assert_eq(s.get(), 42, "method can access private field")

        # External code can access public fields
        test.assert_eq(s.public_value, 100, "external code can access public field")

        # Note: Direct access to private fields should fail, but we can't test that
        # without assert_raises working properly with error messages
    end)
end)

test.describe("Method chaining with mutations", fun ()
    test.it("methods returning nil enable chaining with updated self", fun ()
        type Builder
            x: Int = 0
            y: Int = 0

            fun set_x(val)
                self.x = val
            end

            fun set_y(val)
                self.y = val
            end

            fun get_x()
                return self.x
            end

            fun get_y()
                return self.y
            end
        end

        let b = Builder.new()
        b.set_x(10)
        b.set_y(20)

        test.assert_eq(b.get_x(), 10, nil)
        test.assert_eq(b.get_y(), 20, nil)
    end)
end)

test.describe("Compound operators", fun ()
    test.it("supports += operator", fun ()
        type Counter
            value: Int = 10

            fun add(n)
                self.value += n
            end

            fun get()
                return self.value
            end
        end

        let c = Counter.new()
        c.add(5)
        test.assert_eq(c.get(), 15, nil)
    end)

    test.it("supports -= operator", fun ()
        type Counter
            value: Int = 10

            fun sub(n)
                self.value -= n
            end

            fun get()
                return self.value
            end
        end

        let c = Counter.new()
        c.sub(3)
        test.assert_eq(c.get(), 7, nil)
    end)

    test.it("supports *= operator", fun ()
        type Counter
            value: Int = 5

            fun mul(n)
                self.value *= n
            end

            fun get()
                return self.value
            end
        end

        let c = Counter.new()
        c.mul(3)
        test.assert_eq(c.get(), 15, nil)
    end)

    test.it("supports /= operator", fun ()
        type Counter
            value: Int = 20

            fun div(n)
                self.value /= n
            end

            fun get()
                return self.value
            end
        end

        let c = Counter.new()
        c.div(4)
        test.assert_eq(c.get(), 5, nil)
    end)
end)

test.describe("Float field mutations", fun ()
    test.it("can mutate float fields", fun ()
        type Point
            x: Float = 0.0
            y: Float = 0.0

            fun move(dx, dy)
                self.x += dx
                self.y += dy
            end

            fun get_x()
                return self.x
            end

            fun get_y()
                return self.y
            end
        end

        let p = Point.new()
        p.move(1.5, 2.5)

        test.assert_eq(p.get_x(), 1.5, nil)
        test.assert_eq(p.get_y(), 2.5, nil)
    end)
end)

test.describe("Multiple instances", fun ()
    test.it("mutations to one instance don't affect others", fun ()
        type Counter
            value: Int = 0

            fun increment()
                self.value += 1
            end

            fun get()
                return self.value
            end
        end

        let c1 = Counter.new()
        let c2 = Counter.new()

        c1.increment()
        c1.increment()

        test.assert_eq(c1.get(), 2, "c1 should be 2")
        test.assert_eq(c2.get(), 0, "c2 should still be 0")
    end)
end)

test.describe("Complex mutations", fun ()
    test.it("can use self in expressions", fun ()
        type Calculator
            result: Int = 0

            fun double()
                self.result = self.result * 2
            end

            fun add_itself()
                self.result = self.result + self.result
            end

            fun set(n)
                self.result = n
            end

            fun get()
                return self.result
            end
        end

        let calc = Calculator.new()
        calc.set(5)
        calc.double()
        test.assert_eq(calc.get(), 10, nil)

        calc.add_itself()
        test.assert_eq(calc.get(), 20, nil)
    end)
end)
