# Page Repository
# Handles all page-related database operations

# Find all pages
# Args:
#   db: Database cursor
#   published_only: Boolean - if true, only return published pages
# Returns: Array of page dicts with author info
pub fun find_all(db, published_only)
    let query = """
        SELECT
            p.*,
            u.username as author_username
        FROM pages p
        JOIN users u ON p.author_id = u.id
    """

    if published_only
        query = query .. " WHERE p.published = 1"
    end

    query = query .. " ORDER BY p.updated_at DESC"

    return db.fetch_all(query)
end

# Get published pages for navigation (sorted by sort_order)
# Returns: Array of page dicts with id, title, slug, sort_order
pub fun find_published_for_nav(db)
    return db.fetch_all("""
        SELECT id, title, slug, sort_order
        FROM pages
        WHERE published = 1
        ORDER BY sort_order ASC, title ASC
    """)
end

# Find a single page by slug
# Args:
#   db: Database cursor
#   slug: String - page slug
#   published_only: Boolean - if true, only return if published
# Returns: Page dict with author info or nil if not found
pub fun find_by_slug(db, slug, published_only)
    let query = """
        SELECT
            p.*,
            u.username as author_username
        FROM pages p
        JOIN users u ON p.author_id = u.id
        WHERE p.slug = ?
    """

    if published_only
        query = query .. " AND p.published = 1"
    end

    return db.fetch_one(query, slug)
end

# Create a new page
# Args:
#   db: Database cursor
#   title: String
#   slug: String
#   content: String
#   sort_order: Int
#   author_id: Int
# Returns: Page dict with id and slug
pub fun create(db, title, slug, content, sort_order, author_id)
    # Insert the page
    db.execute("""
        INSERT INTO pages (title, slug, content, sort_order, author_id, published)
        VALUES (?, ?, ?, ?, ?, 1)
    """, title, slug, content, sort_order, author_id)

    # Get the newly created page
    return db.fetch_one("SELECT id FROM pages WHERE slug = ?", slug)
end

# Update an existing page
# Args:
#   db: Database cursor
#   slug: String - current slug to identify the page
#   title: String - new title
#   new_slug: String - new slug (can be same as old)
#   content: String - new content
#   sort_order: Int - display order
# Returns: Page dict with id and slug, or nil if not found
pub fun update(db, slug, title, new_slug, content, sort_order)
    # Get page ID first
    let page = db.fetch_one("SELECT id FROM pages WHERE slug = ?", slug)
    if page == nil
        return nil
    end

    # Update the page
    db.execute("""
        UPDATE pages
        SET title = ?, slug = ?, content = ?, sort_order = ?, updated_at = datetime('now')
        WHERE slug = ?
    """, title, new_slug, content, sort_order, slug)

    return {id: page["id"], slug: new_slug}
end

# Delete a page by slug
# Args:
#   db: Database cursor
#   slug: String
# Returns: Boolean - true if deleted, false if not found
pub fun delete(db, slug)
    # Get page ID
    let page = db.fetch_one("SELECT id FROM pages WHERE slug = ?", slug)
    if page == nil
        return false
    end

    # Delete the page
    db.execute("DELETE FROM pages WHERE id = ?", page["id"])

    return true
end
