# QEP-052: File Upload Support

## Overview

Add comprehensive file upload support to Quest's web server, including automatic parsing of `multipart/form-data` requests and convenient APIs for handling uploaded files. This includes both form field parsing and file upload handling in a single, cohesive API.

## Status

**Draft** - Design phase, updated to align with revised QEP-051

## Revision History

**2025-10-16:** Updated to align with revised QEP-051 (Web Framework API):
- Changed module path from `std/web/server` to unified `std/web` module
- Integrated with QEP-051's hybrid configuration model (quest.toml + imperative API)
- Updated ServerConfig to match QEP-051's structure
- Added Quest module integration section showing additions to `lib/std/web.q`
- Added explicit dependencies on QEP-051 and QEP-053
- Added rationale section explaining design decisions
- Updated all examples and documentation references

## Goals

- Automatic parsing of `multipart/form-data` requests
- Separate `request["form"]` for text fields and `request["files"]` for uploaded files
- Support single and multiple file uploads
- Configurable size limits and file type restrictions
- Memory-efficient handling of large files
- Security best practices built-in
- Intuitive API that works like Flask/Django/Rails

## Motivation

Currently, the Quest web server only provides raw request body as a string. This makes file uploads impossible without manual binary parsing, which is complex and error-prone.

**Current limitations:**
- No way to handle file uploads
- No automatic form field parsing for POST requests
- Manual parsing required for all form data
- Binary file data gets corrupted when treated as string

**Common use cases needing file uploads:**
- User avatars and profile pictures
- Document management systems
- Image galleries and photo sharing
- File attachments in forms
- CSV/Excel data imports
- Backup uploads

## Design

### 1. Request Dictionary Enhancement

Add two new fields to the request dictionary:

```quest
{
    "method": "POST",
    "path": "/upload",
    "body": "...",              # Raw body (still available for custom parsing)
    "content_type": "multipart/form-data; boundary=...",

    # NEW: Form fields (text inputs)
    "form": {
        "title": "My Photo",
        "description": "A beautiful sunset",
        "category": "nature"
    },

    # NEW: Uploaded files
    "files": {
        # Single file upload
        "avatar": {
            "filename": "photo.jpg",
            "content_type": "image/jpeg",
            "size": 1024000,
            "data": <Bytes>,
            "field_name": "avatar"
        },

        # Multiple files with same field name (array)
        "documents": [
            {
                "filename": "doc1.pdf",
                "content_type": "application/pdf",
                "size": 500000,
                "data": <Bytes>,
                "field_name": "documents"
            },
            {
                "filename": "doc2.pdf",
                "content_type": "application/pdf",
                "size": 750000,
                "data": <Bytes>,
                "field_name": "documents"
            }
        ]
    }
}
```

### 2. Automatic Parsing Rules

**Content-Type detection:**
- `multipart/form-data` → Parse into `request["form"]` + `request["files"]`
- `application/x-www-form-urlencoded` → Parse into `request["form"]` (no files)
- Other types → Leave `request["body"]` as-is, `form` and `files` are empty dicts

**Field handling:**
- Text fields → `request["form"]["field_name"]`
- File uploads → `request["files"]["field_name"]`
- Multiple files with same name → Array in `request["files"]["field_name"]`

### 3. Configuration System

File upload configuration follows QEP-051's hybrid configuration model:

**Declarative configuration via quest.toml:**

```toml
# quest.toml
[std.web.upload]
max_upload_size = 104857600  # 100 MB total per request
max_file_size = 10485760     # 10 MB per file
max_file_count = 20          # Max 20 files per request
allowed_types = ["image/jpeg", "image/png", "image/gif", "application/pdf"]
```

**Imperative API via std/web module:**

```quest
use "std/web" as web

# Configure upload limits (overrides quest.toml)
web.set_max_upload_size(100 * 1024 * 1024)  # 100 MB total per request
web.set_max_file_size(10 * 1024 * 1024)     # 10 MB per file
web.set_max_file_count(20)                   # Max 20 files per request

# Optional: Whitelist allowed MIME types
web.set_allowed_file_types([
    "image/jpeg",
    "image/png",
    "image/gif",
    "application/pdf",
    "text/csv"
])
```

**Default limits (if not configured):**
- `max_upload_size`: 50 MB
- `max_file_size`: 10 MB
- `max_file_count`: 10
- `allowed_file_types`: None (all allowed)

### 4. Integration with QEP-051 Web Framework

File uploads integrate seamlessly with the web framework configuration:

