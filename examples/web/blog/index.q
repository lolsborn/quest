use "std/encoding/json"
use "std/html/templates"
use "std/db/sqlite"
use "std/time"
use "std/markdown"
use "std/os"
use "std/io"
use "std/log"
use "std/web" as web
use "atom"
use "router" as router {Get, Post}

# Import repositories
use "repos/user" as user_repo
use "repos/post" as post_repo
use "repos/tag" as tag_repo
use "repos/page" as page_repo
use "repos/media" as media_repo

# Initialize logging with both stdout and file handlers
let logger = log.get_logger("blog")
logger.set_level(log.INFO)

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
        ALLOWED_IPS[i] = ALLOWED_IPS[i].trim()
        i = i + 1
    end
    logger.info("Edit access restricted to IPs: " .. allowed_ips_env)
else
    ALLOWED_IPS = ["127.0.0.1"]
    logger.info("ALLOWED_IPS not set - edit access restricted to localhost (127.0.0.1)")
end

# Configure static file directories
# Default public directory for assets (CSS, JS, images)
web.static("/public", "./public")

# Optional upload directory from environment variable
# Set WEB_UPLOAD_DIR env var to serve uploaded files from a custom location
let upload_dir = os.getenv("WEB_UPLOAD_DIR")
if upload_dir != nil
    # Ensure upload directory exists
    try
        if not io.exists(upload_dir)
            os.mkdir(upload_dir)
            logger.info("Created upload directory: " .. upload_dir)
        end

        # Configure static file serving for uploads
        web.static("/uploads", upload_dir)
        logger.info("Upload directory configured: " .. upload_dir .. " -> /uploads")
    catch e
        logger.error("Failed to setup upload directory: " .. e.message())
        logger.error("Media uploads will not be available")
    end
else
    logger.info("WEB_UPLOAD_DIR not set - upload directory not configured")
    logger.info("Set WEB_UPLOAD_DIR environment variable to enable media uploads")
end

# Get the real client IP, checking X-Forwarded-For header first
fun get_client_ip(req)
    # Check for X-Forwarded-For header first (proxy/load balancer)
    if req["headers"] != nil and req["headers"]["x-forwarded-for"] != nil
        let xff = req["headers"]["x-forwarded-for"]
        # X-Forwarded-For can be a comma-separated list, take the first IP
        let first_ip = xff.split(",")[0].trim()
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

# Helper function to calculate read time from content (words per minute: 200)
fun calculate_read_time(content)
    # Simple word count - split on whitespace
    let words = content.split(" ")
    let word_count = 0
    let i = 0
    while i < words.len()
        if words[i].trim().len() > 0
            word_count = word_count + 1
        end
        i = i + 1
    end

    # 200 words per minute, round up
    let minutes = (word_count + 199) / 200  # Integer division rounds down, so add 199 to round up
    if minutes < 1
        return 1  # Minimum 1 minute
    end
    return minutes
end

# Helper function to get published pages for navigation
fun get_published_pages()
    return page_repo.find_published_for_nav(db)
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

    # Dispatch request to registered route handlers
    return router.dispatch(req, not_found_handler)
end

# Get tags handler - returns all tags as JSON for autocomplete
@Get(path: "/api/tags", match_type: "exact")
fun get_tags_handler(req)
    let tags = tag_repo.find_all(db)

    return {
        status: web.HTTP_OK,
        headers: {
            "Content-Type": "application/json"
        },
        body: json.stringify(tags)
    }
end

# Home page handler - shows blog post listing
@Get(path: "/", match_type: "exact")
fun home_handler(req)
    # Check for tag filter in query params
    let tag_filter = nil
    if req["query"] != nil and req["query"]["tag"] != nil
        tag_filter = req["query"]["tag"]
    end

    # Get all published posts with author info
    let posts = post_repo.find_all(db, true, tag_filter, nil)

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
        posts[i]["tags"] = tag_repo.find_for_post(db, posts[i]["id"])

        i = i + 1
    end

    # Get popular posts for sidebar
    let popular_posts = post_repo.find_popular(db, 5, nil)

    # Get all tags for filter UI
    let all_tags = tag_repo.find_all(db)

    # Get tags with post counts
    let tags_with_counts = tag_repo.find_with_counts(db)

    # Get published pages for navigation
    let pages = get_published_pages()

    # Render template
    let html = tmpl.render("home.html", {
        posts: posts,
        popular_posts: popular_posts,
        all_tags: all_tags,
        current_tag: tag_filter,
        tags_with_counts: tags_with_counts,
        pages: pages,
        can_edit: is_edit_allowed(req)
    })

    return {
        status: web.HTTP_OK,
        headers: {
            "Content-Type": "text/html; charset=utf-8"
        },
        body: html
    }
