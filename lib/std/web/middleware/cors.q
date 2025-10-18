# std/web/middleware/cors.q
# CORS (Cross-Origin Resource Sharing) middleware for Quest web server (QEP-061)
#
# Adds CORS headers to all responses, enabling cross-origin requests from browsers.

# Create CORS middleware
#
# Arguments (all optional, via **kwargs):
#   origins: Array of allowed origins (default: ["*"])
#   methods: Array of allowed methods (default: ["GET", "POST", "PUT", "DELETE"])
#   headers: Array of allowed headers (default: ["Content-Type", "Authorization"])
#   credentials: Allow credentials in cross-origin requests (default: false)
#
# Returns:
#   Dict with {after: Function}
#
# Examples:
#   let cors = cors.create_cors(origins: ["https://example.com"])
#   web.after(cors.after)
#
#   # Allow all origins (default)
#   let cors = cors.create_cors()
#   web.after(cors.after)
#
# Or more simply:
#   web.middleware(middleware_from_elsewhere)
pub fun create_cors(**kwargs)
    let origins = kwargs["origins"] or ["*"]
    let methods = kwargs["methods"] or ["GET", "POST", "PUT", "DELETE"]
    let headers = kwargs["headers"] or ["Content-Type", "Authorization"]
    let credentials = kwargs["credentials"] or false

    return {
        after: fun (req, resp)
            if resp["headers"] == nil
                resp["headers"] = {}
            end

            # Add CORS headers
            if origins.contains("*")
                resp["headers"]["Access-Control-Allow-Origin"] = "*"
            else
                let origin = req["headers"]["origin"] if req["headers"] != nil
                if origin != nil and origins.contains(origin)
                    resp["headers"]["Access-Control-Allow-Origin"] = origin
                end
            end

            resp["headers"]["Access-Control-Allow-Methods"] = methods.join(", ")
            resp["headers"]["Access-Control-Allow-Headers"] = headers.join(", ")

            if credentials
                resp["headers"]["Access-Control-Allow-Credentials"] = "true"
            end

            return resp
        end
    }
end

# Convenience: Create CORS middleware allowing all origins
pub fun allow_all()
    return create_cors(origins: ["*"])
end

# Convenience: Create CORS middleware for specific origins
pub fun allow_origins(origins)
    return create_cors(origins: origins)
end
