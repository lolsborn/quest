---
Number: QEP-053
Title: Module Configuration System (std/conf)
Author: Steven Ruppert
Status: Draft
Created: 2025-10-16
---

# QEP-053: Module Configuration System (std/conf)

## Overview

This QEP proposes a unified configuration system (`std/conf`) that allows Quest modules to declare their configuration schemas and have those configurations automatically loaded from `quest.toml` and environment-specific override files. This standardizes how modules expose configurable behavior and provides a clear, hierarchical configuration pattern.

## Status

**Draft** - Design phase

## Relationship to std/settings

**IMPORTANT**: This QEP replaces the previous `std/settings` module, which has been removed from the codebase. The `std/settings` module was an interim solution that:
- Auto-loaded `.settings.toml` files
- Provided basic key/value access without schemas
- Lacked validation and type safety
- Had no module namespace separation

**Migration from std/settings to std/conf**:
- `std/settings` → `std/conf` (new unified configuration system)
- `.settings.toml` → `quest.toml` (project configuration file)
- No schema validation → Configuration types with validation
- Global namespace → Module-namespaced configurations (`[module.name]`)

**Cleanup required**: All references to `std/settings` must be removed from:
- Documentation (`docs/docs/stdlib/settings.md`, `docs/docs/stdlib/index.md`)
- Specifications (QEP-004, QEP-028, QEP-051)
- Tests (`test/settings/`)
- Rust implementation (`src/modules/settings/mod.rs`)
- Project instructions (`CLAUDE.md`)

## Goals

- Provide a standard way for modules to declare configuration schemas
- Support hierarchical configuration via `quest.toml` with environment overrides
- Enable type validation and default values for module configurations
- Clear namespace separation: `[module.section]` or `[module]` with `section.key = value`
- Consistent terminology: use "configuration" throughout
- Support both flat and nested configuration structures

## Motivation

Currently, Quest has an ad-hoc configuration approach:

**Problems:**
1. No standard way for modules to declare what configuration they accept
2. No schema validation for configuration values
3. Hard to discover what configuration options a module supports
4. `quest.toml` exists but doesn't have a clear pattern for module configuration
5. No type validation or default values for configurations

**Use cases that need solving:**
- `std/test` needs to declare its configuration options (paths, colors, output capture)
- `std/log` needs to declare logging levels, formats, handlers
- `std/web/server` needs to declare host, port, timeouts, body size limits
- Third-party modules need a standard way to expose configuration
- Users need a clear way to discover and configure module behavior

## Rationale

### Why a Unified Configuration System?

**Benefits:**
- **Discoverability**: Users can inspect a module's configuration schema
- **Validation**: Type checking and range validation at load time
- **Documentation**: Schema serves as documentation
- **Consistency**: All modules use the same configuration pattern
- **Tooling**: IDEs can provide autocomplete for configuration keys
- **Debugging**: Clear error messages when configuration is invalid

### Why quest.toml as the Base Configuration File?

**Reasoning:**
- Already exists in the project
- Committed to git (base configuration)
- Environment-specific overrides follow a clear pattern
- Consistent with modern tooling (package.json, Cargo.toml, pyproject.toml)

**Configuration precedence:**
```
quest.toml
  ↓ (overridden by)
quest.<env>.toml
  ↓ (overridden by)
quest.local.toml
```

### Why Two Namespace Styles?

Both `[module.section]` and `[module]` with `section.key = value` are supported for flexibility:

**Flat style (recommended for simple configs):**
```toml
[std.test]
paths = ["./test"]
use_colors = true
```

**Nested style (recommended for complex configs):**
```toml
[std.log]
level = "INFO"
handlers.console.enabled = true
handlers.console.level = "DEBUG"
handlers.file.enabled = false
handlers.file.path = "app.log"
```

