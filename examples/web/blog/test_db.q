use "std/db/sqlite"
use "std/os"

puts("Current directory: " .. os.getcwd())
puts("Testing from blog directory...")

# Check if file exists
let conn = sqlite.connect("blog.sqlite3")
puts("Connected to database")

let db = conn.cursor()
puts("Got cursor")

# Try to check what tables exist
let tables = db.fetch_all("SELECT name FROM sqlite_master WHERE type='table'")
puts("Tables: " .. tables.len().str())
for table in tables
    puts("  - " .. table["name"])
end

let result = db.fetch_one("SELECT COUNT(*) as c FROM posts WHERE published = 1")
if result != nil
    puts("Count: " .. result["c"].str())
else
    puts("Query returned nil")
end

let posts = db.fetch_all("SELECT id, title FROM posts WHERE published = 1")
puts("Posts found: " .. posts.len().str())