```quest
use "std/web" as web
use "std/io" as io
use "std/uuid" as uuid

# Configure static files (QEP-051)
web.static('/uploads', '/var/www/uploads')

# Configure upload limits (QEP-052)
web.set_max_upload_size(50 * 1024 * 1024)  # 50 MB
web.set_max_file_size(10 * 1024 * 1024)    # 10 MB per file
web.set_allowed_file_types(["image/jpeg", "image/png", "image/gif"])

# Handle upload requests
fun handle_request(request)
    if request["path"] == "/api/upload" and request["method"] == "POST"
        let file = request["files"]["photo"]

        # Generate safe filename
        let safe_name = uuid.v4().str() .. ".jpg"
        io.write("/var/www/uploads/" .. safe_name, file["data"])

        {"status": 200, "json": {"url": "/uploads/" .. safe_name}}
    else
        {"status": 404, "body": "Not found"}
    end
end
```

### 5. Usage Examples

#### Example 1: Simple Avatar Upload

```quest
use "std/io" as io
use "std/uuid" as uuid

fun handle_request(request)
    if request["path"] == "/profile/avatar" and request["method"] == "POST"
        # Check if file was uploaded
        if not request["files"]["avatar"]
            return {"status": 400, "json": {"error": "No file uploaded"}}
        end

        let file = request["files"]["avatar"]

        # Validate file type
        if not file["content_type"].starts_with("image/")
            return {
                "status": 400,
                "json": {"error": "Only images allowed"}
            }
        end

        # Validate file size (additional check beyond server limits)
        if file["size"] > 5 * 1024 * 1024  # 5 MB
            return {
                "status": 400,
                "json": {"error": "File too large (max 5 MB)"}
            }
        end

        # Generate safe filename
        let ext = file["filename"].split(".").last()
        let safe_name = uuid.v4().str() .. "." .. ext
        let upload_path = "/var/www/uploads/" .. safe_name

        # Save file to disk
        io.write(upload_path, file["data"])

        return {
            "status": 200,
            "json": {
                "success": true,
                "url": "/uploads/" .. safe_name,
                "filename": file["filename"],
                "size": file["size"]
            }
        }
    end
end
```

**HTML Form:**
```html
<form action="/profile/avatar" method="post" enctype="multipart/form-data">
    <input type="file" name="avatar" accept="image/*" required>
    <button type="submit">Upload Avatar</button>
</form>
```

#### Example 2: Multiple File Upload (Gallery)

```quest
use "std/io" as io
use "std/uuid" as uuid

fun handle_request(request)
    if request["path"] == "/gallery/upload" and request["method"] == "POST"
        let files = request["files"]["photos"]

        if not files
            return {"status": 400, "json": {"error": "No files uploaded"}}
        end

        # Handle single or multiple files uniformly
        if not files.is_array()
            files = [files]
        end

        # Validate and save all files
        let uploaded_urls = []
        let i = 0
        while i < files.len()
            let file = files[i]

            # Validate each file
            if not file["content_type"].starts_with("image/")
                return {
                    "status": 400,
                    "json": {"error": "File " .. file["filename"] .. " is not an image"}
                }
            end

            # Save file
            let safe_name = uuid.v4().str() .. ".jpg"
            io.write("/var/www/gallery/" .. safe_name, file["data"])
            uploaded_urls.push("/gallery/" .. safe_name)

            i = i + 1
        end

        return {
            "status": 200,
            "json": {
                "success": true,
                "count": files.len(),
                "urls": uploaded_urls
            }
        }
    end
end
```

**HTML Form:**
```html
<form action="/gallery/upload" method="post" enctype="multipart/form-data">
    <input type="file" name="photos" accept="image/*" multiple required>
    <button type="submit">Upload Photos</button>
</form>
```

#### Example 3: Form with Text Fields and File Upload

```quest
use "std/io" as io
use "std/db/sqlite" as db
use "std/uuid" as uuid

let conn = db.connect("documents.db")

fun handle_request(request)
    if request["path"] == "/documents/submit" and request["method"] == "POST"
        # Access form text fields
        let title = request["form"]["title"]
        let description = request["form"]["description"]
        let category = request["form"]["category"]

        # Validate text fields
        if not title or title.trim() == ""
            return {"status": 400, "json": {"error": "Title is required"}}
        end

        # Access uploaded file
        let document = request["files"]["document"]

        if not document
            return {"status": 400, "json": {"error": "Document file is required"}}
        end

        # Validate file type
        let allowed_types = ["application/pdf", "application/msword",
                             "application/vnd.openxmlformats-officedocument.wordprocessingml.document"]
        if not allowed_types.contains(document["content_type"])
            return {
                "status": 400,
                "json": {"error": "Only PDF and Word documents allowed"}
            }
        end

        # Save file
        let file_id = uuid.v4().str()
        let ext = document["filename"].split(".").last()
        let safe_name = file_id .. "." .. ext
        let file_path = "/var/www/documents/" .. safe_name

        io.write(file_path, document["data"])

        # Store metadata in database
        let cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO documents (id, title, description, category, filename, original_name, size, uploaded_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'))",
            [file_id, title, description, category, safe_name, document["filename"], document["size"]]
        )
        conn.commit()

        return {
            "status": 200,
            "json": {
                "success": true,
                "document_id": file_id,
                "url": "/documents/" .. file_id
            }
        }
    end
end
```

