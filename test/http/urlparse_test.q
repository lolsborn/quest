# URL Parsing Module Tests
# Tests std/http/urlparse module (Python urllib.parse inspired)

use "std/test" { module, describe, it, assert_eq, assert_nil, assert_type, assert }
use "std/http/urlparse" as urlparse

module("HTTP URL Parsing")

describe("URL parsing", fun ()
  it("parses complete URL with all components", fun ()
    let url = urlparse.urlparse("https://user:pass@example.com:8080/path/to/page?key=value#section")

    assert_eq(url.get("scheme"), "https", "Scheme should be https")
    assert_eq(url.get("netloc"), "user:pass@example.com:8080", "Netloc should include user, pass, host, port")
    assert_eq(url.get("hostname").str(), "example.com", "Hostname should be extracted")
    assert_eq(url.get("port").str(), "8080", "Port should be 8080")
    assert_eq(url.get("path"), "/path/to/page", "Path should be parsed")
    assert_eq(url.get("query"), "key=value", "Query should be parsed")
    assert_eq(url.get("fragment"), "section", "Fragment should be parsed")
    assert_eq(url.get("username").str(), "user", "Username should be extracted")
  end)

  it("parses simple URL without port or credentials", fun ()
    let url = urlparse.urlparse("http://example.com/page")

    assert_eq(url.get("scheme"), "http", "Scheme should be http")
    assert_eq(url.get("hostname").str(), "example.com", "Hostname parsed")
    assert_nil(url.get("port"), "Port should be nil")
    assert_eq(url.get("path"), "/page", "Path parsed")
  end)

  it("parses URL with query string", fun ()
    let url = urlparse.urlparse("https://api.example.com/search?q=test&limit=10")

    assert_eq(url.get("path"), "/search", "Path parsed")
    assert_eq(url.get("query"), "q=test&limit=10", "Query string parsed")
  end)
end)

describe("Query string parsing", fun ()
  it("parses query string into dict of arrays with parse_qs", fun ()
    let qs = "name=Alice&age=30&city=NYC"
    let params = urlparse.parse_qs(qs)

    assert_eq(params.get("name").str(), "[Alice]", "Name should be array with Alice")
    assert_eq(params.get("age").str(), "[30]", "Age should be array with 30")
    assert_eq(params.get("city").str(), "[NYC]", "City should be array with NYC")
  end)

  it("parses query string into array of pairs with parse_qsl", fun ()
    let qs = "a=1&b=2&c=3"
    let pairs = urlparse.parse_qsl(qs)

    assert_eq(pairs.len(), 3, "Should have 3 pairs")
    assert_eq(pairs[0].str(), "[a, 1]", "First pair should be [a, 1]")
    assert_eq(pairs[1].str(), "[b, 2]", "Second pair should be [b, 2]")
    assert_eq(pairs[2].str(), "[c, 3]", "Third pair should be [c, 3]")
  end)

  it("handles URL-encoded values in query string", fun ()
    let qs = "message=Hello%20World&special=a%2Bb"
    let params = urlparse.parse_qs(qs)

    assert_eq(params.get("message").str(), "[Hello World]", "Should decode %20 to space")
    assert_eq(params.get("special").str(), "[a+b]", "Should decode %2B to +")
  end)
end)

describe("URL encoding", fun ()
  it("encodes dict to query string with urlencode", fun ()
    let data = {"name": "Alice", "age": "30"}
    let qs = urlparse.urlencode(data)

    # Dict ordering may vary, so check contains
    assert(qs.contains("name=Alice"), "Should contain name=Alice")
    assert(qs.contains("age=30"), "Should contain age=30")
    assert(qs.contains("&"), "Should have & separator")
  end)

  it("encodes array of pairs to query string with urlencode", fun ()
    let pairs = [["key1", "value1"], ["key2", "value2"]]
    let qs = urlparse.urlencode(pairs)

    assert(qs.contains("key1=value1"), "Should contain first pair")
    assert(qs.contains("key2=value2"), "Should contain second pair")
  end)

  it("encodes special characters in urlencode", fun ()
    let data = {"msg": "hello world", "op": "a+b"}
    let qs = urlparse.urlencode(data)

    assert(qs.contains("hello%20world") or qs.contains("hello+world"), "Should encode space")
    assert(qs.contains("a%2Bb"), "Should encode +")
  end)
end)

describe("URL quote/unquote", fun ()
  it("quotes special characters with quote", fun ()
    let text = "Hello World!"
    let quoted = urlparse.quote(text, "")

    assert_eq(quoted, "Hello%20World%21", "Should encode space and !")
  end)

  it("preserves safe characters in quote", fun ()
    let text = "/path/to/file"
    let quoted = urlparse.quote(text, "/")

    assert_eq(quoted, "/path/to/file", "Should not encode / when it's safe")
  end)

  it("unquotes percent-encoded strings with unquote", fun ()
    let encoded = "Hello%20World%21"
    let decoded = urlparse.unquote(encoded)

    assert_eq(decoded, "Hello World!", "Should decode %20 and %21")
  end)

  it("quote_plus converts spaces to +", fun ()
    let text = "hello world"
    let quoted = urlparse.quote_plus(text)

    assert_eq(quoted, "hello+world", "Should use + for spaces")
  end)

  it("unquote_plus converts + to spaces", fun ()
    let encoded = "hello+world"
    let decoded = urlparse.unquote_plus(encoded)

    assert_eq(decoded, "hello world", "Should decode + to space")
  end)
end)

describe("URL joining", fun ()
  it("joins relative path to base URL", fun ()
    let base = "https://example.com/docs/guide.html"
    let relative = "intro.html"
    let result = urlparse.urljoin(base, relative)

    assert_eq(result, "https://example.com/docs/intro.html", "Should join relative path")
  end)

  it("joins absolute path to base URL", fun ()
    let base = "https://example.com/docs/guide.html"
    let absolute = "/api/users"
    let result = urlparse.urljoin(base, absolute)

    assert_eq(result, "https://example.com/api/users", "Should replace path with absolute")
  end)

  it("returns absolute URL unchanged", fun ()
    let base = "https://example.com/docs/guide.html"
    let other = "https://other.com/page"
    let result = urlparse.urljoin(base, other)

    assert_eq(result, "https://other.com/page", "Should return absolute URL unchanged")
  end)

  it("preserves scheme from base URL", fun ()
    let base = "https://secure.example.com/page"
    let relative = "other.html"
    let result = urlparse.urljoin(base, relative)

    # Check that result contains https (since startswith might not exist)
    assert(result.index_of("https://") == 0, "Should preserve https scheme")
  end)
end)
