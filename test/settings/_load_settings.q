# Manual test for std/settings module
# This must be run from the test/settings directory so .settings.toml is loaded on startup

use "std/settings"
use "std/os" as os

puts("=== std/settings Module Test ===\n")

# Test 1: Simple value retrieval
puts("Test 1: Simple value retrieval")
let app_name = settings.get("app.name")
let app_version = settings.get("app.version")
let app_debug = settings.get("app.debug")
let app_port = settings.get("app.port")

puts("  app.name = ", app_name)
puts("  app.version = ", app_version)
puts("  app.debug = ", app_debug)
puts("  app.port = ", app_port)
puts()

# Test 2: Nested path navigation
puts("Test 2: Nested path navigation")
let db_host = settings.get("database.host")
let db_port = settings.get("database.port")
let pool_min = settings.get("database.pool.min_connections")
let pool_max = settings.get("database.pool.max_connections")

puts("  database.host = ", db_host)
puts("  database.port = ", db_port)
puts("  database.pool.min_connections = ", pool_min)
puts("  database.pool.max_connections = ", pool_max)
puts()

# Test 3: settings.contains()
puts("Test 3: settings.contains()")
let has_app = settings.contains("app")
let has_app_name = settings.contains("app.name")
let has_missing = settings.contains("nonexistent.key")
let has_nested = settings.contains("database.pool.min_connections")

puts("  has('app') = ", has_app)
puts("  has('app.name') = ", has_app_name)
puts("  has('nonexistent.key') = ", has_missing)
puts("  has('database.pool.min_connections') = ", has_nested)
puts()

# Test 4: settings.section()
puts("Test 4: settings.section()")
let app_section = settings.section("app")
puts("  app section = ", app_section)

let cache_section = settings.section("cache")
puts("  cache section = ", cache_section)

let redis_section = settings.section("cache.redis")
puts("  cache.redis section = ", redis_section)

let missing_section = settings.section("nonexistent")
puts("  nonexistent section = ", missing_section)
puts()

# Test 5: Array values
puts("Test 5: Array values")
let allowed_formats = settings.get("features.allowed_formats")
puts("  features.allowed_formats = ", allowed_formats)
puts("  Type: ", allowed_formats.cls())
puts("  Length: ", allowed_formats.len())
puts()

# Test 6: settings.all()
puts("Test 6: settings.all()")
let all_settings = settings.all()
puts("  All top-level keys: ", all_settings.keys())
puts()

# Test 7: [os.environ] section (should NOT be in settings)
puts("Test 7: [os.environ] verification")
let has_os_environ = settings.contains("os.environ")
puts("  has('os.environ') = ", has_os_environ, " (should be false)")

# Check environment variables were set
let test_db_url = os.getenv("TEST_DB_URL")
let test_api_key = os.getenv("TEST_API_KEY")
let test_env = os.getenv("TEST_ENV")

puts("  os.getenv('TEST_DB_URL') = ", test_db_url)
puts("  os.getenv('TEST_API_KEY') = ", test_api_key)
puts("  os.getenv('TEST_ENV') = ", test_env)
puts()

# Test 8: Using defaults with 'or'
puts("Test 8: Defaults with 'or'")
let missing_with_default = settings.get("nonexistent.key") or "default_value"
let existing_with_default = settings.get("app.name") or "default_value"

puts("  settings.get('nonexistent.key') or 'default_value' = ", missing_with_default)
puts("  settings.get('app.name') or 'default_value' = ", existing_with_default)
puts()

# Test 9: Type checking
puts("Test 9: Type checking")
puts("  app.name type: ", app_name.cls())
puts("  app.debug type: ", app_debug.cls())
puts("  app.port type: ", app_port.cls())
puts("  app_section type: ", app_section.cls())
puts("  allowed_formats type: ", allowed_formats.cls())
puts()

puts("=== All Tests Complete ===")