**Or use TOML sections:**
```toml
[std.log]
level = "INFO"

[std.log.handlers.console]
enabled = true
level = "DEBUG"

[std.log.handlers.file]
enabled = false
path = "app.log"
```

## Design

### Module Configuration Schema

Each module can declare a `Configuration` type that defines its configuration schema:

```quest
# lib/std/test.q

pub type Configuration
    # Paths to search for tests (default: ["./test"])
    array?: paths = ["./test"]

    # Enable colored output (default: true)
    bool?: use_colors = true

    # Enable condensed output (default: true)
    bool?: use_condensed = true

    # Output capture mode: "all", "no", "0", "1", "stdout", "stderr"
    str?: capture_output = "all"

    # Tag filters
    array?: filter_tags = []
    array?: skip_tags = []

    # Validation methods
    fun validate_capture_output(value)
        let valid = ["all", "no", "0", "1", "stdout", "stderr"]
        if not valid.contains(value)
            raise ValueErr.new("capture_output must be one of: " .. valid.join(", "))
        end
    end

    static fun from_dict(dict)
        # Create Configuration from dictionary (called by std/conf)
        let config = Configuration.new()
        if dict.contains("paths")
            config.paths = dict["paths"]
        end
        # ... etc
        return config
    end
end

# Module-level configuration instance (loaded by std/conf)
pub let conf = Configuration.new()
```

### Configuration Loading in std/conf

The `std/conf` module handles loading and merging configuration files:

```quest
# lib/std/conf.q

# Load configuration for a specific module
pub fun load_module_config(module_name: str) -> dict
    # 1. Load quest.toml (if exists)
    let base = load_toml("quest.toml")

    # 2. Load environment-specific (if QUEST_ENV set)
    let env = os.getenv("QUEST_ENV")
    let env_config = {}
    if env != nil
        env_config = load_toml("quest." .. env .. ".toml")
    end

    # 3. Load local overrides (if exists)
    let local_config = load_toml("quest.local.toml")

    # 4. Merge configurations (last wins)
    let merged = merge(base, env_config, local_config)

    # 5. Extract module-specific configuration
    return extract_module_config(merged, module_name)
end

# Extract module configuration from merged dict
fun extract_module_config(config: dict, module_name: str) -> dict
    # Support both [module.section] and [module] with section.key
    let result = {}

    # Check for exact module name section
    if config.contains(module_name)
        result = config[module_name]
    end

    # Check for prefixed sections (module.*)
    let prefix = module_name .. "."
    for key in config.keys()
        if key.starts_with(prefix)
            let subkey = key.slice(prefix.len())
            result[subkey] = config[key]
        end
    end

    return result
end

# Deep merge configuration dictionaries
fun merge(*configs: dict) -> dict
    let result = {}
    for config in configs
        deep_merge_into(result, config)
    end
    return result
end

# Register a module's configuration schema
pub fun register_schema(module_name: str, config_type: type)
    # Store schema for validation and introspection
    _schemas[module_name] = config_type
end

# Get configuration for a module (with validation)
pub fun get_config(module_name: str) -> Configuration
    # Load configuration dict
    let config_dict = load_module_config(module_name)

    # Get registered schema
    let schema = _schemas[module_name]
    if schema == nil
        raise ConfigurationErr.new("No schema registered for module: " .. module_name)
    end

    # Validate and create Configuration instance
    let config = schema.from_dict(config_dict)
    config.validate()  # Run validation methods

    return config
end
```

### Load-Time Validation

Configuration validation happens automatically when a module is loaded:

**Validation Lifecycle:**

1. **Module import**: `use "std/test" as test`
2. **Schema registration**: Module's top-level code calls `conf.register_schema("std.test", Configuration)`
3. **Configuration loading**: Module calls `conf.get_config("std.test")`
4. **Validation steps**:
   - Load and merge TOML files (quest.toml + overrides)
   - Extract module-specific configuration
   - Call `Configuration.from_dict(config_dict)` to create instance
   - Call field-specific validators (`validate_field_name()` methods)
   - Call global validator (`validate()` method)
   - If any validation fails, raise exception and halt module load

