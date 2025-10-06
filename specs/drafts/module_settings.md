# Module Settings

**Status:** Proposed
**Version:** 1.0
**Last Updated:** 2025-10-03

## Overview

Quest modules can declare configuration schemas that are automatically populated from `.settings.toml` on interpreter startup. This provides a centralized, type-safe configuration mechanism where modules explicitly publish their configuration options.

Settings are declared using standard Quest dictionary syntax (`let settings = {...}`), requiring no new grammar rules or special syntax.

## Motivation

**Problem:** Current configuration approaches have limitations:
1. Modules read from `std/settings` ad-hoc with no schema declaration
2. No way to know what configuration a module expects without reading its code
3. No validation or defaults at the module level
4. Configuration scattered across module implementation

**Solution:** Modules declare settings schemas with defaults and validation. On startup, Quest populates these from `.settings.toml` and makes them available to the module during initialization.

## How It Works

### Lifecycle

1. **Interpreter Startup:**
   - Load `.settings.toml` (existing behavior)
   - Parse module settings declarations from overlay files
   - Populate module settings from `.settings.toml` values
   - Store in memory (not yet accessible to modules)

2. **Module Import:**
   - User executes `use "std/mymodule" as mymodule`
   - Module initialization code runs
   - Module can access its settings via special `__settings__` variable
   - Settings used to configure module behavior

3. **Runtime:**
   - Settings are read-only after initialization
   - Modules access via their internal variables (set during init)
   - No direct access to `__settings__` after initialization

### Settings Declaration Syntax

Modules declare settings by exporting a `Settings` type:

**lib/std/mymodule.q:**
```quest
use "std/validate" as v

type Settings
    str: host
    num: port
    bool: debug
    num: timeout
    num?: max_connections      # Optional (no default required)
    array: allowed_origins

    fun validate_port(value)
        v.range(1, 65535)(value)
    end

    fun validate_timeout(value)
        v.min(0)(value)
    end
end

# Module initialization - access via __settings__
let HOST = __settings__.host
let PORT = __settings__.port
let DEBUG = __settings__.debug
let TIMEOUT = __settings__.timeout
let MAX_CONNECTIONS = __settings__.max_connections or 100
let ALLOWED_ORIGINS = __settings__.allowed_origins

# Module functions use the initialized constants
fun connect()
    "Connecting to " .. HOST .. ":" .. PORT
end

fun is_debug_enabled()
    DEBUG
end
```

**Settings type features:**
- Uses standard Quest type system with validation
- Optional fields with `?` syntax
- Field validators using `validate_<field_name>` pattern
- Cross-field validation with `validate()` method
- Type checking enforced by type annotations

### .settings.toml Mapping

Settings are populated from `.settings.toml` using a section matching the module path:

**.settings.toml:**
```toml
[mymodule]
host = "example.com"
port = 8080
debug = true
timeout = 60
max_connections = 200
allowed_origins = ["https://example.com", "https://app.example.com"]

[db.postgres]
host = "localhost"
port = 5432
database = "mydb"
pool_size = 10
```

**Module path to section mapping:**
- `std/mymodule` → `[mymodule]` section
- `std/db/postgres` → `[db.postgres]` section
- `std/encoding/json` → `[encoding.json]` section
- `myproject/utils` → `[myproject.utils]` section

**Default values:**
When a field is not in `.settings.toml`, you must provide defaults during module initialization:

```quest
type Settings
    str: host
    num: port
end

# Provide defaults for missing values
let HOST = __settings__.host or "localhost"
let PORT = __settings__.port or 3000
```

Alternatively, make fields optional and provide defaults:

```quest
type Settings
    str?: host
    num?: port
end

let HOST = __settings__.host or "localhost"
let PORT = __settings__.port or 3000
```

### __settings__ Variable

During module initialization, the special `__settings__` variable is available:

**Properties:**
- Type: Instance of the module's `Settings` type
- Scope: Only available during module-level code execution
- Contents: Validated settings constructed from `.settings.toml`
- Immutable: Settings cannot be modified