end

# Individual post handler
@Get(path: "/post/", match_type: "prefix")
fun post_handler(req)
    # Extract slug from path (/post/slug-name)
    let path = req["path"]
    let slug = path.replace("/post/", "")

    # Get post with author info
    let post = post_repo.find_by_slug(db, slug, true)

    if post == nil
        return not_found_handler(req)
    end

    # Increment view count
    post_repo.increment_view_count(db, post["id"])

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
    post["tags"] = tag_repo.find_for_post(db, post["id"])

    # Get popular posts for sidebar
    let popular_posts = post_repo.find_popular(db, 5, post["id"])

    # Get tags with post counts
    let tags_with_counts = tag_repo.find_with_counts(db)

    # Get published pages for navigation
    let pages = get_published_pages()

    # Render template
    let html = tmpl.render("post.html", {
        post: post,
        popular_posts: popular_posts,
        tags_with_counts: tags_with_counts,
        pages: pages,
        can_edit: is_edit_allowed(req)
    })

    return {
        status: web.HTTP_OK,
        headers: {
            "Content-Type": "text/html; charset=utf-8"
        },
        body: html
    }
end

# Editor handler - show the editor for a post
@Get(path: "/edit/", match_type: "prefix")
fun editor_handler(req)
    # Check if editing is allowed from this IP
    if not is_edit_allowed(req)
        return {
            status: web.HTTP_FORBIDDEN,
            headers: {"Content-Type": "text/html; charset=utf-8"},
            body: "<h1>403 Forbidden</h1><p>You are not authorized to edit posts.</p>"
        }
    end

    # Extract slug from path (/edit/slug-name)
    let path = req["path"]
    let slug = path.replace("/edit/", "")

    # Get post
    let post = post_repo.find_by_slug(db, slug, false)

    if post == nil
        return not_found_handler(req)
    end

    # Get tags for this post
    post["tags"] = tag_repo.find_for_post(db, post["id"])

    # Render editor template
    let html = tmpl.render("editor.html", {
        post: post
    })

    return {
        status: web.HTTP_OK,
        headers: {
            "Content-Type": "text/html; charset=utf-8"
        },
        body: html
    }
end

# Save post handler - persist changes from editor
@Post(path: "/edit/", match_type: "prefix")
fun save_post_handler(req)
    # Check if editing is allowed from this IP
    if not is_edit_allowed(req)
        return {
            status: web.HTTP_FORBIDDEN,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: "Forbidden"})
        }
    end

    # Extract slug from path (/edit/slug-name)
    let path = req["path"]
    let slug = path.replace("/edit/", "")

    # Parse JSON body
    let data = json.parse(req["body"])

    # Calculate read time
    let read_time = calculate_read_time(data["content"])

    # Get social_image from data (optional)
    let social_image = data["social_image"]

    # Update post (don't change published_at from quick editor)
    let result = post_repo.update(db, slug, data["title"], data["slug"], data["content"], read_time, data["tags"], nil, social_image)

    if result == nil
        return {
            status: web.HTTP_NOT_FOUND,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: "Post not found"})
        }
    end

    return {
        status: web.HTTP_OK,
        headers: {
            "Content-Type": "application/json"
        },
        body: json.stringify({success: true})
    }
end

# Admin handlers
# Admin page handler - shows all posts for management
@Get(path: "/admin", match_type: "exact")
fun admin_handler(req)
    # Check if editing is allowed from this IP - return 404 to not reveal admin existence
    if not is_edit_allowed(req)
        return not_found_handler(req)
    end

    # Get all posts (published and drafts)
    let posts = post_repo.find_all_for_admin(db)

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
        status: web.HTTP_OK,
        headers: {
            "Content-Type": "text/html; charset=utf-8"
        },
        body: html
    }
