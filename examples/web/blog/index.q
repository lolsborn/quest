use "std/encoding/json"
use "std/html/templates"
use "std/db/sqlite"
use "std/time" as time

# Helper function to format dates nicely
fun format_date(date_str)
    # Parse SQLite datetime string (format: "2024-10-15 12:30:45")
    # Extract just the date part and parse as a Date
    let parts = date_str.split(" ")
    let date_part = parts[0]  # "2024-10-15"
    let date = time.parse(date_part)

    # Format using the date components
    let month_names = ["January", "February", "March", "April", "May", "June",
                       "July", "August", "September", "October", "November", "December"]
    let month_name = month_names[date.month() - 1]

    return month_name .. " " .. date.day().str() .. ", " .. date.year().str()
end

# Initialize database connection (reused across requests)
let conn = sqlite.connect("blog.sqlite3")
let db = conn.cursor()

# Initialize template engine
let tmpl = templates.from_dir("templates/**/*.html")

fun handle_request(req)
    # Route based on path
    let path = req["path"]
    let method = req["method"]

    if path == "/"
        return home_handler(req)
    elif path.starts_with("/edit/") and method == "GET"
        return editor_handler(req)
    elif path.starts_with("/edit/") and method == "POST"
        return save_post_handler(req)
    elif path.starts_with("/post/")
        return post_handler(req)
    else
        return not_found_handler(req)
    end
end

# Home page handler - shows blog post listing
fun home_handler(req)
    # Get all published posts with author info
    let posts = db.fetch_all("""
        SELECT
            p.*,
            u.username as author_username,
            u.email as author_email
        FROM posts p
        JOIN users u ON p.author_id = u.id
        WHERE p.published = 1
        ORDER BY p.published_at DESC
    """)

    # Format dates for display
    let i = 0
    while i < posts.len()
        posts[i]["published_at_formatted"] = format_date(posts[i]["published_at"])
        i = i + 1
    end

    # Get popular posts for sidebar
    let popular_posts = db.fetch_all("""
        SELECT id, title, slug, view_count
        FROM posts
        WHERE published = 1
        ORDER BY view_count DESC
        LIMIT 5
    """)

    # Render template
    let html = tmpl.render("home.html", {
        posts: posts,
        popular_posts: popular_posts
    })

    return {
        status: 200,
        headers: {
            "Content-Type": "text/html; charset=utf-8"
        },
        body: html
    }
end

# Individual post handler
fun post_handler(req)
    # Extract slug from path (/post/slug-name)
    let path = req["path"]
    let slug = path.replace("/post/", "")
    
    # Get post with author info
    let post = db.fetch_one("""
        SELECT 
            p.*,
            u.username as author_username,
            u.email as author_email,
            u.created_at as author_created_at
        FROM posts p
        JOIN users u ON p.author_id = u.id
        WHERE p.slug = ? AND p.published = 1
    """, slug)
    
    if post == nil
        return not_found_handler(req)
    end
    
    # Increment view count (autocommit mode - no explicit commit needed)
    db.execute("UPDATE posts SET view_count = view_count + 1 WHERE id = ?", post["id"])

    # Format the post date
    post["published_at_formatted"] = format_date(post["published_at"])

    # Get popular posts for sidebar
    let popular_posts = db.fetch_all("""
        SELECT id, title, slug, view_count
        FROM posts
        WHERE published = 1 AND id != ?
        ORDER BY view_count DESC
        LIMIT 5
    """, post["id"])

    # Render template
    let html = tmpl.render("post.html", {
        post: post,
        popular_posts: popular_posts
    })
    
    return {
        status: 200,
        headers: {
            "Content-Type": "text/html; charset=utf-8"
        },
        body: html
    }
end

# Editor handler - show the editor for a post
fun editor_handler(req)
    # Extract slug from path (/edit/slug-name)
    let path = req["path"]
    let slug = path.replace("/edit/", "")

    # Get post
    let post = db.fetch_one("""
        SELECT *
        FROM posts
        WHERE slug = ?
    """, slug)

    if post == nil
        return not_found_handler(req)
    end

    # Render editor template
    let html = tmpl.render("editor.html", {
        post: post
    })

    return {
        status: 200,
        headers: {
            "Content-Type": "text/html; charset=utf-8"
        },
        body: html
    }
end

# Save post handler - persist changes from editor
fun save_post_handler(req)
    # Extract slug from path (/edit/slug-name)
    let path = req["path"]
    let slug = path.replace("/edit/", "")

    # Parse JSON body
    let data = json.parse(req["body"])

    # Update post in database
    db.execute("""
        UPDATE posts
        SET title = ?, slug = ?, excerpt = ?, content = ?
        WHERE slug = ?
    """, data["title"], data["slug"], data["excerpt"], data["content"], slug)

    return {
        status: 200,
        headers: {
            "Content-Type": "application/json"
        },
        body: json.stringify({success: true})
    }
end

# 404 handler
fun not_found_handler(req)
    return {
        status: 404,
        headers: {
            "Content-Type": "text/html; charset=utf-8"
        },
        body: """<!DOCTYPE html>
<html>
<head>
    <title>404 Not Found</title>
    <link rel="stylesheet" href="/public/style.css">
</head>
<body>
<div class="header">
    <h1><a href="/" style="text-decoration: none; color: inherit;">A Bitsetter's Blog</a></h1>
</div>
<div class="row">
    <div class="leftcolumn">
        <div class="card">
            <h1>404 - Page Not Found</h1>
            <p>The path '""" .. req["path"] .. """' was not found.</p>
            <p><a href="/">← Back to home</a></p>
        </div>
    </div>
</div>
</body>
</html>"""
    }
end

puts("Quest blog server initialized!")
puts("Database: blog.sqlite3")
puts("Templates: templates/")
puts("Routes: /, /post/<slug>")
