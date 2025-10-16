#!/usr/bin/env quest
# Database migration runner for the blog

use "std/db/sqlite" as sqlite
use "std/os" as os
use "std/io" as io
use "std/sys" as sys

# Configuration - use DB_FILE env var if available
let DB_FILE = os.getenv("DATABASE_URL") or "blog.sqlite3"
const MIGRATIONS_DIR = "migrations"

# Check if database file exists
let db_exists = io.exists(DB_FILE)
if not db_exists
    puts("Database file not found: " .. DB_FILE)
    puts("Creating new database...")
end

# Connect to database (creates file if it doesn't exist)
puts("Connecting to database: " .. DB_FILE)
let conn = sqlite.connect(DB_FILE)
let db = conn.cursor()

puts("")
puts("Blog Database Migration Tool")
puts("=" .. "=".repeat(50))
puts("")

# Create migrations tracking table if it doesn't exist
db.execute("""
    CREATE TABLE IF NOT EXISTS schema_migrations (
        version TEXT PRIMARY KEY,
        applied_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
""")

# Get applied migrations
let applied = db.fetch_all("SELECT version FROM schema_migrations ORDER BY version")
let applied_versions = []
let i = 0
while i < applied.len()
    applied_versions.push(applied[i]["version"])
    i = i + 1
end

puts("Applied migrations: " .. applied_versions.len().str())
for version in applied_versions
    puts("  ✓ " .. version)
end
puts("")

# Find all .q migration files
let migration_files = os.listdir(MIGRATIONS_DIR)
let migrations = []

# Filter and sort .q files
i = 0
while i < migration_files.len()
    let file = migration_files[i]
    if file.ends_with(".q")
        migrations.push(file)
    end
    i = i + 1
end

# Sort migrations by name (they should be numbered)
migrations = migrations.sorted()

puts("Available migrations: " .. migrations.len().str())
for file in migrations
    puts("  - " .. file)
end
puts("")

# Apply pending migrations
let pending = []
for file in migrations
    let version = file.replace(".q", "")
    let is_applied = false

    for applied_ver in applied_versions
        if applied_ver == version
            is_applied = true
        end
    end

    if not is_applied
        pending.push({file: file, version: version})
    end
end

if pending.len() == 0
    puts("No pending migrations. Database is up to date!")
    conn.close()
    return
end

puts("Pending migrations: " .. pending.len().str())
for mig in pending
    puts("  → " .. mig["file"])
end
puts("")

# Apply each pending migration
for mig in pending
    puts("Applying migration: " .. mig["file"])

    try
        # Load the migration module
        let migration_path = MIGRATIONS_DIR .. "/" .. mig["file"]
        let migration = sys.load_module(migration_path)

        # Call the up() function with the database cursor
        migration.up(db)

        # Record as applied
        db.execute(
            "INSERT INTO schema_migrations (version) VALUES (?)",
            mig["version"]
        )

        puts("  ✓ Applied successfully")
    catch e
        puts("  ✗ Failed: " .. e.message())
        puts("")
        puts("Migration failed. Rolling back...")
        conn.close()
        return
    end
end

puts("")
puts("Migration complete!")
conn.close()