end

# New post handler - show editor for creating a new post
@Get(path: "/admin/new", match_type: "exact")
fun new_post_handler(req)
    # Check if editing is allowed from this IP - return 404 to not reveal admin existence
    if not is_edit_allowed(req)
        return not_found_handler(req)
    end

    # Render new post editor template
    let html = tmpl.render("new_post.html", {})

    return {
        status: web.HTTP_OK,
        headers: {
            "Content-Type": "text/html; charset=utf-8"
        },
        body: html
    }
end

# Create post handler - persist new post
@Post(path: "/admin/new", match_type: "exact")
fun create_post_handler(req)
    # Check if editing is allowed from this IP - return 404 to not reveal admin existence
    if not is_edit_allowed(req)
        return {
            status: web.HTTP_NOT_FOUND,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: "Not found"})
        }
    end

    # Parse JSON body
    let data = json.parse(req["body"])

    # Get default author (first user)
    let author = user_repo.find_default_author(db)
    if author == nil
        return {
            status: web.HTTP_INTERNAL_SERVER_ERROR,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: "No author found"})
        }
    end

    # Calculate read time
    let read_time = calculate_read_time(data["content"])

    # Get social_image from data (optional)
    let social_image = data["social_image"]

    # Create the post
    let post = post_repo.create(db, data["title"], data["slug"], data["content"], read_time, author["id"], data["tags"], social_image)

    return {
        status: web.HTTP_OK,
        headers: {
            "Content-Type": "application/json"
        },
        body: json.stringify({success: true, slug: data["slug"]})
    }
end

# Admin editor handler - show the editor for a post
@Get(path: "/admin/edit/", match_type: "prefix")
fun admin_editor_handler(req)
    # Check if editing is allowed from this IP - return 404 to not reveal admin existence
    if not is_edit_allowed(req)
        return not_found_handler(req)
    end

    # Extract slug from path (/admin/edit/slug-name)
    let path = req["path"]
    let slug = path.replace("/admin/edit/", "")

    # Get post
    let post = post_repo.find_by_slug(db, slug, false)

    if post == nil
        return not_found_handler(req)
    end

    # Get tags for this post
    post["tags"] = tag_repo.find_for_post(db, post["id"])

    # Render editor template
    let html = tmpl.render("admin_editor.html", {
        post: post
    })

    return {
        status: web.HTTP_OK,
        headers: {
            "Content-Type": "text/html; charset=utf-8"
        },
        body: html
    }
end

# Admin save post handler - persist changes from editor
@Post(path: "/admin/edit/", match_type: "prefix")
fun admin_save_post_handler(req)
    # Check if editing is allowed from this IP - return 404 to not reveal admin existence
    if not is_edit_allowed(req)
        return {
            status: web.HTTP_NOT_FOUND,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: "Not found"})
        }
    end

    # Extract slug from path (/admin/edit/slug-name)
    let path = req["path"]
    let slug = path.replace("/admin/edit/", "")

    # Parse JSON body
    let data = json.parse(req["body"])

    # Calculate read time
    let read_time = calculate_read_time(data["content"])

    # Get social_image from data (optional)
    let social_image = data["social_image"]

    # Update post
    let result = post_repo.update(db, slug, data["title"], data["slug"], data["content"], read_time, data["tags"], data["published_at"], social_image)

    if result == nil
        return {
            status: web.HTTP_NOT_FOUND,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: "Post not found"})
        }
    end

    return {
        status: web.HTTP_OK,
        headers: {
            "Content-Type": "application/json"
        },
        body: json.stringify({success: true, slug: data["slug"]})
    }
end

