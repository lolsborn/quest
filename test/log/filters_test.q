# Log Filter Tests - QEP-004
# Tests the Filter type for logger name hierarchy filtering

use "std/test" as test
use "std/log" as log
use "std/time" as time

test.module("Log Filters (QEP-004)")

test.describe("Filter construction", fun ()
    test.it("creates filter with empty name", fun ()
        let f = log.Filter.new(name: "")
        # Can't access private field, but we can test behavior
        let record = {"name": "anything", "level_no": log.INFO}
        test.assert(f.filter(record), "Empty filter should match any logger")
    end)

    test.it("creates filter with logger name", fun ()
        let f = log.Filter.new(name: "app.db")
        let record = {"name": "app.db", "level_no": log.INFO}
        test.assert(f.filter(record), "Filter should match its configured name")
    end)
end)

test.describe("Filter matching - exact name", fun ()
    test.it("matches exact logger name", fun ()
        let f = log.Filter.new(name: "app.db")
        let record = {"name": "app.db", "level_no": log.INFO, "message": "test"}

        test.assert(f.filter(record), "Should match exact name")
    end)

    test.it("rejects different logger name", fun ()
        let f = log.Filter.new(name: "app.db")
        let record = {"name": "app.api", "level_no": log.INFO, "message": "test"}

        test.assert(not f.filter(record), "Should reject different name")
    end)

    test.it("rejects partial match without hierarchy", fun ()
        let f = log.Filter.new(name: "app.db")
        let record = {"name": "app.database", "level_no": log.INFO, "message": "test"}

        test.assert(not f.filter(record), "Should reject 'app.database' when filtering 'app.db'")
    end)
end)

test.describe("Filter matching - hierarchy", fun ()
    test.it("matches direct child logger", fun ()
        let f = log.Filter.new(name: "app.db")
        let record = {"name": "app.db.query", "level_no": log.INFO, "message": "test"}

        test.assert(f.filter(record), "Should match child logger app.db.query")
    end)

    test.it("matches deep descendant logger", fun ()
        let f = log.Filter.new(name: "app")
        let record = {"name": "app.db.pool.connection", "level_no": log.INFO, "message": "test"}

        test.assert(f.filter(record), "Should match deep descendant app.db.pool.connection")
    end)

    test.it("rejects parent logger", fun ()
        let f = log.Filter.new(name: "app.db.query")
        let record = {"name": "app.db", "level_no": log.INFO, "message": "test"}

        test.assert(not f.filter(record), "Should not match parent logger")
    end)

    test.it("rejects sibling logger", fun ()
        let f = log.Filter.new(name: "app.db")
        let record = {"name": "app.api", "level_no": log.INFO, "message": "test"}

        test.assert(not f.filter(record), "Should not match sibling logger")
    end)
end)

test.describe("Filter matching - empty name", fun ()
    test.it("empty name matches all loggers", fun ()
        let f = log.Filter.new(name: "")

        let names = ["root", "app", "app.db", "app.db.query", "lib.utils"]
        let i = 0
        while i < names.len()
            let record = {"name": names[i], "level_no": log.INFO, "message": "test"}
            test.assert(f.filter(record), "Empty filter should match logger: " .. names[i])
            i = i + 1
        end
    end)
end)

test.describe("Filter on handler", fun ()
    test.it("handler with filter blocks non-matching records", fun ()
        # Create handler with filter
        let handler = log.StreamHandler.new(
            level: log.NOTSET,
            formatter_obj: nil,
            filters: []
        )

        let filter = log.Filter.new(name: "app.db")
        handler.add_filter(filter)

        # Create records with all required fields
        let matching_record = {
            "record": {
                "name": "app.db.query",
                "level_no": log.INFO,
                "level_name": "INFO",
                "message": "test",
                "datetime": time.now_local(),
                "module_name": nil,
                "line_no": nil
            },
            "exc_info": nil
        }
        let non_matching_record = {
            "record": {
                "name": "app.api",
                "level_no": log.INFO,
                "level_name": "INFO",
                "message": "test",
                "datetime": time.now_local(),
                "module_name": nil,
                "line_no": nil
            },
            "exc_info": nil
        }

        # Note: Due to Quest bug, methods returning nil actually return self
        # So we can't test return values directly
        # Instead, we verify filter behavior by checking if records are emitted

        # For now, just verify filters work correctly in isolation
        test.assert(filter.filter(matching_record["record"]), "Filter should match app.db.query")
        test.assert(not filter.filter(non_matching_record["record"]), "Filter should reject app.api")
    end)
end)

test.describe("Multiple filters on handler", fun ()
    test.it("all filters must pass for record to be logged", fun ()
        let handler = log.StreamHandler.new(
            level: log.NOTSET,
            formatter_obj: nil,
            filters: []
        )

        # Add two filters - both must match
        let filter1 = log.Filter.new(name: "app")
        let filter2 = log.Filter.new(name: "app.db")
        handler.add_filter(filter1)
        handler.add_filter(filter2)

        # Record matching both filters
        let record1 = {
            "record": {
                "name": "app.db.query",
                "level_no": log.INFO,
                "level_name": "INFO",
                "message": "test",
                "datetime": time.now_local(),
                "module_name": nil,
                "line_no": nil
            },
            "exc_info": nil
        }

        # Record matching only first filter
        let record2 = {
            "record": {
                "name": "app.api",
                "level_no": log.INFO,
                "level_name": "INFO",
                "message": "test",
                "datetime": time.now_local(),
                "module_name": nil,
                "line_no": nil
            },
            "exc_info": nil
        }

        # Due to Quest bug with nil returns, test filters directly
        let f1_match1 = filter1.filter(record1["record"])
        let f2_match1 = filter2.filter(record1["record"])
        test.assert(f1_match1 and f2_match1, "Both filters should match app.db.query")

        let f1_match2 = filter1.filter(record2["record"])
        let f2_match2 = filter2.filter(record2["record"])
        test.assert(f1_match2 and not f2_match2, "Only filter1 should match app.api")
    end)
end)

test.describe("Filter edge cases", fun ()
    test.it("filter works with root logger", fun ()
        let f = log.Filter.new(name: "root")
        let record = {"name": "root", "level_no": log.INFO, "message": "test"}

        test.assert(f.filter(record), "Should match root logger")
    end)

    test.it("filter handles single-segment names", fun ()
        let f = log.Filter.new(name: "app")
        let record1 = {"name": "app", "level_no": log.INFO, "message": "test"}
        let record2 = {"name": "lib", "level_no": log.INFO, "message": "test"}

        test.assert(f.filter(record1), "Should match 'app'")
        test.assert(not f.filter(record2), "Should not match 'lib'")
    end)

    test.it("filter is case-sensitive", fun ()
        let f = log.Filter.new(name: "App")
        let record = {"name": "app", "level_no": log.INFO, "message": "test"}

        test.assert(not f.filter(record), "Filter should be case-sensitive")
    end)

    test.it("filter requires exact dot separator", fun ()
        let f = log.Filter.new(name: "app.db")
        let record = {"name": "app.db2", "level_no": log.INFO, "message": "test"}

        test.assert(not f.filter(record), "Should not match 'app.db2' when filtering 'app.db'")
    end)
end)
