# Migration: Add order field to pages table

fun up(db)
    # Add order column to pages table
    db.execute("""
        ALTER TABLE pages
        ADD COLUMN sort_order INTEGER DEFAULT 100
    """)

    puts("  → Added sort_order column to pages table")
end