**HTML Form:**
```html
<form action="/documents/submit" method="post" enctype="multipart/form-data">
    <input type="text" name="title" placeholder="Document Title" required>
    <textarea name="description" placeholder="Description"></textarea>
    <select name="category">
        <option value="report">Report</option>
        <option value="invoice">Invoice</option>
        <option value="contract">Contract</option>
    </select>
    <input type="file" name="document" accept=".pdf,.doc,.docx" required>
    <button type="submit">Submit Document</button>
</form>
```

#### Example 4: File Validation Helper

```quest
# Helper functions for common validation tasks

fun validate_image_file(file)
    # Check if file exists
    if not file
        return {"valid": false, "error": "No file provided"}
    end

    # Check MIME type
    let allowed_types = ["image/jpeg", "image/png", "image/gif", "image/webp"]
    if not allowed_types.contains(file["content_type"])
        return {"valid": false, "error": "Invalid file type. Only JPEG, PNG, GIF, WebP allowed"}
    end

    # Check file extension
    let filename = file["filename"].lower()
    let valid_extensions = [".jpg", ".jpeg", ".png", ".gif", ".webp"]
    let has_valid_ext = false
    let i = 0
    while i < valid_extensions.len()
        if filename.ends_with(valid_extensions[i])
            has_valid_ext = true
        end
        i = i + 1
    end

    if not has_valid_ext
        return {"valid": false, "error": "Invalid file extension"}
    end

    # Check file size (5 MB max)
    if file["size"] > 5 * 1024 * 1024
        return {"valid": false, "error": "File too large (max 5 MB)"}
    end

    # Check magic bytes (verify it's actually an image)
    let data = file["data"]
    if data.len() < 2
        return {"valid": false, "error": "File is empty or corrupted"}
    end

    # JPEG magic bytes: FF D8
    # PNG magic bytes: 89 50
    # GIF magic bytes: 47 49
    let is_jpeg = data[0] == 0xFF and data[1] == 0xD8
    let is_png = data[0] == 0x89 and data[1] == 0x50
    let is_gif = data[0] == 0x47 and data[1] == 0x49

    if not (is_jpeg or is_png or is_gif)
        return {"valid": false, "error": "File content doesn't match image format"}
    end

    {"valid": true}
end

fun handle_request(request)
    if request["path"] == "/upload" and request["method"] == "POST"
        let file = request["files"]["photo"]
        let validation = validate_image_file(file)

        if not validation["valid"]
            return {
                "status": 400,
                "json": {"error": validation["error"]}
            }
        end

        # File is valid, proceed with upload
        # ...
    end
end
```

#### Example 5: Automatic Form Parsing (No Files)

Even if no files are uploaded, the form parsing is useful:

```quest
fun handle_request(request)
    if request["path"] == "/contact" and request["method"] == "POST"
        # Form data automatically parsed from application/x-www-form-urlencoded
        let name = request["form"]["name"]
        let email = request["form"]["email"]
        let message = request["form"]["message"]

        # No need to manually parse request["body"]!

        send_email(email, message)

        return {
            "status": 200,
            "json": {"success": true}
        }
    end
end
```

**HTML Form (no file upload):**
```html
<form action="/contact" method="post">
    <input type="text" name="name" required>
    <input type="email" name="email" required>
    <textarea name="message" required></textarea>
    <button type="submit">Send</button>
</form>
```

### 6. Implementation Details

#### Rust Dependencies

```toml
# Cargo.toml additions
multer = "3.0"  # Multipart form data parser
```

#### Enhanced ServerConfig

Following QEP-051's ServerConfig pattern, add upload configuration:

```rust
// src/server.rs

pub struct ServerConfig {
    // ... existing fields from QEP-051 ...
    pub host: String,
    pub port: u16,
    pub static_dirs: Vec<(String, String)>,
    pub cors: Option<CorsConfig>,
    pub max_body_size: usize,
    pub max_header_size: usize,
    pub request_timeout: u64,
    pub keepalive_timeout: u64,
    pub before_hooks: Vec<QUserFun>,
    pub after_hooks: Vec<QUserFun>,
    pub error_handlers: HashMap<u16, QUserFun>,
    pub redirects: HashMap<String, (String, u16)>,
    pub default_headers: HashMap<String, String>,

    // NEW: Upload configuration (QEP-052)
    pub upload_config: UploadConfig,
}

pub struct UploadConfig {
    pub max_upload_size: usize,       // Total size of all files + fields (default: 50 MB)
    pub max_file_size: usize,         // Max size per individual file (default: 10 MB)
    pub max_file_count: usize,        // Max number of files per request (default: 10)
    pub allowed_types: Option<Vec<String>>,  // Whitelist of MIME types (default: None = all allowed)
}

impl Default for UploadConfig {
    fn default() -> Self {
        Self {
            max_upload_size: 50 * 1024 * 1024,    // 50 MB
            max_file_size: 10 * 1024 * 1024,      // 10 MB
            max_file_count: 10,
            allowed_types: None,
        }
    }
}
```