**Example:**
```quest
use "std/validate" as v

type Settings
    str?: api_key
    num: timeout

    fun validate_timeout(value)
        v.min(0)(value)
    end
end

# Initialize module constants from settings
let API_KEY = __settings__.api_key
let TIMEOUT = __settings__.timeout

if API_KEY == nil
    puts("[WARN] mymodule: No API key configured")
end

# __settings__ is not accessible after initialization
fun get_timeout()
    TIMEOUT  # Use the constant, not __settings__
end
```

## Complete Examples

### Example 1: Database Module

**lib/std/db/postgres.q:**
```quest
use "std/validate" as v

type Settings
    str: host
    num: port
    str: database
    str: user
    str?: password           # Optional, can come from env var
    num: pool_size
    num: timeout
    str: ssl_mode

    fun validate_port(value)
        v.range(1, 65535)(value)
    end

    fun validate_pool_size(value)
        v.range(1, 1000)(value)
    end

    fun validate_timeout(value)
        v.min(0)(value)
    end

    fun validate_ssl_mode(value)
        v.one_of(["disable", "allow", "prefer", "require", "verify-ca", "verify-full"])(value)
    end
end

# Initialize from settings
let DEFAULT_HOST = __settings__.host
let DEFAULT_PORT = __settings__.port
let DEFAULT_DATABASE = __settings__.database
let DEFAULT_USER = __settings__.user
let DEFAULT_PASSWORD = __settings__.password
let DEFAULT_POOL_SIZE = __settings__.pool_size
let DEFAULT_TIMEOUT = __settings__.timeout
let DEFAULT_SSL_MODE = __settings__.ssl_mode

# Document Rust function
%fun connect(connection_string)

"""
Connect to PostgreSQL database.

If connection_string is nil, uses default settings from .settings.toml [db.postgres] section.
"""

fun connect(connection_string)
    if connection_string == nil
        # Build from settings
        let password_part = if DEFAULT_PASSWORD != nil
            ":" .. DEFAULT_PASSWORD
        else
            ""
        end

        connection_string = "postgresql://" .. DEFAULT_USER .. password_part ..
                          "@" .. DEFAULT_HOST .. ":" .. DEFAULT_PORT ..
                          "/" .. DEFAULT_DATABASE
    end

    __builtin__.connect(connection_string)
end

# Re-export builtin
let _connect = __builtin__.connect
```

**.settings.toml:**
```toml
[db.postgres]
host = "db.example.com"
port = 5432
database = "myapp_production"
user = "myapp"
password = "secret123"
pool_size = 20
timeout = 60
ssl_mode = "require"
```

**Usage:**
```quest
use "std/db/postgres" as db

# Use settings-based defaults
let conn = db.connect(nil)  # Uses .settings.toml values

# Or override with explicit connection string
let conn2 = db.connect("postgresql://localhost/testdb")
```

### Example 2: HTTP Server Module

**lib/std/http/server.q:**
```quest
use "std/validate" as v

type Settings
    str: host
    num: port
    num: workers
    num: timeout
    num: max_request_size    # 10MB default
    array: allowed_origins
    bool: enable_compression
    bool: log_requests

    fun validate_port(value)
        v.range(1, 65535)(value)
    end

    fun validate_workers(value)
        v.range(1, 256)(value)
    end

    fun validate_timeout(value)
        v.min(1)(value)
    end

    fun validate_max_request_size(value)
        v.range(1024, 1073741824)(value)  # 1KB to 1GB
    end
end

let HOST = __settings__.host
let PORT = __settings__.port
let WORKERS = __settings__.workers
let TIMEOUT = __settings__.timeout
let MAX_REQUEST_SIZE = __settings__.max_request_size
let ALLOWED_ORIGINS = __settings__.allowed_origins
let ENABLE_COMPRESSION = __settings__.enable_compression
let LOG_REQUESTS = __settings__.log_requests

fun serve(handler)
    """
    Start HTTP server with settings from .settings.toml [http.server] section.

    Parameters:
      handler: Function that handles requests
    """

    if LOG_REQUESTS
        puts("[HTTP] Starting server on ", HOST, ":", PORT)
        puts("[HTTP] Workers: ", WORKERS, ", Timeout: ", TIMEOUT, "s")
    end

    __builtin__.serve(handler, {
        host: HOST,
        port: PORT,
        workers: WORKERS,
        timeout: TIMEOUT,
        max_request_size: MAX_REQUEST_SIZE,
        allowed_origins: ALLOWED_ORIGINS,
        enable_compression: ENABLE_COMPRESSION
    })
end

let listen = serve  # Alias
```

