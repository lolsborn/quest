# Migration: Initial database schema

fun up(db)
    # Users table
    db.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE,
            email TEXT NOT NULL UNIQUE,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    """)

    # Blog posts table
    db.execute("""
        CREATE TABLE IF NOT EXISTS posts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            slug TEXT NOT NULL UNIQUE,
            content TEXT NOT NULL,
            excerpt TEXT,
            author_id INTEGER NOT NULL,
            published INTEGER DEFAULT 0,
            view_count INTEGER DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            published_at DATETIME,
            FOREIGN KEY (author_id) REFERENCES users(id)
        )
    """)

    # Comments table
    db.execute("""
        CREATE TABLE IF NOT EXISTS comments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            post_id INTEGER NOT NULL,
            author_name TEXT NOT NULL,
            author_email TEXT,
            content TEXT NOT NULL,
            approved INTEGER DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
        )
    """)

    # Create indexes
    db.execute("CREATE INDEX IF NOT EXISTS idx_posts_slug ON posts(slug)")
    db.execute("CREATE INDEX IF NOT EXISTS idx_posts_published ON posts(published)")
    db.execute("CREATE INDEX IF NOT EXISTS idx_posts_author ON posts(author_id)")
    db.execute("CREATE INDEX IF NOT EXISTS idx_comments_post ON comments(post_id)")
    db.execute("CREATE INDEX IF NOT EXISTS idx_comments_approved ON comments(approved)")

    # Update trigger
    db.execute("""
        CREATE TRIGGER IF NOT EXISTS update_post_timestamp
        AFTER UPDATE ON posts
        FOR EACH ROW
        BEGIN
            UPDATE posts SET updated_at = CURRENT_TIMESTAMP WHERE id = OLD.id;
        END
    """)

    # Insert sample user
    db.execute("INSERT OR IGNORE INTO users (id, username, email) VALUES (1, 'Steven Osborn', 'osborn.steven@gmail.com')")

    # Insert sample posts
    db.execute("""
        INSERT OR IGNORE INTO posts (id, title, slug, content, excerpt, author_id, published, published_at, view_count)
        VALUES (1, 'Getting Started with Quest', 'getting-started-with-quest',
        'Quest is a scripting language focused on developer happiness...',
        'Learn the basics of Quest...', 1, 1, datetime('now', '-7 days'), 142)
    """)

    db.execute("""
        INSERT OR IGNORE INTO posts (id, title, slug, content, excerpt, author_id, published, published_at, view_count)
        VALUES (2, 'Building a Web Server with Quest', 'building-web-server-quest',
        'Quest makes it incredibly easy to build web applications...',
        'Learn how to build modern web applications...', 1, 1, datetime('now', '-3 days'), 89)
    """)

    db.execute("""
        INSERT OR IGNORE INTO posts (id, title, slug, content, excerpt, author_id, published, published_at, view_count)
        VALUES (3, 'Quest Database Guide', 'quest-database-guide',
        'Quest provides a unified interface for databases...',
        'A comprehensive guide to databases in Quest...', 1, 1, datetime('now', '-1 day'), 56)
    """)

    db.execute("""
        INSERT OR IGNORE INTO posts (id, title, slug, content, excerpt, author_id, published, published_at, view_count)
        VALUES (4, 'Advanced Quest Features', 'advanced-quest-features',
        'Quest includes many advanced features...',
        'Explore advanced Quest features...', 1, 1, datetime('now'), 23)
    """)

    # Insert sample comments
    db.execute("INSERT OR IGNORE INTO comments (id, post_id, author_name, author_email, content, approved) VALUES (1, 1, 'David', 'david@example.com', 'Great introduction!', 1)")
    db.execute("INSERT OR IGNORE INTO comments (id, post_id, author_name, author_email, content, approved) VALUES (2, 1, 'Emma', 'emma@example.com', 'Where can I find more tutorials?', 1)")

    puts("  → Created users, posts, and comments tables")
    puts("  → Inserted sample data")
end
