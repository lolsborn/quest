use "std/encoding/json"
use "std/html/templates"
use "std/db/sqlite"
use "std/time" as time
use "std/markdown" as markdown
use "std/os" as os

# Initialize database connection (reused across requests)
let conn = sqlite.connect("blog.sqlite3")
let db = conn.cursor()

# Initialize template engine
let tmpl = templates.from_dir("templates/**/*.html")

# Load allowed IP addresses from environment variable
# Set ALLOWED_IPS env var with comma-separated IPs: "127.0.0.1,192.168.1.100"
# If not set, defaults to localhost only
let ALLOWED_IPS = nil
let allowed_ips_env = os.getenv("ALLOWED_IPS")
if allowed_ips_env != nil
    ALLOWED_IPS = allowed_ips_env.split(",")
    # Trim whitespace from each IP
    let i = 0
    while i < ALLOWED_IPS.len()
        ALLOWED_IPS[i] = ALLOWED_IPS[i].strip()
        i = i + 1
    end
    puts("Edit access restricted to IPs: " .. allowed_ips_env)
else
    ALLOWED_IPS = ["127.0.0.1"]
    puts("ALLOWED_IPS not set - edit access restricted to localhost (127.0.0.1)")
end

# Check if the client IP is allowed to edit
fun is_edit_allowed(req)
    if req["client_ip"] == nil
        return false
    end

    let client_ip = req["client_ip"]
    let i = 0
    while i < ALLOWED_IPS.len()
        if client_ip == ALLOWED_IPS[i]
            return true
        end
        i = i + 1
    end
    return false
end

fun handle_request(req)
    # Log the request
    let path = req["path"]
    let method = req["method"]

    
    let client_ip = req["client_ip"] or "unknown"
    let now = time.now()
    let timestamp = now.str()
    let query = req["query_string"] or ""
    if query != ""
        query = "?" .. query
    end
    puts(f"[{timestamp}] {client_ip} {method} {path}{query}")

    if path == "/"
        return home_handler(req)
    elif path == "/api/tags" and method == "GET"
        return get_tags_handler(req)
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

# Get tags handler - returns all tags as JSON for autocomplete
fun get_tags_handler(req)
    let tags = db.fetch_all("SELECT id, name FROM tags ORDER BY name ASC")

    return {
        status: 200,
        headers: {
            "Content-Type": "application/json"
        },
        body: json.stringify(tags)
    }
end

