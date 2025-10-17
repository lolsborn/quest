# Tag Repository
# Handles all tag-related database operations

# Get all tags ordered by name
# Returns: Array of tag dicts with id and name
pub fun find_all(db)
    return db.fetch_all("SELECT id, name FROM tags ORDER BY name ASC")
end

# Get all tags with their post counts (only tags with published posts)
# Returns: Array of dicts with name and count fields
pub fun find_with_counts(db)
    return db.fetch_all("""
        SELECT t.name, COUNT(pt.post_id) as count
        FROM tags t
        LEFT JOIN post_tags pt ON t.id = pt.tag_id
        LEFT JOIN posts p ON pt.post_id = p.id AND p.published = 1
        GROUP BY t.id, t.name
        HAVING COUNT(pt.post_id) > 0
        ORDER BY t.name ASC
    """)
end

# Get all tags for a specific post
# Args:
#   db: Database cursor
#   post_id: Post ID
# Returns: Array of tag dicts with name field
pub fun find_for_post(db, post_id)
    return db.fetch_all("""
        SELECT t.name
        FROM tags t
        JOIN post_tags pt ON t.id = pt.tag_id
        WHERE pt.post_id = ?
        ORDER BY t.name
    """, post_id)
end

# Synchronize tags for a post (delete old associations, create new ones)
# Args:
#   db: Database cursor
#   post_id: Post ID
#   tag_names: Array of tag name strings
pub fun sync_post_tags(db, post_id, tag_names)
    # Delete existing tags
    db.execute("DELETE FROM post_tags WHERE post_id = ?", post_id)

    # Insert new tags
    let i = 0
    while i < tag_names.len()
        let tag_name = tag_names[i]

        # Insert tag if it doesn't exist (INSERT OR IGNORE)
        db.execute("INSERT OR IGNORE INTO tags (name) VALUES (?)", tag_name)

        # Get tag ID
        let tag = db.fetch_one("SELECT id FROM tags WHERE name = ?", tag_name)

        # Link tag to post
        db.execute("INSERT INTO post_tags (post_id, tag_id) VALUES (?, ?)", post_id, tag["id"])

        i = i + 1
    end
end
