# Admin routes module
use "std/encoding/json"
use "std/time"
use "std/os"
use "std/web" as web
use "std/log"
use "std/web/router" as router_module

pub fun create_admin_router(db, tmpl, logger, get_client_ip, upload_dir, calculate_read_time, get_published_pages)
    let admin = router_module.Router.new()
    
    # Load allowed IPs from environment
    let ALLOWED_IPS = nil
    let allowed_ips_env = os.getenv("ALLOWED_IPS")
    if allowed_ips_env != nil
        ALLOWED_IPS = allowed_ips_env.split(",")
        let i = 0
        while i < ALLOWED_IPS.len()
            ALLOWED_IPS[i] = ALLOWED_IPS[i].trim()
            i = i + 1
        end
        logger.info("Admin: Edit access restricted to IPs: " .. allowed_ips_env)
    else
        ALLOWED_IPS = ["127.0.0.1"]
        logger.info("Admin: ALLOWED_IPS not set - restricted to localhost")
    end
    
    # Helper for auth checks
    fun is_allowed(req)
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
    
    fun not_found()
        return {status: 404, headers: {"Content-Type": "text/html"}, body: "<h1>404</h1>"}
    end
    
    fun render(template, context)
        return {
            status: 200,
            headers: {"Content-Type": "text/html; charset=utf-8"},
            body: tmpl.render(template, context)
        }
    end
    
    # ========== Post Management ==========
    
    admin.get("/", fun (req)
        if not is_allowed(req)
            return not_found()
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
        
        return render("admin.html", {posts: posts})
    end)
    
    admin.get("/new", fun (req)
        if not is_allowed(req)
            return not_found()
        end
        return render("new_post.html", {})
    end)
    
    admin.post("/new", fun (req)
        if not is_allowed(req)
            return {status: 404, headers: {"Content-Type": "application/json"}, body: json.stringify({error: "Not found"})}
        end
        
        let data = json.parse(req["body"])
        let author = db.user.find_default_author(db.get_db())
        if author == nil
            return {status: 500, headers: {"Content-Type": "application/json"}, body: json.stringify({error: "No author"})}
        end
        
        let read_time = calculate_read_time(data["content"])
        db.post.create(db.get_db(), data["title"], data["slug"], data["content"], read_time, author["id"], data["tags"], data["social_image"])
        
        return {status: 200, headers: {"Content-Type": "application/json"}, body: json.stringify({success: true, slug: data["slug"]})}
    end)
    
    admin.get("/edit/{slug}", fun (req)
        if not is_allowed(req)
            return not_found()
        end
        
        let slug = req["params"]["slug"]
        let post = db.post.find_by_slug(db.get_db(), slug, false)
        if post == nil
            return not_found()
        end
        
        post["tags"] = db.tag.find_for_post(db.get_db(), post["id"])
        return render("admin_editor.html", {post: post})
    end)
    
    admin.post("/edit/{slug}", fun (req)
        if not is_allowed(req)
            return {status: 404, headers: {"Content-Type": "application/json"}, body: json.stringify({error: "Not found"})}
        end
        
        let slug = req["params"]["slug"]
        let data = json.parse(req["body"])
        let read_time = calculate_read_time(data["content"])
        let result = db.post.update(db.get_db(), slug, data["title"], data["slug"], data["content"], read_time, data["tags"], data["published_at"], data["social_image"])
        
        if result == nil
            return {status: 404, headers: {"Content-Type": "application/json"}, body: json.stringify({error: "Post not found"})}
        end
        
        return {status: 200, headers: {"Content-Type": "application/json"}, body: json.stringify({success: true, slug: data["slug"]})}
    end)
    
    admin.post("/delete/{slug}", fun (req)
        if not is_allowed(req)
            return {status: 404, headers: {"Content-Type": "application/json"}, body: json.stringify({error: "Not found"})}
        end
        
        let slug = req["params"]["slug"]
        let deleted = db.post.delete(db.get_db(), slug)
        if not deleted
            return {status: 404, headers: {"Content-Type": "application/json"}, body: json.stringify({error: "Not found"})}
        end
        
        return {status: 200, headers: {"Content-Type": "application/json"}, body: json.stringify({success: true})}
    end)
    
    # ========== Page Management ==========
    
    admin.get("/pages", fun (req)
        if not is_allowed(req)
            return not_found()
        end
        
        let pages = db.page.find_all(db.get_db(), false)
        return render("admin_pages.html", {pages: pages})
    end)
    
    admin.get("/pages/new", fun (req)
        if not is_allowed(req)
            return not_found()
        end
        return render("new_page.html", {})
    end)
    
    admin.post("/pages/new", fun (req)
        if not is_allowed(req)
            return {status: 404, headers: {"Content-Type": "application/json"}, body: json.stringify({error: "Not found"})}
        end
        
        let data = json.parse(req["body"])
        let author = db.user.find_default_author(db.get_db())
        if author == nil
            return {status: 500, headers: {"Content-Type": "application/json"}, body: json.stringify({error: "No author"})}
        end
        
        db.page.create(db.get_db(), data["title"], data["slug"], data["content"], data["order"], author["id"])
        return {status: 200, headers: {"Content-Type": "application/json"}, body: json.stringify({success: true, slug: data["slug"]})}
    end)
    
    admin.get("/pages/edit/{slug}", fun (req)
        if not is_allowed(req)
            return not_found()
        end
        
        let slug = req["params"]["slug"]
        let page = db.page.find_by_slug(db.get_db(), slug, false)
        if page == nil
            return not_found()
        end
        
        return render("admin_page_editor.html", {page: page})
    end)
    
    admin.post("/pages/edit/{slug}", fun (req)
        if not is_allowed(req)
            return {status: 404, headers: {"Content-Type": "application/json"}, body: json.stringify({error: "Not found"})}
        end

        let slug = req["params"]["slug"]
        let data = json.parse(req["body"])
        let result = db.page.update(db.get_db(), slug, data["title"], data["slug"], data["content"], data["order"], data["custom_css"])

        if result == nil
            return {status: 404, headers: {"Content-Type": "application/json"}, body: json.stringify({error: "Not found"})}
        end

        return {status: 200, headers: {"Content-Type": "application/json"}, body: json.stringify({success: true, slug: data["slug"]})}
    end)
    
    admin.post("/pages/delete/{slug}", fun (req)
        if not is_allowed(req)
            return {status: 404, headers: {"Content-Type": "application/json"}, body: json.stringify({error: "Not found"})}
        end
        
        let slug = req["params"]["slug"]
        let deleted = db.page.delete(db.get_db(), slug)
        if not deleted
            return {status: 404, headers: {"Content-Type": "application/json"}, body: json.stringify({error: "Not found"})}
        end
        
        return {status: 200, headers: {"Content-Type": "application/json"}, body: json.stringify({success: true})}
    end)
    
    # ========== Media Management ==========
    
    admin.get("/media", fun (req)
        if not is_allowed(req)
            return not_found()
        end
        
        if upload_dir == nil
            return {status: 500, headers: {"Content-Type": "text/html"}, body: "<h1>Media Library Not Configured</h1>"}
        end
        
        let files = db.media.list_files(upload_dir)
        let i = 0
        while i < files.len()
            files[i]["url"] = db.media.get_file_url(files[i]["filename"])
            i = i + 1
        end

        return render("media_library.html", {files: files, upload_dir: upload_dir})
    end)
    
    admin.post("/media/upload", fun (req)
        if not is_allowed(req)
            return {status: 403, headers: {"Content-Type": "application/json"}, body: json.stringify({error: "Forbidden"})}
        end
        
        if upload_dir == nil
            return {status: 500, headers: {"Content-Type": "application/json"}, body: json.stringify({error: "Not configured"})}
        end
        
        if req["body"].cls() != "Dict"
            return {status: 400, headers: {"Content-Type": "application/json"}, body: json.stringify({error: "Expected multipart"})}
        end
        
        let files = req["body"]["files"]
        if files.len() == 0
            return {status: 400, headers: {"Content-Type": "application/json"}, body: json.stringify({error: "No file"})}
        end
        
        try
            let file = files[0]
            let saved = db.media.save_file(upload_dir, file["filename"], file["mime_type"], file["data"], nil, true)
            let url = db.media.get_file_url(saved["filename"])
            logger.info("File uploaded: " .. saved["filename"])
            
            return {
                status: 200,
                headers: {"Content-Type": "application/json"},
                body: json.stringify({
                    success: true,
                    filename: saved["filename"],
                    url: url,
                    size: saved["size"]
                })
            }
        catch e
            logger.error("Upload failed: " .. e.message())
            return {status: 400, headers: {"Content-Type": "application/json"}, body: json.stringify({error: e.message()})}
        end
    end)
    
    admin.post("/media/delete", fun (req)
        if not is_allowed(req)
            return {status: 403, headers: {"Content-Type": "application/json"}, body: json.stringify({error: "Forbidden"})}
        end
        
        if upload_dir == nil
            return {status: 500, headers: {"Content-Type": "application/json"}, body: json.stringify({error: "Not configured"})}
        end
        
        let data = json.parse(req["body"])
        if data["filename"] == nil
            return {status: 400, headers: {"Content-Type": "application/json"}, body: json.stringify({error: "Filename required"})}
        end
        
        try
            let deleted = db.media.delete_file(upload_dir, data["filename"])
            if not deleted
                return {status: 404, headers: {"Content-Type": "application/json"}, body: json.stringify({error: "Not found"})}
            end
            
            logger.info("File deleted: " .. data["filename"])
            return {status: 200, headers: {"Content-Type": "application/json"}, body: json.stringify({success: true})}
        catch e
            logger.error("Delete failed: " .. e.message())
            return {status: 400, headers: {"Content-Type": "application/json"}, body: json.stringify({error: e.message()})}
        end
    end)
    
    return admin
end
