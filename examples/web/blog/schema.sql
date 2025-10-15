-- Blog database schema for Quest web server example
-- SQLite database schema

-- Drop tables if they exist (for clean migrations)
DROP TABLE IF EXISTS comments;
DROP TABLE IF EXISTS posts;
DROP TABLE IF EXISTS users;

-- Users table
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Blog posts table
CREATE TABLE posts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    content TEXT NOT NULL,
    excerpt TEXT,
    author_id INTEGER NOT NULL,
    published INTEGER DEFAULT 0,  -- 0 = draft, 1 = published
    view_count INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    published_at DATETIME,
    FOREIGN KEY (author_id) REFERENCES users(id)
);

-- Comments table
CREATE TABLE comments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    post_id INTEGER NOT NULL,
    author_name TEXT NOT NULL,
    author_email TEXT,
    content TEXT NOT NULL,
    approved INTEGER DEFAULT 0,  -- 0 = pending, 1 = approved
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
);

-- Create indexes for better query performance
CREATE INDEX idx_posts_slug ON posts(slug);
CREATE INDEX idx_posts_published ON posts(published);
CREATE INDEX idx_posts_author ON posts(author_id);
CREATE INDEX idx_comments_post ON comments(post_id);
CREATE INDEX idx_comments_approved ON comments(approved);

-- Insert sample users
INSERT INTO users (username, email) VALUES
    ('Steven Osborn', 'osborn.steven@gmail.com');