#### Multipart Parsing Function

```rust
// src/server.rs

use multer::{Multipart, Field};
use bytes::Bytes;

/// Parse multipart/form-data request
async fn parse_multipart_form(
    content_type: &str,
    body_bytes: Bytes,
    config: &UploadConfig,
) -> Result<(QDict, QDict), String> {
    // Extract boundary from content-type header
    let boundary = multer::parse_boundary(content_type)
        .map_err(|e| format!("Invalid multipart boundary: {}", e))?;

    // Create multipart parser
    let mut multipart = Multipart::new(Cursor::new(body_bytes), boundary);

    let mut form_fields = HashMap::new();
    let mut files = HashMap::new();
    let mut total_size: usize = 0;
    let mut file_count: usize = 0;

    // Parse each field
    while let Some(field) = multipart.next_field()
        .await
        .map_err(|e| format!("Failed to read field: {}", e))?
    {
        let field_name = field.name()
            .ok_or("Field missing name")?
            .to_string();

        if let Some(filename) = field.file_name() {
            // This is a file upload
            if file_count >= config.max_file_count {
                return Err(format!("Too many files (max: {})", config.max_file_count));
            }

            let content_type = field.content_type()
                .map(|ct| ct.essence_str().to_string())
                .unwrap_or_else(|| "application/octet-stream".to_string());

            // Validate file type if whitelist is configured
            if let Some(ref allowed) = config.allowed_types {
                if !allowed.contains(&content_type) {
                    return Err(format!(
                        "File type '{}' not allowed for file '{}'",
                        content_type, filename
                    ));
                }
            }

            // Read file data
            let data = field.bytes()
                .await
                .map_err(|e| format!("Failed to read file data: {}", e))?;

            // Check individual file size
            if data.len() > config.max_file_size {
                return Err(format!(
                    "File '{}' too large ({} bytes, max: {} bytes)",
                    filename, data.len(), config.max_file_size
                ));
            }

            total_size += data.len();

            // Check total upload size
            if total_size > config.max_upload_size {
                return Err(format!(
                    "Total upload size too large ({} bytes, max: {} bytes)",
                    total_size, config.max_upload_size
                ));
            }

            // Create file dict
            let file_dict = create_file_dict(
                filename.to_string(),
                content_type,
                data,
                field_name.clone(),
            );

            // Handle multiple files with same field name
            add_or_append_file(&mut files, field_name, file_dict);

            file_count += 1;
        } else {
            // Regular form field (text)
            let value = field.text()
                .await
                .map_err(|e| format!("Failed to read field '{}': {}", field_name, e))?;

            total_size += value.len();

            if total_size > config.max_upload_size {
                return Err(format!(
                    "Total upload size too large (max: {} bytes)",
                    config.max_upload_size
                ));
            }

            form_fields.insert(field_name, QValue::Str(QString::new(value)));
        }
    }

    Ok((QDict::new(form_fields), QDict::new(files)))
}

/// Create Quest Dict for uploaded file
fn create_file_dict(
    filename: String,
    content_type: String,
    data: Bytes,
    field_name: String,
) -> QValue {
    let mut map = HashMap::new();
    map.insert("filename".to_string(), QValue::Str(QString::new(filename)));
    map.insert("content_type".to_string(), QValue::Str(QString::new(content_type)));
    map.insert("size".to_string(), QValue::Int(QInt::new(data.len() as i64)));
    map.insert("data".to_string(), QValue::Bytes(QBytes::new(data.to_vec())));
    map.insert("field_name".to_string(), QValue::Str(QString::new(field_name)));
    QValue::Dict(Box::new(QDict::new(map)))
}

/// Add file to files dict, handling multiple files with same name
fn add_or_append_file(files: &mut HashMap<String, QValue>, field_name: String, file_dict: QValue) {
    if let Some(existing) = files.get_mut(&field_name) {
        match existing {
            QValue::Dict(_) => {
                // Convert single file to array of files
                let prev = files.remove(&field_name).unwrap();
                let mut arr = QArray::new();
                arr.push(prev);
                arr.push(file_dict);
                files.insert(field_name, QValue::Array(Box::new(arr)));
            }
            QValue::Array(ref mut arr) => {
                // Append to existing array
                arr.push(file_dict);
            }
            _ => {}
        }
    } else {
        // First file with this field name
        files.insert(field_name, file_dict);
    }
}
```

