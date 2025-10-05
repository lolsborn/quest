# QEP-008: std/compress - Compression and Decompression

**Status:** Draft
**Author:** Quest Team
**Created:** 2025-10-05
**Module Structure:** `std/compress/{gzip,bzip2,deflate,zlib}`

## Abstract

This QEP specifies the `std/compress` family of modules for data compression and decompression in Quest. Each compression format is provided as a separate submodule with a consistent API, allowing users to import only the formats they need.

## Rationale

Compression is essential for:
- **File operations** - Compressing/decompressing .gz, .bz2 files
- **Network protocols** - HTTP compression, API responses
- **Data storage** - Reducing database/storage size
- **Logging** - Compressing log files
- **Backups** - Archive compression

Quest needs compression support that is:
1. **Modular** - Load only the formats you need
2. **Consistent API** - Same interface across all formats
3. **Simple** - Easy compress/decompress functions
4. **Level control** - Choose compression speed vs ratio

## Design Philosophy

**Modular submodules for each format:**

```quest
# Import only what you need
use "std/compress/gzip"
use "std/compress/bzip2"

# Consistent API across all formats
let compressed = gzip.compress(data)
let decompressed = gzip.decompress(compressed)

# With compression level
let compressed = bzip2.compress(data, 9)  # Max compression
```

**Available formats:**
- **std/compress/gzip** - Most common (`.gz` files, HTTP, .tar.gz)
- **std/compress/bzip2** - Better compression ratio (`.bz2` files, .tar.bz2)
- **std/compress/deflate** - Raw compression (no headers)
- **std/compress/zlib** - Deflate with checksums

## Rust Implementation

**Dependencies:**
- `flate2 = "1.0"` - Gzip, deflate, zlib (standard Rust compression)
- `bzip2 = "0.4"` - Bzip2 compression

**Features:**
- Gzip, deflate, zlib, bzip2 formats
- Compression levels 0-9
- Streaming support
- CRC32 checksums (gzip)
- Better compression ratio with bzip2

## API Design

All compression modules follow the same consistent API:

### Common Interface

#### `{format}.compress(data)` / `{format}.compress(data, level)`

Compress data using the specified format.

**Parameters:**
- `data` (Str or Bytes) - Data to compress
- `level` (Int, optional) - Compression level (default: 6 for most formats)
  - 0 = No compression (fastest)
  - 1 = Best speed
  - 6 = Default (balanced)
  - 9 = Best compression (slowest)

**Returns:** Compressed data (Bytes)

#### `{format}.decompress(data)`

Decompress data in the specified format.

**Parameters:**
- `data` (Bytes) - Compressed data

**Returns:** Decompressed data (Bytes)

---

### std/compress/gzip

Gzip compression - most common format for `.gz` files, HTTP compression, and `.tar.gz` archives.

**Example:**
```quest
use "std/compress/gzip"
use "std/io"

# Compress string
let data = "Hello World! " * 100
let compressed = gzip.compress(data)
puts("Original: " .. data.len() .. " bytes")
puts("Compressed: " .. compressed.len() .. " bytes")

# Compress with max compression
let best = gzip.compress(data, 9)

# Write compressed file
io.write("file.gz", compressed)

# Read and decompress
let compressed = io.read("file.txt.gz").bytes()
let decompressed = gzip.decompress(compressed)
let text = decompressed.decode("utf-8")
puts(text)
```

### std/compress/bzip2

Bzip2 compression - better compression ratio than gzip (10-15% smaller) but 2-3x slower. Ideal for archival and backups.

**Example:**
```quest
use "std/compress/bzip2"
use "std/io"

# Compress with best compression
let data = "test data " * 1000
let compressed = bzip2.compress(data, 9)

# Write .bz2 file
io.write("file.txt.bz2", compressed)

# Read and decompress .bz2 file
let compressed = io.read("file.txt.bz2").bytes()
let decompressed = bzip2.decompress(compressed)
let text = decompressed.decode("utf-8")
puts(text)
```

### std/compress/deflate

Raw deflate compression - no headers, minimal overhead. Used when you control both ends of the compression.