**.settings.toml:**
```toml
[http.server]
host = "0.0.0.0"
port = 3000
workers = 8
timeout = 60
max_request_size = 52428800  # 50MB
allowed_origins = ["https://myapp.com"]
enable_compression = true
log_requests = true
```

### Example 3: Conditional Configuration

**lib/std/cache.q:**
```quest
use "std/validate" as v

type Settings
    bool: enabled
    str: backend          # "memory", "redis", "memcached"
    num: ttl
    num: max_size
    str: redis_host
    num: redis_port
    num: redis_db

    fun validate_backend(value)
        v.one_of(["memory", "redis", "memcached"])(value)
    end

    fun validate_ttl(value)
        v.min(0)(value)
    end

    fun validate_max_size(value)
        v.min(1)(value)
    end

    fun validate_redis_port(value)
        v.range(1, 65535)(value)
    end

    fun validate_redis_db(value)
        v.range(0, 15)(value)
    end
end

use "std/os" as os

let ENABLED = __settings__.enabled
let BACKEND = __settings__.backend
let TTL = __settings__.ttl
let MAX_SIZE = __settings__.max_size

# Backend-specific initialization
if BACKEND == "redis"
    use "std/redis" as redis
    let REDIS_CLIENT = redis.connect(
        __settings__.redis_host,
        __settings__.redis_port,
        __settings__.redis_db
    )
elif BACKEND == "memory"
    # Use in-memory cache
    let CACHE_STORAGE = {}
end

fun get(key)
    """Get value from cache."""
    if not ENABLED
        return nil
    end

    if BACKEND == "redis"
        REDIS_CLIENT.get(key)
    elif BACKEND == "memory"
        CACHE_STORAGE[key]
    end
end

fun set(key, value, ttl)
    """Set value in cache."""
    if not ENABLED
        return nil
    end

    let actual_ttl = ttl or TTL

    if BACKEND == "redis"
        REDIS_CLIENT.setex(key, actual_ttl, value)
    elif BACKEND == "memory"
        CACHE_STORAGE[key] = value
        # TODO: Implement expiration for memory backend
    end
end
```

**.settings.toml:**
```toml
[cache]
enabled = true
backend = "redis"
ttl = 7200
max_size = 10000
redis_host = "cache.example.com"
redis_port = 6379
redis_db = 1
```

## Settings Type

### Overview

Modules export a `Settings` type that defines their configuration schema. The type uses Quest's standard type system with optional fields and validators.

**Properties:**
- `Settings` is a user-defined Quest type
- Fields define configuration options with types
- Optional fields use `?` syntax
- Validators use `validate_<field_name>` methods
- Cross-field validation with `validate()` method

### Grammar

**No new grammar rules needed** - uses existing type system:

```quest
type Settings
    str: host
    num: port
    bool?: debug
end
```

The interpreter recognizes a type named `Settings` at module-level scope as the module's configuration schema.

### Validation Rules

1. **Type Consistency:**
   - Value from `.settings.toml` must match declared type
   - Arrays must have consistent element types
   - Dicts can have mixed value types

2. **Required vs Optional:**
   - If default is `nil` → setting is optional
   - If default is non-nil → setting has default value
   - Missing optional settings remain `nil`
   - Missing settings with defaults use declared default

3. **Naming:**
   - Setting names must be valid identifiers
   - Use snake_case by convention
   - No duplicate names within a module

### Error Handling

