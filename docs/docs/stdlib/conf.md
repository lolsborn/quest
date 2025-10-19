# conf - Module Configuration System

A unified configuration system that allows Quest modules to declare their configuration schemas and have those configurations automatically loaded from `quest.toml` and environment-specific override files.

## Overview

The `std/conf` module provides:

- **Schema declaration**: Modules define Configuration types with validation
- **Hierarchical loading**: Base config (`quest.toml`) + environment overrides + local overrides
- **Load-time validation**: Configuration errors are caught immediately when modules load
- **Type safety**: Validation ensures configuration is correct before code runs
- **Namespace separation**: Each module's configuration is isolated (e.g., `[std.web]`, `[std.test]`)

## Quick Start

### For Module Authors

**Define a Configuration type in your module:**

```quest
# lib/myapp/worker.q

use "std/conf" as conf

pub type Configuration
    # Fields with defaults
    workers: Int? = 4
    timeout: Int? = 30
    debug: Bool? = false

    # Validation
    fun validate_workers(value)
        if value < 1 or value > 100
            raise ValueErr.new("workers must be between 1 and 100")
        end
    end

    fun self.from_dict(dict)
        let config = Configuration._new()
        if dict.contains("workers")
            config.workers = dict["workers"]
            config.validate_workers(config.workers)
        end
        if dict.contains("timeout")
            config.timeout = dict["timeout"]
        end
        if dict.contains("debug")
            config.debug = dict["debug"]
        end
        return config
    end
end

# Register schema and load configuration
conf.register_schema("myapp.worker", Configuration)
pub let config = conf.get_config("myapp.worker")
```

**Create configuration file:**

```toml
# quest.toml

[myapp.worker]
workers = 8
timeout = 60
debug = true
```

### For Module Users

**Access module configuration:**

```quest
use "myapp/worker" as worker

# Access configuration values
puts("Workers: ", worker.config.workers)
puts("Timeout: ", worker.config.timeout)
puts("Debug mode: ", worker.config.debug)
```

## Configuration Files

### File Precedence

Configuration is loaded and merged in this order (last wins):

```
1. Module defaults (Configuration type field defaults)
   ↓
2. quest.toml (base configuration, committed to git)
   ↓
3. quest.<env>.toml (environment-specific, if QUEST_ENV is set)
   ↓
4. quest.local.toml (local overrides, NOT committed)
```

### quest.toml (Base Configuration)

**Committed to git** - shared settings for all environments:

```toml
# Project metadata
name = "myapp"
version = "1.0.0"

# Module configurations use fully-qualified names
[std.web]
host = "127.0.0.1"
port = 3000
max_body_size = 10485760  # 10MB

[std.test]
paths = ["./test"]
use_colors = true

[myapp.worker]
workers = 4
timeout = 30
```

### quest.dev.toml (Development Environment)

**Committed to git** - development-specific overrides:

```toml
[os.environ]
DATABASE_URL = "postgresql://localhost/mydb_dev"
LOG_LEVEL = "DEBUG"

[std.web]
host = "0.0.0.0"  # Allow external connections
port = 3000

[myapp.worker]
workers = 2
debug = true
```

### quest.prod.toml (Production Environment)

**Committed to git** - production-specific overrides:

```toml
[os.environ]
DATABASE_URL = "postgresql://prod-db.example.com/mydb"
LOG_LEVEL = "WARNING"

[std.web]
port = 8080
max_body_size = 52428800  # 50MB

[myapp.worker]
workers = 16
timeout = 60
```

### quest.local.toml (Local Overrides)

**NOT committed** (add to .gitignore) - developer-specific settings and secrets:

```toml
[os.environ]
API_KEY = "your-secret-key-here"
DATABASE_URL = "postgresql://localhost/mydb_local"

[std.web]
port = 8080  # Override for local testing

[myapp.worker]
debug = true
```

### Using QUEST_ENV

Set `QUEST_ENV` to load environment-specific configuration:

