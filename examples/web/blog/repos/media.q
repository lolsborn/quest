# Media Repository
# Handles file uploads and media library management

use "std/io" as io
use "std/os" as os
use "std/uuid" as uuid
use "std/time" as time

# Allowed MIME types for uploads
const ALLOWED_MIME_TYPES = [
  "image/png",
  "image/jpeg",
  "image/jpg",
  "image/gif",
  "image/webp",
  "application/pdf"
]

# Allowed file extensions (case insensitive)
const ALLOWED_EXTENSIONS = ["png", "jpg", "jpeg", "gif", "webp", "pdf"]

# Default max file size (20MB in bytes)
const MAX_FILE_SIZE = 20971520

# Validate file type and size
# Args:
#   mime_type: String - MIME type of file
#   filename: String - Original filename
#   size: Int - File size in bytes
#   max_size: Int or nil - Maximum allowed size (defaults to MAX_FILE_SIZE)
# Returns: true if valid, raises ValueErr if invalid
pub fun validate_file(mime_type, filename, size, max_size)
  let max = max_size or MAX_FILE_SIZE

  # Check file size
  if size > max
    let max_mb = max / 1048576
    raise ValueErr.new(f"File size {size} exceeds maximum of {max_mb}MB")
  end

  # Check MIME type
  let mime_ok = false
  let i = 0
  while i < ALLOWED_MIME_TYPES.len()
    if mime_type == ALLOWED_MIME_TYPES[i]
      mime_ok = true
    end
    i = i + 1
  end

  if not mime_ok
    raise ValueErr.new(f"File type {mime_type} is not allowed")
  end

  # Check file extension
  let ext = get_extension(filename).lower()
  let ext_ok = false
  let j = 0
  while j < ALLOWED_EXTENSIONS.len()
    if ext == ALLOWED_EXTENSIONS[j]
      ext_ok = true
    end
    j = j + 1
  end

  if not ext_ok
    raise ValueErr.new(f"File extension .{ext} is not allowed")
  end

  # Check for path traversal attempts
  if filename.contains("..") or filename.contains("/") or filename.contains("\\")
    raise ValueErr.new("Invalid filename - path traversal not allowed")
  end

  return true
end

# Get file extension from filename
# Args:
#   filename: String
# Returns: String - extension without dot, or empty string if none
fun get_extension(filename)
  let parts = filename.split(".")
  if parts.len() < 2
    return ""
  end
  return parts[parts.len() - 1]
end

# Generate unique filename with timestamp and UUID
# Args:
#   original_filename: String - Original filename
# Returns: String - Unique filename like "20251018_abc123_image.png"
fun generate_filename(original_filename)
  # Get current timestamp (YYYYMMDD_HHMMSS format)
  let now = time.now()
  let timestamp = now.format("%Y%m%d_%H%M%S")

  # Generate short UUID (first 8 chars of UUID v4)
  let id = uuid.v4().to_string().split("-")[0]

  # Get original extension
  let ext = get_extension(original_filename)

  # Sanitize original filename (remove extension and special chars)
  let name_parts = original_filename.split(".")
  let base_name = name_parts[0]

  # Remove any non-alphanumeric chars except hyphens and underscores
  let sanitized = ""
  let i = 0
  while i < base_name.len()
    let char = base_name[i]
    # Allow a-z, A-Z, 0-9, hyphens, and underscores
    let code = char.ord()
    let is_valid = (code >= 48 and code <= 57) or   # 0-9
                   (code >= 65 and code <= 90) or   # A-Z
                   (code >= 97 and code <= 122) or  # a-z
                   code == 45 or code == 95         # - or _
    if is_valid
      sanitized = sanitized .. char
    end
    i = i + 1
  end

  # Truncate if too long
  if sanitized.len() > 30
    sanitized = sanitized.substr(0, 30)
  end

  # Build final filename
  if ext != ""
    return f"{timestamp}_{id}_{sanitized}.{ext}"
  else
    return f"{timestamp}_{id}_{sanitized}"
  end
end

# Save uploaded file to directory
# Args:
#   upload_dir: String - Path to upload directory
#   filename: String - Original filename
#   mime_type: String - MIME type
#   data: Bytes - File data
#   max_size: Int or nil - Max size override
# Returns: Dict with file metadata {filename, path, size, mime_type}
pub fun save_file(upload_dir, filename, mime_type, data, max_size)
  # Validate file
  validate_file(mime_type, filename, data.len(), max_size)

  # Generate unique filename
  let unique_filename = generate_filename(filename)

  # Build full path
  let file_path = upload_dir .. "/" .. unique_filename

  # Ensure directory exists
  if not io.exists(upload_dir)
    os.mkdir(upload_dir)
  end

  # Write file
  io.write(file_path, data)

  # Return metadata
  return {
    filename: unique_filename,
    original_filename: filename,
    path: file_path,
    size: data.len(),
    mime_type: mime_type,
    uploaded_at: time.now().format("%Y-%m-%d %H:%M:%S")
  }
end

# List all files in upload directory
# Args:
#   upload_dir: String - Path to upload directory
# Returns: Array of file metadata dicts
pub fun list_files(upload_dir)
  if not io.exists(upload_dir)
    return []
  end

  let files = []
  let entries = os.listdir(upload_dir)

  let i = 0
  while i < entries.len()
    let filename = entries[i]
    let file_path = upload_dir .. "/" .. filename

    # Skip directories and hidden files
    if not filename.startswith(".") and io.exists(file_path)
      # Get file size (we'll need to read it for now, since we don't have stat)
      let size = 0
      try
        let content = io.read(file_path)
        if content.cls() == "Bytes"
          size = content.len()
        end
      catch e
        # Skip files we can't read
        i = i + 1
        continue
      end

      # Determine MIME type from extension
      let ext = get_extension(filename).lower()
      let mime_type = "application/octet-stream"
      if ext == "png"
        mime_type = "image/png"
      elif ext == "jpg" or ext == "jpeg"
        mime_type = "image/jpeg"
      elif ext == "gif"
        mime_type = "image/gif"
      elif ext == "webp"
        mime_type = "image/webp"
      elif ext == "pdf"
        mime_type = "application/pdf"
      end

      files.push({
        filename: filename,
        size: size,
        mime_type: mime_type,
        path: file_path
      })
    end

    i = i + 1
  end

  # Sort by filename (which starts with timestamp, so chronological)
  # Reverse to show newest first
  files.reverse()

  return files
end

# Delete file from upload directory
# Args:
#   upload_dir: String - Path to upload directory
#   filename: String - Filename to delete
# Returns: true if deleted, false if not found
pub fun delete_file(upload_dir, filename)
  # Prevent path traversal
  if filename.contains("..") or filename.contains("/") or filename.contains("\\")
    raise ValueErr.new("Invalid filename")
  end

  let file_path = upload_dir .. "/" .. filename

  if not io.exists(file_path)
    return false
  end

  io.remove(file_path)
  return true
end

# Get public URL for uploaded file
# Args:
#   filename: String - Filename in upload directory
# Returns: String - Public URL path
pub fun get_file_url(filename)
  return "/uploads/" .. filename
end
