"""
#URL encoding and decoding (percent encoding) for web applications.

This module provides functions to encode and decode strings for use in URLs,
following RFC 3986 standards for percent encoding.

**Example:**
```quest
use "std/encoding/url"

# Encode query parameters
let params = url.encode("Hello, World!")
puts(params)  # "Hello%2C%20World%21"

# Decode URL-encoded string
let decoded = url.decode("Hello%20World")
puts(decoded)  # "Hello World"

# Encode for different URL components
let path = url.encode_path("/api/users/John Doe")
let query = url.encode_query("name=John Doe&age=30")
```
"""

%fun encode(text)
"""
## Encode string using URL percent encoding (application/x-www-form-urlencoded).

Encodes all characters except alphanumerics and `-_.~`. Spaces are encoded as `%20`.
This is suitable for encoding query parameter values.

**Parameters:**
- `text` (**Str**) - Text to encode

**Returns:** **Str** - URL-encoded string

**Example:**
```quest
let encoded = url.encode("Hello, World!")
puts(encoded)  # "Hello%2C%20World%21"

let query = "search=" .. url.encode("café au lait")
puts(query)  # "search=caf%C3%A9%20au%20lait"
```
"""

%fun encode_component(text)
"""
## Encode string for use as URL component (stricter than encode).

Encodes all characters except alphanumerics and `-_.~!*'()`.
This is the RFC 3986 "unreserved" character set plus sub-delimiters.

**Parameters:**
- `text` (**Str**) - Text to encode

**Returns:** **Str** - URL-encoded component

**Example:**
```quest
let encoded = url.encode_component("hello world")
puts(encoded)  # "hello%20world"
```
"""

%fun encode_path(path)
"""
## Encode string for use in URL path segment.

Encodes all characters except alphanumerics, `-_.~`, and path separators `/`.
This preserves path structure while encoding special characters.

**Parameters:**
- `path` (**Str**) - Path to encode

**Returns:** **Str** - URL-encoded path

**Example:**
```quest
let path = url.encode_path("/api/users/John Doe")
puts(path)  # "/api/users/John%20Doe"
```
"""

%fun encode_query(query)
"""
## Encode string for use in URL query string.

Encodes all characters except alphanumerics, `-_.~`, and query delimiters `=&`.
This preserves query string structure while encoding values.

**Parameters:**
- `query` (**Str**) - Query string to encode

**Returns:** **Str** - URL-encoded query string

**Example:**
```quest
let query = url.encode_query("name=John Doe&age=30")
puts(query)  # "name=John%20Doe&age=30"
```
"""

%fun decode(text)
"""
## Decode URL percent-encoded string.

Decodes percent-encoded characters (%XX) back to their original form.
Also decodes `+` as space (for form-encoded data).

**Parameters:**
- `text` (**Str**) - URL-encoded text to decode

**Returns:** **Str** - Decoded string

**Raises:** Error if string contains invalid percent encoding

**Example:**
```quest
let decoded = url.decode("Hello%20World")
puts(decoded)  # "Hello World"

let decoded2 = url.decode("Hello+World")
puts(decoded2)  # "Hello World"

let decoded3 = url.decode("caf%C3%A9")
puts(decoded3)  # "café"
```
"""

%fun decode_component(text)
"""
## Decode URL component (does not treat + as space).

Like decode() but does not convert `+` to space. Use this for decoding
URL paths and other components where `+` is a literal plus sign.

**Parameters:**
- `text` (**Str**) - URL-encoded component to decode

**Returns:** **Str** - Decoded string

**Example:**
```quest
let decoded = url.decode_component("a%2Bb%3Dc")
puts(decoded)  # "a+b=c"
```
"""

%fun build_query(params)
"""
## Build URL query string from dictionary.

Encodes keys and values and joins them with `&`.

**Parameters:**
- `params` (**Dict**) - Dictionary of query parameters

**Returns:** **Str** - Encoded query string (without leading `?`)

**Example:**
```quest
let params = {
    "name": "John Doe",
    "age": "30",
    "city": "New York"
}
let query = url.build_query(params)
puts(query)  # "name=John%20Doe&age=30&city=New%20York"

let full_url = "https://api.example.com/search?" .. query
```
"""

%fun parse_query(query)
"""
## Parse URL query string into dictionary.

Decodes percent-encoded keys and values and splits by `&` and `=`.

**Parameters:**
- `query` (**Str**) - Query string (with or without leading `?`)

**Returns:** **Dict** - Dictionary of decoded query parameters

**Example:**
```quest
let params = url.parse_query("name=John%20Doe&age=30")
puts(params["name"])  # "John Doe"
puts(params["age"])   # "30"

# Works with leading ?
let params2 = url.parse_query("?search=hello&limit=10")
```
"""