```bash
# Development
export QUEST_ENV=dev
quest app.q

# Production
export QUEST_ENV=prod
quest app.q

# Without QUEST_ENV, only quest.toml and quest.local.toml load
```

## Configuration Naming Convention

**IMPORTANT**: All module configurations must use **fully-qualified module names** in TOML files:

```toml
# ✅ CORRECT - fully qualified names
[std.web]
port = 3000

[std.test]
paths = ["./test"]

[myapp.worker]
workers = 4

# ❌ WRONG - short names not supported
[web]
port = 3000

[test]
paths = ["./test"]
```

This ensures:
- No name collisions between modules
- Clear module ownership of configuration
- Consistent with Quest's module path system (`use "std/web"` → `[std.web]`)

## API Reference

### Module Author API

#### `register_schema(module_name, config_type)`

Register a module's configuration schema.

**Parameters:**
- `module_name` (Str): Fully-qualified module name (e.g., `"std.web"`, `"myapp.worker"`)
- `config_type` (Type): Configuration type with `from_dict()` static method

**Example:**

```quest
use "std/conf" as conf

pub type Configuration
    # ... fields and methods ...
    fun self.from_dict(dict)
        # ... implementation ...
    end
end

conf.register_schema("myapp.worker", Configuration)
```

#### `get_config(module_name)`

Load and validate configuration for a module.

**Parameters:**
- `module_name` (Str): Fully-qualified module name

**Returns:** Configuration instance (validated)

**Raises:** `ConfigurationErr` if validation fails

**Example:**

```quest
use "std/conf" as conf

# ... define Configuration type and register schema ...

pub let config = conf.get_config("myapp.worker")

# Use configuration
pub fun start_worker()
    let count = config.workers
    # ...
end
```

### Advanced API

#### `load_module_config(module_name)`

Load raw configuration dictionary without validation.

**Parameters:**
- `module_name` (Str): Fully-qualified module name

**Returns:** Dict with merged configuration

**Example:**

```quest
use "std/conf" as conf

let config_dict = conf.load_module_config("myapp.worker")
# Returns: {workers: 8, timeout: 60, debug: true}
```

#### `merge(*configs)`

Merge multiple configuration dictionaries (deep merge).

**Parameters:**
- `*configs` (Dict...): Variable number of dictionaries to merge

**Returns:** Dict with merged configuration (last wins for conflicts)

**Example:**

```quest
use "std/conf" as conf

let base = {host: "localhost", port: 3000}
let override = {port: 8080, debug: true}

let merged = conf.merge(base, override)
# Returns: {host: "localhost", port: 8080, debug: true}
```

#### `list_modules()`

List all registered module names.

**Returns:** Array of module names

**Example:**

```quest
use "std/conf" as conf

let modules = conf.list_modules()
# Returns: ["std.web", "std.test", "myapp.worker"]

for module in modules
    puts("Module: ", module)
end
```

#### `get_schema(module_name)`

Get the Configuration type for a module.

**Parameters:**
- `module_name` (Str): Fully-qualified module name

**Returns:** Configuration type

**Raises:** `ConfigurationErr` if module not registered

**Example:**

```quest
use "std/conf" as conf

let schema = conf.get_schema("std.web")
# Returns: Configuration type
```

#### `validate_config(module_name, config_dict)`

Validate a configuration dictionary against a module's schema.

**Parameters:**
- `module_name` (Str): Fully-qualified module name
- `config_dict` (Dict): Configuration dictionary to validate

**Raises:** `ConfigurationErr` if validation fails

**Example:**

```quest
use "std/conf" as conf

let config = {workers: 8, timeout: 60}
conf.validate_config("myapp.worker", config)
# Raises if invalid
```

#### `clear_cache()`

Clear the configuration cache (useful for testing).

**Example:**

```quest
use "std/conf" as conf

# Reload configuration
conf.clear_cache()
let config = conf.get_config("myapp.worker")
```

## Configuration Type Pattern

### Required Structure

Every module's Configuration type must follow this pattern:

