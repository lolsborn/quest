# std/web/middleware/security.q
# Security headers middleware for Quest web server (QEP-061)
#
# Adds common security headers to all responses to protect against XSS, clickjacking, MIME type sniffing, etc.

# Create security headers middleware
#
# Adds these headers to all responses:
#   - X-Content-Type-Options: nosniff (prevents MIME type sniffing)
#   - X-Frame-Options: DENY (prevents clickjacking)
#   - X-XSS-Protection: 1; mode=block (enables XSS protection in older browsers)
#   - Referrer-Policy: strict-origin-when-cross-origin (controls referrer information)
#
# Returns:
#   Dict with {after: Function}
#
# Example:
#   let sec = security.security_headers()
#   web.after(sec.after)
pub fun security_headers()
    return {
        after: fun (req, resp)
            if resp["headers"] == nil
                resp["headers"] = {}
            end

            resp["headers"]["X-Content-Type-Options"] = "nosniff"
            resp["headers"]["X-Frame-Options"] = "DENY"
            resp["headers"]["X-XSS-Protection"] = "1; mode=block"
            resp["headers"]["Referrer-Policy"] = "strict-origin-when-cross-origin"

            return resp
        end
    }
end

# Convenience function - same as security_headers()
pub fun create_security_middleware()
    return security_headers()
end
