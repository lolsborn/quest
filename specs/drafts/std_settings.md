# std/settings Module - Specification

## Overview

The `std/settings` module provides runtime access to configuration loaded from `.settings.toml` files. On interpreter startup, if a `.settings.toml` file exists in the current working directory, it is automatically loaded. The configuration is then accessible to any Quest script via the `std/settings` module.

## Purpose

- Access configuration values loaded from `.settings.toml`
- Automatic environment variable setup via `[os.environ]` section on startup
- Type-safe configuration access with defaults
- Hierarchical settings with dot-notation paths
- Clean separation of code and configuration

## Module Interface

### Loading Settings

Settings are automatically loaded by the Quest interpreter on startup:

1. **Automatic loading**: On interpreter startup, Quest looks for `.settings.toml` in the current working directory
2. **If file exists**: Settings are loaded into memory and `[os.environ]` values are applied to the process environment
3. **If file doesn't exist**: Module still works, all `get()` calls return `nil`

The loading happens once at interpreter startup, before any Quest code executes. This makes settings immediately available to all scripts.

### Access Methods

```quest
use "std/settings" as settings

# Get a setting value by path
let value = settings.get("database.url")

# Check if setting exists
let exists = settings.contains("app.debug")

# Get entire section as Dict
let db_config = settings.section("database")

# Get all settings as Dict
let all = settings.all()

# Get with default value
let port = settings.get("server.port") or 3000
```

## API Reference

### `settings.get(path)`

Get a setting value by dot-notation path.

**Parameters:**
- `path` (String): Dot-separated path to setting (e.g., "database.pool_size")

**Returns:** Value at path or `nil` if not found

**Examples:**
```quest
# Get simple value
let name = settings.get("app.name")  # "My Quest App"

# Get nested value
let pool = settings.get("database.pool_size")  # 10

# Non-existent path returns nil
let missing = settings.get("foo.bar")  # nil
```

**Path Resolution:**
```toml
[database]
pool_size = 10

[database.replica]
host = "replica.example.com"
```

```quest
settings.get("database.pool_size")      # 10
settings.get("database.replica.host")   # "replica.example.com"
```

### `settings.contains(path)`

Check if a setting exists at the given path.

**Parameters:**
- `path` (String): Dot-separated path to setting

**Returns:** `true` if exists, `false` otherwise

**Examples:**
```quest
if settings.contains("database.url")
    let url = settings.get("database.url")
    # connect to database
end

# Distinguish between nil value and missing key
if not settings.contains("optional.feature")
    puts("Feature not configured")
end
```

### `settings.section(name)`

Get an entire configuration section as a Dict.

**Parameters:**
- `name` (String): Section name (top-level key)

**Returns:** Dict with section contents or `nil` if section doesn't exist

**Examples:**
```toml
[database]
host = "localhost"
port = 5432
user = "admin"
```

```quest
let db_config = settings.section("database")
# Returns: {"host": "localhost", "port": 5432, "user": "admin"}

puts(db_config.host)  # "localhost"
puts(db_config.port)  # 5432

# Non-existent section returns nil
let missing = settings.section("nonexistent")  # nil
```

**Nested sections:**
```toml
[cache]
enabled = true

[cache.redis]
host = "localhost"
port = 6379
```

```quest
let cache = settings.section("cache")
# Returns: {"enabled": true, "redis": {"host": "localhost", "port": 6379}}

let redis = cache.redis
# Or: let redis = settings.section("cache.redis")
```

### `settings.all()`

Get all settings as a single Dict.

**Parameters:** None

**Returns:** Dict with entire configuration

**Examples:**
```quest
let config = settings.all()

# Iterate over all sections
for section_name in config.keys()
    puts("Section: ", section_name)
    let section = config[section_name]
    # ...
end

# Debug: print entire config
puts(json.stringify(settings.all()))
```

## .settings.toml File Format

### Basic Structure

```toml
# Top-level keys become sections
key = "value"

[section]
nested_key = "nested value"

[section.subsection]
deeply_nested = 123
```

### Supported Types

**Strings:**
```toml
name = "My App"
description = "A Quest application"
```

**Numbers:**
```toml
port = 3000
timeout = 30.5
```

**Booleans:**
```toml
debug = true
cache_enabled = false
```

**Arrays:**
```toml
allowed_hosts = ["localhost", "example.com"]
ports = [3000, 3001, 3002]
```

**Nested tables:**
```toml
[database]
host = "localhost"
port = 5432

[database.pool]
size = 10
timeout = 30
```

**Inline tables:**
```toml
server = { host = "0.0.0.0", port = 3000 }
```

### Special Section: [os.environ]

Environment variables are set via the `[os.environ]` section:

```toml
[os.environ]
DATABASE_URL = "postgresql://localhost/mydb"
API_KEY = "secret123"
REDIS_URL = "redis://localhost:6379"
ENVIRONMENT = "production"
```

**Behavior:**
1. On interpreter startup, values from `[os.environ]` are applied **on top of** the existing process environment
2. If a variable already exists in the environment, it will be overridden
3. Variables not in `[os.environ]` remain unchanged
4. These variables are accessible via standard environment variable access (e.g., `os.environ` module)
5. They are NOT accessible via `settings.get()` - use the `os` module instead