# Delete post handler
@Post(path: "/admin/delete/", match_type: "prefix")
fun delete_post_handler(req)
    # Check if editing is allowed from this IP - return 404 to not reveal admin existence
    if not is_edit_allowed(req)
        return {
            status: web.HTTP_NOT_FOUND,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: "Not found"})
        }
    end

    # Extract slug from path (/admin/delete/slug-name)
    let path = req["path"]
    let slug = path.replace("/admin/delete/", "")

    # Delete the post
    let deleted = post_repo.delete(db, slug)

    if not deleted
        return {
            status: web.HTTP_NOT_FOUND,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: "Post not found"})
        }
    end

    return {
        status: web.HTTP_OK,
        headers: {
            "Content-Type": "application/json"
        },
        body: json.stringify({success: true})
    }
end

# Atom feed handler
@Get(path: "/atom.xml", match_type: "exact")
@Get(path: "/feed.xml", match_type: "exact")
fun atom_handler(req)
    # Get recent published posts
    let posts = post_repo.find_all(db, true, nil, 20)

    # Build Atom entries with tags
    let entries = []
    let i = 0
    while i < posts.len()
        let post = posts[i]

        # Get tags for this post
        let post_tags = tag_repo.find_for_post(db, post["id"])

        # Build full post URL
        let post_url = "https://stevenosborn.com/post/" .. post["slug"]

        # Truncate content to first 300 characters for summary
        let content = post["content"]
        let summary = content
        if content.len() > 300
            summary = content.substr(0, 300) .. "..."
        end

        # Create Atom entry
        let entry = {
            title: post["title"],
            link: post_url,
            id: post_url,
            summary: summary,
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
        link: "https://stevenosborn.com/",
        id: "https://stevenosborn.com/",
        subtitle: "Technical writings on software development, programming languages, and digital plumbing",
        author_name: "Steven Osborn",
        author_email: "steven@bitsetters.com"
    }

    # Generate Atom XML
    let xml = atom.generate_atom(feed_info, entries)

    return {
        status: web.HTTP_OK,
        headers: {
            "Content-Type": "application/atom+xml; charset=utf-8"
        },
        body: xml
    }
end

# Page view handler
@Get(path: "/page/", match_type: "prefix")
fun page_handler(req)
    # Extract slug from path (/page/slug-name)
    let path = req["path"]
    let slug = path.replace("/page/", "")

    # Get page with author info
    let page = page_repo.find_by_slug(db, slug, true)

    if page == nil
        return not_found_handler(req)
    end

    # Convert markdown to HTML
    try
        page["content_html"] = markdown.to_html(page["content"])
    catch e
        logger.error("Error converting markdown: " .. e.message())
        page["content_html"] = "<p>Error rendering content</p>"
    end

    # Get published pages for navigation
    let pages = get_published_pages()

    # Render template
    let html = tmpl.render("page.html", {
        page: page,
        pages: pages,
        can_edit: is_edit_allowed(req)
    })

    return {
        status: web.HTTP_OK,
        headers: {
            "Content-Type": "text/html; charset=utf-8"
        },
        body: html
    }
end

# Admin pages list handler
@Get(path: "/admin/pages", match_type: "exact")
fun admin_pages_handler(req)
    # Check if editing is allowed from this IP - return 404 to not reveal admin existence
    if not is_edit_allowed(req)
        return not_found_handler(req)
    end

    # Get all pages
    let pages = page_repo.find_all(db, false)

    # Render template
    let html = tmpl.render("admin_pages.html", {
        pages: pages
    })

    return {
        status: web.HTTP_OK,
        headers: {
            "Content-Type": "text/html; charset=utf-8"
        },
        body: html
    }
end

# New page handler - show editor for creating a new page
@Get(path: "/admin/pages/new", match_type: "exact")
fun new_page_handler(req)
    # Check if editing is allowed from this IP - return 404 to not reveal admin existence
    if not is_edit_allowed(req)
        return not_found_handler(req)
    end

    # Render new page editor template
    let html = tmpl.render("new_page.html", {})

    return {
        status: web.HTTP_OK,
        headers: {
            "Content-Type": "text/html; charset=utf-8"
        },
        body: html
    }
end

