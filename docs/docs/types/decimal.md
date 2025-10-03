# Decimal Type

The `Decimal` type provides arbitrary-precision decimal arithmetic for financial calculations and other use cases where exact decimal representation is required.

## Overview

Unlike the `Num` type which uses 64-bit floating-point (with ~15-17 digit precision), `Decimal` can represent numbers with up to 28-29 significant digits without rounding errors. This makes it ideal for:

- Financial calculations (money, prices, interest rates)
- Scientific measurements requiring high precision
- Database operations with NUMERIC/DECIMAL columns
- Any calculation where floating-point rounding is unacceptable

## Creating Decimals

Currently, `Decimal` values are created automatically when reading from PostgreSQL `NUMERIC` or `DECIMAL` columns:

```quest
use "std/db/postgres" as db

let conn = db.connect("postgresql://localhost/mydb")
let cursor = conn.cursor()

cursor.execute("SELECT price FROM products WHERE id = 1")
let rows = cursor.fetch_all()
let price = rows[0].get("price")  # Returns Decimal if column is NUMERIC

puts(price._rep())  # Decimal(19.99)
puts(price.cls())   # Decimal
```

## Methods

### Arithmetic Operations

#### `plus(other)`
Add another decimal or number.

```quest
let sum = decimal_a.plus(decimal_b)
let sum2 = decimal_a.plus(5.5)  # Can also add Num
```

#### `minus(other)`
Subtract another decimal or number.

```quest
let diff = decimal_a.minus(decimal_b)
```

#### `times(other)`
Multiply by another decimal or number.

```quest
let product = price.times(quantity)
```

#### `div(other)`
Divide by another decimal or number. Raises error on division by zero.

```quest
let quotient = total.div(count)
```

#### `mod(other)`
Get remainder after division.

```quest
let remainder = value.mod(divisor)
```

### Comparison Operations

#### `eq(other)`
Test equality. Returns `true` if values are exactly equal.

```quest
let is_equal = price.eq(19.99)
```

#### `neq(other)`
Test inequality.

```quest
let is_different = price.neq(20.00)
```

#### `lt(other)`, `lte(other)`, `gt(other)`, `gte(other)`
Less than, less than or equal, greater than, greater than or equal.

```quest
if price.gte(minimum_price)
    puts("Price acceptable")
end
```

### Conversion Methods

#### `to_f64()`
Convert to floating-point number (Num type). May lose precision for very large or precise decimals.

```quest
let float_val = decimal_val.to_f64()
```

#### `to_string()`
Convert to string representation.

```quest
let price_str = price.to_string()  # "19.99"
```

### Object Protocol Methods

All standard object methods are available:

- `._str()` - String representation
- `._rep()` - REPL display format (e.g., "Decimal(19.99)")
- `._doc()` - Documentation string
- `._id()` - Unique object ID
- `.cls()` - Type name ("Decimal")

## Type Checking

Check if a value is a Decimal:

```quest
if value.cls().eq("Decimal")
    puts("This is a decimal value")
end
```

## PostgreSQL Integration

Decimals are automatically used when working with PostgreSQL `NUMERIC` and `DECIMAL` columns:

```quest
use "std/db/postgres" as db

let conn = db.connect(conn_string)
let cursor = conn.cursor()

# Create table with NUMERIC column
cursor.execute("CREATE TABLE prices (id SERIAL, amount NUMERIC(10, 2))")

# Insert - Quest Decimal or Num values work
cursor.execute("INSERT INTO prices (amount) VALUES ($1)", [19.99])

# Read - Returns Decimal
cursor.execute("SELECT amount FROM prices")
let rows = cursor.fetch_all()
let amount = rows[0].get("amount")  # Decimal type

# Decimal arithmetic
let tax = amount.times(0.10)
let total = amount.plus(tax)
puts("Total with tax: " .. total.to_string())
```

## Arrays of Decimals

PostgreSQL `NUMERIC[]` arrays are returned as Quest arrays containing Decimal values:

```quest
cursor.execute("SELECT ARRAY[1.5, 2.5, 3.5]::NUMERIC[] as values")
let rows = cursor.fetch_all()
let values = rows[0].get("values")

values.each(fun (val)
    puts(val.to_string())
end)
```

## Precision Notes

- Decimal uses Rust's `rust_decimal` library with up to 28-29 significant digits
- PostgreSQL NUMERIC can have up to 131,072 digits before the decimal point and up to 16,383 digits after
- Values are preserved exactly as stored in the database
- Converting to `Num` (f64) may lose precision for very large or precise values
- For maximum precision, keep values as Decimal throughout your calculations

## Limitations

- No direct decimal literal syntax (e.g., `123.45d`) yet
- Cannot create Decimals from strings in Quest code currently
- Primary use case is PostgreSQL database operations
- Future versions may add constructors and literal support

## See Also

- [Num Type](../language/types.md#num) - Standard floating-point numbers
- [PostgreSQL Module](../stdlib/db/postgres.md) - Database operations
- [Type System](../language/types.md) - Overview of Quest types