**Startup errors (interpreter won't start):**
```
Error in .settings.toml: Type mismatch for [mymodule].port
  Expected: Num
  Got: Str ("8080")

Error in lib/std/mymodule.q: Duplicate setting name 'timeout'

Error loading module settings: [db.postgres] section references undefined setting 'invalid_option'
```

**Runtime warnings (logged but don't stop startup):**
```
[WARN] Module 'mymodule' declares settings but no [mymodule] section in .settings.toml
[WARN] .settings.toml [mymodule] section has unknown key 'unknown_setting'
```

## Implementation Details

### Settings Storage

```rust
// Global registry for module settings
lazy_static! {
    static ref MODULE_SETTINGS: RwLock<HashMap<String, HashMap<String, QValue>>> =
        RwLock::new(HashMap::new());
}

// Store settings for a module
fn register_module_settings(module_path: &str, settings: HashMap<String, QValue>) {
    let mut registry = MODULE_SETTINGS.write().unwrap();
    registry.insert(module_path.to_string(), settings);
}

// Get settings for a module
fn get_module_settings(module_path: &str) -> Option<HashMap<String, QValue>> {
    let registry = MODULE_SETTINGS.read().unwrap();
    registry.get(module_path).cloned()
}
```

### Startup Sequence

```rust
fn initialize_interpreter() -> Result<(), String> {
    // 1. Load .settings.toml
    let toml_settings = load_settings_toml()?;

    // 2. Discover all module overlay files
    let overlay_files = discover_overlay_files("lib/")?;

    // 3. Find Settings types in each overlay
    for (module_path, overlay_path) in overlay_files {
        let settings_type = find_settings_type(&overlay_path)?;

        if let Some(type_def) = settings_type {
            // 4. Get corresponding TOML section
            let section_name = module_path_to_toml_section(&module_path);
            let toml_section = toml_settings.get(&section_name);

            if let Some(section) = toml_section {
                // 5. Construct Settings instance (with validation)
                let settings_instance = construct_settings_from_toml(
                    &type_def,
                    section,
                    &module_path
                )?;

                // 6. Store in registry
                register_module_settings(&module_path, settings_instance);
            } else {
                // No TOML section - all fields must be optional
                // or module will handle defaults
                let empty = HashMap::new();
                let settings_instance = construct_settings_from_toml(
                    &type_def,
                    &empty,
                    &module_path
                )?;
                register_module_settings(&module_path, settings_instance);
            }
        }
    }

    Ok(())
}

fn module_path_to_toml_section(module_path: &str) -> String {
    // "std/db/postgres" -> "db.postgres"
    // "mymodule" -> "mymodule"
    module_path
        .strip_prefix("std/")
        .unwrap_or(module_path)
        .replace("/", ".")
}
```

### Module Loading with Settings

```rust
fn load_module(module_path: &str, scope: &mut Scope) -> Result<QValue, String> {
    let rust_module = get_builtin_module(module_path)?;

    let overlay_path = resolve_overlay_path(module_path)?;

    if let Some(path) = overlay_path {
        let mut overlay_scope = Scope::new();
        overlay_scope.set("__builtin__", rust_module.clone());

        // Add __settings__ to scope if module has settings
        if let Some(settings) = get_module_settings(module_path) {
            let settings_dict = QValue::Dict(QDict::new(settings));
            overlay_scope.set("__settings__", settings_dict);
        }

        let overlay_source = std::fs::read_to_string(&path)?;
        eval_expression(&overlay_source, &mut overlay_scope)?;

        // Remove __settings__ from final scope (not part of module exports)
        overlay_scope.remove("__settings__");

        // Build merged module
        let mut merged_members = HashMap::new();

        if let QValue::Module(m) = &rust_module {
            for (name, value) in m.members() {
                merged_members.insert(name.clone(), value.clone());
            }
        }

        for (key, value) in overlay_scope.variables() {
            if key != "__builtin__" && key != "__settings__" {
                merged_members.insert(key.clone(), value.clone());
            }
        }

        Ok(QValue::Module(QModule::new(module_path.to_string(), merged_members)))
    } else {
        Ok(rust_module)
    }
}
```

### Settings Type Detection

```rust
fn find_settings_type(overlay_path: &str) -> Result<Option<QType>, String> {
    let source = std::fs::read_to_string(overlay_path)?;

    // Parse the overlay file in a temporary scope
    let mut temp_scope = Scope::new();
    eval_expression(&source, &mut temp_scope)?;

    // Check if 'Settings' type was declared
    if let Some(type_value) = temp_scope.get("Settings") {
        if let QValue::Type(settings_type) = type_value {
            return Ok(Some(settings_type.clone()));
        } else {
            return Err(format!(
                "Module 'Settings' must be a type, got {}",
                type_value.cls()
            ));
        }
    }

    Ok(None)  // No Settings type declared
}
```

### Settings Instance Construction

```rust
fn construct_settings_from_toml(
    settings_type: &QType,
    toml_section: &HashMap<String, toml::Value>,
    module_path: &str
) -> Result<QValue, String> {
    // Convert TOML values to QValues
    let mut args = HashMap::new();
    for (key, toml_value) in toml_section {
        args.insert(key.clone(), toml_to_qvalue(toml_value));
    }

    // Construct Settings instance using type system
    // This automatically:
    // 1. Checks required fields are provided
    // 2. Validates types match field annotations
    // 3. Runs validate_<field> methods
    // 4. Runs validate() method for cross-field validation
    construct_type_instance(settings_type, args)
}
```

## Benefits

1. **Centralized Configuration:** All module settings in one `.settings.toml` file
2. **Self-Documenting:** Module declares what it needs with defaults
3. **Type-Safe:** Settings validated on startup, not at runtime
4. **IDE Support:** Settings schema enables autocomplete in editors
5. **Defaults:** Modules work out-of-box with sensible defaults
6. **Environment-Specific:** Easy to swap `.settings.toml` for dev/staging/prod
7. **Discovery:** Can generate documentation from settings declarations

## Best Practices

### 1. Provide Sensible Defaults

```quest
let settings = Settings({
    timeout: 30,          # Good: Works out of box
    api_key: nil          # Good: Optional, document in module _doc
})

let settings = Settings({
    timeout: nil          # Bad: Forces every user to configure
})
```

### 2. Document Settings in Module _doc

```quest
"""
My Module

Configuration (.settings.toml [mymodule] section):
  - timeout: Num - Request timeout in seconds (default: 30, min: 0)
  - api_key: Str - API key for authentication (required)
  - debug: Bool - Enable debug logging (default: false)
"""

let settings = Settings({
    timeout: 30,
    api_key: nil,
    debug: false
}, {
    timeout: Settings.min(0)
})
```

### 3. Validate Critical Settings

```quest
let settings = {
    api_key: nil
}

let API_KEY = __settings__.api_key

if API_KEY == nil
    raise "mymodule requires api_key in .settings.toml [mymodule] section"
end
```

### 4. Use Environment Variables for Secrets

**.settings.toml:**
```toml
[os.environ]
DB_PASSWORD = "secret123"
API_KEY = "sk-..."

[db.postgres]
password = "${DB_PASSWORD}"  # Reference env var
```

**lib/std/db/postgres.q:**
```quest
use "std/os" as os

let settings = {
    password: nil
}

let PASSWORD = __settings__.password or os.getenv("DB_PASSWORD")
```

## Limitations

1. **Read-Only:** Settings cannot be modified after startup
2. **Static Types:** No complex type validation (e.g., "port must be 1-65535")
3. **No Nesting:** Settings are flat key-value pairs (use dicts for nested structures)
4. **Startup Only:** Settings loaded once; no hot-reloading

## Future Enhancements

1. **Type Annotations:** `port: Num(1..65535)` for range validation
2. **Required Settings:** `api_key!: Str` to mark as required
3. **Setting Groups:** Group related settings for better organization
4. **Setting Inheritance:** Child modules inherit parent settings
5. **Runtime Validation:** Custom validation functions
6. **Hot Reload:** Detect `.settings.toml` changes and reload

## See Also

- [std/settings](../docs/stdlib/settings.md) - Runtime settings access
- [Module Shadowing](stdlib_shadowing.md) - Module overlay system
- [Configuration Best Practices](#) - General configuration patterns
