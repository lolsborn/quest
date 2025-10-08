# Test type validation for field type annotations
# Ensures that field types are validated at type declaration time
use "std/test" as test

test.module("Type Annotation Validation")

test.describe("Built-in types", fun ()
    test.it("accepts lowercase built-in types", fun ()
        use "std/uuid" as uuid

        type Config
            pub port: Int
            pub host: Str
            pub ratio: Float
            pub value: Num
            pub enabled: Bool
            pub items: Array
            pub settings: Dict
            pub data: Bytes
            pub id: Uuid
            pub price: Decimal
        end

        let c = Config.new(
            port: 8080,
            host: "localhost",
            ratio: 0.5,
            value: 42,
            enabled: true,
            items: [1, 2, 3],
            settings: {"key": "value"},
            data: b"binary",
            id: uuid.parse("550e8400-e29b-41d4-a716-446655440000"),
            price: Decimal.new("19.99")
        )
        test.assert_eq(c.port, 8080)    end)

    test.it("accepts TitleCase built-in types", fun ()
        type Data
            pub value: Int
            pub text: Str
        end

        let d = Data.new(value: 100, text: "test")
        test.assert_eq(d.value, 100)        test.assert_eq(d.text, "test")    end)
end)

test.describe("User-defined types", fun ()
    test.it("accepts user-defined types when defined before use", fun ()
        type Address
            pub street: Str
        end

        type Person
            pub name: Str
            pub address: Address
        end

        let addr = Address.new(street: "Main St")
        let p = Person.new(name: "Alice", address: addr)
        test.assert_eq(p.address.street, "Main St")    end)

    test.it("accepts optional user-defined types", fun ()
        type Contact
            pub email: Str
        end

        type User
            pub name: Str
            pub contact: Contact?
        end

        let u1 = User.new(name: "Bob")
        test.assert_nil(u1.contact)
        let contact = Contact.new(email: "bob@test.com")
        let u2 = User.new(name: "Alice", contact: contact)
        test.assert_eq(u2.contact.email, "bob@test.com")    end)
end)

test.describe("Optional field syntax", fun ()
    test.it("correctly identifies optional fields with ?", fun ()
        type Optional
            pub value: Int?
        end

        let o1 = Optional.new()
        test.assert_nil(o1.value, "optional field should default to nil")

        let o2 = Optional.new(value: 42)
        test.assert_eq(o2.value, 42, "optional field should accept value")
    end)

    test.it("handles optional with default values", fun ()
        type WithDefault
            pub port: Int? = 8080
        end

        let w1 = WithDefault.new()
        test.assert_eq(w1.port, 8080, "should use default value")

        let w2 = WithDefault.new(port: 3000)
        test.assert_eq(w2.port, 3000, "should override default")
    end)
end)

test.describe("Type ordering", fun ()
    test.it("requires types to be defined in order", fun ()
        # This test documents that forward references are not allowed
        # Types must be defined before they are referenced
        # The following would fail if uncommented:
        #
        # type UsesBefore
        #     pub field: DefinedAfter
        # end
        #
        # type DefinedAfter
        #     pub value: Int
        # end

        # Correct order:
        type Base
            pub value: Int
        end

        type UsesBase
            pub base: Base
        end

        let b = Base.new(value: 10)
        let u = UsesBase.new(base: b)
        test.assert_eq(u.base.value, 10)    end)
end)