**Example:**
```quest
use "std/compress/deflate"

let data = "test data"
let compressed = deflate.compress(data)
let decompressed = deflate.decompress(compressed)

test.assert_eq(decompressed.decode("utf-8"), data, nil)
```

### std/compress/zlib

Zlib compression - deflate with checksums and headers. Used in libraries and when data integrity verification is needed.

**Example:**
```quest
use "std/compress/zlib"

let data = "test data"
let compressed = zlib.compress(data)
let decompressed = zlib.decompress(compressed)
```

## Complete Examples

### Compressing Log Files

```quest
use "std/compress/gzip"
use "std/io"

# Read log file
let log_data = io.read("app.log")

# Compress and save
let compressed = gzip.compress(log_data)
io.write("app.log.gz", compressed)

puts("Original: " .. log_data.len() .. " bytes")
puts("Compressed: " .. compressed.len() .. " bytes")
let ratio = (1.0 - (compressed.len() / log_data.len())) * 100
puts("Compression ratio: " .. ratio .. "%")
```

### Reading Compressed Files

```quest
use "std/compress/gzip"
use "std/io"
use "std/encoding/json"

# Read compressed JSON
let compressed = io.read("data.json.gz").bytes()
let json_text = gzip.decompress(compressed).decode("utf-8")
let data = json.parse(json_text)

puts("Loaded " .. data.len() .. " records")
```

### Compression Levels Comparison

```quest
use "std/compress/gzip"

let data = "x" * 10000

# Test different compression levels
for level in 0 to 9
    let compressed = gzip.compress(data, level)
    puts("Level " .. level .. ": " .. compressed.len() .. " bytes")
end
# Output:
# Level 0: 10029 bytes (no compression)
# Level 1: 89 bytes (fast)
# Level 6: 48 bytes (default)
# Level 9: 48 bytes (best)
```

### Comparing Compression Formats

```quest
use "std/compress/gzip"
use "std/compress/bzip2"
use "std/io"

let data = io.read("large_file.txt")

# Gzip - Fast, good compression
let gz = gzip.compress(data, 6)
puts("Gzip: " .. gz.len() .. " bytes")

# Bzip2 - Slower, better compression
let bz2 = bzip2.compress(data, 9)
puts("Bzip2: " .. bz2.len() .. " bytes")

# Typically: bz2 < gz in size, but bz2 slower to compress
```

### HTTP Response Compression

```quest
use "std/compress/gzip"
use "std/encoding/json"

fun compress_api_response(data)
    let json = json.stringify(data)
    gzip.compress(json)
end

let response_data = [
    {"id": 1, "name": "Item 1"},
    {"id": 2, "name": "Item 2"}
]

let compressed = compress_api_response(response_data)
# Send compressed data with Content-Encoding: gzip header
```

### Data Deduplication

```quest
use "std/compress/gzip"
use "std/hash"
use "std/io"

fun deduplicate_files(files)
    let seen_hashes = {}
    let unique_files = []

    for file in files
        let data = io.read(file)
        let hash = hash.sha256(data)

        if not seen_hashes.contains(hash)
            seen_hashes[hash] = true
            unique_files.push(file)

            # Compress unique file
            let compressed = gzip.compress(data)
            io.write(file .. ".gz", compressed)
        end
    end

    unique_files
end
```

### Backup with Compression

```quest
use "std/compress/gzip"
use "std/io"
use "std/encoding/json"

fun backup_data(data, filename)
    # Serialize to JSON
    let json_text = json.stringify(data)

    # Compress with max compression for backups
    let compressed = gzip.compress(json_text, 9)

    # Save
    io.write(filename .. ".json.gz", compressed)

    puts("Backup saved: " .. compressed.len() .. " bytes")
end

fun restore_data(filename)
    # Read compressed file
    let compressed = io.read(filename .. ".json.gz").bytes()

    # Decompress
    let json_text = gzip.decompress(compressed).decode("utf-8")

    # Parse JSON
    json.parse(json_text)
end
```

## Implementation Notes

### Rust Structure

Each compression format is implemented as a separate module file:

