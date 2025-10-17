# URL Parsing

The `std/http/urlparse` module provides URL parsing and manipulation functions inspired by Python's `urllib.parse`.

## Import

```quest
use "std/http/urlparse"
```

## Functions

### `urlparse.urlparse(url)`

Parse a URL into its components.

**Parameters:**
- `url` - URL string to parse (Str)

**Returns:** Dictionary with URL components (Dict)

**Dictionary Keys:**
- `scheme` - URL scheme (http, https, ftp, etc.)
- `netloc` - Network location (user:pass@host:port)
- `hostname` - Just the hostname (Nil if not present)
- `port` - Port number as Int (Nil if not present)
- `username` - Username from netloc (Nil if not present)
- `password` - Password from netloc (Nil if not present)
- `path` - URL path
- `query` - Query string (without `?`)
- `fragment` - Fragment identifier (without `#`)
- `params` - URL parameters (always empty, not separated by parser)

**Example:**
```quest
use "std/http/urlparse"

let url = "https://user:pass@api.example.com:8080/v1/users?id=42&name=alice#section1"
let parsed = urlparse.urlparse(url)

puts(parsed["scheme"])    # https
puts(parsed["hostname"])  # api.example.com
puts(parsed["port"])      # 8080
puts(parsed["username"])  # user
puts(parsed["password"])  # pass
puts(parsed["path"])      # /v1/users
puts(parsed["query"])     # id=42&name=alice
puts(parsed["fragment"])  # section1
```

### `urlparse.urljoin(base, url)`

Join a relative URL with a base URL.

**Parameters:**
- `base` - Base URL (Str)
- `url` - Relative or absolute URL (Str)

**Returns:** Joined URL string (Str)

**Behavior:**
- If `url` is absolute (starts with `http://` or `https://`), returns `url` as-is
- If `url` starts with `/`, replaces path of base URL
- Otherwise, joins relative to base URL's path

**Example:**
```quest
use "std/http/urlparse"

let base = "https://example.com/docs/index.html"

# Relative path
let url1 = urlparse.urljoin(base, "tutorial.html")
puts(url1)  # https://example.com/docs/tutorial.html

# Absolute path
let url2 = urlparse.urljoin(base, "/api/users")
puts(url2)  # https://example.com/api/users

# Absolute URL
let url3 = urlparse.urljoin(base, "https://other.com/page")
puts(url3)  # https://other.com/page
```

### `urlparse.parse_qs(query_string)`

Parse query string into a dictionary of arrays (handles duplicate keys).

**Parameters:**
- `query_string` - Query string to parse (Str)

**Returns:** Dictionary mapping keys to arrays of values (Dict)

**Example:**
```quest
use "std/http/urlparse"

# Query with duplicate keys
let query = "color=red&color=blue&size=large"
let params = urlparse.parse_qs(query)

puts(params["color"])  # ["red", "blue"]
puts(params["size"])   # ["large"]

# Access first value
puts(params["color"][0])  # red
```

### `urlparse.parse_qsl(query_string)`

Parse query string into an array of [key, value] pairs (preserves order and duplicates).

**Parameters:**
- `query_string` - Query string to parse (Str)

**Returns:** Array of [key, value] pairs (Array)

**Example:**
```quest
use "std/http/urlparse"

let query = "a=1&b=2&a=3"
let pairs = urlparse.parse_qsl(query)

puts(pairs)  # [["a", "1"], ["b", "2"], ["a", "3"]]

# Iterate over pairs
for pair in pairs
    puts(pair[0] .. " = " .. pair[1])
end
# Output:
# a = 1
# b = 2
# a = 3
```

### `urlparse.urlencode(data)`

Encode dictionary or array of pairs into a query string.

**Parameters:**
- `data` - Dictionary or array of [key, value] pairs

**Returns:** URL-encoded query string (Str)

**Example:**
```quest
use "std/http/urlparse"

# From dictionary
let params = {
    "name": "John Doe",
    "email": "john@example.com",
    "age": "30"
}
let query = urlparse.urlencode(params)
puts(query)  # name=John%20Doe&email=john%40example.com&age=30

# From array of pairs (preserves order)
let pairs = [["a", "1"], ["b", "2"], ["a", "3"]]
let query2 = urlparse.urlencode(pairs)
puts(query2)  # a=1&b=2&a=3
```

### `urlparse.quote(string, safe)`

Percent-encode a string for use in URLs.

**Parameters:**
- `string` - String to encode (Str)
- `safe` - Characters to NOT encode (Str), default is `"/"`

**Returns:** Percent-encoded string (Str)

**Example:**
```quest
use "std/http/urlparse"

let encoded = urlparse.quote("hello world")
puts(encoded)  # hello%20world

# Preserve certain characters
let path = urlparse.quote("/api/users", "/")
puts(path)  # /api/users (/ preserved)

# Encode everything
let encoded2 = urlparse.quote("hello/world", "")
puts(encoded2)  # hello%2Fworld
```

