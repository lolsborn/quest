"""
Function decorators for Quest (QEP-003)

This module provides built-in decorator implementations for common patterns
like caching, logging, timing, and retry logic.

Example:
  use "std/decorators" as dec
  use "std/time" as time

  @dec.Cache(max_size: 100, ttl: 300)
  @dec.Timing
  fun fetch_data(id)
      # Function implementation
  end
"""

use "std/time" as time

# =============================================================================
# Timing Decorator - Measure execution time
# =============================================================================

pub type Timing
    """
    Measures and logs function execution time.

    Parameters:
    - threshold: Optional minimum time (in seconds) to log. Default: 0 (log all)

    Example:
        @Timing
        fun slow_function()
            # ...
        end

        @Timing(threshold: 1.0)
        fun maybe_slow()
            # Only logs if takes > 1 second
        end
    """
    func
    threshold: Num?

    fun _call(*args, **kwargs)
        let start = time.ticks_ms()
        let result = self.func(*args, **kwargs)
        let elapsed = (time.ticks_ms() - start) / 1000.0

        let threshold_val = 0
        if self.threshold != nil
            threshold_val = self.threshold
        end

        if elapsed >= threshold_val
            puts("[TIMING] " .. self.func._name() .. " took " .. elapsed.str() .. "s")
        end

        return result
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

# =============================================================================
# Log Decorator - Log function calls
# =============================================================================

pub type Log
    """
    Logs function calls with arguments and return values.

    Parameters:
    - level: Log level prefix. Default: "INFO"
    - include_result: Whether to log return value. Default: true
    - include_args: Whether to log arguments. Default: true

    Example:
        @Log
        fun process(x)
            return x * 2
        end

        @Log(level: "DEBUG", include_result: false)
        fun internal_process(data)
            # ...
        end
    """
    func
    level: Str?
    include_result: Bool?
    include_args: Bool?

    fun _call(*args, **kwargs)
        let level_val = "INFO"
        if self.level != nil
            level_val = self.level
        end

        let inc_result = true
        if self.include_result != nil
            inc_result = self.include_result
        end

        let inc_args = true
        if self.include_args != nil
            inc_args = self.include_args
        end

        let func_name = self.func._name()

        if inc_args
            puts("[" .. level_val .. "] Calling " .. func_name .. " with " .. args.len().str() .. " args, " .. kwargs.len().str() .. " kwargs")
        else
            puts("[" .. level_val .. "] Calling " .. func_name)
        end

        let result = self.func(*args, **kwargs)

        if inc_result
            puts("[" .. level_val .. "] " .. func_name .. " returned: " .. result.str())
        else
            puts("[" .. level_val .. "] " .. func_name .. " completed")
        end

        return result
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

# =============================================================================
# Cache Decorator - Memoization
# =============================================================================

pub type Cache
    """
    Caches function results based on arguments.

    Parameters:
    - max_size: Maximum cache size. Default: 128
    - ttl: Time-to-live in seconds. Default: nil (no expiration)

    Note: Currently implements simple argument-based caching.
    For production use, consider implementing LRU eviction.

    Example:
        @Cache(max_size: 100, ttl: 300)
        fun expensive_query(id)
            # Result cached for 5 minutes
        end
    """
    func
    cache: Dict?
    max_size: Int?
    ttl: Num?
    access_times: Dict?  # For TTL tracking

    fun _call(*args, **kwargs)
        # Initialize cache on first call
        if self.cache == nil
            self.cache = {}
        end
        if self.access_times == nil
            self.access_times = {}
        end

        # Create cache key from args (simple string concatenation)
        # For better caching, would need proper hashing
        let key = args.str()
        if kwargs.len() > 0
            key = key .. kwargs.str()
        end

        # Check if cached and not expired
        if self.cache.contains(key)
            let cache_time = 0
            if self.access_times.contains(key)
                cache_time = self.access_times[key]
            end

            let now = time.ticks_ms() / 1000.0
            let ttl_val = 999999999
            if self.ttl != nil
                ttl_val = self.ttl
            end

            if (now - cache_time) < ttl_val
                return self.cache[key]
            end
        end

        # Not cached or expired - compute result
        let result = self.func(*args, **kwargs)

        # Store in cache
        let max_val = 128
        if self.max_size != nil
            max_val = self.max_size
        end

        if self.cache.len() >= max_val
            # Simple eviction: clear oldest (first key)
            # For production, implement LRU
            let first_key = self.cache.keys()[0]
            self.cache.remove(first_key)
            if self.access_times.contains(first_key)
                self.access_times.remove(first_key)
            end
        end

        self.cache[key] = result
        self.access_times[key] = time.ticks_ms() / 1000.0

        return result
    end

    fun clear()
        """Clear the cache"""
        self.cache = {}
        self.access_times = {}
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