#### Parse application/x-www-form-urlencoded

```rust
// src/server.rs

/// Parse URL-encoded form data (non-file uploads)
fn parse_urlencoded_form(body: &str) -> QDict {
    // Reuse existing query string parser
    parse_query_string(body)
}
```

#### Integration into Request Handler

```rust
// src/server.rs

fn build_request_dict_from_parts(
    parts: axum::http::request::Parts,
    body_bytes: Bytes,
    client_ip: String,
    config: &ServerConfig,
) -> Result<QDict, String> {
    // ... existing code ...

    let content_type = parts.headers.get(header::CONTENT_TYPE)
        .and_then(|h| h.to_str().ok())
        .unwrap_or("")
        .to_string();

    // Parse form data based on content-type
    let (form, files) = if content_type.starts_with("multipart/form-data") {
        // Parse multipart form (files + fields)
        futures::executor::block_on(parse_multipart_form(
            &content_type,
            body_bytes.clone(),
            &config.upload_config,
        ))?
    } else if content_type.starts_with("application/x-www-form-urlencoded") {
        // Parse URL-encoded form (fields only)
        let body_str = String::from_utf8_lossy(&body_bytes);
        let form = parse_urlencoded_form(&body_str);
        let files = QDict::new(HashMap::new());
        (form, files)
    } else {
        // No form parsing for other content types
        (QDict::new(HashMap::new()), QDict::new(HashMap::new()))
    };

    // ... existing code ...

    // Add form and files to request dict
    map.insert("form".to_string(), QValue::Dict(Box::new(form)));
    map.insert("files".to_string(), QValue::Dict(Box::new(files)));

    // ... rest of request dict building ...
}
```

### 7. Quest Module Integration (lib/std/web.q)

Following QEP-051's module structure, add upload configuration to `lib/std/web.q`:

```quest
# lib/std/web.q (additions to QEP-051 module)

# Add upload config to Configuration type
pub type Configuration
    # ... existing fields from QEP-051 ...
    str?: host = "127.0.0.1"
    num?: port = 3000
    num?: max_body_size = 10485760
    # ... etc ...

    # NEW: Upload configuration fields (QEP-052)
    num?: max_upload_size = 52428800    # 50 MB
    num?: max_file_size = 10485760      # 10 MB
    num?: max_file_count = 10
    array?: allowed_file_types = nil    # nil = all allowed

    fun validate_max_upload_size(value)
        v.min(1024)(value)  # At least 1KB
    end

    fun validate_max_file_count(value)
        v.min(1)(value)
    end

    static fun from_dict(dict)
        # ... existing QEP-051 fields ...
        let config = Configuration.new()
        if dict.contains("max_upload_size")
            config.max_upload_size = dict["max_upload_size"]
        end
        # ... etc
        return config
    end
end

# Runtime configuration state (additions)
let _runtime_config = {
    # ... existing QEP-051 fields ...
    "static_dirs": [],
    "cors": nil,
    # ... etc ...

    # NEW: Upload configuration (QEP-052)
    "max_upload_size": nil,
    "max_file_size": nil,
    "max_file_count": nil,
    "allowed_file_types": nil
}

# NEW: Upload configuration API (QEP-052)
pub exports.set_max_upload_size = fun (size)
    _runtime_config["max_upload_size"] = size
end

pub exports.set_max_file_size = fun (size)
    _runtime_config["max_file_size"] = size
end

pub exports.set_max_file_count = fun (count)
    _runtime_config["max_file_count"] = count
end

pub exports.set_allowed_file_types = fun (types)
    _runtime_config["allowed_file_types"] = types
end
```

### 8. Security Considerations

#### Built-in Protections

1. **Size Limits (Enforced Automatically)**
   - Total upload size limit (default 50 MB)
   - Per-file size limit (default 10 MB)
   - Max file count per request (default 10)
   - Request automatically rejected if limits exceeded

2. **MIME Type Validation (Optional)**
   - Whitelist allowed file types via `server.set_allowed_file_types()`
   - Automatic rejection of non-whitelisted types
   - Server returns 400 Bad Request with error message

3. **Filename Safety**
   - Original filename preserved in `file["filename"]`
   - **NEVER use original filename directly** - always sanitize
   - Recommended: Generate UUIDs for saved files
   - Preserve extension separately if needed

#### Quest-Level Security Best Practices

