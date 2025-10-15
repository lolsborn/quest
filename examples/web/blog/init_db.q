#!/usr/bin/env quest
# Initialize the blog database

use "std/db/sqlite"
use "std/io"

puts("Initializing blog database...")

# Read the schema file
let schema = io.read("examples/web/blog/schema.sql")

# Connect to database (creates if doesn't exist)
let db = sqlite.connect("examples/web/blog/blog.db")

# Execute the schema
# Split by semicolons and execute each statement
let statements = schema.split(";")
for stmt in statements
    let trimmed = stmt.trim()
    if trimmed.len() > 0 && !trimmed.starts_with("--")
        try
            db.execute(trimmed)
        catch e
            # Ignore errors for SELECT statements at the end
            if !trimmed.starts_with("SELECT")
                puts("Error executing statement: " .. e.message())
            end
        end
    end
end

# Verify the setup
puts("\nDatabase statistics:")
let user_count = db.fetch_one("SELECT COUNT(*) as count FROM users")
puts("Users: " .. user_count["count"].str())

let post_count = db.fetch_one("SELECT COUNT(*) as count FROM posts")
puts("Posts: " .. post_count["count"].str())

let comment_count = db.fetch_one("SELECT COUNT(*) as count FROM comments")
puts("Comments: " .. comment_count["count"].str())

db.close()

puts("\n✓ Database initialized successfully!")
puts("Database location: examples/web/blog/blog.db")
