# std/compress - Data Compression

Quest provides four compression formats in the `std/compress` module family, each optimized for different use cases. All formats share a consistent API for easy interoperability.

## Available Formats

### std/compress/gzip

The most common compression format, ideal for web, files, and general use.

```quest
use "std/compress/gzip"

let data = "Hello World! " * 100
let compressed = gzip.compress(data)
let decompressed = gzip.decompress(compressed)
puts(decompressed.decode("utf-8"))
```

**When to use:**
- `.gz` files and `.tar.gz` archives
- HTTP compression
- Standard file compression
- Widely supported format

**Format:** RFC 1952 (gzip with CRC32 checksum)

### std/compress/bzip2

Better compression ratios than gzip, ideal for archival and backups.

```quest
use "std/compress/bzip2"

let log_data = io.read("app.log")
let compressed = bzip2.compress(log_data, 9)  # Max compression
io.write("app.log.bz2", compressed)
```

**When to use:**
- `.bz2` files and `.tar.bz2` archives
- Archival storage (best compression ratio)
- Backups where space is critical
- Text-heavy data compression

**Format:** Bzip2 block-sorting compression (typically 10-15% better than gzip)

### std/compress/deflate

Raw compression algorithm without headers, minimal overhead.

```quest
use "std/compress/deflate"

let payload = "Custom protocol data"
let compressed = deflate.compress(payload)
# Embed in your own format with no header overhead
```

**When to use:**
- Custom compression protocols
- Embedding compressed data in other formats
- Minimizing overhead (no headers)
- When you need raw compressed data

**Format:** Raw DEFLATE (the core algorithm used by gzip and zlib)

### std/compress/zlib

DEFLATE with checksums but minimal headers, used by many file formats.

```quest
use "std/compress/zlib"

let data = "Data that needs integrity checking"
let compressed = zlib.compress(data)
# Automatic Adler-32 checksum verification on decompress
```

**When to use:**
- PNG images, PDF documents
- Git repositories
- When you need integrity checks (Adler-32 checksum)
- More compact headers than gzip

**Format:** Zlib (DEFLATE + Adler-32 checksum, 6-byte overhead)

## API Reference

All formats share the same API:

### compress(data, level?) → Bytes

Compresses data using the specified format.

**Parameters:**
- `data` (Str or Bytes) - Data to compress
- `level` (Int, optional) - Compression level
  - **gzip, deflate, zlib:** 0-9 (default: 6)
    - 0 = No compression (fastest)
    - 1 = Best speed
    - 6 = Default (balanced)
    - 9 = Best compression (slowest)
  - **bzip2:** 1-9 (default: 6)
    - 1 = Fastest (100KB blocks)
    - 6 = Default (600KB blocks)
    - 9 = Best compression (900KB blocks)

**Returns:** Compressed data as Bytes

**Examples:**

```quest
# Default compression
let gz = gzip.compress("Hello World!")

# Maximum compression
let bz = bzip2.compress(data, 9)

# Fastest compression
let zl = zlib.compress(data, 1)

# No compression (gzip only, for testing)
let raw = gzip.compress(data, 0)
```

### decompress(data) → Bytes

Decompresses data that was compressed with the corresponding format.

**Parameters:**
- `data` (Bytes or Str) - Compressed data

**Returns:** Decompressed data as Bytes

**Examples:**

```quest
use "std/compress/gzip"

let compressed = gzip.compress("Hello World!")
let decompressed = gzip.decompress(compressed)
let text = decompressed.decode("utf-8")
puts(text)  # "Hello World!"
```

## Format Comparison

| Format | Ratio | Speed | Headers | Checksum | Use Case |
|--------|-------|-------|---------|----------|----------|
| gzip | Good | Fast | 18 bytes | CRC32 | General purpose, HTTP |
| bzip2 | Best | Slow | Variable | CRC32 | Archival, backups |
| deflate | Good | Fastest | 0 bytes | None | Custom protocols |
| zlib | Good | Fast | 6 bytes | Adler-32 | File formats (PNG, PDF) |

## Common Patterns

### Compressing Files

```quest
use "std/compress/gzip"
use "std/io"

# Read, compress, and save
let data = io.read("large_file.txt")
let compressed = gzip.compress(data, 9)
io.write("large_file.txt.gz", compressed)

# Calculate compression ratio
let ratio = (1.0 - (compressed.len().to_f64() / data.len().to_f64())) * 100.0
puts("Saved " .. ratio._str() .. "% space")
```

