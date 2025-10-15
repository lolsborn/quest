use "std/encoding/json"
use "std/html/templates"
use "std/db/sqlite"

# Initialize database connection (reused across requests)
let conn = sqlite.connect("blog.sqlite3")
let db = conn.cursor()

# Initialize template engine
let tmpl = templates.from_dir("templates/**/*.html")

fun handle_request(req)
    # Route based on path
    let path = req["path"]

    if path == "/"
        return home_handler(req)
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
    
    # Get popular posts for sidebar
    let popular_posts = db.fetch_all("""
        SELECT id, title, slug, view_count
        FROM posts
        WHERE published = 1
        ORDER BY view_count DESC
        LIMIT 5
    """)
    
    # Get author stats for sidebar
    let authors = db.fetch_all("""
        SELECT 
            u.username,
            COUNT(p.id) as post_count
        FROM users u
        LEFT JOIN posts p ON u.id = p.author_id AND p.published = 1
        GROUP BY u.id
        HAVING post_count > 0
        ORDER BY post_count DESC
    """)
    
    # Render template
    let html = tmpl.render("home.html", {
        posts: posts,
        popular_posts: popular_posts,
        authors: authors
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

    # Get related posts from same author
    let related_posts = db.fetch_all("""
        SELECT id, title, slug
        FROM posts
        WHERE author_id = ? AND id != ? AND published = 1
        ORDER BY published_at DESC
        LIMIT 3
    """, post["author_id"], post["id"])
    
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
        related_posts: related_posts,
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
