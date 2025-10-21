use "std/encoding/json"
use "std/html/templates"
use "std/time"
use "std/markdown"
use "std/io"
use "std/os"
use "std/log"

use "std/web" as web
use "std/web/router" as router_module
use "./atom"
use "./db"


# Initialize logging with both stdout and file handlers
let logger = log.get_logger("blog")
logger.set_level(log.INFO)

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

# Initialize template engine
let tmpl = templates.from_dir("templates/**/*.html")

# Configure static file directories
# Default public directory for assets (CSS, JS, images)
try
    web.static("/public", "./public")
catch e
    logger.error("Failed to configure /public static directory: " .. e.message())
end

# Optional upload directory from environment variable
# Set WEB_UPLOAD_DIR env var to serve uploaded files from a custom location
let upload_dir = os.getenv("WEB_UPLOAD_DIR") or "./uploads"
# try
#     # Configure static file serving for uploads
#     web.static("/uploads", upload_dir)
#     logger.info("Upload directory configured: " .. upload_dir .. " -> /uploads")
# catch e
#     logger.error("Failed to setup upload directory: " .. e.message())
#     logger.error("Media uploads will not be available")
# end

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
    return db.page.find_published_for_nav(db.get_db())
end

# Helper function to get published pages for navigation
fun render_template(template, context)
    return {
        status: 200,
        headers: {"Content-Type": "text/html; charset=utf-8"},
        body: tmpl.render(template, context)
    }
end


fun atom_handler(req)
    # Get recent published posts
    let posts = db.post.find_all(db.get_db(), true, nil, 20)

    # Build Atom entries with tags
    let entries = []
    let i = 0
    while i < posts.len()
        let post = posts[i]

        # Get tags for this post
        let post_tags = db.tag.find_for_post(db.get_db(), post["id"])

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



# Initialize main router with inline handlers
let route = router_module.Router.new()
route.get("/atom.xml", atom_handler)
route.get("/feed.xml", atom_handler)


# API routes  
route.get("/api/tags", fun (req)
    let tags = db.tag.find_all(db.get_db())
    return {status: 200, headers: {"Content-Type": "application/json"}, body: json.stringify(tags)}
end)

# Public routes
route.get("/", fun (req)
    # Check for tag filter in query params
    let tag_filter = nil
    if req["query"] != nil and req["query"]["tag"] != nil
        tag_filter = req["query"]["tag"]
    end
    
    # Get all published posts with author info
    let posts = db.post.find_all(db.get_db(), true, tag_filter, nil)
    
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
        posts[i]["tags"] = db.tag.find_for_post(db.get_db(), posts[i]["id"])
        i = i + 1
    end
    
    return render_template("home.html", {
        posts: posts,
        popular_posts: db.post.find_popular(db.get_db(), 5, nil),
        all_tags: db.tag.find_all(db.get_db()),
        current_tag: tag_filter,
        tags_with_counts: db.tag.find_with_counts(db.get_db()),
        pages: get_published_pages()
    })
end)

route.get("/post/{slug}", fun (req)
    let slug = req["params"]["slug"]
    let post = db.post.find_by_slug(db.get_db(), slug, true)
    if post == nil
        return not_found_handler(req)
    end
    
    db.post.increment_view_count(db.get_db(), post["id"])
    
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
    post["tags"] = db.tag.find_for_post(db.get_db(), post["id"])
    
    return render_template("post.html", {
        post: post,
        popular_posts: db.post.find_popular(db.get_db(), 5, post["id"]),
        tags_with_counts: db.tag.find_with_counts(db.get_db()),
        pages: get_published_pages()
    })
end)

route.get("/page/{slug}", fun (req)
    let slug = req["params"]["slug"]
    let page = db.page.find_by_slug(db.get_db(), slug, true)
    if page == nil
        return not_found_handler(req)
    end
    
    try
        page["content_html"] = markdown.to_html(page["content"])
    catch e
        logger.error("Error converting markdown: " .. e.message())
        page["content_html"] = "<p>Error rendering content</p>"
    end
    
    return render_template("page.html", {
        page: page,
        pages: get_published_pages()
    })
end)


# Admin routes (moved to separate module)
use "./admin" as admin_module
let admin_router = admin_module.create_admin_router(
    db, tmpl, logger, get_client_ip,
    upload_dir, calculate_read_time, get_published_pages
)
web.route("/admin", admin_router)
# Request logging middleware
web.middleware(fun (req)
    let path = req["path"]
    let method = req["method"]
    let client_ip = get_client_ip(req) or "unknown"
    let query = req["query_string"] or ""
    if query != ""
        query = "?" .. query
    end
    logger.info(f"{client_ip} {method} {path}{query}")
    return req
end)

# Main router
web.route("/", route)

# 404 handler
web.middleware(fun (req)
    return not_found_handler(req)
end)

# Start web server
web.run(8888)
