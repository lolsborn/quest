# std/compress/gzip - Gzip Compression and Decompression
#
# This module provides gzip compression and decompression functionality using
# the industry-standard gzip format (RFC 1952).
#
# Common use cases:
# - Compressing log files
# - HTTP response compression
# - Reducing storage size
# - Creating .gz files
# - Reading compressed data
#
# Usage:
#   use "std/compress/gzip"
#
#   # Compress data
#   let compressed = gzip.compress("Hello World!")
#
#   # Decompress data
#   let decompressed = gzip.decompress(compressed)
#   let text = decompressed.decode("utf-8")
#
#   # Compress with specific level
#   let compressed = gzip.compress(data, 9)  # Max compression
#
# Available functions:
#
# gzip.compress(data, level?) -> Bytes
#   Compress data using gzip format.
#
#   Parameters:
#     data (Str or Bytes) - Data to compress
#     level (Int, optional) - Compression level 0-9 (default: 6)
#       0 = No compression (fastest)
#       1 = Best speed
#       6 = Default (balanced)
#       9 = Best compression (slowest)
#
#   Returns: Compressed data as Bytes
#
#   Example:
#     use "std/compress/gzip"
#     let data = "Hello World! " * 100
#     let compressed = gzip.compress(data)
#     puts("Original: " .. data.len() .. " bytes")
#     puts("Compressed: " .. compressed.len() .. " bytes")
#
# gzip.decompress(data) -> Bytes
#   Decompress gzip data.
#
#   Parameters:
#     data (Bytes) - Gzip compressed data
#
#   Returns: Decompressed data as Bytes
#
#   Example:
#     use "std/compress/gzip"
#     use "std/io"
#
#     # Read compressed file
#     let compressed = io.read("file.txt.gz").bytes()
#     let decompressed = gzip.decompress(compressed)
#     let text = decompressed.decode("utf-8")
#     puts(text)
#
# Compression Levels:
#
# Level 0: No compression (only CRC32 checksum)
#   - Fastest
#   - Useful for already compressed data
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
#   - Invalid gzip format
#   - Corrupted data
#   - I/O errors during decompression
#
# Performance Notes:
#
# - Level 1 is ~5-10x faster than level 9
# - Level 6 offers the best speed/ratio balance
# - Higher levels have diminishing returns
# - Use level 1 for real-time compression
# - Use level 9 for archival storage
#
# Example: Compress log files
#
#   use "std/compress/gzip"
#   use "std/io"
#
#   let log_data = io.read("app.log")
#   let compressed = gzip.compress(log_data, 6)
#   io.write("app.log.gz", compressed)
#
#   let ratio = (1.0 - (compressed.len() / log_data.len())) * 100
#   puts("Compression ratio: " .. ratio .. "%")
#
# Example: Read compressed JSON
#
#   use "std/compress/gzip"
#   use "std/io"
#   use "std/encoding/json"
#
#   let compressed = io.read("data.json.gz").bytes()
#   let json_text = gzip.decompress(compressed).decode("utf-8")
#   let data = json.parse(json_text)
#   puts("Loaded " .. data.len() .. " records")
