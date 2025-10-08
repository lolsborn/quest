use "std/test"

test.module("Struct Field Defaults (QEP-045)")

test.describe("Basic default values", fun ()
    test.it("uses default value when field not provided", fun ()
        type Point
            pub x: Int = 0
            pub y: Int = 0
        end

        let p = Point.new()
        test.assert_eq(p.x, 0, "x should default to 0")
        test.assert_eq(p.y, 0, "y should default to 0")
    end)

    test.it("allows overriding default values", fun ()
        type Point
            pub x: Int = 0
            pub y: Int = 0
        end

        let p = Point.new(x: 10, y: 20)
        test.assert_eq(p.x, 10, "x should be 10")
        test.assert_eq(p.y, 20, "y should be 20")
    end)

    test.it("allows partial override of defaults", fun ()
        type Point
            pub x: Int = 0
            pub y: Int = 0
        end

        let p = Point.new(x: 5)
        test.assert_eq(p.x, 5, "x should be 5")
        test.assert_eq(p.y, 0, "y should default to 0")
    end)
end)

test.describe("Mixed required and optional fields", fun ()
    test.it("requires non-default fields", fun ()
        type Config
            pub host: Str
            pub port: Int = 8080
        end

        test.assert_raises(ArgErr, fun ()
            Config.new()
        end, "Should raise error when required field not provided")
    end)

    test.it("allows creating with required field only", fun ()
        type Config
            pub host: Str
            pub port: Int = 8080
        end

        let c = Config.new(host: "localhost")
        test.assert_eq(c.host, "localhost", "host should be set")
        test.assert_eq(c.port, 8080, "port should default to 8080")
    end)

    test.it("allows overriding optional fields", fun ()
        type Config
            pub host: Str
            pub port: Int = 8080
        end

        let c = Config.new(host: "example.com", port: 3000)
        test.assert_eq(c.host, "example.com", "host should be set")
        test.assert_eq(c.port, 3000, "port should be 3000")
    end)
end)

test.describe("Optional fields with ? syntax", fun ()
    test.it("defaults optional fields to nil", fun ()
        type Person
            pub name: Str
            pub age: Int?
        end

        let p = Person.new(name: "Alice")
        test.assert_eq(p.name, "Alice", "name should be set")
        test.assert_nil(p.age, "age should be nil")
    end)

    test.it("allows setting optional fields", fun ()
        type Person
            pub name: Str
            pub age: Int?
        end

        let p = Person.new(name: "Bob", age: 30)
        test.assert_eq(p.name, "Bob", "name should be set")
        test.assert_eq(p.age, 30, "age should be 30")
    end)

    test.it("allows explicitly setting optional fields to nil", fun ()
        type Person
            pub name: Str
            pub age: Int?
        end

        let p = Person.new(name: "Charlie", age: nil)
        test.assert_eq(p.name, "Charlie", "name should be set")
        test.assert_nil(p.age, "age should be nil")
    end)
end)

test.describe("Various default value types", fun ()
    test.it("supports string defaults", fun ()
        type Logger
            pub prefix: Str = "[LOG]"
        end

        let log = Logger.new()
        test.assert_eq(log.prefix, "[LOG]", "prefix should default to [LOG]")
    end)

    test.it("supports boolean defaults", fun ()
        type Server
            pub ssl: Bool = false
        end

        let srv = Server.new()
        test.assert_eq(srv.ssl, false, "ssl should default to false")
    end)

    test.it("supports multiple field types with defaults", fun ()
        type AppConfig
            pub debug: Bool = false
            pub max_connections: Int = 100
            pub app_name: Str = "MyApp"
        end

        let cfg = AppConfig.new()
        test.assert_eq(cfg.debug, false, "debug should default to false")
        test.assert_eq(cfg.max_connections, 100, "max_connections should default to 100")
        test.assert_eq(cfg.app_name, "MyApp", "app_name should default to MyApp")
    end)
end)

