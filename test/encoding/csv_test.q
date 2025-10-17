use "std/test" {it, describe, module, assert_eq, assert_type, assert_near}
use "std/encoding/csv"

module("std/encoding/csv")

describe("csv.parse with headers", fun ()
  it("parses simple CSV", fun ()
    let csv_text = "name,age\nAlice,30\nBob,25"
    let rows = csv.parse(csv_text)

    assert_eq(rows.len(), 2)
    assert_eq(rows[0]["name"], "Alice")    assert_eq(rows[0]["age"], 30)    assert_eq(rows[1]["name"], "Bob")    assert_eq(rows[1]["age"], 25)  end)

  it("auto-detects integer types", fun ()
    let csv_text = "value\n42\n-10\n0"
    let rows = csv.parse(csv_text)

    assert_type(rows[0]["value"], "Int")    assert_eq(rows[0]["value"], 42)    assert_eq(rows[1]["value"], -10)  end)

  it("auto-detects float types", fun ()
    let csv_text = "value\n3.14\n-2.5\n1.0"
    let rows = csv.parse(csv_text)

    assert_type(rows[0]["value"], "Float")    assert_near(rows[0]["value"], 3.14, 0.001)  end)

  it("auto-detects boolean types", fun ()
    let csv_text = "active\ntrue\nfalse\nTRUE\nFALSE"
    let rows = csv.parse(csv_text)

    assert_type(rows[0]["active"], "Bool")    assert_eq(rows[0]["active"], true)    assert_eq(rows[1]["active"], false)    assert_eq(rows[2]["active"], true)    assert_eq(rows[3]["active"], false)  end)

  it("handles empty fields", fun ()
    let csv_text = "name,age,city\nAlice,30,NYC\nBob,,LA"
    let rows = csv.parse(csv_text)

    assert_eq(rows[0]["age"], 30)    assert_eq(rows[1]["age"], "")  end)

  it("handles quoted fields", fun ()
    let csv_text = "name,note\nAlice,\"Hello, World!\"\nBob,Simple"
    let rows = csv.parse(csv_text)

    assert_eq(rows[0]["note"], "Hello, World!")    assert_eq(rows[1]["note"], "Simple")  end)

  it("trims whitespace by default", fun ()
    let csv_text = "name, age\n Alice , 30 \n Bob , 25 "
    let rows = csv.parse(csv_text)

    assert_eq(rows[0]["name"], "Alice")    assert_eq(rows[0]["age"], 30)  end)
end)

describe("csv.parse without headers", fun ()
  it("parses as array of arrays", fun ()
    let csv_text = "Alice,30\nBob,25"
    let rows = csv.parse(csv_text, {"has_headers": false})

    assert_eq(rows.len(), 2)
    assert_eq(rows[0][0], "Alice")    assert_eq(rows[0][1], 30)    assert_eq(rows[1][0], "Bob")    assert_eq(rows[1][1], 25)  end)

  it("auto-detects types in arrays", fun ()
    let csv_text = "Alice,30,true,3.14"
    let rows = csv.parse(csv_text, {"has_headers": false})

    assert_type(rows[0][0], "Str")    assert_type(rows[0][1], "Int")    assert_type(rows[0][2], "Bool")    assert_type(rows[0][3], "Float")  end)
end)

describe("csv.parse with custom delimiter", fun ()
  it("parses TSV (tab-separated)", fun ()
    let tsv_text = "name\tage\nAlice\t30\nBob\t25"
    let rows = csv.parse(tsv_text, {"delimiter": "\t"})

    assert_eq(rows.len(), 2)
    assert_eq(rows[0]["name"], "Alice")    assert_eq(rows[0]["age"], 30)  end)

  it("parses pipe-delimited", fun ()
    let csv_text = "name|age\nAlice|30\nBob|25"
    let rows = csv.parse(csv_text, {"delimiter": "|"})

    assert_eq(rows[0]["name"], "Alice")    assert_eq(rows[0]["age"], 30)  end)
end)

describe("csv.stringify with dictionaries", fun ()
  it("stringifies simple data", fun ()
    let data = [
      {"name": "Alice", "age": "30"},
      {"name": "Bob", "age": "25"}
    ]
    let csv = csv.stringify(data)

    # Check it contains headers and data
    assert_eq(csv.contains("name"), true)
    assert_eq(csv.contains("age"), true)
    assert_eq(csv.contains("Alice"), true)
    assert_eq(csv.contains("Bob"), true)
  end)

  it("handles numbers and booleans", fun ()
    let data = [
      {"name": "Alice", "age": 30, "active": true}
    ]
    let csv = csv.stringify(data)

    assert_eq(csv.contains("30"), true)
    assert_eq(csv.contains("true"), true)
  end)
end)

describe("csv.stringify with arrays", fun ()
  it("stringifies array of arrays", fun ()
    let data = [
      ["Alice", "30", "NYC"],
      ["Bob", "25", "LA"]
    ]
    let csv_text = csv.stringify(data)

    assert_eq(csv_text.contains("Alice"), true)
    assert_eq(csv_text.contains("30"), true)
  end)

  it("handles custom headers", fun ()
    let data = [
      ["Alice", "30"],
      ["Bob", "25"]
    ]
    let csv_text = csv.stringify(data, {"headers": ["Name", "Age"]})

    assert_eq(csv_text.contains("Name"), true)
    assert_eq(csv_text.contains("Age"), true)
  end)
end)

describe("csv.stringify with custom delimiter", fun ()
  it("creates TSV", fun ()
    let data = [
      {"name": "Alice", "age": "30"}
    ]
    let tsv = csv.stringify(data, {"delimiter": "\t"})

    assert_eq(tsv.contains("\t"), true)
    assert_eq(tsv.contains("Alice"), true)
  end)
end)

describe("round trip", fun ()
  it("parses and stringifies correctly", fun ()
    let original_data = [
      {"name": "Alice", "age": "30", "city": "NYC"},
      {"name": "Bob", "age": "25", "city": "LA"}
    ]

    let csv_text = csv.stringify(original_data)
    let parsed = csv.parse(csv_text)

    assert_eq(parsed.len(), 2)
    assert_eq(parsed[0]["name"], "Alice")    assert_eq(parsed[0]["age"], 30)    assert_eq(parsed[1]["name"], "Bob")  end)
end)

describe("edge cases", fun ()
  it("handles empty CSV", fun ()
    let csv_text = ""
    let rows = csv.parse(csv_text, {"has_headers": false})
    assert_eq(rows.len(), 0)
  end)

  it("handles single row with headers", fun ()
    let csv_text = "name,age\nAlice,30"
    let rows = csv.parse(csv_text)
    assert_eq(rows.len(), 1)
    assert_eq(rows[0]["name"], "Alice")  end)

  it("handles headers only", fun ()
    let csv_text = "name,age,city"
    let rows = csv.parse(csv_text)
    assert_eq(rows.len(), 0)
  end)
end)
