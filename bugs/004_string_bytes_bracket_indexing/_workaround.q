# Current workarounds that work

# String workaround: use slice()
let s = "hello"
puts(s.slice(0, 1))  # → "h"

# Bytes workaround: use get()
let b = b"hello"
puts(b.get(0))  # → 104

# Arrays and Dicts work correctly
let a = [1, 2, 3]
puts(a[0])  # → 1

let d = {"x": 10}
puts(d["x"])  # → 10
