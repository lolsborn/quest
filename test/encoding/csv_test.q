use "std/test"
use "std/encoding/csv"

test.module("std/encoding/csv")

test.describe("csv.parse with headers", fun ()
    test.it("parses simple CSV", fun ()
        let csv_text = "name,age\nAlice,30\nBob,25"
        let rows = csv.parse(csv_text)

        test.assert_eq(rows.len(), 2)
        test.assert_eq(rows[0]["name"], "Alice")        test.assert_eq(rows[0]["age"], 30)        test.assert_eq(rows[1]["name"], "Bob")        test.assert_eq(rows[1]["age"], 25)    end)

    test.it("auto-detects integer types", fun ()
        let csv_text = "value\n42\n-10\n0"
        let rows = csv.parse(csv_text)

        test.assert_type(rows[0]["value"], "Int")        test.assert_eq(rows[0]["value"], 42)        test.assert_eq(rows[1]["value"], -10)    end)

    test.it("auto-detects float types", fun ()
        let csv_text = "value\n3.14\n-2.5\n1.0"
        let rows = csv.parse(csv_text)

        test.assert_type(rows[0]["value"], "Float")        test.assert_near(rows[0]["value"], 3.14, 0.001)    end)

    test.it("auto-detects boolean types", fun ()
        let csv_text = "active\ntrue\nfalse\nTRUE\nFALSE"
        let rows = csv.parse(csv_text)

        test.assert_type(rows[0]["active"], "Bool")        test.assert_eq(rows[0]["active"], true)        test.assert_eq(rows[1]["active"], false)        test.assert_eq(rows[2]["active"], true)        test.assert_eq(rows[3]["active"], false)    end)

    test.it("handles empty fields", fun ()
        let csv_text = "name,age,city\nAlice,30,NYC\nBob,,LA"
        let rows = csv.parse(csv_text)

        test.assert_eq(rows[0]["age"], 30)        test.assert_eq(rows[1]["age"], "")    end)

    test.it("handles quoted fields", fun ()
        let csv_text = "name,note\nAlice,\"Hello, World!\"\nBob,Simple"
        let rows = csv.parse(csv_text)

        test.assert_eq(rows[0]["note"], "Hello, World!")        test.assert_eq(rows[1]["note"], "Simple")    end)

    test.it("trims whitespace by default", fun ()
        let csv_text = "name, age\n Alice , 30 \n Bob , 25 "
        let rows = csv.parse(csv_text)

        test.assert_eq(rows[0]["name"], "Alice")        test.assert_eq(rows[0]["age"], 30)    end)
end)

test.describe("csv.parse without headers", fun ()
    test.it("parses as array of arrays", fun ()
        let csv_text = "Alice,30\nBob,25"
        let rows = csv.parse(csv_text, {"has_headers": false})

        test.assert_eq(rows.len(), 2)
        test.assert_eq(rows[0][0], "Alice")        test.assert_eq(rows[0][1], 30)        test.assert_eq(rows[1][0], "Bob")        test.assert_eq(rows[1][1], 25)    end)

    test.it("auto-detects types in arrays", fun ()
        let csv_text = "Alice,30,true,3.14"
        let rows = csv.parse(csv_text, {"has_headers": false})

        test.assert_type(rows[0][0], "Str")        test.assert_type(rows[0][1], "Int")        test.assert_type(rows[0][2], "Bool")        test.assert_type(rows[0][3], "Float")    end)
end)

test.describe("csv.parse with custom delimiter", fun ()
    test.it("parses TSV (tab-separated)", fun ()
        let tsv_text = "name\tage\nAlice\t30\nBob\t25"
        let rows = csv.parse(tsv_text, {"delimiter": "\t"})

        test.assert_eq(rows.len(), 2)
        test.assert_eq(rows[0]["name"], "Alice")        test.assert_eq(rows[0]["age"], 30)    end)

    test.it("parses pipe-delimited", fun ()
        let csv_text = "name|age\nAlice|30\nBob|25"
        let rows = csv.parse(csv_text, {"delimiter": "|"})

        test.assert_eq(rows[0]["name"], "Alice")        test.assert_eq(rows[0]["age"], 30)    end)
end)

test.describe("csv.stringify with dictionaries", fun ()
    test.it("stringifies simple data", fun ()
        let data = [
            {"name": "Alice", "age": "30"},
            {"name": "Bob", "age": "25"}
        ]
        let csv = csv.stringify(data)

        # Check it contains headers and data
        test.assert_eq(csv.contains("name"), true)
        test.assert_eq(csv.contains("age"), true)
        test.assert_eq(csv.contains("Alice"), true)
        test.assert_eq(csv.contains("Bob"), true)
    end)

    test.it("handles numbers and booleans", fun ()
        let data = [
            {"name": "Alice", "age": 30, "active": true}
        ]
        let csv = csv.stringify(data)

        test.assert_eq(csv.contains("30"), true)
        test.assert_eq(csv.contains("true"), true)
    end)
end)

test.describe("csv.stringify with arrays", fun ()
    test.it("stringifies array of arrays", fun ()
        let data = [
            ["Alice", "30", "NYC"],
            ["Bob", "25", "LA"]
        ]
        let csv_text = csv.stringify(data)

        test.assert_eq(csv_text.contains("Alice"), true)
        test.assert_eq(csv_text.contains("30"), true)
    end)

    test.it("handles custom headers", fun ()
        let data = [
            ["Alice", "30"],
            ["Bob", "25"]
        ]
        let csv_text = csv.stringify(data, {"headers": ["Name", "Age"]})

        test.assert_eq(csv_text.contains("Name"), true)
        test.assert_eq(csv_text.contains("Age"), true)
    end)
end)

test.describe("csv.stringify with custom delimiter", fun ()
    test.it("creates TSV", fun ()
        let data = [
            {"name": "Alice", "age": "30"}
        ]
        let tsv = csv.stringify(data, {"delimiter": "\t"})

        test.assert_eq(tsv.contains("\t"), true)
        test.assert_eq(tsv.contains("Alice"), true)
    end)
end)

test.describe("round trip", fun ()
    test.it("parses and stringifies correctly", fun ()
        let original_data = [
            {"name": "Alice", "age": "30", "city": "NYC"},
            {"name": "Bob", "age": "25", "city": "LA"}
        ]

        let csv_text = csv.stringify(original_data)
        let parsed = csv.parse(csv_text)

        test.assert_eq(parsed.len(), 2)
        test.assert_eq(parsed[0]["name"], "Alice")        test.assert_eq(parsed[0]["age"], 30)        test.assert_eq(parsed[1]["name"], "Bob")    end)
end)

test.describe("edge cases", fun ()
    test.it("handles empty CSV", fun ()
        let csv_text = ""
        let rows = csv.parse(csv_text, {"has_headers": false})
        test.assert_eq(rows.len(), 0)
    end)

    test.it("handles single row with headers", fun ()
        let csv_text = "name,age\nAlice,30"
        let rows = csv.parse(csv_text)
        test.assert_eq(rows.len(), 1)
        test.assert_eq(rows[0]["name"], "Alice")    end)

    test.it("handles headers only", fun ()
        let csv_text = "name,age,city"
        let rows = csv.parse(csv_text)
        test.assert_eq(rows.len(), 0)
    end)
end)
