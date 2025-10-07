# Comprehensive test for optional fields with QEP-032 syntax (name: type?)
use "std/test" as test

test.module("Optional Fields - Comprehensive")

# Test different types as optional
test.describe("Optional field types", fun ()
    test.it("supports optional int", fun ()
        type Config
            pub port: Int?
        end
        let c1 = Config.new()
        test.assert_nil(c1.port, "port should be nil when not provided")
        let c2 = Config.new(port: 8080)
        test.assert_eq(c2.port, 8080, "port should be 8080 when provided")
    end)

    test.it("supports optional float", fun ()
        type Measurement
            pub value: Float?
        end
        let m1 = Measurement.new()
        test.assert_nil(m1.value, "value should be nil")
        let m2 = Measurement.new(value: 3.14)
        test.assert_eq(m2.value, 3.14, "value should be 3.14")
    end)

    test.it("supports optional num", fun ()
        type Score
            pub points: Num?
        end
        let s1 = Score.new()
        test.assert_nil(s1.points, "points should be nil")
        let s2 = Score.new(points: 42)
        test.assert_eq(s2.points, 42, "points should be 42")
    end)

    test.it("supports optional bool", fun ()
        type Feature
            pub enabled: Bool?
        end
        let f1 = Feature.new()
        test.assert_nil(f1.enabled, "enabled should be nil")
        let f2 = Feature.new(enabled: true)
        test.assert_eq(f2.enabled, true, "enabled should be true")
        let f3 = Feature.new(enabled: false)
        test.assert_eq(f3.enabled, false, "enabled should be false")
    end)

    test.it("supports optional str", fun ()
        type Note
            pub text: Str?
        end
        let n1 = Note.new()
        test.assert_nil(n1.text, "text should be nil")
        let n2 = Note.new(text: "hello")
        test.assert_eq(n2.text, "hello", "text should be hello")
    end)

    test.it("supports optional array", fun ()
        type Collection
            pub items: Array?
        end
        let c1 = Collection.new()
        test.assert_nil(c1.items, "items should be nil")
        let c2 = Collection.new(items: [1, 2, 3])
        test.assert_eq(c2.items.len(), 3, "items should have 3 elements")
    end)

    test.it("supports optional dict", fun ()
        type Config
            pub settings: Dict?
        end
        let c1 = Config.new()
        test.assert_nil(c1.settings, "settings should be nil")
        let c2 = Config.new(settings: {"key": "value"})
        test.assert_eq(c2.settings["key"], "value", "settings key should be value")
    end)
end)

# Test mixed required and optional fields
test.describe("Mixed required and optional fields", fun ()
    test.it("requires all non-optional fields", fun ()
        type User
            pub name: Str
            pub email: Str?
            pub age: Int?
        end

        let u = User.new(name: "Alice")
        test.assert_eq(u.name, "Alice", "name should be Alice")
        test.assert_nil(u.email, "email should be nil")
        test.assert_nil(u.age, "age should be nil")
    end)

    test.it("allows partial specification with named args", fun ()
        type Profile
            pub username: Str
            pub bio: Str?
            pub avatar: Str?
        end

        let p = Profile.new(username: "bob", bio: "Developer")
        test.assert_eq(p.username, "bob", "username should be bob")
        test.assert_eq(p.bio, "Developer", "bio should be Developer")
        test.assert_nil(p.avatar, "avatar should be nil")
    end)

    test.it("allows all optional fields to be provided", fun ()
        type Settings
            pub host: Str
            pub port: Int?
            pub timeout: Int?
            pub debug: Bool?
        end

        let s = Settings.new(host: "localhost", port: 8080, timeout: 30, debug: true)
        test.assert_eq(s.host, "localhost")        test.assert_eq(s.port, 8080)        test.assert_eq(s.timeout, 30)        test.assert_eq(s.debug, true)    end)

    test.it("works with multiple required fields", fun ()
        type Person
            pub first_name: Str
            pub last_name: Str
            pub middle_name: Str?
        end

        let p1 = Person.new(first_name: "John", last_name: "Doe")
        test.assert_eq(p1.first_name, "John")        test.assert_eq(p1.last_name, "Doe")        test.assert_nil(p1.middle_name)
        let p2 = Person.new(first_name: "Jane", last_name: "Smith", middle_name: "Marie")
        test.assert_eq(p2.middle_name, "Marie")    end)
end)

