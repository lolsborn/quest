#!/usr/bin/env quest
# chr() and ord() Demo - Character/Codepoint Conversion

puts("=== chr() and ord() Demo ===\n")

# Basic usage
puts("Basic ASCII:")
puts("  chr(65) = " .. chr(65))
puts("  chr(72) = " .. chr(72))
puts("  ord('A') = " .. ord("A").str())
puts("  ord('H') = " .. ord("H").str())
puts("")

# Build string from codepoints
puts("Building strings from codepoints:")
let hello = chr(72) .. chr(101) .. chr(108) .. chr(108) .. chr(111)
puts("  chr(72,101,108,108,111) = " .. hello)
puts("")

# Using string method
puts("String method syntax:")
puts("  'A'.ord() = " .. "A".ord().str())
puts("  'Z'.ord() = " .. "Z".ord().str())
puts("")

# Unicode examples
puts("Unicode support:")
puts("  chr(8364) = " .. chr(8364) .. " (Euro)")
puts("  chr(9731) = " .. chr(9731) .. " (Snowman)")
puts("  chr(128077) = " .. chr(128077) .. " (Thumbs up)")
puts("  ord('€') = " .. ord("€").str())
puts("  ord('👍') = " .. ord("👍").str())
puts("")

# Roundtrip
puts("Roundtrip conversion:")
let original = "Hello"
let codes = []
for i in 0 until original.len()
    codes.push(original.slice(i, i + 1).ord())
end
puts("  '" .. original .. "' -> " .. codes.str())

let rebuilt = ""
for code in codes
    rebuilt = rebuilt .. chr(code)
end
puts("  " .. codes.str() .. " -> '" .. rebuilt .. "'")
puts("")

# Simple Caesar cipher
puts("Caesar cipher (shift by 3):")
let plaintext = "ABC"
let encrypted = ""
let idx = 0
while idx < plaintext.len()
    encrypted = encrypted .. chr(plaintext.slice(idx, idx + 1).ord() + 3)
    idx = idx + 1
end
puts("  '" .. plaintext .. "' -> '" .. encrypted .. "'")

# Decrypt
let decrypted = ""
let idx2 = 0
while idx2 < encrypted.len()
    decrypted = decrypted .. chr(encrypted.slice(idx2, idx2 + 1).ord() - 3)
    idx2 = idx2 + 1
end
puts("  '" .. encrypted .. "' -> '" .. decrypted .. "'")
puts("")

# Character range
puts("Character ranges:")
let a_code = "A".ord()
let z_code = "Z".ord()
puts("  'A' to 'Z' = " .. a_code.str() .. " to " .. z_code.str() .. " (" .. (z_code - a_code + 1).str() .. " letters)")
puts("")

puts("✓ chr() and ord() working perfectly!")