```quest
# MUST be public - std/conf needs to instantiate it
pub type Configuration
    # Fields with optional types and defaults
    field_name: Type? = default_value

    # Field-specific validation (optional)
    # Naming convention: validate_<field_name>
    fun validate_field_name(value)
        if not valid
            raise ValueErr.new("error message")
        end
    end

    # Global validation (optional)
    # Called after all fields are set
    fun validate()
        if self.field_a and not self.field_b
            raise ValueErr.new("field_b required when field_a is set")
        end
    end

    # Factory method (REQUIRED)
    # Called by std/conf to create Configuration from TOML dict
    fun self.from_dict(dict)
        let config = Configuration._new()

        # For each field:
        # 1. Check if key exists in dict
        # 2. Set the field value
        # 3. Call field validator if it exists
        if dict.contains("field_name")
            config.field_name = dict["field_name"]
            config.validate_field_name(config.field_name)
        end

        return config
    end
end
```

### Requirements Checklist

- ✅ Type MUST be `pub` (public) - std/conf instantiates it
- ✅ MUST have `fun self.from_dict(dict)` that returns Configuration instance
- ✅ Field validators follow naming: `validate_<field_name>(value)`
- ✅ Global validator (if needed): `fun validate()`
- ✅ All validation errors should raise `ValueErr` or `ConfigurationErr`

## Examples

### Example 1: Simple Configuration

```quest
# lib/myapp/cache.q

use "std/conf" as conf

pub type Configuration
    backend: Str? = "memory"        # "memory", "redis"
    ttl: Int? = 3600               # Default TTL in seconds
    max_size: Int? = 1000          # Max items in memory cache

    fun validate_backend(value)
        let valid = ["memory", "redis"]
        if not valid.contains(value)
            raise ValueErr.new("backend must be one of: " .. valid.join(", "))
        end
    end

    fun self.from_dict(dict)
        let config = Configuration._new()
        if dict.contains("backend")
            config.backend = dict["backend"]
            config.validate_backend(config.backend)
        end
        if dict.contains("ttl")
            config.ttl = dict["ttl"]
        end
        if dict.contains("max_size")
            config.max_size = dict["max_size"]
        end
        return config
    end
end

conf.register_schema("myapp.cache", Configuration)
pub let config = conf.get_config("myapp.cache")

# Use configuration
pub fun create_cache()
    if config.backend == "memory"
        return MemoryCache.new(max_size: config.max_size, ttl: config.ttl)
    end
end
```

**quest.toml:**

```toml
[myapp.cache]
backend = "redis"
ttl = 7200
max_size = 5000
```

### Example 2: Complex Configuration with Cross-Field Validation

```quest
# lib/myapp/worker.q

use "std/conf" as conf

pub type Configuration
    enabled: Bool? = true
    workers: Int? = 4
    timeout: Int? = 30
    max_retries: Int? = 3
    queue_size: Int? = 1000

    # Field validators
    fun validate_workers(value)
        if value < 1 or value > 100
            raise ValueErr.new("workers must be between 1 and 100")
        end
    end

    fun validate_timeout(value)
        if value < 1
            raise ValueErr.new("timeout must be positive")
        end
    end

    # Global validator (cross-field validation)
    fun validate()
        if self.enabled
            if self.queue_size < self.workers
                raise ValueErr.new("queue_size must be >= workers when enabled")
            end
        end
    end

    fun self.from_dict(dict)
        let config = Configuration._new()
        if dict.contains("enabled")
            config.enabled = dict["enabled"]
        end
        if dict.contains("workers")
            config.workers = dict["workers"]
            config.validate_workers(config.workers)
        end
        if dict.contains("timeout")
            config.timeout = dict["timeout"]
            config.validate_timeout(config.timeout)
        end
        if dict.contains("max_retries")
            config.max_retries = dict["max_retries"]
        end
        if dict.contains("queue_size")
            config.queue_size = dict["queue_size"]
        end
        return config
    end
end

conf.register_schema("myapp.worker", Configuration)
pub let config = conf.get_config("myapp.worker")
```

