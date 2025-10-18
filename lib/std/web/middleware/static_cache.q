# std/web/middleware/static_cache.q
# Static asset caching middleware for Quest web server (QEP-061)
#
# Adds cache headers to static assets (CSS, JS, images, fonts) to enable browser caching.

# Create static cache middleware
#
# Arguments:
#   max_age: Cache duration in seconds (default: 3600 = 1 hour)
#   extensions: Array of file extensions to cache (default: common static extensions)
#
# Returns:
#   Dict with {after: Function}
#
# Example:
#   let cache = static_cache.static_cache(max_age: 86400)  # Cache for 1 day
#   web.after(cache.after)
pub fun static_cache(max_age = 3600, extensions = nil)
    if extensions == nil
        extensions = [".css", ".js", ".png", ".jpg", ".jpeg", ".gif", ".svg", ".ico", ".woff", ".woff2", ".ttf", ".otf", ".eot"]
    end

    return {
        after: fun (req, resp)
            let path = req["path"] or ""

            # Check if any extension matches
            let should_cache = false
            let i = 0
            while i < extensions.len()
                let ext = extensions[i]
                if path.endswith(ext)
                    should_cache = true
                    i = extensions.len()  # Break
                end
                i = i + 1
            end

            if should_cache
                if resp["headers"] == nil
                    resp["headers"] = {}
                end
                resp["headers"]["Cache-Control"] = "public, max-age=" .. max_age.str()
            end

            return resp
        end
    }
end

# Convenience: Cache for 1 day
pub fun cache_one_day()
    return static_cache(max_age: 86400)
end

# Convenience: Cache for 1 week
pub fun cache_one_week()
    return static_cache(max_age: 604800)
end

# Convenience: No cache (cache-busting for development)
pub fun no_cache()
    return static_cache(max_age: 0)
end