### `urlparse.quote_plus(string)`

Percent-encode a string, converting spaces to `+` (form encoding).

**Parameters:**
- `string` - String to encode (Str)

**Returns:** Percent-encoded string with `+` for spaces (Str)

**Example:**
```quest
use "std/http/urlparse"

let encoded = urlparse.quote_plus("hello world!")
puts(encoded)  # hello+world%21
```

### `urlparse.unquote(string)`

Decode a percent-encoded string.

**Parameters:**
- `string` - Percent-encoded string (Str)

**Returns:** Decoded string (Str)

**Example:**
```quest
use "std/http/urlparse"

let decoded = urlparse.unquote("hello%20world")
puts(decoded)  # hello world

let decoded2 = urlparse.unquote("user%40example.com")
puts(decoded2)  # user@example.com
```

### `urlparse.unquote_plus(string)`

Decode a percent-encoded string, converting `+` to spaces.

**Parameters:**
- `string` - Percent-encoded string (Str)

**Returns:** Decoded string (Str)

**Example:**
```quest
use "std/http/urlparse"

let decoded = urlparse.unquote_plus("hello+world%21")
puts(decoded)  # hello world!
```

## Complete Examples

### Building API URLs

```quest
use "std/http/urlparse"

let base = "https://api.example.com"
let path = "/v1/users"
let params = {
    "search": "John Doe",
    "limit": "10",
    "offset": "0"
}

let query = urlparse.urlencode(params)
let full_url = base .. path .. "?" .. query

puts(full_url)
# https://api.example.com/v1/users?search=John%20Doe&limit=10&offset=0
```

### Parsing and Manipulating URLs

```quest
use "std/http/urlparse"

let url = "https://example.com/api/v1/users?sort=name&order=asc#results"
let parsed = urlparse.urlparse(url)

puts("Hostname: " .. parsed["hostname"])  # example.com
puts("Path: " .. parsed["path"])          # /api/v1/users

# Parse query string
let query_params = urlparse.parse_qs(parsed["query"])
puts("Sort by: " .. query_params["sort"][0])    # name
puts("Order: " .. query_params["order"][0])     # asc
```

### Resolving Relative URLs

```quest
use "std/http/urlparse"

let current_page = "https://example.com/docs/intro.html"

# Resolve relative links
let tutorial = urlparse.urljoin(current_page, "tutorial.html")
puts(tutorial)  # https://example.com/docs/tutorial.html

let api = urlparse.urljoin(current_page, "/api/reference")
puts(api)  # https://example.com/api/reference

let external = urlparse.urljoin(current_page, "https://other.com/")
puts(external)  # https://other.com/
```

### Building Form Data

```quest
use "std/http/urlparse"
use "std/http/client"

let form_data = {
    "username": "alice",
    "password": "secret123",
    "remember": "true"
}

let encoded = urlparse.urlencode(form_data)
let resp = http.post("https://example.com/login")
    .header("Content-Type", "application/x-www-form-urlencoded")
    .body(encoded)
    .send()

if resp.ok()
    puts("Login successful!")
end
```

### Extracting URL Components

```quest
use "std/http/urlparse"

fun extract_api_key(url)
    let parsed = urlparse.urlparse(url)
    let query_params = urlparse.parse_qs(parsed["query"])

    if query_params.contains("api_key")
        query_params["api_key"][0]
    else
        nil
    end
end

let url = "https://api.example.com/data?api_key=abc123&format=json"
let key = extract_api_key(url)
puts("API Key: " .. key)  # abc123
```

### Working with Query Parameters

```quest
use "std/http/urlparse"

# Parse existing query string
let url = "https://shop.com/search?q=laptop&price_max=1000&brand=acme"
let parsed = urlparse.urlparse(url)
let params = urlparse.parse_qs(parsed["query"])

# Modify parameters
params["price_max"] = ["1500"]  # Increase max price
params["sort"] = ["price"]      # Add sort parameter

# Build new query string
let pairs = []
for key in params
    for value in params[key]
        pairs.push([key, value])
    end
end
let new_query = urlparse.urlencode(pairs)

# Construct new URL
let new_url = parsed["scheme"] .. "://" .. parsed["hostname"] .. parsed["path"] .. "?" .. new_query
puts(new_url)
```

## Notes

- `urlparse.urlparse()` handles various URL formats including those with authentication
- `parse_qs()` returns arrays for all values to handle duplicate keys
- `parse_qsl()` preserves order and all duplicates
- `urlencode()` automatically percent-encodes special characters
- `quote()` and `unquote()` are lower-level encoding/decoding
- `quote_plus()` and `unquote_plus()` use `+` for spaces (form encoding)
- `urljoin()` correctly handles absolute URLs, absolute paths, and relative paths
- All encoding follows RFC 3986 standards