# Create page handler - persist new page
@Post(path: "/admin/pages/new", match_type: "exact")
fun create_page_handler(req)
    # Check if editing is allowed from this IP - return 404 to not reveal admin existence
    if not is_edit_allowed(req)
        return {
            status: web.HTTP_NOT_FOUND,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: "Not found"})
        }
    end

    # Parse JSON body
    let data = json.parse(req["body"])

    # Get default author (first user)
    let author = user_repo.find_default_author(db)
    if author == nil
        return {
            status: web.HTTP_INTERNAL_SERVER_ERROR,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: "No author found"})
        }
    end

    # Create the page
    page_repo.create(db, data["title"], data["slug"], data["content"], data["order"], author["id"])

    return {
        status: web.HTTP_OK,
        headers: {
            "Content-Type": "application/json"
        },
        body: json.stringify({success: true, slug: data["slug"]})
    }
end

# Admin page editor handler - show the editor for a page
@Get(path: "/admin/pages/edit/", match_type: "prefix")
fun admin_page_editor_handler(req)
    # Check if editing is allowed from this IP - return 404 to not reveal admin existence
    if not is_edit_allowed(req)
        return not_found_handler(req)
    end

    # Extract slug from path (/admin/pages/edit/slug-name)
    let path = req["path"]
    let slug = path.replace("/admin/pages/edit/", "")

    # Get page
    let page = page_repo.find_by_slug(db, slug, false)

    if page == nil
        return not_found_handler(req)
    end

    # Render editor template
    let html = tmpl.render("admin_page_editor.html", {
        page: page
    })

    return {
        status: web.HTTP_OK,
        headers: {
            "Content-Type": "text/html; charset=utf-8"
        },
        body: html
    }
end

# Admin save page handler - persist changes from editor
@Post(path: "/admin/pages/edit/", match_type: "prefix")
fun admin_save_page_handler(req)
    # Check if editing is allowed from this IP - return 404 to not reveal admin existence
    if not is_edit_allowed(req)
        return {
            status: web.HTTP_NOT_FOUND,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: "Not found"})
        }
    end

    # Extract slug from path (/admin/pages/edit/slug-name)
    let path = req["path"]
    let slug = path.replace("/admin/pages/edit/", "")

    # Parse JSON body
    let data = json.parse(req["body"])

    # Update page
    let result = page_repo.update(db, slug, data["title"], data["slug"], data["content"], data["order"])

    if result == nil
        return {
            status: web.HTTP_NOT_FOUND,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: "Page not found"})
        }
    end

    return {
        status: web.HTTP_OK,
        headers: {
            "Content-Type": "application/json"
        },
        body: json.stringify({success: true, slug: data["slug"]})
    }
end

# Delete page handler
@Post(path: "/admin/pages/delete/", match_type: "prefix")
fun delete_page_handler(req)
    # Check if editing is allowed from this IP - return 404 to not reveal admin existence
    if not is_edit_allowed(req)
        return {
            status: web.HTTP_NOT_FOUND,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: "Not found"})
        }
    end

    # Extract slug from path (/admin/pages/delete/slug-name)
    let path = req["path"]
    let slug = path.replace("/admin/pages/delete/", "")

    # Delete the page
    let deleted = page_repo.delete(db, slug)

    if not deleted
        return {
            status: web.HTTP_NOT_FOUND,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: "Page not found"})
        }
    end

    return {
        status: web.HTTP_OK,
        headers: {
            "Content-Type": "application/json"
        },
        body: json.stringify({success: true})
    }
end

# ============================================================================
# Media Management Handlers
# ============================================================================

# Media library handler - show all uploaded files
@Get(path: "/admin/media", match_type: "exact")
fun media_library_handler(req)
    # Check if editing is allowed from this IP - return 404 to not reveal admin existence
    if not is_edit_allowed(req)
        return not_found_handler(req)
    end

    # Check if upload directory is configured
    if upload_dir == nil
        return {
            status: web.HTTP_INTERNAL_SERVER_ERROR,
            headers: {"Content-Type": "text/html; charset=utf-8"},
            body: "<h1>Media Library Not Configured</h1><p>Set WEB_UPLOAD_DIR environment variable.</p>"
        }
    end

    # List all files
    let files = media_repo.list_files(upload_dir)

    # Add public URLs to each file
    let i = 0
    while i < files.len()
        files[i]["url"] = media_repo.get_file_url(files[i]["filename"])
        i = i + 1
    end

    # Render template
    let html = tmpl.render("media_library.html", {
        files: files,
        upload_dir: upload_dir
    })

    return {
        status: web.HTTP_OK,
        headers: {
            "Content-Type": "text/html; charset=utf-8"
        },
        body: html
    }
