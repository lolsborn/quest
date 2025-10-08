use "std/test"

test.module("Bug #017: pub keyword not implemented")

# Test Case 1: Simple public field access (should work but fails)
test.describe("Public field access", fun ()
    test.it("allows reading public fields", fun ()
        # This should parse and run, but currently:
        # - Parser may not accept 'pub' keyword, OR
        # - Runtime treats all fields as private regardless

        # Uncomment when pub is implemented:
        # type Point
        #     pub x: Int
        #     pub y: Int
        # end
        #
        # let p = Point.new(x: 10, y: 20)
        # test.assert_eq(p.x, 10)
        # test.assert_eq(p.y, 20)

        puts("SKIPPED: pub keyword not implemented")
    end)
end)

# Test Case 2: Private field access should fail
test.describe("Private field access", fun ()
    test.it("raises AttrErr for private fields", fun ()
        # type BankAccount
        #     pub balance: Int
        #     pin: Str  # Private (no pub)
        # end
        #
        # let account = BankAccount.new(balance: 1000, pin: "1234")
        # test.assert_eq(account.balance, 1000)  # Should work
        # test.assert_raises(fun ()
        #     account.pin  # Should raise AttrErr
        # end)

        puts("SKIPPED: pub keyword not implemented")
    end)
end)

# Test Case 3: Methods can access private fields
test.describe("Method access to private fields", fun ()
    test.it("allows methods to access private fields", fun ()
        # type Secret
        #     pub name: Str
        #     value: Str  # Private
        #
        #     fun reveal()
        #         self.value  # Method can access private field
        #     end
        # end
        #
        # let s = Secret.new(name: "password", value: "secret123")
        # test.assert_eq(s.name, "password")  # Public - OK
        # test.assert_eq(s.reveal(), "secret123")  # Via method - OK
        # # s.value would raise AttrErr

        puts("SKIPPED: pub keyword not implemented")
    end)
end)

# Test Case 4: Current behavior - all fields private
test.describe("Current behavior (all fields private)", fun ()
    test.it("raises AttrErr for all field access", fun ()
        type Point
            x: Int
            y: Int
        end

        let p = Point.new(x: 10, y: 20)

        # Currently, ANY field access from outside raises AttrErr
        test.assert_raises(fun ()
            p.x
        end)

        test.assert_raises(fun ()
            p.y
        end)
    end)

    test.it("requires getter methods as workaround", fun ()
        type Point
            x: Int
            y: Int

            fun get_x() self.x end
            fun get_y() self.y end
            fun set_x(val) self.x = val end
            fun set_y(val) self.y = val end
        end

        let p = Point.new(x: 10, y: 20)

        # Verbose but works
        test.assert_eq(p.get_x(), 10)
        test.assert_eq(p.get_y(), 20)

        p.set_x(100)
        p.set_y(200)
        test.assert_eq(p.get_x(), 100)
        test.assert_eq(p.get_y(), 200)
    end)
end)