**1. Generate Safe Filenames**
```quest
use "std/uuid" as uuid

# GOOD: Generate new filename
let safe_name = uuid.v4().str() .. ".jpg"
io.write("/uploads/" .. safe_name, file["data"])

# BAD: Use original filename directly (path traversal risk!)
io.write("/uploads/" .. file["filename"], file["data"])  # DON'T DO THIS!
```

**2. Validate File Extension**
```quest
fun get_safe_extension(filename)
    let parts = filename.split(".")
    if parts.len() < 2
        return "bin"  # No extension
    end

    let ext = parts.last().lower()
    let allowed = ["jpg", "jpeg", "png", "gif", "pdf"]

    if allowed.contains(ext)
        return ext
    else
        return "bin"  # Unknown extension
    end
end

let ext = get_safe_extension(file["filename"])
let safe_name = uuid.v4().str() .. "." .. ext
```

**3. Verify Magic Bytes (File Type)**
```quest
fun is_valid_jpeg(data)
    # JPEG files start with FF D8 FF
    if data.len() < 3
        return false
    end
    return data[0] == 0xFF and data[1] == 0xD8 and data[2] == 0xFF
end

fun is_valid_png(data)
    # PNG files start with 89 50 4E 47
    if data.len() < 4
        return false
    end
    return data[0] == 0x89 and data[1] == 0x50 and
           data[2] == 0x4E and data[3] == 0x47
end

# Verify file matches claimed type
let file = request["files"]["photo"]
if file["content_type"] == "image/jpeg"
    if not is_valid_jpeg(file["data"])
        return {"status": 400, "json": {"error": "File is not a valid JPEG"}}
    end
end
```

**4. Store Files Outside Web Root**
```quest
# GOOD: Store outside web-accessible directory
io.write("/var/uploads/private/" .. safe_name, file["data"])

# Then serve via authenticated endpoint
fun handle_request(request)
    if request["path"].starts_with("/files/")
        # Check authentication
        if not is_authenticated(request)
            return {"status": 401, "json": {"error": "Unauthorized"}}
        end

        # Serve file from private location
        let file_id = request["path"].split("/").last()
        let data = io.read("/var/uploads/private/" .. file_id)
        return {"status": 200, "body": data}
    end
end
```

**5. Scan for Malware (External Tool)**
```quest
use "std/process" as process

fun scan_file(file_path)
    # Use ClamAV or similar
    let result = process.run(["clamscan", "--no-summary", file_path])

    if result["exit_code"] != 0
        return {"safe": false, "reason": "Virus detected"}
    end

    {"safe": true}
end

let temp_path = "/tmp/" .. uuid.v4().str()
io.write(temp_path, file["data"])

let scan = scan_file(temp_path)
if not scan["safe"]
    io.remove(temp_path)
    return {"status": 400, "json": {"error": "File failed security scan"}}
end
```

#### Common Attack Vectors and Mitigations

| Attack | Mitigation |
|--------|------------|
| Path traversal (`../../etc/passwd`) | Never use original filename, generate UUIDs |
| Malicious file types (`.php`, `.exe`) | Validate extensions, use whitelist |
| MIME type spoofing | Verify magic bytes match claimed type |
| Zip bombs / XML bombs | Enforce size limits (automatic) |
| Memory exhaustion | Size limits + streaming (Phase 2) |
| XSS via filenames | Sanitize filenames before displaying in HTML |

### 9. Error Handling

**Automatic errors (returned by server):**

```quest
# File too large
{
    "status": 413,  # Request Entity Too Large
    "json": {
        "error": "File 'document.pdf' too large (15728640 bytes, max: 10485760 bytes)"
    }
}

# Too many files
{
    "status": 400,
    "json": {
        "error": "Too many files (max: 10)"
    }
}

# Invalid file type
{
    "status": 400,
    "json": {
        "error": "File type 'application/x-executable' not allowed for file 'virus.exe'"
    }
}

# Total upload too large
{
    "status": 413,
    "json": {
        "error": "Total upload size too large (52428800 bytes, max: 52428800 bytes)"
    }
}
```

**Quest-level error handling:**

```quest
fun handle_request(request)
    if request["path"] == "/upload" and request["method"] == "POST"
        # Check if upload succeeded
        if not request["files"]
            return {"status": 400, "json": {"error": "No files uploaded"}}
        end

        let file = request["files"]["document"]

        if not file
            return {"status": 400, "json": {"error": "Missing required field 'document'"}}
        end

        # Additional validation
        if file["size"] == 0
            return {"status": 400, "json": {"error": "File is empty"}}
        end

        # Wrap in try/catch for I/O errors
        try
            io.write("/uploads/" .. safe_name, file["data"])
        catch e
            return {"status": 500, "json": {"error": "Failed to save file: " .. e}}
        end

        {"status": 200, "json": {"success": true}}
    end
end
```