# =============================================================================
# Retry Decorator - Automatic retry on failure
# =============================================================================

pub type Retry
    """
    Automatically retries function on exception.

    Parameters:
    - max_attempts: Maximum retry attempts. Default: 3
    - delay: Initial delay between retries in seconds. Default: 1.0
    - backoff: Multiplier for delay after each retry. Default: 1.0 (no backoff)
    - exceptions: Array of exception types to catch. Default: [Err] (all)

    Example:
        @Retry(max_attempts: 5, delay: 0.5, backoff: 2.0)
        fun fetch_data(url)
            # Retries up to 5 times with exponential backoff
        end
    """
    func
    max_attempts: Int?
    delay: Num?
    backoff: Num?

    fun _call(*args, **kwargs)
        let attempts = 0
        let max_val = 3
        if self.max_attempts != nil
            max_val = self.max_attempts
        end

        let delay_val = 1.0
        if self.delay != nil
            delay_val = self.delay
        end

        let backoff_val = 1.0
        if self.backoff != nil
            backoff_val = self.backoff
        end

        let current_delay = delay_val

        while attempts < max_val
            try
                return self.func(*args, **kwargs)
            catch e
                attempts = attempts + 1
                if attempts >= max_val
                    # Final attempt failed - re-raise
                    raise e
                end

                puts("[RETRY] Attempt " .. attempts.str() .. " failed: " .. e.message() .. ". Retrying in " .. current_delay.str() .. "s...")
                time.sleep(current_delay)
                current_delay = current_delay * backoff_val
            end
        end

        # Should never reach here
        raise RuntimeErr.new("Retry logic error")
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

# =============================================================================
# Once Decorator - Execute only once
# =============================================================================

pub type Once
    """
    Ensures a function is executed only once, returning cached result on subsequent calls.

    Example:
        @Once
        fun initialize()
            puts("Initializing...")
            return "initialized"
        end

        initialize()  # Prints and returns "initialized"
        initialize()  # Just returns "initialized" (no print)
    """
    func

    fun _call(*args, **kwargs)
        # Use func._id() as a marker for "not yet called"
        # Store called state and result as instance variables dynamically
        if not self.called
            self.result = self.func(*args, **kwargs)
            self.called = true
        end
        return self.result
    end

    fun reset()
        """Reset the decorator to allow calling again"""
        self.called = false
        self.result = nil
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

# =============================================================================
# Deprecated Decorator - Deprecation warnings
# =============================================================================

pub type Deprecated
    """
    Warns when calling deprecated functions.

    Parameters:
    - message: Custom deprecation message. Default: "Function is deprecated"
    - alternative: Suggested alternative function. Default: nil

    Example:
        @Deprecated(message: "Use new_function instead", alternative: "new_function")
        fun old_function()
            # ...
        end
    """
    func
    message: Str?
    alternative: Str?

    fun _call(*args, **kwargs)
        let msg = "Function is deprecated"
        if self.message != nil
            msg = self.message
        end

        let warning = "[DEPRECATED] " .. self.func._name() .. ": " .. msg

        if self.alternative != nil
            warning = warning .. " (use " .. self.alternative .. " instead)"
        end

        puts(warning)
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
