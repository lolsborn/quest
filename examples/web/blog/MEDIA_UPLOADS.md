# Media Upload Feature

The Quest blog now supports file uploads for images and PDFs through a media library interface.

## Configuration

Set the `WEB_UPLOAD_DIR` environment variable to specify where uploaded files should be stored:

```bash
export WEB_UPLOAD_DIR=uploads
```

The upload directory is relative to the blog working directory (`examples/web/blog/`).

## Supported File Types

- **Images**: PNG, JPEG, GIF, WebP
- **Documents**: PDF
- **Maximum file size**: 20MB

## Usage

### Accessing the Media Library

1. Ensure you're on an allowed IP (see `ALLOWED_IPS` env var)
2. Navigate to `/admin/media` or click the "Media" button in the navigation
3. The media library shows all uploaded files in a grid

### Uploading Files

**From Media Library:**
1. Go to `/admin/media`
2. Click "Choose File" and select an image or PDF
3. Click "Upload File"
4. File appears in the grid with a timestamped, unique filename

**From Post Editor:**
1. Open any post in the editor (`/admin/edit/[slug]`)
2. Click the "🖼️ Media Library" button above the content editor
3. Upload a new file or select an existing one
4. Click on a file to insert it at the cursor position
   - Images: Inserted as `![filename](URL)`
   - PDFs: Inserted as `[filename](URL)`

### Copying URLs

Click the "📋 Copy URL" button next to any file in the media library to copy its full public URL to your clipboard.

### Deleting Files

Click the 🗑️ button next to any file and confirm to delete it permanently.

## File Naming

Uploaded files are automatically renamed with a timestamp and UUID for uniqueness:

```
20251018_143052_abc12345_myimage.png
```

Format: `YYYYMMDD_HHMMSS_[UUID]_[sanitized-original-name].[ext]`

## Implementation Details

### Multipart Form Data

The Quest web server now supports multipart/form-data parsing via the `multer` Rust crate. When a request with `Content-Type: multipart/form-data` is received, the request body is structured as:

```quest
request["body"] = {
  fields: {key: value, ...},  # Text form fields
  files: [                     # Array of uploaded files
    {
      name: "file",
      filename: "image.png",
      mime_type: "image/png",
      size: 123456,
      data: <Bytes>             # File contents
    }
  ]
}
```

### Media Repository

The `repos/media.q` module provides functions for file management:

- `validate_file(mime_type, filename, size, max_size)` - Validates file type and size
- `save_file(upload_dir, filename, mime_type, data, max_size)` - Saves file to disk
- `list_files(upload_dir)` - Returns array of file metadata
- `delete_file(upload_dir, filename)` - Deletes file
- `get_file_url(filename)` - Returns public URL path

### API Endpoints

- `GET /admin/media` - Media library UI
- `POST /admin/media/upload` - Upload file endpoint
- `POST /admin/media/delete` - Delete file endpoint

All endpoints require IP authorization (same as post editing).

## Security

- Path traversal protection (no `..`, `/`, or `\` in filenames)
- MIME type validation
- File extension validation
- File size limits (20MB default)
- IP-based access control (same as admin panel)
- Files served as static assets via `/uploads/` URL prefix
