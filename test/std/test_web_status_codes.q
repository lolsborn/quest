# Test HTTP status code constants in std/web

use "std/test"
use "std/web" as web

test.module("std/web HTTP Status Codes")

test.describe("1xx Informational status codes", fun ()
    test.it("defines HTTP_CONTINUE", fun ()
        test.assert_eq(web.HTTP_CONTINUE, 100)
    end)

    test.it("defines HTTP_SWITCHING_PROTOCOLS", fun ()
        test.assert_eq(web.HTTP_SWITCHING_PROTOCOLS, 101)
    end)

    test.it("defines HTTP_PROCESSING", fun ()
        test.assert_eq(web.HTTP_PROCESSING, 102)
    end)

    test.it("defines HTTP_EARLY_HINTS", fun ()
        test.assert_eq(web.HTTP_EARLY_HINTS, 103)
    end)
end)

test.describe("2xx Success status codes", fun ()
    test.it("defines HTTP_OK", fun ()
        test.assert_eq(web.HTTP_OK, 200)
    end)

    test.it("defines HTTP_CREATED", fun ()
        test.assert_eq(web.HTTP_CREATED, 201)
    end)

    test.it("defines HTTP_ACCEPTED", fun ()
        test.assert_eq(web.HTTP_ACCEPTED, 202)
    end)

    test.it("defines HTTP_NO_CONTENT", fun ()
        test.assert_eq(web.HTTP_NO_CONTENT, 204)
    end)

    test.it("defines HTTP_PARTIAL_CONTENT", fun ()
        test.assert_eq(web.HTTP_PARTIAL_CONTENT, 206)
    end)
end)

test.describe("3xx Redirection status codes", fun ()
    test.it("defines HTTP_MOVED_PERMANENTLY", fun ()
        test.assert_eq(web.HTTP_MOVED_PERMANENTLY, 301)
    end)

    test.it("defines HTTP_FOUND", fun ()
        test.assert_eq(web.HTTP_FOUND, 302)
    end)

    test.it("defines HTTP_SEE_OTHER", fun ()
        test.assert_eq(web.HTTP_SEE_OTHER, 303)
    end)

    test.it("defines HTTP_NOT_MODIFIED", fun ()
        test.assert_eq(web.HTTP_NOT_MODIFIED, 304)
    end)

    test.it("defines HTTP_TEMPORARY_REDIRECT", fun ()
        test.assert_eq(web.HTTP_TEMPORARY_REDIRECT, 307)
    end)

    test.it("defines HTTP_PERMANENT_REDIRECT", fun ()
        test.assert_eq(web.HTTP_PERMANENT_REDIRECT, 308)
    end)
end)

test.describe("4xx Client Error status codes", fun ()
    test.it("defines HTTP_BAD_REQUEST", fun ()
        test.assert_eq(web.HTTP_BAD_REQUEST, 400)
    end)

    test.it("defines HTTP_UNAUTHORIZED", fun ()
        test.assert_eq(web.HTTP_UNAUTHORIZED, 401)
    end)

    test.it("defines HTTP_FORBIDDEN", fun ()
        test.assert_eq(web.HTTP_FORBIDDEN, 403)
    end)

    test.it("defines HTTP_NOT_FOUND", fun ()
        test.assert_eq(web.HTTP_NOT_FOUND, 404)
    end)

    test.it("defines HTTP_METHOD_NOT_ALLOWED", fun ()
        test.assert_eq(web.HTTP_METHOD_NOT_ALLOWED, 405)
    end)

    test.it("defines HTTP_CONFLICT", fun ()
        test.assert_eq(web.HTTP_CONFLICT, 409)
    end)

    test.it("defines HTTP_UNPROCESSABLE_ENTITY", fun ()
        test.assert_eq(web.HTTP_UNPROCESSABLE_ENTITY, 422)
    end)

    test.it("defines HTTP_TOO_MANY_REQUESTS", fun ()
        test.assert_eq(web.HTTP_TOO_MANY_REQUESTS, 429)
    end)

    test.it("defines HTTP_IM_A_TEAPOT", fun ()
        test.assert_eq(web.HTTP_IM_A_TEAPOT, 418)
    end)
end)

test.describe("5xx Server Error status codes", fun ()
    test.it("defines HTTP_INTERNAL_SERVER_ERROR", fun ()
        test.assert_eq(web.HTTP_INTERNAL_SERVER_ERROR, 500)
    end)

    test.it("defines HTTP_NOT_IMPLEMENTED", fun ()
        test.assert_eq(web.HTTP_NOT_IMPLEMENTED, 501)
    end)

    test.it("defines HTTP_BAD_GATEWAY", fun ()
        test.assert_eq(web.HTTP_BAD_GATEWAY, 502)
    end)

    test.it("defines HTTP_SERVICE_UNAVAILABLE", fun ()
        test.assert_eq(web.HTTP_SERVICE_UNAVAILABLE, 503)
    end)

    test.it("defines HTTP_GATEWAY_TIMEOUT", fun ()
        test.assert_eq(web.HTTP_GATEWAY_TIMEOUT, 504)
    end)
end)

test.describe("Status code constants in responses", fun ()
    test.it("can be used in response dictionaries", fun ()
        let response = {
            status: web.HTTP_OK,
            headers: {"Content-Type": "application/json"},
            body: "{}"
        }
        test.assert_eq(response["status"], 200)
    end)

    test.it("can be used for error responses", fun ()
        let not_found = {
            status: web.HTTP_NOT_FOUND,
            body: "Not Found"
        }
        test.assert_eq(not_found["status"], 404)
    end)

    test.it("can be used for redirects", fun ()
        let redirect = {
            status: web.HTTP_MOVED_PERMANENTLY,
            headers: {"Location": "/new-url"}
        }
        test.assert_eq(redirect["status"], 301)
    end)
end)