```rust
// src/modules/compress/gzip.rs
use flate2::Compression;
use flate2::read::GzDecoder;
use flate2::write::GzEncoder;
use std::io::{Read, Write};

pub fn compress(data: &[u8], level: u32) -> Result<Vec<u8>, String> {
    let mut encoder = GzEncoder::new(Vec::new(), Compression::new(level));
    encoder.write_all(data)
        .map_err(|e| format!("Failed to compress: {}", e))?;
    encoder.finish()
        .map_err(|e| format!("Failed to finish compression: {}", e))
}

pub fn decompress(data: &[u8]) -> Result<Vec<u8>, String> {
    let mut decoder = GzDecoder::new(data);
    let mut result = Vec::new();
    decoder.read_to_end(&mut result)
        .map_err(|e| format!("Failed to decompress: {}", e))?;
    Ok(result)
}
```

```rust
// src/modules/compress/bzip2.rs
use bzip2::read::BzDecoder;
use bzip2::write::BzEncoder;
use bzip2::Compression;
use std::io::{Read, Write};

pub fn compress(data: &[u8], level: u32) -> Result<Vec<u8>, String> {
    let mut encoder = BzEncoder::new(Vec::new(), Compression::new(level));
    encoder.write_all(data)
        .map_err(|e| format!("Failed to compress: {}", e))?;
    encoder.finish()
        .map_err(|e| format!("Failed to finish compression: {}", e))
}

pub fn decompress(data: &[u8]) -> Result<Vec<u8>, String> {
    let mut decoder = BzDecoder::new(data);
    let mut result = Vec::new();
    decoder.read_to_end(&mut result)
        .map_err(|e| format!("Failed to decompress: {}", e))?;
    Ok(result)
}
```

### Module Registration

```rust
// In src/main.rs module loading
"std/compress/gzip" => {
    let mut module = QModule::new("gzip");
    module.add_function("compress", gzip_compress);
    module.add_function("decompress", gzip_decompress);
    module
}
"std/compress/bzip2" => {
    let mut module = QModule::new("bzip2");
    module.add_function("compress", bzip2_compress);
    module.add_function("decompress", bzip2_decompress);
    module
}
// Similar for deflate and zlib
```

### Type Handling

**Input:** Accept both Str and Bytes
```rust
let bytes = match value {
    QValue::Str(s) => s.value.as_bytes().to_vec(),
    QValue::Bytes(b) => b.data.clone(),
    _ => return Err("Expected Str or Bytes"),
};
```

**Output:** Always return Bytes
- User can call `.decode("utf-8")` if needed

## Performance Characteristics

### Compression Levels (Gzip/Deflate/Zlib)

| Level | Speed | Ratio | Use Case |
|-------|-------|-------|----------|
| 0 | Fastest | 0% | No compression (CRC only) |
| 1 | Very fast | ~60% | Real-time compression |
| 6 | Balanced | ~75% | Default (good speed/ratio) |
| 9 | Slowest | ~80% | Archival, backups |

### Format Comparison

| Format | Speed | Ratio | Use Case |
|--------|-------|-------|----------|
| Gzip | Fast | Good | General purpose, HTTP, logs |
| Bzip2 | Slow | Best | Archival, backups, max compression |
| Deflate | Fastest | Good | Embedded, low overhead |
| Zlib | Fast | Good | Libraries, checksummed data |

**Recommendations:**
- **Gzip** - Default choice for most use cases
- **Bzip2** - When file size matters more than speed (backups, archives)
- **Deflate** - When you control both ends (no headers needed)
- **Zlib** - When you need checksums without gzip headers

## Future Enhancements

**Phase 2:**
- Zip file support (`compress.zip()`, `compress.unzip()`)
- Tar support (`compress.tar()`, `compress.untar()`)
- Streaming compression for large files
- Compression with dictionary (for small repeated data)

**Phase 3:**
- Modern formats (zstd, brotli)
- Archive manipulation (add/remove files from zip)
- Compression benchmarking utilities

## Open Questions

1. **Should we support tar.gz directly?**
   - `compress.tar_gzip(files, output)`
   - **Decision:** Phase 2 - focus on compression primitives first

2. **Error handling for corrupted data?**
   - Return error or raise exception?
   - **Decision:** Return error (consistent with Quest error handling)

