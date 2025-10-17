# User Repository
# Handles all user-related database operations

# Get the default author (first user in the database)
# Returns: User dict or nil if no users exist
pub fun find_default_author(db)
    return db.fetch_one("SELECT id FROM users LIMIT 1")
end

# Find a user by ID
# Args:
#   db: Database cursor
#   id: User ID
# Returns: User dict with all fields or nil if not found
pub fun find_by_id(db, id)
    return db.fetch_one("""
        SELECT id, username, email, created_at
        FROM users
        WHERE id = ?
    """, id)
end

# Get all users
# Returns: Array of user dicts
pub fun find_all(db)
    return db.fetch_all("""
        SELECT id, username, email, created_at
        FROM users
        ORDER BY username ASC
    """)
end