# Home page handler - shows blog post listing
fun home_handler(req)
    # Check for tag filter in query params
    let tag_filter = nil
    if req["query"] != nil and req["query"]["tag"] != nil
        tag_filter = req["query"]["tag"]
    end

    # Get all published posts with author info
    let posts = nil
    if tag_filter != nil
        posts = db.fetch_all("""
            SELECT DISTINCT
                p.*,
                u.username as author_username,
                u.email as author_email
            FROM posts p
            JOIN users u ON p.author_id = u.id
            JOIN post_tags pt ON p.id = pt.post_id
            JOIN tags t ON pt.tag_id = t.id
            WHERE p.published = 1 AND t.name = ?
            ORDER BY p.published_at DESC
        """, tag_filter)
    else
        posts = db.fetch_all("""
            SELECT
                p.*,
                u.username as author_username,
                u.email as author_email
            FROM posts p
            JOIN users u ON p.author_id = u.id
            WHERE p.published = 1
            ORDER BY p.published_at DESC
        """)
    end

    # Format dates and convert markdown to HTML
    let i = 0
    while i < posts.len()
        let date = time.parse(posts[i]["published_at"].split(" ")[0])
        let midnight = time.time(0, 0, 0)
        let zoned = date.at_time(midnight, "UTC")
        posts[i]["published_at_formatted"] = zoned.format("%B %d, %Y")
        try
            posts[i]["content_html"] = markdown.to_html(posts[i]["content"])
        catch e
            puts("Error converting markdown: " .. e.message())
            posts[i]["content_html"] = "<p>Error rendering content</p>"
        end

        # Get tags for this post
        let post_tags = db.fetch_all("""
            SELECT t.name
            FROM tags t
            JOIN post_tags pt ON t.id = pt.tag_id
            WHERE pt.post_id = ?
            ORDER BY t.name
        """, posts[i]["id"])
        posts[i]["tags"] = post_tags

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

    # Get all tags for filter UI
    let all_tags = db.fetch_all("SELECT name FROM tags ORDER BY name ASC")

    # Render template
    let html = tmpl.render("home.html", {
        posts: posts,
        popular_posts: popular_posts,
        all_tags: all_tags,
        current_tag: tag_filter,
        can_edit: is_edit_allowed(req)
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

    # Format the post date and convert markdown to HTML
    let date = time.parse(post["published_at"].split(" ")[0])
    let midnight = time.time(0, 0, 0)
    let zoned = date.at_time(midnight, "UTC")
    post["published_at_formatted"] = zoned.format("%B %d, %Y")
    try
        post["content_html"] = markdown.to_html(post["content"])
    catch e
        puts("Error converting markdown: " .. e.message())
        post["content_html"] = "<p>Error rendering content</p>"
    end

    # Get tags for this post
    let post_tags = db.fetch_all("""
        SELECT t.name
        FROM tags t
        JOIN post_tags pt ON t.id = pt.tag_id
        WHERE pt.post_id = ?
        ORDER BY t.name
    """, post["id"])
    post["tags"] = post_tags

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
        popular_posts: popular_posts,
        can_edit: is_edit_allowed(req)
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
    # Check if editing is allowed from this IP
    if not is_edit_allowed(req)
        return {
            status: 403,
            headers: {"Content-Type": "text/html; charset=utf-8"},
            body: "<h1>403 Forbidden</h1><p>You are not authorized to edit posts.</p>"
        }
    end

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

    # Get tags for this post
    let post_tags = db.fetch_all("""
        SELECT t.name
        FROM tags t
        JOIN post_tags pt ON t.id = pt.tag_id
        WHERE pt.post_id = ?
        ORDER BY t.name
    """, post["id"])
    post["tags"] = post_tags

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
    # Check if editing is allowed from this IP
    if not is_edit_allowed(req)
        return {
            status: 403,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: "Forbidden"})
        }
    end

    # Extract slug from path (/edit/slug-name)
    let path = req["path"]
    let slug = path.replace("/edit/", "")

    # Parse JSON body
    let data = json.parse(req["body"])

    # Get post ID
    let post = db.fetch_one("SELECT id FROM posts WHERE slug = ?", slug)
    if post == nil
        return {
            status: 404,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: "Post not found"})
        }
    end
    let post_id = post["id"]

    # Update post in database
    db.execute("""
        UPDATE posts
        SET title = ?, slug = ?, excerpt = ?, content = ?
        WHERE slug = ?
    """, data["title"], data["slug"], data["excerpt"], data["content"], slug)

    # Update tags if provided
    if data["tags"] != nil
        # Delete existing tags
        db.execute("DELETE FROM post_tags WHERE post_id = ?", post_id)

        # Insert new tags
        let i = 0
        while i < data["tags"].len()
            let tag_name = data["tags"][i]

            # Insert tag if it doesn't exist
            db.execute("INSERT OR IGNORE INTO tags (name) VALUES (?)", tag_name)

            # Get tag ID
            let tag = db.fetch_one("SELECT id FROM tags WHERE name = ?", tag_name)

            # Link tag to post
            db.execute("INSERT INTO post_tags (post_id, tag_id) VALUES (?, ?)", post_id, tag["id"])

            i = i + 1
        end
    end

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
    # Render 404 template
    let html = tmpl.render("404.html", {
        path: req["path"]
    })

    return {
        status: 404,
        headers: {
            "Content-Type": "text/html; charset=utf-8"
        },
        body: html
    }
end

puts("Quest blog server initialized!")
