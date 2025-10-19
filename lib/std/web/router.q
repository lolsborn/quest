# std/web/router.q - Flexible Path Parameter Routing (QEP-062)
#
# Provides flexible path parameter routing with automatic URL decoding and type conversion.
# Patterns like `/post/{slug}` automatically extract parameters into `req["params"]`.

use "std/uuid" as uuid

# =============================================================================
# Type Definitions
# =============================================================================

# Route is represented as a dict with:
# {pattern_segments, method, handler, priority}

pub type Router
  pub routes = []  # Array of routes (dicts) for this router instance

  # Register routes on this router instance
  fun get(pattern, handler)
    self._register_route("GET", pattern, handler)
  end

  fun post(pattern, handler)
    self._register_route("POST", pattern, handler)
  end

  fun put(pattern, handler)
    self._register_route("PUT", pattern, handler)
  end

  fun delete(pattern, handler)
    self._register_route("DELETE", pattern, handler)
  end

  fun patch(pattern, handler)
    self._register_route("PATCH", pattern, handler)
  end

  # Dispatch middleware function for QEP-061 integration
  fun dispatch(req)
    let path = req["path"]
    let method = req["method"]

    let i = 0
    while i < self.routes.len()
      let route = self.routes[i]

      if route["method"] != method
        i = i + 1
        continue
      end

      let params = match_path(route["pattern_segments"], path)
      if params != nil
        req["params"] = params
        return route["handler"](req)
      end
      i = i + 1
    end
    return req  # No match, continue chain (let other handlers try)
  end

  # Internal method to register a route
  fun _register_route(method, pattern, handler)
    let segments = parse_pattern(pattern)
    let priority = calculate_priority(segments)

    let route = {
      "pattern_segments": segments,
      "method": method,
      "handler": handler,
      "priority": priority
    }

    self.routes.push(route)
    sort_routes(self.routes)
  end

  # Dispatch request to routes in this router
  fun _dispatch(req, not_found_handler)
    let path = req["path"]
    let method = req["method"]

    let i = 0
    while i < self.routes.len()
      let route = self.routes[i]

      if route["method"] != method
        i = i + 1
        continue
      end

      let params = match_path(route["pattern_segments"], path)
      if params != nil
        req["params"] = params
        return route["handler"](req)
     end
      i = i + 1
    end

    # No match - try not_found_handler if provided
    if not_found_handler != nil
      return not_found_handler(req)
    end

    return nil  # No route matched
  end
end


# =============================================================================
# Pattern Parsing
# =============================================================================

# Parse a pattern like "/post/{slug}" into segments
# Returns array of {type: "static"|"param", ...}
pub fun parse_pattern(pattern)
  let segments = []
  let parts = pattern.split("/")

  let i = 0
  while i < parts.len()
    let part = parts[i]

    if part == ""
      # Skip empty segments (from leading/trailing slashes)
      i = i + 1
      continue
    elif part.starts_with("{") and part.ends_with("}")
      # Brace syntax: {slug} or {id<int>}
      let param_str = part.slice(1, part.len() - 1)  # Strip { and }
      let param_name = param_str
      let param_type = "str"  # Default type

      # Extract type annotation if present: {id<int>}
      if param_str.contains("<")
        let angle_idx = param_str.index_of("<")
        param_name = param_str.slice(0, angle_idx)
        let type_end = param_str.index_of(">")
        param_type = param_str.slice(angle_idx + 1, type_end)
      end

      # Validate: path type must be last segment
      if param_type == "path"
        # Check if there are more non-empty segments after this
        let j = i + 1
        while j < parts.len()
          if parts[j] != ""
            raise ValueErr.new("path type parameter must be last segment in pattern")
          end
          j = j + 1
        end
      end

      segments.push({
        "type": "param",
        "name": param_name,
        "param_type": param_type
      })
    else
      # Static segment
      segments.push({"type": "static", "value": part})
    end

    i = i + 1
  end

  return segments
end

# =============================================================================
# Path Matching & URL Decoding
# =============================================================================