# Test optional with pub modifier
test.describe("Public optional fields", fun ()
    test.it("supports pub with optional int", fun ()
        type Data
            pub value: Int?
        end

        let d = Data.new()
        test.assert_nil(d.value, "value should be nil")
    end)

    test.it("allows mix of pub and private with optional", fun ()
        type Record
            pub id: Int
            name: Str?
            pub status: Str?
        end

        let r = Record.new(id: 1)
        test.assert_eq(r.id, 1)        test.assert_nil(r.status)    end)
end)

# Test optional user-defined types
test.describe("Optional custom types", fun ()
    test.it("supports optional user-defined types", fun ()
        type Address
            pub street: Str
        end

        type Person
            pub name: Str
            pub address: Address?
        end

        let p1 = Person.new(name: "Alice")
        test.assert_nil(p1.address, "address should be nil")

        let addr = Address.new(street: "Main St")
        let p2 = Person.new(name: "Bob", address: addr)
        test.assert_eq(p2.address.street, "Main St", "address street should be Main St")
    end)

    test.it("supports nested optional types", fun ()
        type City
            pub name: Str
        end

        type Address
            pub street: Str
            pub city: City?
        end

        type Person
            pub name: Str
            pub address: Address?
        end

        let p = Person.new(name: "Alice")
        test.assert_nil(p.address)
        let addr = Address.new(street: "Main St")
        let p2 = Person.new(name: "Bob", address: addr)
        test.assert_nil(p2.address.city, "city should be nil")
    end)
end)

# Test explicitly passing nil
test.describe("Explicit nil values", fun ()
    test.it("allows explicit nil for optional fields", fun ()
        type Config
            pub port: Int?
        end

        let c = Config.new(port: nil)
        test.assert_nil(c.port, "port should be nil")
    end)

    test.it("allows explicit nil mixed with other args", fun ()
        type Server
            pub host: Str
            pub port: Int?
            pub ssl: Bool?
        end

        let s = Server.new(host: "localhost", port: nil, ssl: true)
        test.assert_eq(s.host, "localhost")        test.assert_nil(s.port)        test.assert_eq(s.ssl, true)    end)
end)

# Test positional vs named arguments with optional
test.describe("Positional vs named with optional", fun ()
    test.it("allows positional arguments up to optional boundary", fun ()
        type User
            pub name: Str
            pub email: Str?
        end

        let u1 = User.new("alice")
        test.assert_eq(u1.name, "alice")        test.assert_nil(u1.email)
        let u2 = User.new("bob", "bob@test.com")
        test.assert_eq(u2.name, "bob")        test.assert_eq(u2.email, "bob@test.com")    end)

    test.it("allows named arguments in any order with optional", fun ()
        type Config
            pub host: Str
            pub port: Int?
            pub debug: Bool?
        end

        let c = Config.new(debug: true, host: "localhost")
        test.assert_eq(c.host, "localhost")        test.assert_nil(c.port)        test.assert_eq(c.debug, true)    end)
end)

# Test all optional fields
test.describe("All fields optional", fun ()
    test.it("allows type with all optional fields", fun ()
        type OptionalConfig
            pub host: Str?
            pub port: Int?
        end

        let c1 = OptionalConfig.new()
        test.assert_nil(c1.host)        test.assert_nil(c1.port)
        let c2 = OptionalConfig.new(host: "localhost")
        test.assert_eq(c2.host, "localhost")        test.assert_nil(c2.port)    end)
end)