**quest.toml:**

```toml
[myapp.worker]
enabled = true
workers = 8
timeout = 60
max_retries = 5
queue_size = 100
```

### Example 3: Environment-Specific Configuration

**quest.toml (base):**

```toml
[myapp.api]
base_url = "https://api.example.com"
timeout = 30
retry_attempts = 3
```

**quest.dev.toml (development):**

```toml
[myapp.api]
base_url = "http://localhost:8000"
timeout = 60
debug = true
```

**quest.prod.toml (production):**

```toml
[myapp.api]
base_url = "https://api.production.com"
timeout = 10
retry_attempts = 5
```

**quest.local.toml (local secrets):**

```toml
[os.environ]
API_KEY = "your-secret-key"

[myapp.api]
base_url = "http://localhost:3000"  # Local development server
```

## Error Handling

### Configuration Validation Errors

When validation fails, `std/conf` raises `ConfigurationErr` with clear error messages:

```
Error loading module myapp.worker:
  ConfigurationErr: Invalid configuration for myapp.worker
    Field 'workers': must be between 1 and 100
    Got: 150

  at std/conf.q:202 in get_config()
  at myapp/worker.q:45 in <module>
```

### Missing Configuration

If a module's configuration section doesn't exist in any TOML file, the module uses its default values:

```quest
# If quest.toml has no [myapp.worker] section,
# Configuration defaults are used:
# workers = 4, timeout = 30, debug = false
```

### Invalid TOML Syntax

If a TOML file has syntax errors, loading fails immediately:

```
Error loading quest.toml:
  Failed to load TOML file 'quest.toml': expected '=' at line 5
```

## Best Practices

### For Module Authors

1. **Always provide sensible defaults:**

```quest
pub type Configuration
    timeout: Int? = 30    # ✅ Good default
    host: Str? = "localhost"  # ✅ Good default
end
```

2. **Validate early in from_dict():**

```quest
fun self.from_dict(dict)
    let config = Configuration._new()
    if dict.contains("workers")
        config.workers = dict["workers"]
        config.validate_workers(config.workers)  # ✅ Validate immediately
    end
    return config
end
```

3. **Use clear error messages:**

```quest
fun validate_port(value)
    if value < 1 or value > 65535
        raise ValueErr.new("port must be between 1 and 65535, got: " .. value.str())
    end
end
```

4. **Document your configuration:**

```quest
pub type Configuration
    # Maximum number of worker threads (1-100)
    # Default: 4
    workers: Int? = 4

    # Request timeout in seconds
    # Default: 30
    timeout: Int? = 30
end
```

### For Module Users

1. **Use environment-specific files:**

```
quest.toml           # Base (committed)
quest.dev.toml       # Dev (committed)
quest.prod.toml      # Prod (committed)
quest.local.toml     # Local (gitignored)
```

2. **Keep secrets in quest.local.toml:**

```toml
# quest.local.toml (add to .gitignore)
[os.environ]
API_KEY = "secret-key"
DATABASE_PASSWORD = "password"
```

3. **Provide example configuration:**

```toml
# quest.example.toml
[myapp.worker]
workers = 4
timeout = 30
# Copy to quest.local.toml and customize
```

## Migration from std/settings

The previous `std/settings` module has been replaced by `std/conf`. Key changes:

| Old (std/settings) | New (std/conf) |
|-------------------|----------------|
| `.settings.toml` | `quest.toml` |
| Global namespace | Module-namespaced: `[std.web]` |
| `settings.get("key")` | `module.config.field` |
| No schema validation | Configuration types with validation |
| Runtime access | Load-time validation |

**Migration steps:**

1. Rename `.settings.toml` → `quest.toml`
2. Update sections: `[app]` → `[myapp.main]` (use fully-qualified module names)
3. Create Configuration type in your module
4. Register schema and load config
5. Access via `module.config.field` instead of `settings.get()`

## See Also

- [std/os](os.md) - Environment variables (`os.getenv()`)
- [Language: Modules](../language/modules.md) - Creating modules
