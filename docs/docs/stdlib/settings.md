# settings - Global settings / Configuration

Configuration management for Quest applications via `.settings.toml` files.

## Overview

The `std/settings` module provides runtime access to configuration loaded from `.settings.toml` files. On interpreter startup, if a `.settings.toml` file exists in the current working directory, it is automatically loaded and made accessible to all Quest scripts.

**Key features:**
- Automatic loading on interpreter startup
- Hierarchical configuration with dot-notation paths
- Environment variable setup via `[os.environ]` section
- Type-safe configuration access with defaults
- Clean separation of code and configuration

## Quick Start

**Create `.settings.toml` in your project directory:**

```toml
[os.environ]
DATABASE_URL = "postgresql://localhost/mydb"

[app]
name = "My Quest App"
debug = true
port = 3000

[database]
pool_size = 10
timeout = 30
```

**Access settings in your Quest script:**

```quest
use "std/settings" as settings

let app_name = settings.get("app.name")
let port = settings.get("app.port") or 3000
let pool_size = settings.get("database.pool_size")

puts("Starting ", app_name, " on port ", port)
```

## How It Works

### Automatic Loading

1. When Quest starts, it looks for `.settings.toml` in the current working directory
2. If found, the file is parsed and loaded into memory
3. Values from `[os.environ]` are applied to the process environment
4. Remaining settings are accessible via the `std/settings` module
5. All Quest code can then access these settings

### File Location

The `.settings.toml` file must be in the **current working directory** when Quest starts:

```bash
# Settings loaded from current directory
quest my_script.q

# Settings loaded from /path/to/project/
cd /path/to/project
quest my_script.q
```

## API Reference

### `settings.get(path)`

Get a setting value by dot-notation path.

**Parameters:**
- `path` (Str): Dot-separated path to setting

**Returns:** Value at path or `nil` if not found

**Examples:**

```quest
use "std/settings" as settings

# Simple values
let name = settings.get("app.name")         # "My Quest App"
let debug = settings.get("app.debug")       # true
let port = settings.get("app.port")         # 3000

# Nested values
let pool_size = settings.get("database.pool_size")          # 10
let redis_host = settings.get("cache.redis.host")           # "localhost"

# Missing values return nil
let missing = settings.get("nonexistent.key")  # nil

# Use defaults with 'or'
let timeout = settings.get("server.timeout") or 30
```

### `settings.contains(path)`

Check if a setting exists at the given path.

**Parameters:**
- `path` (Str): Dot-separated path to setting

**Returns:** `true` if exists, `false` otherwise

**Examples:**

```quest
use "std/settings" as settings

if settings.contains("database.url")
    let url = settings.get("database.url")
    # connect to database
else
    puts("Database not configured")
end

# Check nested paths
if settings.contains("cache.redis.port")
    puts("Redis caching enabled")
end
```

### `settings.section(name)`

Get an entire configuration section as a Dict.

**Parameters:**
- `name` (Str): Section name (can use dot-notation for nested sections)

**Returns:** Dict with section contents or `nil` if section doesn't exist

**Examples:**

```quest
use "std/settings" as settings

# Get top-level section
let app_config = settings.section("app")
# Returns: {name: "My Quest App", debug: true, port: 3000}

puts(app_config.name)   # "My Quest App"
puts(app_config.port)   # 3000

# Get nested section
let redis_config = settings.section("cache.redis")
# Returns: {host: "localhost", port: 6379, db: 0}

# Missing section returns nil
let missing = settings.section("nonexistent")  # nil
```

### `settings.all()`

Get all settings as a single Dict.

**Parameters:** None

**Returns:** Dict with entire configuration (excludes `[os.environ]`)

**Examples:**

```quest
use "std/settings" as settings

let config = settings.all()

# Iterate over all sections
for section_name in config.keys()
    puts("Section: ", section_name)
end

# Debug: print entire config
use "std/encoding/json" as json
puts(json.stringify(config))
```

## .settings.toml Format

### Basic Structure

Settings are organized in TOML sections:

```toml
# Top-level values
version = "1.0.0"

# Sections
[app]
name = "My App"
debug = true

# Nested sections
[database.pool]
min_connections = 2
max_connections = 10
```

### Supported Types

**Strings:**
```toml
name = "My Application"
description = "A Quest app"
```

**Numbers:**
```toml
port = 3000           # Integer
timeout = 30.5        # Float
```

**Booleans:**
```toml
debug = true
enabled = false
```

**Arrays:**
```toml
allowed_hosts = ["localhost", "example.com"]
ports = [3000, 3001, 3002]
```

**Nested Tables:**
```toml
[database]
host = "localhost"
port = 5432

[database.pool]
size = 10
timeout = 30
```

### Type Conversion

TOML types are automatically converted to Quest types:

| TOML Type | Quest Type | Example |
|-----------|------------|---------|
| String | Str | `"hello"` → `"hello"` |
| Integer | Num | `42` → `42` |
| Float | Num | `3.14` → `3.14` |
| Boolean | Bool | `true` → `true` |
| Array | Array | `[1, 2, 3]` → `[1, 2, 3]` |
| Table | Dict | `{a = 1}` → `{a: 1}` |

