# Migration: Add tags support to blog

fun up(db)
    # Create tags table
    db.execute("""
        CREATE TABLE IF NOT EXISTS tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    """)

    # Create post_tags junction table
    db.execute("""
        CREATE TABLE IF NOT EXISTS post_tags (
            post_id INTEGER NOT NULL,
            tag_id INTEGER NOT NULL,
            PRIMARY KEY (post_id, tag_id),
            FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
            FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
        )
    """)

    # Create indexes for better query performance
    db.execute("CREATE INDEX IF NOT EXISTS idx_post_tags_post ON post_tags(post_id)")
    db.execute("CREATE INDEX IF NOT EXISTS idx_post_tags_tag ON post_tags(tag_id)")

    # Insert some default tags
    db.execute("INSERT OR IGNORE INTO tags (name) VALUES ('quest')")
    db.execute("INSERT OR IGNORE INTO tags (name) VALUES ('tutorial')")
    db.execute("INSERT OR IGNORE INTO tags (name) VALUES ('web')")
    db.execute("INSERT OR IGNORE INTO tags (name) VALUES ('database')")
    db.execute("INSERT OR IGNORE INTO tags (name) VALUES ('beginner')")
    db.execute("INSERT OR IGNORE INTO tags (name) VALUES ('advanced')")

    # Tag existing posts
    # Getting Started with Quest -> quest, tutorial, beginner
    db.execute("""
        INSERT OR IGNORE INTO post_tags (post_id, tag_id)
        SELECT 1, id FROM tags WHERE name IN ('quest', 'tutorial', 'beginner')
    """)

    # Building a Web Server -> quest, web, tutorial
    db.execute("""
        INSERT OR IGNORE INTO post_tags (post_id, tag_id)
        SELECT 2, id FROM tags WHERE name IN ('quest', 'web', 'tutorial')
    """)

    # Quest Database Guide -> quest, database, tutorial
    db.execute("""
        INSERT OR IGNORE INTO post_tags (post_id, tag_id)
        SELECT 3, id FROM tags WHERE name IN ('quest', 'database', 'tutorial')
    """)

    # Advanced Quest Features -> quest, advanced
    db.execute("""
        INSERT OR IGNORE INTO post_tags (post_id, tag_id)
        SELECT 4, id FROM tags WHERE name IN ('quest', 'advanced')
    """)

    puts("  → Created tags and post_tags tables")
    puts("  → Inserted default tags")
    puts("  → Tagged existing posts")
end