### 10. Testing Strategy

#### Unit Tests (Rust)

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_parse_single_file() {
        // Create multipart request with single file
        let body = create_multipart_body(&[
            ("title", "Test"),
            ("file", "photo.jpg", "image/jpeg", b"fake-jpeg-data"),
        ]);

        let (form, files) = parse_multipart_form(
            "multipart/form-data; boundary=----WebKitFormBoundary",
            body,
            &UploadConfig::default(),
        ).await.unwrap();

        assert_eq!(form.get("title"), Some("Test"));
        assert!(files.contains_key("file"));
    }

    #[tokio::test]
    async fn test_file_size_limit() {
        // File larger than max_file_size
        let large_file = vec![0u8; 11 * 1024 * 1024];  // 11 MB
        let body = create_multipart_body(&[
            ("file", "large.jpg", "image/jpeg", &large_file),
        ]);

        let result = parse_multipart_form(
            "multipart/form-data; boundary=----WebKitFormBoundary",
            body,
            &UploadConfig::default(),
        ).await;

        assert!(result.is_err());
        assert!(result.unwrap_err().contains("too large"));
    }

    #[tokio::test]
    async fn test_file_type_whitelist() {
        let config = UploadConfig {
            allowed_types: Some(vec!["image/jpeg".to_string()]),
            ..Default::default()
        };

        let body = create_multipart_body(&[
            ("file", "doc.pdf", "application/pdf", b"fake-pdf"),
        ]);

        let result = parse_multipart_form(
            "multipart/form-data; boundary=----WebKitFormBoundary",
            body,
            &config,
        ).await;

        assert!(result.is_err());
        assert!(result.unwrap_err().contains("not allowed"));
    }

    #[tokio::test]
    async fn test_multiple_files_same_name() {
        let body = create_multipart_body(&[
            ("photos", "pic1.jpg", "image/jpeg", b"data1"),
            ("photos", "pic2.jpg", "image/jpeg", b"data2"),
        ]);

        let (_, files) = parse_multipart_form(
            "multipart/form-data; boundary=----WebKitFormBoundary",
            body,
            &UploadConfig::default(),
        ).await.unwrap();

        let photos = files.get("photos").unwrap();
        assert!(matches!(photos, QValue::Array(_)));
    }
}
```

#### Integration Tests (Quest)

```quest
# test/server/upload_test.q

use "std/test" as test
use "std/http/client" as http

test.module("File Upload")

test.describe("Single file upload", fun ()
    test.it("uploads avatar successfully", fun ()
        let file_data = b"\xFF\xD8\xFF\xE0"  # JPEG header
        let resp = http.post("http://localhost:3000/upload", {
            "files": {
                "avatar": {
                    "filename": "photo.jpg",
                    "content_type": "image/jpeg",
                    "data": file_data
                }
            }
        })

        test.assert_eq(resp.status(), 200)
        test.assert(resp.json()["success"])
    end)

    test.it("rejects file that is too large", fun ()
        let large_data = b"\x00" * (11 * 1024 * 1024)  # 11 MB
        let resp = http.post("http://localhost:3000/upload", {
            "files": {
                "avatar": {
                    "filename": "large.jpg",
                    "data": large_data
                }
            }
        })

        test.assert_eq(resp.status(), 413)
    end)
end)

test.describe("Multiple file upload", fun ()
    test.it("uploads multiple photos", fun ()
        let resp = http.post("http://localhost:3000/gallery", {
            "files": {
                "photos": [
                    {"filename": "pic1.jpg", "data": b"\xFF\xD8\xFF\xE0"},
                    {"filename": "pic2.jpg", "data": b"\xFF\xD8\xFF\xE0"}
                ]
            }
        })

        test.assert_eq(resp.status(), 200)
        test.assert_eq(resp.json()["count"], 2)
    end)
end)
```

### 11. Documentation

#### Update docs/docs/webserver.md

Add comprehensive section:
- **File Uploads** - Overview and basic usage
- **Configuration** - Upload limits and file type restrictions
- **Security** - Best practices and common pitfalls
- **Examples** - Avatar upload, gallery, document management
- **Error Handling** - Common errors and how to handle them

#### Update CLAUDE.md

Add to web server section:
```markdown
## File Uploads

Quest web server automatically parses file uploads from multipart/form-data:

```quest
use "std/web" as web
use "std/io" as io
use "std/uuid" as uuid

# Configure upload limits
web.set_max_upload_size(100 * 1024 * 1024)  # 100 MB
web.set_max_file_size(10 * 1024 * 1024)     # 10 MB per file

fun handle_request(request)
    let file = request["files"]["avatar"]
    let title = request["form"]["title"]

    io.write("/uploads/" .. uuid.v4().str(), file["data"])
    {"status": 200, "json": {"uploaded": true}}
end
```