test.describe("Complex default scenarios", fun ()
    test.it("supports all field categories mixed", fun ()
        type DatabaseConfig
            pub database: Str
            pub host: Str = "localhost"
            pub port: Int = 5432
            pub username: Str = "postgres"
            pub password: Str?
            pub ssl: Bool = false
        end

        let db = DatabaseConfig.new(database: "mydb", password: "secret")
        test.assert_eq(db.database, "mydb", "database should be set")
        test.assert_eq(db.host, "localhost", "host should default")
        test.assert_eq(db.port, 5432, "port should default")
        test.assert_eq(db.username, "postgres", "username should default")
        test.assert_eq(db.password, "secret", "password should be set")
        test.assert_eq(db.ssl, false, "ssl should default to false")
    end)

    test.it("handles selective overrides", fun ()
        type Server
            pub host: Str = "localhost"
            pub port: Int = 8080
            pub ssl: Bool = false
            pub timeout: Int = 30
        end

        let srv = Server.new(ssl: true)
        test.assert_eq(srv.host, "localhost", "host should default")
        test.assert_eq(srv.port, 8080, "port should default")
        test.assert_eq(srv.ssl, true, "ssl should be overridden")
        test.assert_eq(srv.timeout, 30, "timeout should default")
    end)
end)

test.describe("Nullable with explicit defaults", fun ()
    test.it("allows nullable fields with non-nil default", fun ()
        type Config
            pub timeout: Int? = 30
        end

        let c = Config.new()
        test.assert_eq(c.timeout, 30, "timeout should default to 30")
    end)

    test.it("allows overriding nullable default with nil", fun ()
        type Config
            pub timeout: Int? = 30
        end

        let c = Config.new(timeout: nil)
        test.assert_nil(c.timeout, "timeout should be nil")
    end)

    test.it("allows overriding nullable default with value", fun ()
        type Config
            pub timeout: Int? = 30
        end

        let c = Config.new(timeout: 60)
        test.assert_eq(c.timeout, 60, "timeout should be 60")
    end)
end)

test.describe("Untyped fields with defaults", fun ()
    test.it("supports untyped fields with defaults", fun ()
        type Point
            pub x = 0
            pub y = 0
        end

        let p = Point.new()
        test.assert_eq(p.x, 0, "x should default to 0")
        test.assert_eq(p.y, 0, "y should default to 0")
    end)

    test.it("allows mixed typed and untyped defaults", fun ()
        type Mixed
            pub name: Str = "default"
            pub count = 42
        end

        let m = Mixed.new()
        test.assert_eq(m.name, "default", "name should default")
        test.assert_eq(m.count, 42, "count should default to 42")
    end)
end)

test.describe("Mutable default values (arrays and dicts)", fun ()
    test.it("creates independent arrays for each instance", fun ()
        type Container
            pub items: Array = []
        end

        let c1 = Container.new()
        c1.items.push(1)
        c1.items.push(2)

        let c2 = Container.new()
        test.assert_eq(c2.items.len(), 0, "c2 should have empty array")
        test.assert_eq(c1.items.len(), 2, "c1 should have 2 items")
    end)

    test.it("creates independent dicts for each instance", fun ()
        type Config
            pub settings: Dict = {debug: false}
        end

        let c1 = Config.new()
        c1.settings["debug"] = true
        c1.settings["logging"] = "enabled"

        let c2 = Config.new()
        test.assert_eq(c2.settings["debug"], false, "c2 should have original debug value")
        test.assert_eq(c2.settings.keys().len(), 1, "c2 should only have debug key")
        test.assert_eq(c1.settings.keys().len(), 2, "c1 should have both keys")
    end)

    test.it("handles nested arrays independently", fun ()
        type Grid
            pub matrix: Array = [[0, 0], [0, 0]]
        end

        let g1 = Grid.new()
        g1.matrix[0][0] = 1

        let g2 = Grid.new()
        test.assert_eq(g2.matrix[0][0], 0, "g2 should have original value")
        test.assert_eq(g1.matrix[0][0], 1, "g1 should have modified value")
    end)

    test.it("handles array with initial values", fun ()
        type Queue
            pub items: Array = [1, 2, 3]
        end

        let q1 = Queue.new()
        q1.items.push(4)

        let q2 = Queue.new()
        test.assert_eq(q2.items.len(), 3, "q2 should have 3 items")
        test.assert_eq(q1.items.len(), 4, "q1 should have 4 items")
    end)
end)