# Match a request path against parsed pattern segments
# Returns dict of params if match, nil if no match
pub fun match_path(segments, req_path)
  let parts = req_path.split("/")
  let params = {}

  let seg_idx = 0
  let part_idx = 0

  while part_idx < parts.len()
    let part = parts[part_idx]

    if part == ""
      part_idx = part_idx + 1
      continue
    end

    if seg_idx >= segments.len()
      return nil  # Too many segments
    end

    let segment = segments[seg_idx]

    if segment["type"] == "static"
      if part != segment["value"]
        return nil  # Mismatch
      end
    elif segment["type"] == "param"
      # Check if this is a path type (greedy capture)
      if segment["param_type"] == "path"
        # Capture all remaining segments
        let remaining_parts = []
        while part_idx < parts.len()
          if parts[part_idx] != ""
            remaining_parts.push(parts[part_idx])
          end
          part_idx = part_idx + 1
        end

        # Join with / to reconstruct path, then URL-decode
        let path_value = remaining_parts.join("/")
        path_value = url_decode(path_value)
        params[segment["name"]] = path_value

        # Must be last segment
        seg_idx = seg_idx + 1
        break  # Done matching
      else
        # Regular parameter - single segment
        # URL-decode the segment
        let decoded_value = url_decode(part)

        # Convert based on param_type
        let converted_value = convert_param(decoded_value, segment["param_type"])

        if converted_value == nil
          # Type validation failed
          return nil
        end

        params[segment["name"]] = converted_value
      end
    end

    seg_idx = seg_idx + 1
    part_idx = part_idx + 1
  end

  if seg_idx != segments.len()
    return nil  # Too few segments
  end

  return params
end

# URL-decode a path segment (e.g., "hello%20world" → "hello world")
fun url_decode(encoded)
  # Built-in URL decoding using Rust string method
  return encoded._url_decode()
end

# =============================================================================
# Type Conversion
# =============================================================================

# Convert parameter value based on specified type
fun convert_param(value, param_type)
  if param_type == "str"
    return value  # Return decoded string as-is
  elif param_type == "int"
    # Try to convert to int
    let result = nil
    try
      result = value.to_int()
    catch exc
      result = nil
    ensure
      # Ensure block - just needed for syntax
    end
    return result
  elif param_type == "float"
    # Try to convert to float
    let result = nil
    try
      result = value.to_float()
    catch exc
      result = nil
    ensure
      # Ensure block - just needed for syntax
    end
    return result
  elif param_type == "uuid"
    # Try to parse UUID
    let result = nil
    try
      result = uuid.parse(value)
    catch exc
      result = nil
    ensure
      # Ensure block - just needed for syntax
    end
    return result
  elif param_type == "path"
    # Special handling - captures rest of path (already decoded)
    return value
  else
    # Unknown type, treat as string
    return value
  end
end

# =============================================================================
# Priority Calculation
# =============================================================================

# Calculate priority for route (lower = higher priority)
# Static routes have priority 0, dynamic routes have priority based on segment count
fun calculate_priority(segments)
  let static_count = 0
  let param_count = 0

  let i = 0
  while i < segments.len()
    let segment = segments[i]
    if segment["type"] == "static"
      static_count = static_count + 1
    else
      param_count = param_count + 1
    end
    i = i + 1
  end

  # Static routes get priority 0 (highest)
  # Routes with more static segments get higher priority than dynamic
  # Within same static count, routes registered first win (stable sort)
  if param_count == 0
    return 0  # All static - highest priority
  else
    return static_count * 1000 + param_count  # More static = higher priority
  end
end

# =============================================================================
# Route Sorting
# =============================================================================

# Sort routes by priority (in-place, stable)
fun sort_routes(routes)
  # Simple bubble sort (stable, preserves registration order for equal priorities)
  let n = routes.len()
  let i = 0
  while i < n
    let j = 0
    while j < n - i - 1
      if routes[j]["priority"] > routes[j + 1]["priority"]
        # Swap
        let temp = routes[j]
        routes[j] = routes[j + 1]
        routes[j + 1] = temp
      end
      j = j + 1
    end
    i = i + 1
  end
end

# =============================================================================
# Module-Level Dispatch Function (for use in middleware when type lookup fails)
# =============================================================================

# Dispatch a request to a router instance without relying on type method lookup
# This is needed because middleware runs in a thread-local scope where type lookup may fail
pub fun dispatch_router(router, req)
  # Call the router's _dispatch method
  return router._dispatch(req, nil)
end
