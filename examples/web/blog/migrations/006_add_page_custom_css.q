# Migration: Add custom_css column to pages table

fun up(db)
    db.execute("""
        ALTER TABLE pages
        ADD COLUMN custom_css TEXT
    """)

    puts("  → Added custom_css column to pages table")
end