See [Web Server - File Uploads](docs/docs/webserver.md#file-uploads) for details.
```

### 12. Future Enhancements (Phase 2)

**Streaming API for Large Files:**
```quest
# For files > 100 MB, avoid loading entire file into memory
fun handle_request(request)
    if request["content_type"].starts_with("multipart/form-data")
        # Stream files one at a time
        request.stream_files(fun (file_info, reader)
            let path = "/uploads/" .. file_info["filename"]
            let writer = io.open(path, "wb")

            # Stream in chunks
            while true
                let chunk = reader.read(64 * 1024)  # 64 KB chunks
                if chunk.len() == 0
                    break
                end
                writer.write(chunk)
            end

            writer.close()
        end)
    end
end
```

**Direct-to-S3 Uploads:**
```quest
use "std/cloud/s3" as s3

fun handle_request(request)
    let file = request["files"]["document"]

    # Upload directly to S3 without saving to disk
    s3.upload(
        bucket: "my-bucket",
        key: "uploads/" .. uuid.v4().str(),
        data: file["data"],
        content_type: file["content_type"]
    )
end
```

**Image Processing Integration:**
```quest
use "std/image" as image

fun handle_request(request)
    let file = request["files"]["avatar"]

    # Process image
    let img = image.from_bytes(file["data"])
    let thumbnail = img.resize(200, 200).crop_center(200, 200)

    io.write("/uploads/thumb.jpg", thumbnail.to_bytes("jpeg", quality: 85))
end
```

## Implementation Timeline

### Week 1: Rust Infrastructure
- Add `multer` dependency
- Extend `ServerConfig` with `UploadConfig`
- Implement `parse_multipart_form()` function
- Implement `parse_urlencoded_form()` function
- Unit tests for parsing

### Week 2: Integration
- Integrate form/file parsing into request handler
- Add `request["form"]` and `request["files"]` fields
- Implement size limit enforcement
- Implement MIME type whitelist
- Error handling and messages

### Week 3: Quest API
- Add upload configuration to `lib/std/web.q` module (QEP-051)
  - Extend `Configuration` type with upload fields
  - Add runtime configuration state
  - Implement imperative API methods:
    - `web.set_max_upload_size()`
    - `web.set_max_file_size()`
    - `web.set_max_file_count()`
    - `web.set_allowed_file_types()`
- Update Rust bridge to read upload config from Quest module
- Integration tests (Quest)
- Manual testing with real uploads

### Week 4: Documentation & Examples
- Write comprehensive docs (webserver.md)
- Create example applications
  - Avatar upload
  - Gallery (multiple files)
  - Document submission form
- Security best practices guide
- Update CLAUDE.md

## Success Criteria

- ✅ Single file uploads work automatically
- ✅ Multiple file uploads (same field name) work
- ✅ Form fields and files parsed separately
- ✅ Size limits enforced automatically
- ✅ MIME type whitelist works
- ✅ Clear error messages for validation failures
- ✅ No breaking changes to existing code
- ✅ All tests pass (unit + integration)
- ✅ Documentation complete with security guidance
- ✅ Example applications demonstrate common patterns

## Rationale

### Why Integrate into std/web Module?

Following QEP-051's unified web framework design:
- **Consistency:** All web configuration in one place (`std/web`)
- **Discoverability:** Users import one module for all web features
- **Hybrid configuration:** Support both `quest.toml` and imperative API
- **Clean architecture:** Upload config is part of web server config

### Why Automatic Parsing?

Instead of requiring manual parsing:
- **Ergonomics:** Most common case should be easiest
- **Security:** Built-in validation prevents common errors
- **Framework convention:** Matches Flask/Django/Rails patterns
- **Flexibility:** Raw body still accessible for custom parsing

### Why Separate request["form"] and request["files"]?

- **Type safety:** Form fields are always strings, files are always Bytes
- **Clarity:** Clear distinction between text data and binary data
- **Convenience:** No need to check if field is a file or text

## Dependencies

QEP-052 builds on and requires:
- **QEP-051:** Web Framework API - Provides unified `std/web` module structure
- **QEP-053:** Module Configuration System - Provides configuration loading from `quest.toml`

## References

- [RFC 7578: Multipart Form Data](https://datatracker.ietf.org/doc/html/rfc7578)
- [multer crate documentation](https://docs.rs/multer/)
- [OWASP File Upload Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html)
- [QEP-028: Serve Command](qep-028-serve-command.md) - Original web server spec
- [QEP-051: Web Framework API](qep-051-web-framework.md) - Unified web framework (REQUIRED)
- [QEP-053: Module Configuration System](qep-053-module-configuration-system.md) - Configuration loading (REQUIRED)
