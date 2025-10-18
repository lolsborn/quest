# Migration: Add social_image field to posts

fun up(db)
    # Add social_image column to posts table
    db.execute("""
        ALTER TABLE posts ADD COLUMN social_image TEXT
    """)

    puts("  → Added social_image column to posts table")
end

fun down(db)
    # SQLite doesn't support DROP COLUMN directly, so we'd need to recreate the table
    # For now, just leave the column (safe for rollback)
    puts("  → Note: SQLite doesn't support DROP COLUMN, social_image column will remain")
end