-- Insert sample blog posts
INSERT INTO posts (
    title, 
    slug, 
    content, 
    excerpt, 
    author_id, 
    published, 
    published_at,
    view_count
) VALUES
    (
        'Getting Started with Quest',
        'getting-started-with-quest',
        'Quest is a scripting language focused on developer happiness with a REPL implementation in Rust. Everything is an object (including primitives), and all operations are method calls.

In this post, we''ll explore the basics of Quest and build a simple web application.

## Installing Quest

First, clone the repository and build Quest:

```bash
git clone https://github.com/lolsborn/quest
cd quest
cargo build --release
```

## Your First Quest Program

Here''s a simple "Hello, World!" program in Quest:

```quest
puts("Hello, World!")
```

## Variables and Types

Quest supports several built-in types:

- Integers: `42`, `0xFF`, `1_000_000`
- Floats: `3.14`, `1.5e10`
- Strings: `"hello"` or `''single quotes''`
- Booleans: `true`, `false`
- Arrays: `[1, 2, 3]`
- Dicts: `{name: "Alice", age: 30}`

## Functions

Define functions with the `fun` keyword:

```quest
fun greet(name)
    "Hello, " .. name .. "!"
end

puts(greet("Quest"))
```

Stay tuned for more Quest tutorials!',
        'Learn the basics of Quest, a modern scripting language focused on developer happiness. This tutorial covers installation, basic syntax, and your first Quest program.',
        1,
        1,
        datetime('now', '-7 days'),
        142
    ),
    (
        'Building a Web Server with Quest',
        'building-web-server-quest',
        'Quest makes it incredibly easy to build web applications with its built-in HTTP server support.

## The Serve Command

Quest includes a `serve` command that runs your application as a web server:

```bash
quest serve --port 3000 app.q
```

## Request Handler

Every Quest web application needs a `handle_request` function:

```quest
fun handle_request(req)
    return {
        status: 200,
        headers: {"content-type": "text/plain"},
        body: "Hello from Quest!"
    }
end
```

## Routing

You can implement routing by checking the request path:

```quest
fun handle_request(req)
    let path = req["path"]
    
    if path == "/"
        return home_handler(req)
    elif path == "/about"
        return about_handler(req)
    else
        return not_found(req)
    end
end
```

## Working with Databases

Quest has excellent database support with SQLite, PostgreSQL, and MySQL:

```quest
use "std/db/sqlite"

let db = sqlite.connect("blog.db")
let posts = db.fetch_all("SELECT * FROM posts WHERE published = 1")

db.close()
```

## Static Files

Place your CSS, JavaScript, and images in a `public/` directory and they''ll be automatically served at `/public/*`.

Check out the full example at `examples/web/blog/` in the Quest repository!',
        'Learn how to build modern web applications with Quest''s built-in HTTP server, including routing, database integration, and static file serving.',
        1,
        1,
        datetime('now', '-3 days'),
        89
    ),
    (
        'Quest Database Guide',
        'quest-database-guide',
        'Quest provides a unified interface for working with multiple database systems.

## Supported Databases

Quest currently supports:

- SQLite (embedded database)
- PostgreSQL (production-ready)
- MySQL (widely used)

## SQLite Example

SQLite is perfect for development and small applications:

```quest
use "std/db/sqlite"

let db = sqlite.connect(":memory:")

# Create table
db.execute("""
    CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT UNIQUE
    )
""")

# Insert data
db.execute("INSERT INTO users (name, email) VALUES (?, ?)", 
    "Alice", "alice@example.com")

# Query data
let users = db.fetch_all("SELECT * FROM users")
for user in users
    puts(user["name"] .. " - " .. user["email"])
end

db.close()
```

## PostgreSQL Example

For production applications, PostgreSQL is an excellent choice:

```quest
use "std/db/postgres"

let db = postgres.connect(
    "host=localhost dbname=myapp user=postgres password=secret"
)

let posts = db.fetch_all(
    "SELECT * FROM posts WHERE author_id = $1 ORDER BY created_at DESC",
    42
)

db.close()
```

## Connection Pooling

For web applications, you typically want to reuse database connections:

```quest
use "std/db/sqlite"

# Create connection once at module level
let db = sqlite.connect("blog.db")

fun handle_request(req)
    # Reuse the same connection
    let posts = db.fetch_all("SELECT * FROM posts LIMIT 10")
    
    return {
        status: 200,
        json: posts
    }
end
```

Quest makes database programming simple and enjoyable!',
        'A comprehensive guide to working with databases in Quest, covering SQLite, PostgreSQL, and MySQL with practical examples.',
        2,
        1,
        datetime('now', '-1 day'),
        56
    ),
    (
        'Advanced Quest Features',
        'advanced-quest-features',
        'Quest includes many advanced features that make it a powerful scripting language.

## Pattern Matching

Use `match` statements for elegant control flow:

```quest
match value
in 0
    puts("zero")
in 1
    puts("one")
in 2..10
    puts("small number")
else
    puts("something else")
end
```

## Decorators

Quest supports Python-style decorators:

```quest
use "std/decorators" as dec

let Timing = dec.Timing
let Cache = dec.Cache

@Timing
@Cache(max_size: 100)
fun expensive_query(id)
    # This function is timed and cached
    db.fetch_one("SELECT * FROM posts WHERE id = ?", id)
end
```

## Exception Handling

Robust error handling with typed exceptions:

```quest
try
    let result = risky_operation()
catch e: ValueError
    puts("Invalid value: " .. e.message())
catch e: IOError
    puts("IO error: " .. e.message())
ensure
    cleanup()
end
```

## Modules and Imports

Organize your code with Quest''s module system:

```quest
use "std/encoding/json"
use "std/http/client" as http
use "./lib/helpers" as h

let data = json.parse(http.get("https://api.example.com/data"))
```

## Context Managers

Python-style `with` statements:

```quest
with file_open("data.txt") as f
    let content = f.read()
end  # File is automatically closed
```

These are just a few of the powerful features Quest provides!',
        'Explore advanced Quest features including pattern matching, decorators, exception handling, modules, and more.',
        2,
        1,
        datetime('now'),
        23
    ),
    (
        'Coming Soon: Async Support',
        'coming-soon-async-support',
        'We''re working on adding async/await support to Quest!

This feature is currently in development and will bring powerful asynchronous programming capabilities to Quest.

## Planned Syntax

```quest
async fun fetch_data(url)
    let response = await http.get(url)
    return response.json()
end

async fun main()
    let data1 = await fetch_data("https://api1.example.com")
    let data2 = await fetch_data("https://api2.example.com")
    
    puts("Got data!")
end
```

Stay tuned for updates!',
        'A preview of upcoming async/await support in Quest for building high-performance concurrent applications.',
        3,
        0,  -- Draft
        NULL,
        5
    );

-- Insert sample comments
INSERT INTO comments (post_id, author_name, author_email, content, approved) VALUES
    (1, 'David', 'david@example.com', 'Great introduction! I''m excited to try Quest.', 1),
    (1, 'Emma', 'emma@example.com', 'Where can I find more tutorials?', 1),
    (1, 'Frank', 'frank@example.com', 'This is exactly what I was looking for. Thanks!', 1),
    (2, 'Grace', 'grace@example.com', 'The web server is really easy to use!', 1),
    (2, 'Henry', 'henry@example.com', 'How do I handle POST requests?', 1),
    (3, 'Iris', 'iris@example.com', 'The database API is very clean and intuitive.', 1),
    (3, 'Jack', 'jack@example.com', 'Does Quest support database migrations?', 0),  -- Pending approval
    (4, 'Kate', 'kate@example.com', 'Decorators are awesome! 🎉', 1);

-- Update view counts trigger
CREATE TRIGGER update_post_timestamp 
AFTER UPDATE ON posts
FOR EACH ROW
BEGIN
    UPDATE posts SET updated_at = CURRENT_TIMESTAMP WHERE id = OLD.id;
END;

-- Verify the data
SELECT 'Database initialized successfully!' as message;
SELECT COUNT(*) as user_count FROM users;
SELECT COUNT(*) as post_count FROM posts;
SELECT COUNT(*) as comment_count FROM comments;
