# Admin routes module
use "std/encoding/json"
use "std/html/templates"
use "std/db/sqlite"
use "std/os"
use "std/time"
use "std/web" as web
use "std/web/router" as router_module
use "std/log"

# Initialize logging with both stdout and file handlers
let logger = log.get_logger("blog")
logger.set_level(log.INFO)


# Admin handlers will need access to these (passed as parameters or imported)
# For now, export a function that takes dependencies and returns configured router

pub fun create_admin_router(db, tmpl, logger, get_client_ip_fn, upload_dir, calculate_read_time_fn, get_published_pages_fn)


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

    # Check if the client IP is allowed to edit
    fun is_edit_allowed(req)
        let client_ip = get_client_ip_fn(req)
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

    let admin = router_module.Router.new()
    
    # Admin post management
    admin.get("/", fun (req)
        if not is_edit_allowed(req)
            return {status: 404, headers: {"Content-Type": "text/html"}, body: "<h1>404</h1>"}
        end
        
        let posts = db.post.find_all_for_admin(db.get_db())
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
        
        return {
            status: 200,
            headers: {"Content-Type": "text/html; charset=utf-8"},
            body: tmpl.render("admin.html", {posts: posts})
        }
    end)

        # Edit routes  
    admin.get("/edit/{slug}", fun (req)
        if not is_edit_allowed(req)
            return {status: 403, headers: {"Content-Type": "text/html"}, body: "<h1>403 Forbidden</h1>"}
        end

        let slug = req["params"]["slug"]
        let post = db.post.find_by_slug(db.get_db(), slug, false)
        if post == nil
            return not_found_handler(req)
        end

        post["tags"] = db.tag.find_for_post(db.get_db(), post["id"])
        return {
            status: 200,
            headers: {"Content-Type": "text/html; charset=utf-8"},
            body: tmpl.render("editor.html", {post: post})
        }
    end)

    admin.post("/edit/{slug}", fun (req)
        if not is_edit_allowed(req)
            return {status: 403, headers: {"Content-Type": "application/json"}, body: json.stringify({error: "Forbidden"})}
        end

        let slug = req["params"]["slug"]
        let data = json.parse(req["body"])
        let read_time = calculate_read_time(data["content"])
        let social_image = data["social_image"]
        let result = db.post.update(db.get_db(), slug, data["title"], data["slug"], data["content"], read_time, data["tags"], nil, social_image)

        if result == nil
            return {status: 404, headers: {"Content-Type": "application/json"}, body: json.stringify({error: "Post not found"})}
        end

        return {status: 200, headers: {"Content-Type": "application/json"}, body: json.stringify({success: true})}
    end)
    
    # New post form
    admin.get("/new", fun (req)
        if not is_edit_allowed_fn(req)
            return {status: 404, headers: {"Content-Type": "text/html"}, body: "<h1>404</h1>"}
        end
        return {
            status: 200,
            headers: {"Content-Type": "text/html; charset=utf-8"},
            body: tmpl.render("new_post.html", {})
        }
    end)
    
    # Create post
    admin.post("/new", fun (req)
        if not is_edit_allowed_fn(req)
            return {status: 404, headers: {"Content-Type": "application/json"}, body: json.stringify({error: "Not found"})}
        end
        
        let data = json.parse(req["body"])
        let author = db.user.find_default_author(db.get_db())
        if author == nil
            return {status: 500, headers: {"Content-Type": "application/json"}, body: json.stringify({error: "No author found"})}
        end
        
        let read_time = calculate_read_time_fn(data["content"])
        let social_image = data["social_image"]
        db.post.create(db.get_db(), data["title"], data["slug"], data["content"], read_time, author["id"], data["tags"], social_image)
        
        return {status: 200, headers: {"Content-Type": "application/json"}, body: json.stringify({success: true, slug: data["slug"]})}
    end)
    
    # Edit post form
    admin.get("/edit/{slug}", fun (req)
        if not is_edit_allowed(req)
            return {status: 404, headers: {"Content-Type": "text/html"}, body: "<h1>404</h1>"}
        end
        
        let slug = req["params"]["slug"]
        let post = db.post.find_by_slug(db.get_db(), slug, false)
        if post == nil
            return {status: 404, headers: {"Content-Type": "text/html"}, body: "<h1>404</h1>"}
        end
        
        post["tags"] = db.tag.find_for_post(db.get_db(), post["id"])
        return {
            status: 200,
            headers: {"Content-Type": "text/html; charset=utf-8"},
            body: tmpl.render("admin_editor.html", {post: post})
        }
    end)
    
    # Save post
    admin.post("/edit/{slug}", fun (req)
        if not is_edit_allowed(req)
            return {status: 404, headers: {"Content-Type": "application/json"}, body: json.stringify({error: "Not found"})}
        end
        
        let slug = req["params"]["slug"]
        let data = json.parse(req["body"])
        let read_time = calculate_read_time_fn(data["content"])
        let social_image = data["social_image"]
        let result = db.post.update(db.get_db(), slug, data["title"], data["slug"], data["content"], read_time, data["tags"], data["published_at"], social_image)
        
        if result == nil
            return {status: 404, headers: {"Content-Type": "application/json"}, body: json.stringify({error: "Post not found"})}
        end
        
        return {status: 200, headers: {"Content-Type": "application/json"}, body: json.stringify({success: true, slug: data["slug"]})}
    end)
    
    # Delete post
    admin.post("/delete/{slug}", fun (req)
        if not is_edit_allowed(req)
            return {status: 404, headers: {"Content-Type": "application/json"}, body: json.stringify({error: "Not found"})}
        end
        
        let slug = req["params"]["slug"]
        let deleted = db.post.delete(db.get_db(), slug)
        if not deleted
            return {status: 404, headers: {"Content-Type": "application/json"}, body: json.stringify({error: "Post not found"})}
        end
        
        return {status: 200, headers: {"Content-Type": "application/json"}, body: json.stringify({success: true})}
    end)
    
    # TODO: Add pages and media routes similarly
    
    # ============================================================================
    # Media Management Handlers
    # ============================================================================

    # Media library handler - show all uploaded files
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
        let files = db.media.list_files(upload_dir)

        # Add public URLs to each file
        let i = 0
        while i < files.len()
            files[i]["url"] = db.media.get_file_url(files[i]["filename"])
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
            let saved = db.media.save_file(upload_dir, filename, mime_type, data, nil)
            let url = db.media.get_file_url(saved["filename"])

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
            let deleted = db.media.delete_file(upload_dir, filename)

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

    return admin
end