**Key requirements for Quest-implemented modules:**

```quest
# lib/std/test.q

use "std/conf" as conf

# Configuration type MUST be public (so std/conf can instantiate it)
pub type Configuration
    # Field declarations with defaults
    array?: paths = ["./test"]
    bool?: use_colors = true
    str?: capture_output = "all"

    # Field-specific validation (optional)
    # Called automatically for each field during from_dict()
    fun validate_capture_output(value)
        let valid = ["all", "no", "0", "1", "stdout", "stderr"]
        if not valid.contains(value)
            raise ValueErr.new("capture_output must be one of: " .. valid.join(", "))
        end
    end

    # Global validation (optional)
    # Called after all fields are set
    fun validate()
        if self.paths.len() == 0
            raise ValueErr.new("paths cannot be empty")
        end
    end

    # Factory method (REQUIRED - called by std/conf)
    static fun from_dict(dict) -> Configuration
        let config = Configuration.new()

        # Set each field from dict
        if dict.contains("paths")
            config.paths = dict["paths"]
            config.validate_paths(config.paths)  # Validate immediately
        end
        if dict.contains("use_colors")
            config.use_colors = dict["use_colors"]
        end
        if dict.contains("capture_output")
            config.capture_output = dict["capture_output"]
            config.validate_capture_output(config.capture_output)
        end

        return config
    end
end

# Register schema (happens at module load time)
conf.register_schema("std.test", Configuration)

# Load and validate configuration (happens at module load time)
# If validation fails, module load fails with clear error message
pub let config = conf.get_config("std.test")

# Use configuration throughout module
pub fun run_tests(paths: array?)
    let test_paths = paths or config.paths
    let use_colors = config.use_colors
    # ... use configuration ...
end
```

**Validation error messages:**

```
Error loading module std/test:
  ConfigurationErr: Invalid configuration for std.test
    Field 'capture_output': must be one of: all, no, 0, 1, stdout, stderr
    Got: 'invalid_value'

  at std/conf.q:258 in get_config()
  at std/test.q:283 in <module>
```

**Benefits of load-time validation:**

- ✅ Fail fast - invalid configuration is caught immediately
- ✅ Clear error messages - users know exactly what's wrong
- ✅ Type safety - configuration is validated before any code runs
- ✅ No runtime checks needed - once module loads, config is valid
- ✅ IDE support - Configuration types can be introspected

### Module Integration Pattern

Modules integrate with `std/conf` like this:

```quest
# lib/std/test.q

use "std/conf" as conf

# 1. Define PUBLIC Configuration type (must be accessible to std/conf)
pub type Configuration
    # ... schema definition ...
end

# 2. Register schema with conf module (at module load time)
conf.register_schema("std.test", Configuration)

# 3. Load configuration (at module load time - validates immediately)
pub let config = conf.get_config("std.test")

# 4. Use configuration throughout module
pub fun run_tests(paths: array?)
    let test_paths = paths or config.paths
    let use_colors = config.use_colors
    # ... use configuration ...
end
```

### Configuration File Examples

**quest.toml** (base configuration, committed to git):

```toml
# Project metadata
name = "quest"
version = "0.1.0"
description = "A scripting language focused on developer happiness"

# Module configurations
[std.test]
paths = ["./test"]
use_colors = true
use_condensed = true
capture_output = "all"
filter_tags = []
skip_tags = []

# Alternative: flat style
[std.log]
level = "INFO"
use_colors = true
format = "{asctime} [{level_name}] {name}: {message}"

# Alternative: nested style with sections
[std.web.server]
host = "127.0.0.1"
port = 3000
max_body_size = 10485760  # 10MB

[std.web.server.timeouts]
request = 30
keepalive = 60
```

**quest.dev.toml** (development environment, committed to git):

