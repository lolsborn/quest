use "std/encoding/json"
use "std/html/templates"
use "std/db/sqlite"
use "std/time" as time
use "std/markdown" as markdown
use "std/os" as os
use "std/log" as log
use "atom" as atom

# Initialize logging with both stdout and file handlers
let logger = log.get_logger("blog")
logger.set_level(log.DEBUG)  # Set to DEBUG to capture header logs

# Add stream handler (stdout) with colors - keep at INFO level
let stream_handler = log.StreamHandler.new(
    level: log.INFO,
    formatter_obj: nil,
    filters: []
)
logger.add_handler(stream_handler)

# Add file handler (blog.log) without colors - set to DEBUG to log headers
let file_formatter = log.Formatter.new(
    format_string: "[{timestamp}] {level_name} [{name}] {message}",
    date_format: "[%d/%b/%Y %H:%M:%S]",
    use_colors: false
)
let file_handler = log.FileHandler.new(
    filepath: "blog.log",
    mode: "a",
    level: log.DEBUG,  # Set to DEBUG to capture all logs including headers
    formatter_obj: file_formatter,
    filters: []
)
logger.add_handler(file_handler)

let db_file = os.getenv("DATABASE_URL") or "blog.sqlite3"

# Initialize database connection (reused across requests)
let conn = sqlite.connect(db_file)
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
    logger.info("Edit access restricted to IPs: " .. allowed_ips_env)
else
    ALLOWED_IPS = ["127.0.0.1"]
    logger.info("ALLOWED_IPS not set - edit access restricted to localhost (127.0.0.1)")
end

# Get the real client IP, checking X-Forwarded-For header first
fun get_client_ip(req)
    # Check for X-Forwarded-For header first (proxy/load balancer)
    if req["headers"] != nil and req["headers"]["x-forwarded-for"] != nil
        let xff = req["headers"]["x-forwarded-for"]
        # X-Forwarded-For can be a comma-separated list, take the first IP
        let first_ip = xff.split(",")[0].strip()
        return first_ip
    end

    # Fall back to direct client_ip
    return req["client_ip"]
end

