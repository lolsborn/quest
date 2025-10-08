# URL Parsing Module Tests
# Tests std/http/urlparse module (Python urllib.parse inspired)

use "std/test" as test
use "std/http/urlparse" as urlparse

test.module("HTTP URL Parsing")

test.describe("URL parsing", fun ()
    test.it("parses complete URL with all components", fun ()
        let url = urlparse.urlparse("https://user:pass@example.com:8080/path/to/page?key=value#section")

        test.assert_eq(url.get("scheme"), "https", "Scheme should be https")
        test.assert_eq(url.get("netloc"), "user:pass@example.com:8080", "Netloc should include user, pass, host, port")
        test.assert_eq(url.get("hostname").str(), "example.com", "Hostname should be extracted")
        test.assert_eq(url.get("port").str(), "8080", "Port should be 8080")
        test.assert_eq(url.get("path"), "/path/to/page", "Path should be parsed")
        test.assert_eq(url.get("query"), "key=value", "Query should be parsed")
        test.assert_eq(url.get("fragment"), "section", "Fragment should be parsed")
        test.assert_eq(url.get("username").str(), "user", "Username should be extracted")
    end)

    test.it("parses simple URL without port or credentials", fun ()
        let url = urlparse.urlparse("http://example.com/page")

        test.assert_eq(url.get("scheme"), "http", "Scheme should be http")
        test.assert_eq(url.get("hostname").str(), "example.com", "Hostname parsed")
        test.assert_nil(url.get("port"), "Port should be nil")
        test.assert_eq(url.get("path"), "/page", "Path parsed")
    end)

    test.it("parses URL with query string", fun ()
        let url = urlparse.urlparse("https://api.example.com/search?q=test&limit=10")

        test.assert_eq(url.get("path"), "/search", "Path parsed")
        test.assert_eq(url.get("query"), "q=test&limit=10", "Query string parsed")
    end)
end)

test.describe("Query string parsing", fun ()
    test.it("parses query string into dict of arrays with parse_qs", fun ()
        let qs = "name=Alice&age=30&city=NYC"
        let params = urlparse.parse_qs(qs)

        test.assert_eq(params.get("name").str(), "[Alice]", "Name should be array with Alice")
        test.assert_eq(params.get("age").str(), "[30]", "Age should be array with 30")
        test.assert_eq(params.get("city").str(), "[NYC]", "City should be array with NYC")
    end)

    test.it("parses query string into array of pairs with parse_qsl", fun ()
        let qs = "a=1&b=2&c=3"
        let pairs = urlparse.parse_qsl(qs)

        test.assert_eq(pairs.len(), 3, "Should have 3 pairs")
        test.assert_eq(pairs[0].str(), "[a, 1]", "First pair should be [a, 1]")
        test.assert_eq(pairs[1].str(), "[b, 2]", "Second pair should be [b, 2]")
        test.assert_eq(pairs[2].str(), "[c, 3]", "Third pair should be [c, 3]")
    end)

    test.it("handles URL-encoded values in query string", fun ()
        let qs = "message=Hello%20World&special=a%2Bb"
        let params = urlparse.parse_qs(qs)

        test.assert_eq(params.get("message").str(), "[Hello World]", "Should decode %20 to space")
        test.assert_eq(params.get("special").str(), "[a+b]", "Should decode %2B to +")
    end)
end)

test.describe("URL encoding", fun ()
    test.it("encodes dict to query string with urlencode", fun ()
        let data = {"name": "Alice", "age": "30"}
        let qs = urlparse.urlencode(data)

        # Dict ordering may vary, so check contains
        test.assert(qs.contains("name=Alice"), "Should contain name=Alice")
        test.assert(qs.contains("age=30"), "Should contain age=30")
        test.assert(qs.contains("&"), "Should have & separator")
    end)

    test.it("encodes array of pairs to query string with urlencode", fun ()
        let pairs = [["key1", "value1"], ["key2", "value2"]]
        let qs = urlparse.urlencode(pairs)

        test.assert(qs.contains("key1=value1"), "Should contain first pair")
        test.assert(qs.contains("key2=value2"), "Should contain second pair")
    end)

    test.it("encodes special characters in urlencode", fun ()
        let data = {"msg": "hello world", "op": "a+b"}
        let qs = urlparse.urlencode(data)

        test.assert(qs.contains("hello%20world") or qs.contains("hello+world"), "Should encode space")
        test.assert(qs.contains("a%2Bb"), "Should encode +")
    end)
end)

test.describe("URL quote/unquote", fun ()
    test.it("quotes special characters with quote", fun ()
        let text = "Hello World!"
        let quoted = urlparse.quote(text, "")

        test.assert_eq(quoted, "Hello%20World%21", "Should encode space and !")
    end)

    test.it("preserves safe characters in quote", fun ()
        let text = "/path/to/file"
        let quoted = urlparse.quote(text, "/")

        test.assert_eq(quoted, "/path/to/file", "Should not encode / when it's safe")
    end)

    test.it("unquotes percent-encoded strings with unquote", fun ()
        let encoded = "Hello%20World%21"
        let decoded = urlparse.unquote(encoded)

        test.assert_eq(decoded, "Hello World!", "Should decode %20 and %21")
    end)

    test.it("quote_plus converts spaces to +", fun ()
        let text = "hello world"
        let quoted = urlparse.quote_plus(text)

        test.assert_eq(quoted, "hello+world", "Should use + for spaces")
    end)

    test.it("unquote_plus converts + to spaces", fun ()
        let encoded = "hello+world"
        let decoded = urlparse.unquote_plus(encoded)

        test.assert_eq(decoded, "hello world", "Should decode + to space")
    end)
end)

test.describe("URL joining", fun ()
    test.it("joins relative path to base URL", fun ()
        let base = "https://example.com/docs/guide.html"
        let relative = "intro.html"
        let result = urlparse.urljoin(base, relative)

        test.assert_eq(result, "https://example.com/docs/intro.html", "Should join relative path")
    end)

    test.it("joins absolute path to base URL", fun ()
        let base = "https://example.com/docs/guide.html"
        let absolute = "/api/users"
        let result = urlparse.urljoin(base, absolute)

        test.assert_eq(result, "https://example.com/api/users", "Should replace path with absolute")
    end)

    test.it("returns absolute URL unchanged", fun ()
        let base = "https://example.com/docs/guide.html"
        let other = "https://other.com/page"
        let result = urlparse.urljoin(base, other)

        test.assert_eq(result, "https://other.com/page", "Should return absolute URL unchanged")
    end)

    test.it("preserves scheme from base URL", fun ()
        let base = "https://secure.example.com/page"
        let relative = "other.html"
        let result = urlparse.urljoin(base, relative)

        # Check that result contains https (since startswith might not exist)
        test.assert(result.index_of("https://") == 0, "Should preserve https scheme")
    end)
end)
