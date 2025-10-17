# Post Repository
# Handles all post-related database operations

# Find all posts with optional filtering
# Args:
#   db: Database cursor
#   published_only: Boolean - if true, only return published posts
#   tag_filter: String or nil - if provided, filter by tag name
#   limit: Int or nil - limit number of results
# Returns: Array of post dicts with author info
pub fun find_all(db, published_only, tag_filter, limit)
    let query = nil
    let params = []

    if tag_filter != nil
        # Query with tag filtering
        query = """
            SELECT DISTINCT
                p.*,
                u.username as author_username,
                u.email as author_email
            FROM posts p
            JOIN users u ON p.author_id = u.id
            JOIN post_tags pt ON p.id = pt.post_id
            JOIN tags t ON pt.tag_id = t.id
            WHERE t.name = ?
        """
        params.push(tag_filter)

        if published_only
            query = query .. " AND p.published = 1"
        end

        query = query .. " ORDER BY p.published_at DESC"
    else
        # Query without tag filtering
        query = """
            SELECT
                p.*,
                u.username as author_username,
                u.email as author_email
            FROM posts p
            JOIN users u ON p.author_id = u.id
        """

        if published_only
            query = query .. " WHERE p.published = 1"
        end

        query = query .. " ORDER BY p.published_at DESC"
    end

    if limit != nil
        query = query .. " LIMIT " .. limit.str()
    end

    if params.len() > 0
        return db.fetch_all(query, *params)
    else
        return db.fetch_all(query)
    end
end

# Find a single post by slug
# Args:
#   db: Database cursor
#   slug: String - post slug
#   published_only: Boolean - if true, only return if published
# Returns: Post dict with author info or nil if not found
pub fun find_by_slug(db, slug, published_only)
    let query = """
        SELECT
            p.*,
            u.username as author_username,
            u.email as author_email,
            u.created_at as author_created_at
        FROM posts p
        JOIN users u ON p.author_id = u.id
        WHERE p.slug = ?
    """

    if published_only
        query = query .. " AND p.published = 1"
    end

    return db.fetch_one(query, slug)
end

# Get popular posts by view count
# Args:
#   db: Database cursor
#   limit: Int - maximum number of posts to return
#   exclude_id: Int or nil - optional post ID to exclude
# Returns: Array of post dicts
pub fun find_popular(db, limit, exclude_id)
    let query = """
        SELECT id, title, slug, view_count
        FROM posts
        WHERE published = 1
    """

    let params = []
    if exclude_id != nil
        query = query .. " AND id != ?"
        params.push(exclude_id)
    end

    query = query .. " ORDER BY view_count DESC LIMIT " .. limit.str()

    if params.len() > 0
        return db.fetch_all(query, *params)
    else
        return db.fetch_all(query)
    end
end

# Create a new post
# Args:
#   db: Database cursor
#   title: String
#   slug: String
#   content: String
#   read_time: Int - estimated reading time in minutes
#   author_id: Int
#   tags: Array of tag name strings
# Returns: Post dict with id and slug
pub fun create(db, title, slug, content, read_time, author_id, tags)
    # Insert the post
    db.execute("""
        INSERT INTO posts (title, slug, content, read_time, author_id, published, published_at)
        VALUES (?, ?, ?, ?, ?, 1, datetime('now'))
    """, title, slug, content, read_time, author_id)

    # Get the newly created post
    let post = db.fetch_one("SELECT id FROM posts WHERE slug = ?", slug)

    # Handle tags if provided
    if tags != nil and tags.len() > 0
        use "repos/tag" as tag_repo
        tag_repo.sync_post_tags(db, post["id"], tags)
    end

    return post
end

# Update an existing post
# Args:
#   db: Database cursor
#   slug: String - current slug to identify the post
#   title: String - new title
#   new_slug: String - new slug (can be same as old)
#   content: String - new content
#   read_time: Int - estimated reading time in minutes
#   tags: Array of tag name strings or nil
pub fun update(db, slug, title, new_slug, content, read_time, tags)
    # Get post ID first
    let post = db.fetch_one("SELECT id FROM posts WHERE slug = ?", slug)
    if post == nil
        return nil
    end

    # Update the post
    db.execute("""
        UPDATE posts
        SET title = ?, slug = ?, content = ?, read_time = ?, updated_at = datetime('now')
        WHERE slug = ?
    """, title, new_slug, content, read_time, slug)

    # Update tags if provided
    if tags != nil
        use "repos/tag" as tag_repo
        tag_repo.sync_post_tags(db, post["id"], tags)
    end

    return {id: post["id"], slug: new_slug}
end

# Delete a post by slug
# Args:
#   db: Database cursor
#   slug: String
# Returns: Boolean - true if deleted, false if not found
pub fun delete(db, slug)
    # Get post ID
    let post = db.fetch_one("SELECT id FROM posts WHERE slug = ?", slug)
    if post == nil
        return false
    end

    # Delete post tags first (foreign key constraint)
    db.execute("DELETE FROM post_tags WHERE post_id = ?", post["id"])

    # Delete the post
    db.execute("DELETE FROM posts WHERE id = ?", post["id"])

    return true
end

# Increment the view count for a post
# Args:
#   db: Database cursor
#   post_id: Int
pub fun increment_view_count(db, post_id)
    db.execute("UPDATE posts SET view_count = view_count + 1 WHERE id = ?", post_id)
end

# Get all posts for admin (includes unpublished)
# Returns: Array of post dicts with author info, ordered by updated_at
pub fun find_all_for_admin(db)
    return db.fetch_all("""
        SELECT
            p.*,
            u.username as author_username
        FROM posts p
        JOIN users u ON p.author_id = u.id
        ORDER BY p.updated_at DESC
    """)
end
