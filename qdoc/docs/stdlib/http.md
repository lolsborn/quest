# HTTP Client

The HTTP client module provides functionality for making HTTP requests to web servers and APIs.

## Import

```quest
use "std/http/client"
```

## Quick Start

```quest
use "std/http/client"

# Simple GET request
let resp = http.get("https://api.github.com/users/octocat")
if resp.ok()
    let user = resp.json()
    puts("Name: " .. user["name"])
end
```

## Module Functions

### `http.client()`
Create a reusable HTTP client with connection pooling

**Returns:** HttpClient object

**Example:**
```quest
use "std/http/client"
let client = http.client()
client.set_timeout(60)
client.set_header("User-Agent", "QuestApp/1.0")

let resp1 = client.get("https://example.com")
let resp2 = client.get("https://example.com/api")  # Reuses connection
```

### `http.get(url, ...)`
Perform a GET request (convenience function)

**Parameters:**
- `url` - URL to request (Str)
- Named arguments: `headers`, `query`, `timeout`

**Returns:** HttpResponse object

**Example:**
```quest
use "std/http/client"
let resp = http.get("https://api.example.com/users")
puts(resp.status())  # 200
```

### `http.post(url, ...)`
Perform a POST request (convenience function)

**Parameters:**
- `url` - URL to request (Str)
- Named arguments: `body`, `headers`, `query`, `timeout`

**Returns:** HttpResponse object

**Example:**
```quest
use "std/http/client"
let resp = http.post(
    "https://api.example.com/users",
    body: json.stringify({"name": "Alice", "email": "alice@example.com"})
)
```

### `http.put(url, ...)`, `http.delete(url, ...)`, `http.patch(url, ...)`
Perform PUT, DELETE, or PATCH requests

**Parameters:**
- `url` - URL to request (Str)
- Named arguments: `body`, `headers`, `query`, `timeout`

**Returns:** HttpResponse object

### `http.head(url, ...)`, `http.options(url, ...)`
Perform HEAD or OPTIONS requests

**Parameters:**
- `url` - URL to request (Str)
- Named arguments: `headers`, `query`, `timeout`

**Returns:** HttpResponse object

## HttpClient Object

The HttpClient provides connection pooling and reusable configuration.

### Methods

#### `client.get(url, ...)` / `client.post(url, ...)` / etc.
Perform HTTP requests using the client's default settings

**Parameters:**
- `url` - URL to request (Str)
- Named arguments: `body`, `headers`, `query`, `timeout`

**Returns:** HttpResponse object

**Example:**
```quest
use "std/http/client"
let client = http.client()
let resp = client.get("https://example.com")
```

#### `client.request(method, url)`
Create a custom request builder

**Parameters:**
- `method` - HTTP method (Str): "GET", "POST", "PUT", "DELETE", etc.
- `url` - URL to request (Str)

**Returns:** HttpRequest builder object

**Example:**
```quest
use "std/http/client"
let client = http.client()
let req = client.request("PATCH", "https://api.example.com/resource/123")
let resp = req
    .header("Authorization", "Bearer token123")
    .json({"status": "active"})
    .send()
```

#### `client.set_timeout(seconds)`
Set default timeout for all requests made with this client

**Parameters:**
- `seconds` - Timeout in seconds (Int)

**Returns:** Nil

**Example:**
```quest
let client = http.client()
client.set_timeout(120)  # 2 minute timeout
```

#### `client.timeout()`
Get current default timeout setting

**Returns:** Timeout in seconds (Int)

#### `client.set_header(name, value)`
Set a default header for all requests made with this client

**Parameters:**
- `name` - Header name (Str)
- `value` - Header value (Str)

**Returns:** Nil

**Example:**
```quest
let client = http.client()
client.set_header("User-Agent", "MyApp/1.0")
client.set_header("Accept", "application/json")
```

#### `client.headers()`
Get all default headers

**Returns:** Dictionary of headers (Dict)

## HttpRequest Builder

The HttpRequest builder allows you to construct complex requests with a fluent API.

### Methods

All methods return `self` for chaining, except `send()` which executes the request.

#### `request.header(name, value)`
Set a single request header

**Parameters:**
- `name` - Header name (Str)
- `value` - Header value (Str)

**Returns:** HttpRequest (for chaining)

#### `request.headers(dict)`
Set multiple request headers

**Parameters:**
- `dict` - Dictionary of header name/value pairs (Dict)

**Returns:** HttpRequest (for chaining)

#### `request.query(key, value)`
Add a single query parameter

**Parameters:**
- `key` - Query parameter name (Str)
- `value` - Query parameter value (Str)