### Example Configuration

**Complete .settings.toml example:**

```toml
# Environment variables
[os.environ]
DATABASE_URL = "postgresql://user:pass@localhost/mydb"
REDIS_URL = "redis://localhost:6379"
SMTP_HOST = "smtp.gmail.com"
SMTP_USER = "user@example.com"
SMTP_PASS = "password"
API_KEY = "your-api-key-here"

# Application settings
[app]
name = "My Quest App"
version = "1.0.0"
debug = false
base_url = "https://example.com"

# Server configuration
[server]
host = "0.0.0.0"
port = 3000
workers = 4

# Database settings
[database]
pool_size = 10
timeout = 30
retry_attempts = 3
log_queries = false

[database.replica]
enabled = true
host = "replica.example.com"
port = 5432

# Cache settings
[cache]
enabled = true
ttl = 3600

[cache.redis]
host = "localhost"
port = 6379
db = 0

# Feature flags
[features]
enable_analytics = true
enable_uploads = true
max_upload_size = 10485760  # 10 MB

# External services
[services]
stripe_key = "pk_test_..."
sendgrid_key = "SG...."

[services.aws]
region = "us-east-1"
bucket = "my-app-bucket"

# Logging
[logging]
level = "info"
format = "json"
outputs = ["stdout", "file"]

[logging.file]
path = "/var/log/quest-app.log"
max_size = "100MB"
```

## Usage Examples

### Example 1: Database Configuration

**.settings.toml:**
```toml
[os.environ]
DATABASE_URL = "postgresql://localhost/mydb"

[database]
pool_size = 10
timeout = 30
retry_attempts = 3
```

**app.q:**
```quest
use "std/settings" as settings

# Get pool configuration from settings
let pool_size = settings.get("database.pool_size")
let timeout = settings.get("database.timeout")
let retry_attempts = settings.get("database.retry_attempts")

puts("Database configuration:")
puts("  Pool size: ", pool_size)
puts("  Timeout: ", timeout, "s")
puts("  Retry attempts: ", retry_attempts)
```

### Example 2: Feature Flags

**.settings.toml:**
```toml
[features]
enable_analytics = true
enable_uploads = false
max_upload_size = 10485760
allow_beta_features = false
```

**app.q:**
```quest
use "std/settings" as settings

fun handle_request(request)
    if request.path == "/upload"
        if not settings.get("features.enable_uploads")
            return {"status": 403, "body": "Uploads disabled"}
        end

        let max_size = settings.get("features.max_upload_size")
        # Handle upload with max_size limit
    end

    if settings.get("features.enable_analytics")
        # Track analytics
    end

    # ... rest of handler
end
```

### Example 3: Multi-Environment Setup

**Use different settings files for different environments:**

**.settings.development.toml:**
```toml
[os.environ]
DATABASE_URL = "postgresql://localhost/mydb_dev"

[app]
debug = true
base_url = "http://localhost:3000"
```

**.settings.production.toml:**
```toml
[os.environ]
DATABASE_URL = "postgresql://prod-db.example.com/mydb"

[app]
debug = false
base_url = "https://myapp.com"
```

Then use symbolic link or copy:
```bash
# Development
ln -sf .settings.development.toml .settings.toml

# Production
ln -sf .settings.production.toml .settings.toml
```

### Example 4: External Service Configuration

**.settings.toml:**
```toml
[os.environ]
STRIPE_SECRET_KEY = "sk_test_..."
SENDGRID_API_KEY = "SG...."

[services.stripe]
webhook_secret = "whsec_..."
timeout = 30

[services.sendgrid]
from_email = "noreply@example.com"
from_name = "My App"
max_retries = 3
```

**app.q:**
```quest
use "std/settings" as settings

# Get service configuration
let stripe_config = settings.section("services.stripe")
let sendgrid_config = settings.section("services.sendgrid")

puts("Stripe webhook secret: ", stripe_config.webhook_secret)
puts("Stripe timeout: ", stripe_config.timeout)

puts("SendGrid from: ", sendgrid_config.from_name, " <", sendgrid_config.from_email, ">")
puts("SendGrid max retries: ", sendgrid_config.max_retries)
```

### Example 5: Runtime Configuration

**Check settings at runtime to configure behavior:**

```quest
use "std/settings" as settings

# Get entire app configuration
let app_config = settings.section("app")

if app_config.debug
    puts("Debug mode enabled")
    puts("All settings: ", settings.all())
end

# Configure based on settings
let max_retries = settings.get("database.retry_attempts") or 3
let timeout = settings.get("server.timeout") or 30

puts("Server configured with:")
puts("  Max retries: ", max_retries)
puts("  Timeout: ", timeout, "s")
```

## Implementation Details

### Rust Module Structure

**src/modules/settings/mod.rs**

