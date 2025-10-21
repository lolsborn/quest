# Quest Blog Example

A full-featured blog web application demonstrating Quest's web server capabilities, database integration, and static file serving.

## Features

- 📝 Blog post management with SQLite database
- 👥 User system with authors
- 💬 Comments system with approval
- 📊 View counts tracking
- 🎨 Static file serving (CSS, images, etc.)
- 🔄 Hot reload with `--watch` flag
- 🗄️ Database migrations and seed data

## Database Schema

The blog uses SQLite with the following tables:

- **users** - Blog authors
- **posts** - Blog posts with publish status, slugs, and metadata
- **comments** - User comments with approval workflow

## Getting Started

### Option A: Using Docker

```bash
# Build the Docker image (from quest root directory)
docker build -f examples/web/blog/Dockerfile -t quest-blog .

# Run the container
docker run -p 3000:3000 quest-blog

# Visit http://localhost:3000
```

The Docker image will automatically build Quest, initialize the database with sample data, and start the server.

### Option B: Local Development

#### 1. Initialize the Database

```bash
# From the quest root directory
cd /path/to/quest2
./target/release/quest examples/web/blog/migrate.q
```

This will set up the database with the migrations:
- `000_initial_schema` - Users, posts, and comments tables
- `001_add_tags` - Tags system
- `002_add_pages` - Static pages
- `003_add_page_order` - Page ordering
- `004_add_read_time` - Post reading time estimation
- `005_add_social_image` - Social media image field

#### 2. Start the Server

```bash
# From the quest root directory (IMPORTANT: must run from here to find lib/ directory)
cd /path/to/quest2

# Basic start (port 8888 by default)
./target/release/quest examples/web/blog/index.q

# With custom port (edit the last line of index.q or create a wrapper)
```

The server will start on http://localhost:8888

#### 3. Visit the Blog

Open your browser to http://localhost:8888

## Available Routes

Current routes (see `index.q`):

- `/` - Home page (blog listing)
- `/hello?name=YourName` - Hello handler with query params
- `/json` - JSON response example
- `/echo` - Echo request details
- `/headers` - Display request headers
- `/cookies` - Cookie demo with visit counter

Static files (configured via `web.static()` in `index.q`):
- `/public/style.css` - Blog styles
- `/public/test.txt` - Test file

## Directory Structure

```
examples/web/blog/
├── README.md           # This file
├── index.q             # Main Quest web server (configures static dirs)
├── schema.sql          # Database schema and seed data
├── init_db.q          # Database initialization script
├── blog.db            # SQLite database (created by init_db.q)
└── public/            # Static files (served via web.static)
    ├── style.css      # CSS styles
    └── test.txt       # Test file
```

## Extending the Blog

### Add a New Route

Edit `index.q` and add a new handler:

```quest
fun handle_request(req)
    let path = req["path"]
    
    if path == "/new-route"
        return new_route_handler(req)
    # ... existing routes
end

fun new_route_handler(req)
    return {
        status: 200,
        body: "My new route!"
    }
end
```

### Query the Database

```quest
use "std/db/sqlite"

let db = sqlite.connect("examples/web/blog/blog.db")

fun posts_handler(req)
    # Get all published posts
    let posts = db.fetch_all(
        "SELECT * FROM posts WHERE published = 1 ORDER BY published_at DESC"
    )
    
    return {
        status: 200,
        json: posts
    }
end
```

### Add Static Files

The blog configures static file serving via `web.static()` in `index.q`:

```quest
web.static("/public", "./public")
```

Place any files in the `public/` directory:

```bash
# They'll be available at /public/<filename>
cp my-image.png examples/web/blog/public/
# Now accessible at http://localhost:3000/public/my-image.png
```

To serve static files from additional directories, use `web.static()` in your script:

```quest
web.static("/uploads", "./uploads")  # Serves uploads/ at /uploads/*
web.static("/assets", "./assets")    # Serves assets/ at /assets/*
```

## Database Queries

Some useful SQLite queries for development:

```sql
-- View all posts
SELECT id, title, slug, published FROM posts;

-- Get post with comments
SELECT p.title, c.author_name, c.content
FROM posts p
JOIN comments c ON p.id = c.post_id
WHERE p.slug = 'getting-started-with-quest';

-- Top posts by views
SELECT title, view_count FROM posts 
ORDER BY view_count DESC LIMIT 5;

-- Pending comments
SELECT p.title, c.author_name, c.content
FROM comments c
JOIN posts p ON c.post_id = p.id
WHERE c.approved = 0;
```

## Tips

- Use `--watch` flag during development for automatic reload on file changes
- The database connection is persistent across requests for better performance
- Check `schema.sql` for the complete database structure
- Static files are cached by the browser - use Ctrl+Shift+R to hard refresh

## Next Steps

Try implementing:
- Blog post listing page with database queries
- Individual post view by slug
- Comment submission form
- Admin dashboard for managing posts
- RSS feed generation
- Search functionality

## Learn More

- [Quest Documentation](../../docs/)
- [Quest Database Guide](../../docs/stdlib/database.md)
- [Quest HTTP Server](../../docs/stdlib/http.md)