```toml
# Development-specific configuration

[os.environ]
DATABASE_URL = "postgresql://localhost/mydb_dev"
LOG_LEVEL = "DEBUG"

[std.test]
use_colors = true
capture_output = "all"

[std.log]
level = "DEBUG"

[std.web.server]
host = "0.0.0.0"  # Allow external connections in dev
port = 3000
```

**quest.prod.toml** (production environment, committed to git):

```toml
# Production-specific configuration

[os.environ]
DATABASE_URL = "postgresql://prod-db.example.com/mydb"
LOG_LEVEL = "WARNING"

[std.test]
use_colors = false  # No colors in CI/CD

[std.log]
level = "WARNING"

[std.web.server]
host = "127.0.0.1"
port = 8080
max_body_size = 52428800  # 50MB
```

**quest.local.toml** (local developer machine, NOT committed):

```toml
# Local overrides (in .gitignore)

[os.environ]
API_KEY = "your-secret-key-here"
DATABASE_URL = "postgresql://localhost/mydb_local"

[std.test]
paths = ["./test", "./integration_test"]  # Local test paths

[std.web.server]
port = 8080  # Override for local testing
```

### Usage in User Code

**Reading module configuration:**

```quest
use "std/test" as test

# Access module configuration
let paths = test.conf.paths
let use_colors = test.conf.use_colors

puts("Test paths: ", paths.join(", "))
puts("Colors enabled: ", use_colors)
```

**Programmatic configuration override:**

```quest
use "std/test" as test

# Override configuration programmatically
test.conf.use_colors = false
test.conf.capture_output = "no"

# Run tests with overridden config
test.run(test.conf.paths)
```

### API Reference

#### `std/conf` Module API

```quest
# Register a module's configuration schema
conf.register_schema(module_name: str, config_type: type)

# Load configuration for a module (validates against schema)
conf.get_config(module_name: str) -> Configuration

# Load raw configuration dictionary (no validation)
conf.load_module_config(module_name: str) -> dict

# Merge multiple configuration dictionaries
conf.merge(*configs: dict) -> dict

# List all registered modules
conf.list_modules() -> array[str]

# Get schema for a module
conf.get_schema(module_name: str) -> type

# Validate configuration dict against schema
conf.validate_config(module_name: str, config_dict: dict)
```

#### Module Configuration Type Pattern

Every module should define a `Configuration` type with these requirements:

```quest
# MUST be public - std/conf needs to instantiate it
pub type Configuration
    # Fields with types and defaults
    str?: field_name = "default"

    # Field-specific validation (optional)
    # Naming convention: validate_<field_name>
    # Called during from_dict() for that field
    fun validate_field_name(value)
        if not valid
            raise ValueErr.new("...")
        end
    end

    # Global validation (optional)
    # Called after all fields are set
    # Use for cross-field validation
    fun validate()
        if self.field_a and not self.field_b
            raise ValueErr.new("field_b required when field_a is set")
        end
    end

    # Factory method (REQUIRED)
    # Called by std/conf to create Configuration from TOML dict
    # Should set fields and call field validators
    static fun from_dict(dict) -> Configuration
        let config = Configuration.new()

        # For each field in dict:
        # 1. Set the field value
        # 2. Call field validator if it exists
        if dict.contains("field_name")
            config.field_name = dict["field_name"]
            config.validate_field_name(config.field_name)
        end

        return config
    end
end
```

**Requirements:**
- ✅ Type MUST be `pub` (public) - std/conf instantiates it
- ✅ MUST have `static fun from_dict(dict) -> Configuration`
- ✅ Field validators follow naming: `validate_<field_name>(value)`
- ✅ Global validator (if needed): `fun validate()`
- ✅ All validation errors should raise `ValueErr` or `ConfigurationErr`

## Examples

### Example 1: Simple Module Configuration

**lib/std/cache.q:**

