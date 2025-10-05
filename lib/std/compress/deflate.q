# std/compress/deflate - Deflate Compression and Decompression
#
# This module provides raw deflate compression and decompression (no headers).
# Deflate is the core compression algorithm used by gzip and zlib.
#
# Common use cases:
# - Custom compression protocols
# - Embedding compressed data in other formats
# - Low-overhead compression
# - When you need raw compressed data without headers
#
# Usage:
#   use "std/compress/deflate"
#
#   # Compress data
#   let compressed = deflate.compress("Hello World!")
#
#   # Decompress data
#   let decompressed = deflate.decompress(compressed)
#   let text = decompressed.decode("utf-8")
#
#   # Compress with specific level
#   let compressed = deflate.compress(data, 9)  # Max compression
#
# Available functions:
#
# deflate.compress(data, level?) -> Bytes
#   Compress data using raw deflate format (no headers).
#
#   Parameters:
#     data (Str or Bytes) - Data to compress
#     level (Int, optional) - Compression level 0-9 (default: 6)
#       0 = No compression (fastest)
#       1 = Best speed
#       6 = Default (balanced)
#       9 = Best compression (slowest)
#
#   Returns: Compressed data as Bytes (raw, no headers)
#
#   Example:
#     use "std/compress/deflate"
#     let data = "Hello World! " * 100
#     let compressed = deflate.compress(data)
#     puts("Original: " .. data.len() .. " bytes")
#     puts("Compressed: " .. compressed.len() .. " bytes")
#
# deflate.decompress(data) -> Bytes
#   Decompress raw deflate data.
#
#   Parameters:
#     data (Bytes) - Raw deflate compressed data (no headers)
#
#   Returns: Decompressed data as Bytes
#
#   Example:
#     use "std/compress/deflate"
#
#     let compressed = deflate.compress("Test data")
#     let decompressed = deflate.decompress(compressed)
#     let text = decompressed.decode("utf-8")
#     puts(text)
#
# When to use deflate vs gzip vs zlib:
#
# Use deflate when:
#   - You need raw compressed data without headers
#   - Building custom compression protocols
#   - Minimizing overhead (no extra bytes)
#   - Embedding compressed data in other formats
#
# Use gzip when:
#   - Working with .gz files
#   - HTTP compression
#   - Standard file compression
#   - Need filename, timestamp, CRC32 checksum
#
# Use zlib when:
#   - Need checksums but minimal headers
#   - Working with PNG files, PDF, etc.
#   - Need data integrity verification
#   - More compact than gzip headers
#
# Compression Levels:
#
# Level 0: No compression
#   - Fastest
#   - Useful for testing or pre-compressed data
#   - ~0% size reduction
#
# Level 1: Minimal compression
#   - Very fast
#   - Good for real-time compression
#   - ~60% size reduction (typical)
#
# Level 6: Default compression (recommended)
#   - Balanced speed/ratio
#   - Good for most use cases
#   - ~75% size reduction (typical)
#
# Level 9: Maximum compression
#   - Slowest
#   - Best for archival and backups
#   - ~80% size reduction (typical)
#
# Error Handling:
#
# compress() errors:
#   - Invalid compression level (must be 0-9)
#   - I/O errors during compression
#
# decompress() errors:
#   - Invalid deflate format
#   - Corrupted data
#   - I/O errors during decompression
#
# Performance Notes:
#
# - Fastest format (no header overhead)
#   - Same compression algorithm as gzip/zlib
# - No integrity checks (use zlib if needed)
# - Smallest compressed size (no headers)
#
# Example: Compress data for embedding
#
#   use "std/compress/deflate"
#
#   let data = "Important data to embed"
#   let compressed = deflate.compress(data, 9)
#
#   # Embed in custom format
#   let header = b"\x01\x02\x03\x04"
#   let output = header .. compressed
#
# Example: Custom protocol with deflate
#
#   use "std/compress/deflate"
#
#   # Compress payload
#   let payload = "Custom protocol data"
#   let compressed = deflate.compress(payload)
#
#   # Add length prefix
#   let length = compressed.len()
#   # ... send length and compressed data
