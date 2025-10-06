# Minimal reproduction for Bug #017
# Optional typed fields reject explicit nil values

type Person
    name: str
    email: str?  # Should allow str or nil
end

# This should work but fails with "Type mismatch: expected str, got Nil"
let p = Person.new(
    name: "Alice",
    email: nil  # BUG: Should be valid for optional field
)

puts("Success: ", p)