```quest
use "std/conf" as conf

pub type Configuration
    str?: backend = "memory"        # "memory", "redis", "memcached"
    int?: ttl = 3600               # Default TTL in seconds
    int?: max_size = 1000          # Max items in memory cache

    # Redis-specific
    str?: redis_host = "localhost"
    int?: redis_port = 6379

    fun validate_backend(value)
        let valid = ["memory", "redis", "memcached"]
        if not valid.contains(value)
            raise ValueErr.new("backend must be one of: " .. valid.join(", "))
        end
    end

    static fun from_dict(dict)
        let config = Configuration.new()
        if dict.contains("backend")
            config.backend = dict["backend"]
        end
        if dict.contains("ttl")
            config.ttl = dict["ttl"]
        end
        # ... etc
        return config
    end
end

conf.register_schema("std.cache", Configuration)
pub let conf = conf.get_config("std.cache")

# Use configuration
pub fun create_cache()
    if conf.backend == "memory"
        return MemoryCache.new(max_size: conf.max_size, ttl: conf.ttl)
    elif conf.backend == "redis"
        return RedisCache.new(
            host: conf.redis_host,
            port: conf.redis_port,
            ttl: conf.ttl
        )
    end
end
```

**quest.toml:**

```toml
[std.cache]
backend = "redis"
ttl = 7200
redis_host = "localhost"
redis_port = 6379
```

**User code:**

```quest
use "std/cache" as cache

let c = cache.create_cache()
c.set("key", "value", ttl: cache.conf.ttl)
```

### Example 2: Complex Nested Configuration

**lib/std/http/server.q:**

```quest
use "std/conf" as conf

pub type Configuration
    str?: host = "127.0.0.1"
    int?: port = 3000
    int?: max_body_size = 10485760  # 10MB
    int?: max_header_size = 8192     # 8KB

    # Nested: timeouts
    int?: timeout_request = 30
    int?: timeout_keepalive = 60

    # Nested: CORS
    bool?: cors_enabled = false
    array?: cors_origins = ["*"]
    array?: cors_methods = ["GET", "POST"]

    # Nested: Static files
    dict?: static_dirs = {}  # {"/path": "/fs/path"}

    fun validate_port(value)
        if value < 1 or value > 65535
            raise ValueErr.new("port must be 1-65535")
        end
    end

    static fun from_dict(dict)
        let config = Configuration.new()

        # Simple fields
        if dict.contains("host")
            config.host = dict["host"]
        end
        if dict.contains("port")
            config.port = dict["port"]
        end

        # Nested: check for both flat and nested keys
        # Flat: timeout_request = 30
        # Nested: timeout.request = 30 or [server.timeout] request = 30
        if dict.contains("timeout_request")
            config.timeout_request = dict["timeout_request"]
        elif dict.contains("timeout") and dict["timeout"].contains("request")
            config.timeout_request = dict["timeout"]["request"]
        end

        # ... etc

        return config
    end
end

conf.register_schema("std.http.server", Configuration)
pub let conf = conf.get_config("std.http.server")
```

**quest.toml (flat style):**

```toml
[std.http.server]
host = "0.0.0.0"
port = 8080
max_body_size = 52428800
timeout_request = 60
timeout_keepalive = 120
cors_enabled = true
cors_origins = ["https://example.com"]
```

**quest.toml (nested style with sections):**

```toml
[std.http.server]
host = "0.0.0.0"
port = 8080
max_body_size = 52428800

[std.http.server.timeout]
request = 60
keepalive = 120

[std.http.server.cors]
enabled = true
origins = ["https://example.com"]
methods = ["GET", "POST", "PUT", "DELETE"]

[std.http.server.static]
"/css" = "./public/css"
"/js" = "./public/js"
"/images" = "./public/images"
```

### Example 3: Third-Party Module

**lib/acme/analytics.q:**

