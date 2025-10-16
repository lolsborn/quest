# Blog Database Migrations

This directory contains SQL migrations for the Quest blog example.

## Running Migrations

From the `examples/web/blog` directory, run:

```bash
quest migrate.q
```

This will:
1. Check which migrations have already been applied
2. Apply any pending migrations in order
3. Track applied migrations in the `schema_migrations` table

## Creating New Migrations

Migration files should follow the naming convention:
```
NNN_description.q
```

For example:
- `001_add_tags.q`
- `002_add_user_roles.q`
- `003_add_post_categories.q`

The numeric prefix ensures migrations are applied in the correct order.

## Migration File Format

Each migration is a Quest module with an `up(db)` function:

```quest
# Migration: Description of what this migration does

fun up(db)
    # Create tables
    db.execute("""
        CREATE TABLE IF NOT EXISTS new_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
        )
    """)

    # Add indexes
    db.execute("CREATE INDEX IF NOT EXISTS idx_new_table_name ON new_table(name)")

    # Insert data
    db.execute("INSERT INTO new_table (name) VALUES ('example')")

    puts("  → Migration completed!")
end
```

The `db` parameter is a SQLite cursor that you can use to execute individual SQL statements.

## Current Migrations

- **000_initial_schema.q**: Creates initial database schema (users, posts, comments) with sample data
- **001_add_tags.q**: Adds tags and post_tags tables for blog post tagging

## Fresh Installation

If you're starting from scratch, just run:

```bash
quest migrate.q
```

This will:
1. Create the database file if it doesn't exist
2. Apply all migrations in order (starting with 000_initial_schema.sql)
3. Set up your blog with sample data

## Environment Variables

- `DB_FILE`: Path to the SQLite database file (default: `blog.sqlite3`)

Example:
```bash
DB_FILE=/data/my-blog.db quest migrate.q
```
