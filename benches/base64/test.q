use "std/encoding/b64"
use "std/time"
use "std/sys"

# Test fixtures
let fixtures = [["hello", "aGVsbG8="], ["world", "d29ybGQ="]]

for pair in fixtures
  let src = pair[0]
  let dst = pair[1]

  let encoded = b64.encode(src)
  if encoded != dst
    puts(encoded .. " != " .. dst)
    sys.exit(1)
  end

  let decoded = b64.decode(dst)
  if decoded != src
    puts(decoded .. " != " .. src)
    sys.exit(1)
  end
end

let STR_SIZE = 131072
let TRIES = 8192

let str1 = "a" * STR_SIZE
let str2 = b64.encode(str1)
let str3 = b64.decode(str2)

# Encode benchmark
let t_start = time.now().as_millis()
let s_encoded = 0
let i = 0
while i < TRIES
  s_encoded = s_encoded + b64.encode(str1).len()
  i = i + 1
end
let t_end = time.now().as_millis()
let t_encoded = (t_end - t_start) / 1000.0

# Decode benchmark
t_start = time.now().as_millis()
let s_decoded = 0
i = 0
while i < TRIES
  s_decoded = s_decoded + b64.decode(str2).len()
  i = i + 1
end
t_end = time.now().as_millis()
let t_decoded = (t_end - t_start) / 1000.0

puts("encode " .. str1.slice(0, 4) .. "... to " .. str2.slice(0, 4) .. "...: " .. s_encoded.str() .. ", " .. t_encoded.str())
puts("decode " .. str2.slice(0, 4) .. "... to " .. str3.slice(0, 4) .. "...: " .. s_decoded.str() .. ", " .. t_decoded.str())