3. **Memory limits for decompression?**
   - Prevent decompression bombs
   - **Decision:** Phase 2 - add optional max_size parameter

4. **File I/O integration?**
   - `compress.gzip_file(input, output)`
   - **Decision:** No - use `io.read()` + `compress.gzip()` + `io.write()`

## Testing Strategy

Each compression module should have its own test file:

```quest
# test/compress/gzip_test.q
use "std/test"
use "std/compress/gzip"

test.module("std/compress/gzip")

test.describe("gzip.compress and gzip.decompress", fun ()
    test.it("compresses and decompresses data", fun ()
        let original = "Hello World! " * 100
        let compressed = gzip.compress(original)
        let decompressed = gzip.decompress(compressed)

        test.assert_eq(decompressed.decode("utf-8"), original, nil)
        test.assert_lt(compressed.len(), original.len(), nil)
    end)

    test.it("supports compression levels", fun ()
        let data = "x" * 10000
        let fast = gzip.compress(data, 1)
        let best = gzip.compress(data, 9)

        # Best compression should be smaller or equal
        test.assert_lte(best.len(), fast.len(), nil)
    end)

    test.it("handles empty data", fun ()
        let compressed = gzip.compress("")
        let decompressed = gzip.decompress(compressed)
        test.assert_eq(decompressed.decode("utf-8"), "", nil)
    end)

    test.it("handles bytes input", fun ()
        let data = b"binary data"
        let compressed = gzip.compress(data)
        let decompressed = gzip.decompress(compressed)
        test.assert_eq(decompressed, data, nil)
    end)
end)
```

```quest
# test/compress/bzip2_test.q
use "std/test"
use "std/compress/bzip2"

test.module("std/compress/bzip2")

test.describe("bzip2.compress and bzip2.decompress", fun ()
    test.it("compresses and decompresses data", fun ()
        let original = "Hello World! " * 100
        let compressed = bzip2.compress(original)
        let decompressed = bzip2.decompress(compressed)

        test.assert_eq(decompressed.decode("utf-8"), original, nil)
        test.assert_lt(compressed.len(), original.len(), nil)
    end)
end)
```

## Implementation Checklist

### Phase 1: Gzip (Core)
- [ ] Create QEP-008 specification
- [ ] Add `flate2` crate to Cargo.toml
- [ ] Create `src/modules/compress/` directory
- [ ] Implement `src/modules/compress/gzip.rs`
- [ ] Register `std/compress/gzip` in module system
- [ ] Create `lib/std/compress/gzip.q` documentation file
- [ ] Write `test/compress/gzip_test.q`
- [ ] Add to docs/docs/stdlib/compress.md

### Phase 2: Bzip2 (Better Compression)
- [ ] Add `bzip2` crate to Cargo.toml
- [ ] Implement `src/modules/compress/bzip2.rs`
- [ ] Register `std/compress/bzip2` in module system
- [ ] Create `lib/std/compress/bzip2.q` documentation file
- [ ] Write `test/compress/bzip2_test.q`

### Phase 3: Deflate & Zlib (Additional Formats)
- [ ] Implement `src/modules/compress/deflate.rs`
- [ ] Implement `src/modules/compress/zlib.rs`
- [ ] Register modules in module system
- [ ] Create documentation files
- [ ] Write test files

## Conclusion

The `std/compress` family of modules provides Quest with industry-standard compression capabilities using a modular, consistent API. Each compression format is available as a separate submodule (`std/compress/gzip`, `std/compress/bzip2`, etc.), allowing users to import only what they need.

**Key Benefits:**
- **Modular design** - Load only the formats you need
- **Consistent API** - All formats use `compress()` and `decompress()` methods
- **Extensible** - Easy to add new formats (zstd, brotli, etc.) without breaking existing code
- **Battle-tested** - Uses proven `flate2` and `bzip2` Rust crates

**Implementation Strategy:**
1. **Phase 1:** Start with `std/compress/gzip` (most common use case)
2. **Phase 2:** Add `std/compress/bzip2` (better compression for archival)
3. **Phase 3:** Add `std/compress/deflate` and `std/compress/zlib` (specialized formats)
4. **Future:** Consider `std/compress/zstd` and `std/compress/brotli` (modern formats)
