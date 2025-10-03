use "std/http/client" as http

puts("=== Quest HTTP Client Demo ===\n")

# Example 1: Simple GET request
puts("1. Fetching GitHub user data:")
let resp = http.get("https://api.github.com/users/octocat")
if resp.ok()
    let user = resp.json()
    puts("   Name: " .. user["name"])
    puts("   Company: " .. user["company"])
    puts("   Bio: " .. user["bio"])
else
    puts("   Error: " .. resp.status())
end

# Example 2: Random fact from API
puts("\n2. Random cat fact:")
let fact_resp = http.get("https://catfact.ninja/fact")
let fact = fact_resp.json()
puts("   " .. fact["fact"])

# Example 3: Client reuse with multiple requests
puts("\n3. Fetching multiple UUIDs:")
let client = http.client()
for i in 1 to 3
    let uuid_resp = client.get("https://httpbin.org/uuid")
    let uuid_data = uuid_resp.json()
    puts("   UUID " .. i .. ": " .. uuid_data["uuid"])
end

# Example 4: Response headers
puts("\n4. Examining response headers:")
let header_resp = http.get("https://httpbin.org/get")
puts("   Content-Type: " .. header_resp.content_type())
puts("   Is JSON: " .. header_resp.is_json())
puts("   Status: " .. header_resp.status())

# Example 5: Binary data
puts("\n5. Downloading binary data:")
let bytes_resp = http.get("https://httpbin.org/bytes/256")
let data = bytes_resp.bytes()
puts("   Downloaded " .. data.len() .. " bytes")

puts("\n=== Demo Complete ===")