end

# Upload media handler - handle file uploads
@Post(path: "/admin/media/upload", match_type: "exact")
fun upload_media_handler(req)
    # Check if editing is allowed from this IP
    if not is_edit_allowed(req)
        return {
            status: web.HTTP_FORBIDDEN,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: "Forbidden"})
        }
    end

    # Check if upload directory is configured
    if upload_dir == nil
        return {
            status: web.HTTP_INTERNAL_SERVER_ERROR,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: "Upload directory not configured"})
        }
    end

    # Check if body is multipart
    if req["body"].cls() != "Dict"
        return {
            status: web.HTTP_BAD_REQUEST,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: "Expected multipart/form-data"})
        }
    end

    let body = req["body"]
    let files = body["files"]

    # Check if any files were uploaded
    if files.len() == 0
        return {
            status: web.HTTP_BAD_REQUEST,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: "No file uploaded"})
        }
    end

    # Process first file (single file upload for now)
    let file = files[0]
    let filename = file["filename"]
    let mime_type = file["mime_type"]
    let data = file["data"]

    # Save file
    try
        let saved = media_repo.save_file(upload_dir, filename, mime_type, data, nil)
        let url = media_repo.get_file_url(saved["filename"])

        let upload_msg = "File uploaded: " .. saved["filename"] .. " (" .. saved["size"].str() .. " bytes)"
        logger.info(upload_msg)

        return {
            status: web.HTTP_OK,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({
                success: true,
                filename: saved["filename"],
                original_filename: saved["original_filename"],
                url: url,
                size: saved["size"],
                mime_type: saved["mime_type"]
            })
        }
    catch e
        logger.error("File upload failed: " .. e.message())
        return {
            status: web.HTTP_BAD_REQUEST,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: e.message()})
        }
    end
end

# Delete media handler
@Post(path: "/admin/media/delete", match_type: "exact")
fun delete_media_handler(req)
    # Check if editing is allowed from this IP
    if not is_edit_allowed(req)
        return {
            status: web.HTTP_FORBIDDEN,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: "Forbidden"})
        }
    end

    # Check if upload directory is configured
    if upload_dir == nil
        return {
            status: web.HTTP_INTERNAL_SERVER_ERROR,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: "Upload directory not configured"})
        }
    end

    # Parse JSON body
    let data = json.parse(req["body"])
    let filename = data["filename"]

    if filename == nil
        return {
            status: web.HTTP_BAD_REQUEST,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: "Filename required"})
        }
    end

    # Delete file
    try
        let deleted = media_repo.delete_file(upload_dir, filename)

        if not deleted
            return {
                status: web.HTTP_NOT_FOUND,
                headers: {"Content-Type": "application/json"},
                body: json.stringify({error: "File not found"})
            }
        end

        logger.info("File deleted: " .. filename)

        return {
            status: web.HTTP_OK,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({success: true})
        }
    catch e
        logger.error("File deletion failed: " .. e.message())
        return {
            status: web.HTTP_BAD_REQUEST,
            headers: {"Content-Type": "application/json"},
            body: json.stringify({error: e.message()})
        }
    end
end

# 404 handler
fun not_found_handler(req)
    # Get published pages for navigation
    let pages = get_published_pages()

    # Render 404 template
    let html = tmpl.render("404.html", {
        path: req["path"],
        pages: pages
    })

    return {
        status: web.HTTP_NOT_FOUND,
        headers: {
            "Content-Type": "text/html; charset=utf-8"
        },
        body: html
    }
end

# Routes are automatically registered via @Get/@Post decorators (QEP-003 Phase 2)
# No need for manual router.register_handler() calls!

logger.info("Quest blog server initialized!")
logger.info("Auto-registered " .. router.get_routes().len().str() .. " routes via decorators")
