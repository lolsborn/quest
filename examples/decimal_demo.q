#!/usr/bin/env quest

use "std/decimal" as decimal

puts("=== Quest Decimal Demo ===\n")

# Example 1: Creating decimals
puts("1. Creating Decimals:")
let d1 = decimal.new("123.45")
let d2 = decimal.new(100.5)
puts("   From string: ", d1, " (", d1.cls(), ")")
puts("   From number: ", d2, " (", d2.cls(), ")")

# Example 2: Precision preservation
puts("\n2. Precision preservation (avoid floating point errors):")
let float_result = 0.1 + 0.2
let decimal_result = decimal.new("0.1").plus(decimal.new("0.2"))
puts("   Float:   0.1 + 0.2 = ", float_result)
puts("   Decimal: 0.1 + 0.2 = ", decimal_result)

# Example 3: Financial calculations
puts("\n3. Financial calculations:")
let price = decimal.new("19.99")
let quantity = decimal.new("3")
let subtotal = price.times(quantity)
let tax_rate = decimal.new("0.08")  # 8% tax
let tax = subtotal.times(tax_rate)
let total = subtotal.plus(tax)
puts("   Price: $", price)
puts("   Quantity: ", quantity)
puts("   Subtotal: $", subtotal)
puts("   Tax (8%): $", tax)
puts("   Total: $", total)

# Example 4: Arithmetic operations
puts("\n4. Arithmetic operations:")
let a = decimal.new("100")
let b = decimal.new("3")
puts("   ", a, " + ", b, " = ", a.plus(b))
puts("   ", a, " - ", b, " = ", a.minus(b))
puts("   ", a, " * ", b, " = ", a.times(b))
puts("   ", a, " / ", b, " = ", a.div(b))
puts("   ", a, " % ", b, " = ", a.mod(b))

# Example 5: Comparisons
puts("\n5. Comparisons:")
let x = decimal.new("50.5")
let y = decimal.new("25.25")
puts("   ", x, " > ", y, " = ", x.gt(y))
puts("   ", x, " < ", y, " = ", x.lt(y))
puts("   ", x, " == ", y, " = ", x.eq(y))
puts("   ", x, " == ", x, " = ", x.eq(x))

# Example 6: Conversion
puts("\n6. Conversion:")
let precise = decimal.new("123.456789")
puts("   Decimal: ", precise)
puts("   to_string(): ", precise.to_string())
puts("   to_f64(): ", precise.to_f64())

# Example 7: Constants
puts("\n7. Constants:")
puts("   Zero: ", decimal.zero())
puts("   One: ", decimal.one())

puts("\n=== Demo Complete ===")