## Environment Variables

### The [os.environ] Section

The special `[os.environ]` section sets environment variables:

```toml
[os.environ]
DATABASE_URL = "postgresql://localhost/mydb"
API_KEY = "secret_key_123"
REDIS_URL = "redis://localhost:6379"
```

**Behavior:**
1. Values are applied **on top of** existing environment variables on startup
2. If a variable already exists, it will be overridden
3. These variables are **not** accessible via `settings.get()`
4. Access them via `os.getenv()` instead
5. The `[os.environ]` section is removed from settings data

**Example:**

```quest
use "std/settings" as settings
use "std/os" as os

# Environment variable (from [os.environ])
let db_url = os.getenv("DATABASE_URL")

# Application setting (from other sections)
let pool_size = settings.get("database.pool_size")
```

## Usage Patterns

### Database Configuration

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
use "std/os" as os
use "std/db/postgres" as db

let db_url = os.getenv("DATABASE_URL")
let pool_size = settings.get("database.pool_size")

puts("Connecting with pool size: ", pool_size)
let conn = db.connect(db_url)
```

### Feature Flags

**.settings.toml:**
```toml
[features]
enable_analytics = true
enable_uploads = false
max_upload_size = 10485760
```

**app.q:**
```quest
use "std/settings" as settings

fun handle_upload(file)
    if not settings.get("features.enable_uploads")
        return "Uploads are disabled"
    end

    let max_size = settings.get("features.max_upload_size")
    if file.size > max_size
        return "File too large"
    end

    # Process upload...
end
```

### Multi-Environment Setup

Quest supports a hierarchical configuration system with automatic merging:

```
┌─────────────────────────────────────────────────────────────┐
│                    Configuration Loading                    │
│                      (Last wins)                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. quest.toml                                              │
│     └─> Base configuration (committed to git)              │
│         • Default values for all environments              │
│         • Shared settings                                  │
│                                                             │
│  2. settings.<env>.toml                                     │
│     └─> Environment-specific (committed to git)            │
│         • Development: settings.dev.toml                   │
│         • Staging: settings.staging.toml                   │
│         • Production: settings.prod.toml                   │
│         • Overrides quest.toml values                      │
│                                                             │
│  3. settings.local.toml                                     │
│     └─> Local overrides (NOT committed, in .gitignore)     │
│         • Developer-specific settings                      │
│         • Secrets and credentials                          │
│         • Overrides all previous files                     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Example setup:**

**quest.toml** (base settings):
```toml
[app]
name = "My App"
port = 3000
debug = false

[database]
pool_size = 10
```

**settings.dev.toml** (development):
```toml
[os.environ]
DATABASE_URL = "postgresql://localhost/mydb_dev"

[app]
debug = true
base_url = "http://localhost:3000"
```

**settings.prod.toml** (production):
```toml
[os.environ]
DATABASE_URL = "postgresql://prod-db.example.com/mydb"

[app]
base_url = "https://myapp.com"
```

**settings.local.toml** (your local machine, gitignored):
```toml
[os.environ]
API_KEY = "your-secret-key"

[app]
port = 8080  # Override for local testing
```

Use environment variable to select configuration:
```bash
# Development
export QUEST_ENV=dev
quest app.q

# Production
export QUEST_ENV=prod
quest app.q

# Without QUEST_ENV, only quest.toml and settings.local.toml load
```

### Configuration with Defaults

Always provide sensible defaults:

```quest
use "std/settings" as settings

# Good: with defaults
let port = settings.get("server.port") or 3000
let host = settings.get("server.host") or "127.0.0.1"
let timeout = settings.get("server.timeout") or 30

# Check before using
if settings.contains("cache.redis.host")
    # Use Redis caching
else
    # Fall back to in-memory cache
end
```

## Security Best Practices

### Protecting Sensitive Data

**DO:**
- ✅ Store secrets in `[os.environ]` section
- ✅ Add `.settings.toml` to `.gitignore`
- ✅ Use `.settings.example.toml` for documentation
- ✅ Use environment-specific settings files

**DON'T:**
- ❌ Commit secrets to version control
- ❌ Log full settings in production
- ❌ Expose settings via HTTP endpoints

### Example .gitignore

```
# Ignore actual settings
.settings.toml
.settings.*.toml

# Keep example
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
port = 3000
```

## Error Handling

### Missing Settings

Missing settings return `nil`. Always handle this:

```quest
use "std/settings" as settings

# Use defaults
let port = settings.get("server.port") or 3000

# Check before using
if settings.contains("optional.feature")
    let value = settings.get("optional.feature")
    # Use feature
end
```

### Invalid TOML

If `.settings.toml` has invalid syntax, the interpreter fails on startup with a clear error:

```
Error loading .settings.toml: expected '=' at line 5
```

## Limitations

- Settings are loaded **once** at startup (no hot-reloading)
- File must be named exactly `.settings.toml`
- Must be in current working directory
- Cannot reload or change settings at runtime

## See Also

- [std/os](os.md) - For accessing environment variables
- [std/encoding/json](json.md) - For working with JSON configuration