# Check if the client IP is allowed to edit
fun is_edit_allowed(req)
    let client_ip = get_client_ip(req)
    if client_ip == nil
        return false
    end

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

    let client_ip = get_client_ip(req) or "unknown"
    let query = req["query_string"] or ""
    if query != ""
        query = "?" .. query
    end
    logger.info(f"{client_ip} {method} {path}{query}")

    # Log all request headers for debugging
    if req["headers"] != nil
        logger.debug("Request headers:")
        let headers = req["headers"]
        let keys = headers.keys()
        let i = 0
        while i < keys.len()
            let key = keys[i]
            let value = headers[key]
            logger.debug(f"  {key}: {value}")
            i = i + 1
        end
    end
    
    if path == "/"
        return home_handler(req)
    elif path == "/atom.xml" or path == "/feed.xml"
        return atom_handler(req)
    elif path == "/api/tags" and method == "GET"
        return get_tags_handler(req)
    elif path == "/admin" and method == "GET"
        return admin_handler(req)
    elif path == "/admin/new" and method == "GET"
        return new_post_handler(req)
    elif path == "/admin/new" and method == "POST"
        return create_post_handler(req)
    elif path.starts_with("/admin/edit/") and method == "GET"
        return admin_editor_handler(req)
    elif path.starts_with("/admin/edit/") and method == "POST"
        return admin_save_post_handler(req)
    elif path.starts_with("/admin/delete/") and method == "POST"
        return delete_post_handler(req)
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
            logger.error("Error converting markdown: " .. e.message())
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

    # Get tags with post counts
    let tags_with_counts = db.fetch_all("""
        SELECT t.name, COUNT(pt.post_id) as count
        FROM tags t
        LEFT JOIN post_tags pt ON t.id = pt.tag_id
        LEFT JOIN posts p ON pt.post_id = p.id AND p.published = 1
        GROUP BY t.id, t.name
        HAVING COUNT(pt.post_id) > 0
        ORDER BY t.name ASC
    """)

    # Render template
    let html = tmpl.render("home.html", {
        posts: posts,
        popular_posts: popular_posts,
        all_tags: all_tags,
        current_tag: tag_filter,
        tags_with_counts: tags_with_counts,
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
        logger.error("Error converting markdown: " .. e.message())
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

    # Get tags with post counts
    let tags_with_counts = db.fetch_all("""
        SELECT t.name, COUNT(pt.post_id) as count
        FROM tags t
        LEFT JOIN post_tags pt ON t.id = pt.tag_id
        LEFT JOIN posts p ON pt.post_id = p.id AND p.published = 1
        GROUP BY t.id, t.name
        HAVING COUNT(pt.post_id) > 0
        ORDER BY t.name ASC
    """)

    # Render template
    let html = tmpl.render("post.html", {
        post: post,
        popular_posts: popular_posts,
        tags_with_counts: tags_with_counts,
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

# Admin handlers
# Admin page handler - shows all posts for management
fun admin_handler(req)
    # Check if editing is allowed from this IP - return 404 to not reveal admin existence
    if not is_edit_allowed(req)
        return not_found_handler(req)
    end

    # Get all posts (published and drafts)
    let posts = db.fetch_all("""
        SELECT
            p.*,
            u.username as author_username
        FROM posts p
        JOIN users u ON p.author_id = u.id
        ORDER BY p.updated_at DESC
    """)

    # Format dates
    let i = 0
    while i < posts.len()
        let pub_date = time.parse(posts[i]["published_at"].split(" ")[0])
        let midnight = time.time(0, 0, 0)
        let zoned = pub_date.at_time(midnight, "UTC")
        posts[i]["published_at_formatted"] = zoned.format("%B %d, %Y")

        let upd_date = time.parse(posts[i]["updated_at"].split(" ")[0])
        let upd_zoned = upd_date.at_time(midnight, "UTC")
        posts[i]["updated_at_formatted"] = upd_zoned.format("%b %d, %Y")

        i = i + 1
    end

    # Render template
    let html = tmpl.render("admin.html", {
        posts: posts
    })

    return {
        status: 200,
        headers: {
            "Content-Type": "text/html; charset=utf-8"
        },
        body: html
    }
end

# New post handler - show editor for creating a new post
fun new_post_handler(req)
    # Check if editing is allowed from this IP - return 404 to not reveal admin existence
    if not is_edit_allowed(req)
        return not_found_handler(req)
    end

    # Render new post editor template
    let html = tmpl.render("new_post.html", {})

    return {
        status: 200,
        headers: {
            "Content-Type": "text/html; charset=utf-8"
        },
        body: html
    }
end

# Create post handler - persist new post
fun create_post_handler(req)
    # Check if editing is allowed from this IP - return 404 to not reveal admin existence
    if not is_edit_allowed(req)
        return {
            status: 404,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: "Not found"})
        }
    end

    # Parse JSON body
    let data = json.parse(req["body"])

    # Get default author (first user)
    let author = db.fetch_one("SELECT id FROM users LIMIT 1")
    if author == nil
        return {
            status: 500,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: "No author found"})
        }
    end

    # Insert new post
    db.execute("""
        INSERT INTO posts (title, slug, excerpt, content, author_id, published, published_at)
        VALUES (?, ?, ?, ?, ?, 1, datetime('now'))
    """, data["title"], data["slug"], data["excerpt"], data["content"], author["id"])

    # Get the newly created post ID
    let post = db.fetch_one("SELECT id FROM posts WHERE slug = ?", data["slug"])

    # Insert tags if provided
    if data["tags"] != nil
        let i = 0
        while i < data["tags"].len()
            let tag_name = data["tags"][i]

            # Insert tag if it doesn't exist
            db.execute("INSERT OR IGNORE INTO tags (name) VALUES (?)", tag_name)

            # Get tag ID
            let tag = db.fetch_one("SELECT id FROM tags WHERE name = ?", tag_name)

            # Link tag to post
            db.execute("INSERT INTO post_tags (post_id, tag_id) VALUES (?, ?)", post["id"], tag["id"])

            i = i + 1
        end
    end

    return {
        status: 200,
        headers: {
            "Content-Type": "application/json"
        },
        body: json.stringify({success: true, slug: data["slug"]})
    }