**Returns:** HttpRequest (for chaining)

#### `request.queries(dict)`
Add multiple query parameters

**Parameters:**
- `dict` - Dictionary of query parameters (Dict)

**Returns:** HttpRequest (for chaining)

#### `request.body(data)`
Set raw request body

**Parameters:**
- `data` - Request body (Str or Bytes)

**Returns:** HttpRequest (for chaining)

#### `request.json(data)`
Set request body as JSON (automatically sets Content-Type header)

**Parameters:**
- `data` - Data to serialize as JSON (Dict or Array)

**Returns:** HttpRequest (for chaining)

#### `request.form(dict)`
Set request body as form-urlencoded (automatically sets Content-Type header)

**Parameters:**
- `dict` - Form data dictionary (Dict)

**Returns:** HttpRequest (for chaining)

#### `request.text(string)`
Set request body as plain text

**Parameters:**
- `string` - Text content (Str)

**Returns:** HttpRequest (for chaining)

#### `request.bytes(bytes)`
Set request body as raw bytes

**Parameters:**
- `bytes` - Binary data (Bytes)

**Returns:** HttpRequest (for chaining)

#### `request.timeout(seconds)`
Set timeout for this specific request

**Parameters:**
- `seconds` - Timeout in seconds (Int)

**Returns:** HttpRequest (for chaining)

#### `request.send()`
Execute the HTTP request

**Returns:** HttpResponse object

**Example:**
```quest
use "std/http/client"
use "std/encoding/json"

let resp = http.client()
    .request("POST", "https://api.example.com/users")
    .header("Authorization", "Bearer token123")
    .header("Content-Type", "application/json")
    .json({"name": "Bob", "email": "bob@example.com"})
    .timeout(30)
    .send()

if resp.ok()
    puts("User created!")
end
```

## HttpResponse Object

The HttpResponse object represents the response from an HTTP request.

### Status Methods

#### `response.status()`
Get HTTP status code

**Returns:** Status code (Int) - e.g., 200, 404, 500

#### `response.ok()`
Check if status code indicates success (200-299)

**Returns:** True if successful (Bool)

#### `response.is_success()`
Check if status is 2xx (same as `ok()`)

**Returns:** True if successful (Bool)

#### `response.is_redirect()`
Check if status is 3xx

**Returns:** True if redirect (Bool)

#### `response.is_client_error()`
Check if status is 4xx

**Returns:** True if client error (Bool)

#### `response.is_server_error()`
Check if status is 5xx

**Returns:** True if server error (Bool)

#### `response.is_informational()`
Check if status is 1xx

**Returns:** True if informational (Bool)

### Header Methods

#### `response.header(name)`
Get value of a specific response header (case-insensitive)

**Parameters:**
- `name` - Header name (Str)

**Returns:** Header value or nil (Str or Nil)

**Example:**
```quest
let content_type = resp.header("Content-Type")
puts("Content-Type: " .. content_type)
```

#### `response.headers()`
Get all response headers as a dictionary

**Returns:** Dictionary of headers (Dict)

#### `response.has_header(name)`
Check if response has a specific header

**Parameters:**
- `name` - Header name (Str)

**Returns:** True if header exists (Bool)

#### `response.content_type()`
Get Content-Type header value

**Returns:** Content type or nil (Str or Nil)

#### `response.content_length()`
Get Content-Length header value

**Returns:** Content length in bytes or nil (Int or Nil)

### Body Methods

#### `response.text()`
Get response body as UTF-8 string (cached after first call)

**Returns:** Response body text (Str)

**Example:**
```quest
let resp = http.get("https://example.com")
let html = resp.text()
puts(html)
```

#### `response.json()`
Parse response body as JSON (cached after first call)

**Returns:** Parsed JSON data (Dict or Array)

**Example:**
```quest
let resp = http.get("https://api.example.com/users")
let users = resp.json()
for user in users
    puts(user["name"])
end
```

#### `response.bytes()`
Get response body as raw bytes

**Returns:** Response body (Bytes)

#### `response.body()`
Alias for `bytes()` - get response body as raw bytes

**Returns:** Response body (Bytes)

### Content Type Detection

#### `response.is_json()`
Check if content type is JSON

**Returns:** True if JSON (Bool)

#### `response.is_html()`
Check if content type is HTML

**Returns:** True if HTML (Bool)

#### `response.is_text()`
Check if content type is text

**Returns:** True if text (Bool)

### Other Methods

#### `response.url()`
Get final URL (after redirects)

**Returns:** URL string (Str)

#### `response.cookie(name)`
Get value of a specific cookie

**Parameters:**
- `name` - Cookie name (Str)

