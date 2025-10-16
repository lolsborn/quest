# Migration: Add read_time field to posts table

fun up(db)
    # Add read_time column to posts table
    db.execute("""
        ALTER TABLE posts
        ADD COLUMN read_time INTEGER DEFAULT 1
    """)

    puts("  → Added read_time column to posts table")
end
