#!/usr/bin/env quest
# URL Parsing Demo - Python urllib.parse inspired
# Shows URL parsing, encoding, and manipulation

use "std/http/urlparse" as urlparse

puts("=== URL Parsing Module Demo ===\n")

# Example 1: Parse a complex URL
puts("1. Parsing URLs:")
puts("   URL: https://user:pass@api.example.com:8080/v1/users?role=admin&limit=10#results")
puts("")

let url = urlparse.urlparse("https://user:pass@api.example.com:8080/v1/users?role=admin&limit=10#results")

puts("   Components:")
puts("     scheme:   " .. url.get("scheme"))
puts("     hostname: " .. url.get("hostname").str())
puts("     port:     " .. url.get("port").str())
puts("     path:     " .. url.get("path"))
puts("     query:    " .. url.get("query"))
puts("     fragment: " .. url.get("fragment"))
puts("     username: " .. url.get("username").str())

# Example 2: Parse query strings
puts("\n2. Query String Parsing:")
let query_str = "search=hello+world&page=1&filter=active"
puts("   Query: " .. query_str)
puts("")

let params = urlparse.parse_qs(query_str)
puts("   Parsed parameters:")
puts("     search: " .. params.get("search").str())
puts("     page:   " .. params.get("page").str())
puts("     filter: " .. params.get("filter").str())

# Example 3: Build query strings
puts("\n3. Building Query Strings:")
let search_params = {
    "q": "machine learning",
    "category": "ai/ml",
    "year": "2025"
}

let query_string = urlparse.urlencode(search_params)
puts("   Parameters: " .. search_params.str())
puts("   Query string: " .. query_string)

# Example 4: URL encoding/decoding
puts("\n4. URL Encoding:")
let original = "Hello World! Special: @#$%"
puts("   Original: " .. original)

let encoded = urlparse.quote(original, "")
puts("   Encoded:  " .. encoded)

let decoded = urlparse.unquote(encoded)
puts("   Decoded:  " .. decoded)

# Example 5: Form-style encoding (+ for spaces)
puts("\n5. Form Encoding (plus for spaces):")
let form_text = "first name last name"
let form_encoded = urlparse.quote_plus(form_text)
puts("   Original: " .. form_text)
puts("   Encoded:  " .. form_encoded .. " (spaces become +)")

let form_decoded = urlparse.unquote_plus(form_encoded)
puts("   Decoded:  " .. form_decoded)

# Example 6: URL joining (relative paths)
puts("\n6. URL Joining:")
let base_url = "https://example.com/docs/guide/intro.html"
puts("   Base: " .. base_url)
puts("")

let scenarios = [
    ["relative.html", "Relative file"],
    ["/api/users", "Absolute path"],
    ["https://other.com/page", "Different domain"]
]

let i = 0
while i < scenarios.len()
    let scenario = scenarios[i]
    let path = scenario[0]
    let desc = scenario[1]

    let result = urlparse.urljoin(base_url, path)
    puts("   + " .. path)
    puts("     → " .. result)
    puts("     (" .. desc .. ")")
    puts("")
    i = i + 1
end

# Example 7: Practical use case - API client
puts("7. Practical Example - Building API URLs:")
puts("")

let api_base = "https://api.github.com"
let endpoint = "/repos/owner/repo/issues"

let filters = {
    "state": "open",
    "labels": "bug,help wanted",
    "sort": "created"
}

let query = urlparse.urlencode(filters)
let full_url = urlparse.urljoin(api_base, endpoint .. "?" .. query)

puts("   API Base: " .. api_base)
puts("   Endpoint: " .. endpoint)
puts("   Filters:  " .. filters.str())
puts("")
puts("   Final URL:")
puts("   " .. full_url)

puts("\n=== Complete ===")
puts("The urlparse module provides Python urllib.parse compatible functions for:")
puts("  • URL parsing and component extraction")
puts("  • Query string parsing and building")
puts("  • URL encoding/decoding (percent encoding)")
puts("  • URL joining (relative to absolute)")
