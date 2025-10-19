# Router Module - Simplified HTTP routing with route decorators
# Provides a clean API for registering route handlers and dispatching requests

# Global route registry - stores all registered routes
let ROUTES = []

# Route entry - internal structure for storing route information
type RouteEntry
    pub path
    pub method
    pub handler
    pub match_type

    fun self.new(path, method, handler, match_type)
        let entry = RouteEntry._new()
        entry.path = path
        entry.method = method
        entry.handler = handler
        entry.match_type = match_type
        return entry
    end

    # Check if this route matches the request
    fun matches(req_path, req_method)
        # Check HTTP method match (if method specified)
        if self.method != nil and self.method != req_method
            return false
        end

        # Check path match based on match_type
        if self.match_type == "exact"
            return req_path == self.path
        elif self.match_type == "prefix"
            return req_path.starts_with(self.path)
        end

        return false
    end
end

# Route decorator types for common HTTP methods
# Use named arguments: @Get(path: "/api/users")
# Or with prefix matching: @Get(path: "/posts/", match_type: "prefix")
pub type Get
    func            # Decorated function (set automatically by decorator protocol)
    path            # Required: route path
    match_type      # Optional: "exact" (default) or "prefix"

    # QEP-003 Phase 2: Decoration-time hook for auto-registration
    fun _decorate(original_func)
        # Auto-register this route when the decorator is applied
        let m_type = self.match_type
        if m_type == nil
            m_type = "exact"
        end
        let entry = RouteEntry.new(self.path, "GET", self, m_type)
        ROUTES.push(entry)

        # Return the decorator instance (self)
        return self
    end

    fun _call(*args, **kwargs)
        return self.func(*args, **kwargs)
    end

    fun _name()
        return self.func._name()
    end

    fun _doc()
        return self.func._doc()
    end

    fun _id()
        return self.func._id()
    end
end

pub type Post
    func            # Decorated function (set automatically by decorator protocol)
    path            # Required: route path
    match_type      # Optional: "exact" (default) or "prefix"

    # QEP-003 Phase 2: Decoration-time hook for auto-registration
    fun _decorate(original_func)
        # Auto-register this route when the decorator is applied
        let m_type = self.match_type
        if m_type == nil
            m_type = "exact"
        end
        let entry = RouteEntry.new(self.path, "POST", self, m_type)
        ROUTES.push(entry)

        # Return the decorator instance (self)
        return self
    end

    fun _call(*args, **kwargs)
        return self.func(*args, **kwargs)
    end

    fun _name()
        return self.func._name()
    end

    fun _doc()
        return self.func._doc()
    end

    fun _id()
        return self.func._id()
    end
end

# Register a decorated handler function in the global route registry
pub fun register_handler(decorated_func)
    # Extract route information from the decorated function
    let path = nil
    let method = nil
    let match_type = "exact"
    let handler = decorated_func

    # Check if it's a Get decorator
    if decorated_func._type() == "Get"
        path = decorated_func.path
        method = "GET"
        if decorated_func.match_type != nil
            match_type = decorated_func.match_type
        end
    elif decorated_func._type() == "Post"
        path = decorated_func.path
        method = "POST"
        if decorated_func.match_type != nil
            match_type = decorated_func.match_type
        end
    else
        # Not a decorated function, skip
        return
    end

    # Create and register the route entry
    let entry = RouteEntry.new(path, method, handler, match_type)
    ROUTES.push(entry)
end

# Dispatch a request to the appropriate handler
# Returns the handler result, or nil if no route matches
pub fun dispatch(req, not_found_handler)
    let path = req["path"]
    let method = req["method"]

    # Try to find a matching route
    let i = 0
    while i < ROUTES.len()
        let entry = ROUTES[i]
        if entry.matches(path, method)
            let handler_fn = entry.handler
            return handler_fn(req)
        end
        i = i + 1
    end

    # No route matched - call 404 handler
    if not_found_handler != nil
        return not_found_handler(req)
    end

    return nil
end

# Get all registered routes (for debugging/introspection)
pub fun get_routes()
    return ROUTES
end

# Clear all routes (useful for testing)
pub fun clear_routes()
    ROUTES = []
end