```rust
use std::collections::HashMap;
use toml::Value as TomlValue;

pub struct QSettings {
    data: HashMap<String, TomlValue>,
    id: u64,
}

impl QSettings {
    pub fn from_toml(toml_str: &str) -> Result<Self, String> {
        let data: HashMap<String, TomlValue> = toml::from_str(toml_str)
            .map_err(|e| format!("Failed to parse TOML: {}", e))?;

        Ok(QSettings {
            data,
            id: next_object_id(),
        })
    }

    pub fn get(&self, path: &str) -> Option<QValue> {
        // Split path and navigate nested structure
        // Convert TomlValue to QValue
    }

    pub fn has(&self, path: &str) -> bool {
        // Check if path exists
    }

    pub fn section(&self, name: &str) -> Option<QValue> {
        // Get entire section as Dict
    }

    pub fn all(&self) -> QValue {
        // Return all settings as Dict
    }
}

pub fn create_settings_module(settings: QSettings) -> QValue {
    // Create module with get, has, section, all functions
}

pub fn call_settings_function(
    func_name: &str,
    args: Vec<QValue>,
    settings: &QSettings
) -> Result<QValue, String> {
    match func_name {
        "settings.get" => { /* ... */ }
        "settings.has" => { /* ... */ }
        "settings.section" => { /* ... */ }
        "settings.all" => { /* ... */ }
        _ => Err(format!("Unknown function: {}", func_name))
    }
}
```

### Type Conversion

**TOML → Quest types:**

| TOML Type | Quest Type |
|-----------|------------|
| String | Str |
| Integer | Num |
| Float | Num |
| Boolean | Bool |
| Array | Array |
| Table | Dict |

### Environment Variable Handling

When loading `.settings.toml` on interpreter startup:

1. Parse entire TOML file
2. Check for `[os.environ]` section
3. For each key-value pair in `[os.environ]`:
   - Call `std::env::set_var(key, value)` to apply to process environment
4. Remove `[os.environ]` section from the data structure
5. Store remaining sections in global settings data (accessible via `std/settings` module)

## Error Handling

### TOML Parsing Errors

If `.settings.toml` has invalid syntax:
- Interpreter fails to start with a clear error message
- Error message shows line number and parsing issue
- Example: "Failed to parse .settings.toml: expected '=' at line 5"

### Type Errors

Settings values are returned as-is. Type checking is up to the script:

```quest
# Settings contains string "3000"
let port = settings.get("server.port")  # Returns "3000" (string)

# Script must convert if needed
let port_num = port.to_num()  # Convert to number
```

**Better approach:** Use proper types in TOML:
```toml
[server]
port = 3000  # Number, not string
```

### Missing Settings

Missing settings return `nil`. Always provide defaults:

```quest
# Good: with default
let port = settings.get("server.port") or 3000

# Bad: might be nil
let port = settings.get("server.port")
if port == nil
    # Handle error...
end
```

## Security Considerations

### Sensitive Data

**DO:**
- Store secrets in `[os.environ]`
- Use environment-specific settings files
- Add `.settings.toml` to `.gitignore`
- Use `.settings.example.toml` for documentation

**DON'T:**
- Commit secrets to version control
- Log full settings in production
- Expose settings via HTTP endpoints

### Example .gitignore

```
.settings.toml
.settings.*.toml
!.settings.example.toml
```

### Example .settings.example.toml

```toml
# Example settings file
# Copy to .settings.toml and fill in your values

[os.environ]
DATABASE_URL = "postgresql://user:pass@localhost/dbname"
API_KEY = "your-api-key-here"

[app]
name = "My App"
debug = false
```

## Testing

### Unit Tests

**test/settings/basic_test.q**
```quest
use "std/test" as test
use "std/settings" as settings

test.module("Settings")

test.describe("get", fun ()
    test.it("retrieves simple values", fun ()
        let value = settings.get("app.name")
        test.assert_type(value, "Str")    end)

    test.it("returns nil for missing keys", fun ()
        let value = settings.get("nonexistent.key")
        test.assert_nil(value)    end)
end)
```

### Integration Tests

Test with actual `.settings.toml` file loading.

## Documentation

**docs/docs/stdlib/settings.md** (~200 lines)
- Module overview
- API reference
- .settings.toml format
- Usage examples
- Best practices
- Security guidelines

**Update docs/docs/stdlib/index.md:**
- Add settings to module list

**Update CLAUDE.md:**
- Document settings module and automatic loading on startup
- Explain [os.environ] section behavior

## Future Enhancements

- **Validation schemas** - Define required/optional settings
- **Type coercion** - Automatic string → number conversion
- **Environment variable substitution** - `url = "${DATABASE_URL}/path"`
- **Settings reloading** - Watch file for changes (hot reload)
- **Encrypted settings** - Decrypt sensitive values
- **Remote configuration** - Load from configuration service
- **Settings inheritance** - Extend base configuration

## Success Criteria

- ✅ Automatic loading on interpreter startup
- ✅ Easy access to configuration from any Quest script
- ✅ Clean separation of code and config
- ✅ Environment variables applied seamlessly via [os.environ]
- ✅ Type-safe with proper defaults
- ✅ Secure handling of sensitive data
- ✅ Clear error messages for common mistakes
- ✅ Well-documented with examples