**Returns:** Cookie value or nil (Str or Nil)

#### `response.cookies()`
Get all cookies as a dictionary

**Returns:** Dictionary of cookies (Dict)

## Common Use Cases

### Making GET Requests

```quest
use "std/http/client"

# Simple GET
let resp = http.get("https://api.github.com/users/octocat")
if resp.ok()
    let user = resp.json()
    puts("Name: " .. user["name"])
    puts("Bio: " .. user["bio"])
end

# GET with query parameters
let client = http.client()
let resp = client.get(
    "https://api.example.com/search",
    query: {"q": "Quest language", "limit": "10"}
)
```

### POST Requests with JSON

```quest
use "std/http/client"
use "std/encoding/json"

let data = {
    "name": "Alice",
    "email": "alice@example.com",
    "age": 30
}

let resp = http.post(
    "https://api.example.com/users",
    body: json.stringify(data),
    headers: {"Content-Type": "application/json"}
)

if resp.ok()
    puts("User created!")
    let created_user = resp.json()
    puts("ID: " .. created_user["id"])
end
```

### Using Request Builder

```quest
use "std/http/client"

let resp = http.client()
    .request("POST", "https://api.example.com/data")
    .header("Authorization", "Bearer my-token")
    .header("Accept", "application/json")
    .json({"key": "value"})
    .timeout(60)
    .send()

puts("Status: " .. resp.status())
```

### Error Handling

```quest
use "std/http/client"

let resp = http.get("https://api.example.com/data")

if resp.is_client_error()
    puts("Client error: " .. resp.status())
elif resp.is_server_error()
    puts("Server error: " .. resp.status())
elif resp.ok()
    puts("Success!")
    let data = resp.json()
end
```

### Working with Headers

```quest
use "std/http/client"

let client = http.client()
client.set_header("User-Agent", "MyApp/1.0")
client.set_header("Accept-Language", "en-US")

let resp = client.get("https://example.com")

# Check response headers
if resp.has_header("Last-Modified")
    puts("Last modified: " .. resp.header("Last-Modified"))
end

puts("Content type: " .. resp.content_type())
```

### Downloading Files

```quest
use "std/http/client"
use "std/io"

let resp = http.get("https://example.com/file.pdf")
if resp.ok()
    let data = resp.bytes()
    io.write("downloaded.pdf", data)
    puts("File downloaded!")
end
```

### Reusing Connections

```quest
use "std/http/client"

# Create a client to reuse connections
let client = http.client()
client.set_timeout(30)
client.set_header("Authorization", "Bearer my-token")

# Make multiple requests - connections are pooled
let resp1 = client.get("https://api.example.com/users")
let resp2 = client.get("https://api.example.com/posts")
let resp3 = client.get("https://api.example.com/comments")

# All three requests benefit from connection pooling
```

### API Integration Example

```quest
use "std/http/client"
use "std/encoding/json"

# GitHub API client
let github = http.client()
github.set_header("Accept", "application/vnd.github.v3+json")
github.set_header("User-Agent", "QuestApp")

fun get_user(username)
    let url = "https://api.github.com/users/" .. username
    let resp = github.get(url)

    if resp.ok()
        resp.json()
    else
        raise "Failed to fetch user: " .. resp.status()
    end
end

fun get_repos(username)
    let url = "https://api.github.com/users/" .. username .. "/repos"
    let resp = github.get(url)

    if resp.ok()
        resp.json()
    else
        raise "Failed to fetch repos: " .. resp.status()
    end
end

# Usage
let user = get_user("octocat")
puts("User: " .. user["name"])

let repos = get_repos("octocat")
puts("Repositories: " .. repos.len())
```

## Features

- **Connection Pooling**: Automatic connection reuse when using HttpClient
- **Automatic Redirects**: Follows HTTP redirects by default
- **Cookie Handling**: Automatic cookie storage and sending
- **Gzip Compression**: Automatic gzip decompression
- **JSON Support**: Built-in JSON encoding/decoding
- **UTF-8 Text**: Automatic UTF-8 text encoding/decoding
- **Binary Data**: Full support for binary request/response bodies
- **Case-Insensitive Headers**: Header names are case-insensitive
- **Response Caching**: Response body is cached after first access

## Notes

- Default timeout is 30 seconds
- Responses automatically follow redirects
- Connection pooling is automatic when reusing an HttpClient
- Response bodies are loaded into memory (not streamed)
- Multiple calls to `text()` or `json()` return the cached result
- Header names are case-insensitive
- Query parameters are automatically URL-encoded
- JSON requests automatically set `Content-Type: application/json`