```quest
use "std/conf" as conf

pub type Configuration
    str?: api_key = nil
    str?: endpoint = "https://api.analytics.example.com"
    bool?: enabled = false
    int?: batch_size = 100
    int?: flush_interval = 30  # seconds

    fun validate()
        if self.enabled and self.api_key == nil
            raise ConfigurationErr.new("api_key is required when analytics is enabled")
        end
    end

    static fun from_dict(dict)
        # ... standard from_dict implementation ...
    end
end

conf.register_schema("acme.analytics", Configuration)
pub let conf = conf.get_config("acme.analytics")
```

**quest.toml:**

```toml
[acme.analytics]
enabled = true
api_key = "REPLACE_ME_IN_LOCAL_TOML"
batch_size = 200
flush_interval = 60
```

**quest.local.toml:**

```toml
[acme.analytics]
api_key = "actual-secret-key-here"
```

## Implementation Plan

### Phase 1: Core Infrastructure

**1. Create `lib/std/conf.q`**
- Implement configuration loading from quest.toml
- Implement environment-specific overrides (quest.<env>.toml)
- Implement deep merging of configuration dictionaries
- Implement schema registration and validation
- Implement `get_config()` with validation

**2. Add TOML parsing (if not already available)**
- Use existing TOML parser or add dependency
- Error handling for invalid TOML syntax

**3. Define standard exceptions**
- `ConfigurationErr` - Invalid configuration
- `SchemaErr` - Invalid schema definition
- `ValidationErr` - Configuration validation failed

### Phase 2: Module Migration

**1. Update `std/test` to use `std/conf`**
- Define `Configuration` type
- Register schema
- Load configuration via `std/conf`
- Update tests

**2. Update `std/log` to use `std/conf`**
- Define `Configuration` type
- Register schema
- Load configuration via `std/conf`

**3. Update `std/web/server` to use `std/conf`**
- Define `Configuration` type
- Register schema
- Load configuration via `std/conf`

### Phase 3: Documentation and Tooling

**1. Update documentation**
- Add `docs/docs/configuration.md` - Comprehensive configuration guide
- Update `CLAUDE.md` with configuration patterns
- Update module docs to show Configuration types

**2. Add CLI introspection commands**
```bash
# List all registered module configurations
quest config list

# Show schema for a module
quest config show std.test

# Validate current configuration
quest config validate
```

**3. Add IDE support**
- Generate JSON schema from Configuration types for autocomplete
- LSP integration for configuration validation

## Configuration Precedence

The final configuration is loaded in this order (last wins):

```
1. Module defaults (Configuration type field defaults)
   ↓
2. quest.toml [module.*] sections
   ↓
3. quest.<env>.toml (if QUEST_ENV is set)
   ↓
4. quest.local.toml (local overrides)
   ↓
5. Programmatic overrides (module.conf.field = value)
```

**Example:**

```quest
# lib/std/test.q default
pub type Configuration
    bool?: use_colors = true  # DEFAULT: true
end
```

```toml
# quest.toml
[std.test]
use_colors = false  # OVERRIDE: false
```

```toml
# quest.local.toml
[std.test]
use_colors = true  # FINAL: true (local wins)
```

```quest
# User code
use "std/test" as test
test.conf.use_colors = false  # FINAL OVERRIDE: false (programmatic wins)
```

## Namespace Conventions

### Module Naming

- Standard library modules: `std.<name>`
- Third-party modules: `<vendor>.<name>`
- Project-specific: `<project>.<name>`

**Examples:**
- `std.test`
- `std.log`
- `std.http.server`
- `acme.analytics`
- `myapp.notifications`

### Configuration Sections

Both flat and nested styles are supported:

**Flat style (use underscore for nesting):**
```toml
[std.http.server]
timeout_request = 30
timeout_keepalive = 60
cors_enabled = true
```

**Nested style (use dots):**
```toml
[std.http.server]
timeout.request = 30
timeout.keepalive = 60
cors.enabled = true
```