### Decompressing Files

```quest
use "std/compress/bzip2"
use "std/io"

let compressed = io.read("archive.tar.bz2").bytes()
let decompressed = bzip2.decompress(compressed)
io.write("archive.tar", decompressed)
```

### HTTP Response Compression

```quest
use "std/compress/gzip"
use "std/http/client"

let response = http.get("https://api.example.com/large_data")

# Check if response is gzip compressed
if response.header("Content-Encoding") == "gzip"
    let decompressed = gzip.decompress(response.bytes())
    let json = json.parse(decompressed.decode("utf-8"))
end
```

### Testing Compression Ratios

```quest
use "std/compress/gzip"
use "std/compress/bzip2"
use "std/compress/zlib"

let data = "Repeated text " * 1000

let gz = gzip.compress(data, 9)
let bz = bzip2.compress(data, 9)
let zl = zlib.compress(data, 9)

puts("Original: " .. data.len() .. " bytes")
puts("Gzip:     " .. gz.len() .. " bytes")
puts("Bzip2:    " .. bz.len() .. " bytes (best)")
puts("Zlib:     " .. zl.len() .. " bytes")
```

### Stream Processing (Compress on Write)

```quest
use "std/compress/gzip"
use "std/io"

# Compress log entries as you write them
let log_file = "app.log.gz"
let entries = ["Entry 1", "Entry 2", "Entry 3"]

let all_data = entries.join("\n")
let compressed = gzip.compress(all_data)
io.write(log_file, compressed)
```

### Working with Archives

```quest
use "std/compress/bzip2"
use "std/io"

# Create compressed archive
let files_data = io.read("file1.txt") .. io.read("file2.txt")
let archive = bzip2.compress(files_data, 9)
io.write("backup.bz2", archive)
```

## Error Handling

All compression functions can raise errors:

```quest
use "std/compress/gzip"

try
    # Invalid compression level
    let bad = gzip.compress("data", 10)
catch e
    puts("Error: " .. e.message())  # "Compression level must be between 0 and 9"
end

try
    # Invalid compressed data
    let bad = gzip.decompress(b"not gzip data")
catch e
    puts("Error: " .. e.message())  # "Failed to decompress: ..."
end
```

## Performance Tips

### Choosing Compression Level

- **Level 1:** Real-time compression, streaming
- **Level 6:** Default, balanced for most uses
- **Level 9:** Archival, backups, storage

```quest
# Real-time: Use level 1
let fast = gzip.compress(stream_data, 1)

# Storage: Use level 9
let archived = bzip2.compress(backup_data, 9)
```

### Choosing Format

```quest
# For web/HTTP: gzip (widely supported)
let web_data = gzip.compress(response)

# For best ratio: bzip2
let backup = bzip2.compress(large_file, 9)

# For custom format: deflate (no headers)
let embedded = deflate.compress(payload)

# For integrity: zlib (built-in checksum)
let safe_data = zlib.compress(important_data)
```

### Memory Considerations

- Higher compression levels use more memory
- Bzip2 level 9 uses ~900KB blocks
- For large data, consider streaming (future feature)

## Format Details

### Gzip Format

- Header: 10 bytes (method, flags, timestamp)
- Footer: 8 bytes (CRC32 + uncompressed size)
- Overhead: ~18 bytes
- Extensions: `.gz`, `.gzip`
- MIME: `application/gzip`

### Bzip2 Format

- Header: 4 bytes ("BZh" + block size)
- Uses block-sorting Burrows-Wheeler transform
- Better compression for text and repetitive data
- Overhead: Variable (typically 50-80 bytes)
- Extensions: `.bz2`, `.bzip2`
- MIME: `application/x-bzip2`

### Deflate Format

- No headers or trailers
- Raw DEFLATE stream
- Overhead: 0 bytes
- Used internally by gzip and zlib
- Not a standalone file format

### Zlib Format

- Header: 2 bytes (method + flags)
- Footer: 4 bytes (Adler-32 checksum)
- Overhead: 6 bytes
- Used by PNG, PDF, Git
- MIME: `application/zlib`

## See Also

- [io](./io.md) - File operations
- [http](./http.md) - HTTP client with compression support
- QEP-008 - Compression Module Specification
