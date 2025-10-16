# Migration: Add pages table for static pages

fun up(db)
    # Pages table - similar to posts but separate
    db.execute("""
        CREATE TABLE IF NOT EXISTS pages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            slug TEXT NOT NULL UNIQUE,
            content TEXT NOT NULL,
            author_id INTEGER NOT NULL,
            published INTEGER DEFAULT 1,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (author_id) REFERENCES users(id)
        )
    """)

    # Create indexes
    db.execute("CREATE INDEX IF NOT EXISTS idx_pages_slug ON pages(slug)")
    db.execute("CREATE INDEX IF NOT EXISTS idx_pages_published ON pages(published)")

    # Update trigger for pages
    db.execute("""
        CREATE TRIGGER IF NOT EXISTS update_page_timestamp
        AFTER UPDATE ON pages
        FOR EACH ROW
        BEGIN
            UPDATE pages SET updated_at = CURRENT_TIMESTAMP WHERE id = OLD.id;
        END
    """)

    puts("  → Created pages table")
end
