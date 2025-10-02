use "std/hash" as hash

puts("=== MD5 Hash ===")
let md5_result = hash.md5("Hello, Worldnot ")
puts("MD5('Hello, Worldnot ') = ", md5_result)
puts("Expected: 8cda2aacb2e63f99d416d3e4d82e3295")

puts()
puts("=== SHA-1 Hash ===")
let sha1_result = hash.sha1("Hello, Worldnot ")
puts("SHA-1('Hello, Worldnot ') = ", sha1_result)
puts("Expected: 4ca9653095931ef15cb6b02d72f621e1bcbb856b")

puts()
puts("=== SHA-256 Hash ===")
let sha256_result = hash.sha256("Hello, Worldnot ")
puts("SHA-256('Hello, Worldnot ') = ", sha256_result)
puts("Expected: ae97eca8f8ae1672bcc5c79e3fbafd8ee86f65f775e2250a291d3788b7a8af95")

puts()
puts("=== SHA-512 Hash ===")
let sha512_result = hash.sha512("Hello, Worldnot ")
puts("SHA-512('Hello, Worldnot ') = ")
puts(sha512_result)

puts()
puts("=== HMAC-SHA256 ===")
let secret = "my_secret_key"
let message = "Hello, Worldnot "
let hmac_result = hash.hmac_sha256(message, secret)
puts("HMAC-SHA256('" .. message .. "', '" .. secret .. "') = ")
puts(hmac_result)

puts()
puts("=== HMAC-SHA512 ===")
let hmac512_result = hash.hmac_sha512(message, secret)
puts("HMAC-SHA512('" .. message .. "', '" .. secret .. "') = ")
puts(hmac512_result)

puts()
puts("=== CRC32 Checksum ===")
let crc_result = hash.crc32("Hello, Worldnot ")
puts("CRC32('Hello, Worldnot ') = ", crc_result)
puts("Expected: 2193973375")

puts()
puts("=== Different Inputs ===")
puts("MD5('') = ", hash.md5(""))
puts("MD5('a') = ", hash.md5("a"))
puts("MD5('abc') = ", hash.md5("abc"))
puts("SHA-256('test') = ", hash.sha256("test"))