end

# Admin editor handler - show the editor for a post
fun admin_editor_handler(req)
    # Check if editing is allowed from this IP - return 404 to not reveal admin existence
    if not is_edit_allowed(req)
        return not_found_handler(req)
    end

    # Extract slug from path (/admin/edit/slug-name)
    let path = req["path"]
    let slug = path.replace("/admin/edit/", "")

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
    let html = tmpl.render("admin_editor.html", {
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

# Admin save post handler - persist changes from editor
fun admin_save_post_handler(req)
    # Check if editing is allowed from this IP - return 404 to not reveal admin existence
    if not is_edit_allowed(req)
        return {
            status: 404,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: "Not found"})
        }
    end

    # Extract slug from path (/admin/edit/slug-name)
    let path = req["path"]
    let slug = path.replace("/admin/edit/", "")

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
        SET title = ?, slug = ?, excerpt = ?, content = ?, updated_at = datetime('now')
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
        body: json.stringify({success: true, slug: data["slug"]})
    }
end

# Delete post handler
fun delete_post_handler(req)
    # Check if editing is allowed from this IP - return 404 to not reveal admin existence
    if not is_edit_allowed(req)
        return {
            status: 404,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: "Not found"})
        }
    end

    # Extract slug from path (/admin/delete/slug-name)
    let path = req["path"]
    let slug = path.replace("/admin/delete/", "")

    # Get post ID
    let post = db.fetch_one("SELECT id FROM posts WHERE slug = ?", slug)
    if post == nil
        return {
            status: 404,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: "Post not found"})
        }
    end

    # Delete post tags first (foreign key constraint)
    db.execute("DELETE FROM post_tags WHERE post_id = ?", post["id"])

    # Delete the post
    db.execute("DELETE FROM posts WHERE id = ?", post["id"])

    return {
        status: 200,
        headers: {
            "Content-Type": "application/json"
        },
        body: json.stringify({success: true})
    }
end

# Atom feed handler
fun atom_handler(req)
    # Get recent published posts with tags
    let posts = db.fetch_all("""
        SELECT
            p.id,
            p.title,
            p.slug,
            p.excerpt,
            p.published_at,
            p.updated_at
        FROM posts p
        WHERE p.published = 1
        ORDER BY p.published_at DESC
        LIMIT 20
    """)

    # Build Atom entries with tags
    let entries = []
    let i = 0
    while i < posts.len()
        let post = posts[i]

        # Get tags for this post
        let post_tags = db.fetch_all("""
            SELECT t.name
            FROM tags t
            JOIN post_tags pt ON t.id = pt.tag_id
            WHERE pt.post_id = ?
            ORDER BY t.name
        """, post["id"])

        # Build full post URL
        let post_url = "https://blog.bitsetters.com/post/" .. post["slug"]

        # Create Atom entry
        let entry = {
            title: post["title"],
            link: post_url,
            id: post_url,
            summary: post["excerpt"] or "Read more...",
            published: post["published_at"],
            updated: post["updated_at"],
            tags: post_tags
        }

        entries.push(entry)
        i = i + 1
    end

    # Feed information
    let feed_info = {
        title: "A Bitsetter's Blog",
        link: "https://blog.bitsetters.com/",
        id: "https://blog.bitsetters.com/",
        subtitle: "Technical writings on software development, programming languages, and digital plumbing",
        author_name: "Steven Osborn",
        author_email: "steven@bitsetters.com"
    }

    # Generate Atom XML
    let xml = atom.generate_atom(feed_info, entries)

    return {
        status: 200,
        headers: {
            "Content-Type": "application/atom+xml; charset=utf-8"
        },
        body: xml
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

logger.info("Quest blog server initialized!")