**Section style (use TOML sections):**
```toml
[std.http.server]

[std.http.server.timeout]
request = 30
keepalive = 60

[std.http.server.cors]
enabled = true
```

All three styles are equivalent and can be mixed.

## Security Considerations

### Secrets Management

**DO:**
- ✅ Store secrets in `quest.local.toml` (gitignored)
- ✅ Use `[os.environ]` section for environment variables
- ✅ Provide `quest.example.toml` files with placeholder values
- ✅ Document which fields are sensitive

**DON'T:**
- ❌ Commit `quest.local.toml` to version control
- ❌ Put secrets in `quest.toml` (committed to git)
- ❌ Log full configuration (may contain secrets)
- ❌ Expose configuration via HTTP endpoints

### Validation

- Always validate configuration at load time
- Use type annotations for basic validation
- Use `validate_*` methods for complex validation
- Fail fast on invalid configuration (don't continue with bad config)

## Future Enhancements

### Phase 2 Features

1. **Configuration encryption**
   - Encrypt sensitive fields in configuration files
   - Decrypt on load using key from environment

2. **Configuration reloading**
   - Hot-reload configuration without restarting
   - `conf.reload()` method

3. **Configuration versioning**
   - Track configuration schema versions
   - Automatic migration between versions

4. **Remote configuration**
   - Load configuration from remote sources
   - Consul, etcd, AWS SSM Parameter Store

5. **Configuration validation tools**
   - CLI tool to validate configuration files
   - Pre-commit hooks for configuration validation

## Success Criteria

- ✅ Modules can declare configuration schemas using `Configuration` types
- ✅ Configuration is loaded from `quest.toml` with environment overrides
- ✅ Type validation and default values work correctly
- ✅ Both flat and nested configuration styles are supported
- ✅ Clear error messages for invalid configuration
- ✅ Documentation is comprehensive with examples
- ✅ At least 3 stdlib modules migrated to new system

## Cleanup Tasks for std/settings Removal

The following files need to be updated or removed as part of migrating from `std/settings` to `std/conf`:

### Files to Remove
1. **Rust implementation**: `src/modules/settings/mod.rs` - Old native settings module
2. **Tests**: `test/settings/` directory - Tests for old settings module
3. **Documentation**: `docs/docs/stdlib/settings.md` - Old settings documentation
4. **Draft specs**: `specs/drafts/std_settings.md`, `specs/drafts/module_settings.md` - Superseded by this QEP

### Files to Update
1. **Documentation index**: `docs/docs/stdlib/index.md` - Remove settings from module list
2. **CLAUDE.md**: Remove `std/settings` from Standard Library section
3. **QEP-004** (Logging Framework): Update to use `std/conf` instead of `std/settings`
4. **QEP-028** (Serve Command): Update to use `std/conf` instead of `std/settings`
5. **QEP-051** (Web Server Configuration): Update to use `std/conf` instead of `std/settings`
6. **lib/std/log.q**: Update if it references settings (check implementation)
7. **.gitignore**: Update `.settings.toml` → `quest.local.toml`
8. **Example files**: Rename `.settings.local.example.toml` → `quest.local.example.toml`

### Verification
After cleanup, verify no references remain:
```bash
# Should return no results
grep -r "std/settings" --exclude-dir=.git --exclude-dir=target
grep -r "\.settings\.toml" --exclude-dir=.git --exclude-dir=target
```

## References

- [QEP-028: Serve Command](qep-028-serve-command.md) - Web server specification (needs update)
- [QEP-004: Logging Framework](qep-004-logging-framework.md) - Configuration type pattern (needs update)
- [QEP-051: Web Server Configuration](qep-051-web-server-configuration.md) - Web server configuration API (needs update)
- [quest.toml](../quest.toml) - Example configuration file
- [TOML Specification](https://toml.io/) - TOML format reference
