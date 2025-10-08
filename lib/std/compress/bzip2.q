# std/compress/bzip2 - Bzip2 Compression and Decompression
#
# This module provides bzip2 compression and decompression functionality using
# the bzip2 format, which offers better compression ratios than gzip.
#
# Common use cases:
# - Creating .bz2 files
# - Compressing tar archives (.tar.bz2)
# - Better compression ratio for text files
# - Archival and backups
#
# Usage:
#   use "std/compress/bzip2"
#
#   # Compress data
#   let compressed = bzip2.compress("Hello World!")
#
#   # Decompress data
#   let decompressed = bzip2.decompress(compressed)
#   let text = decompressed.decode("utf-8")
#
#   # Compress with specific level
#   let compressed = bzip2.compress(data, 9)  # Max compression
#
# Available functions:
#
# bzip2.compress(data, level?) -> Bytes
#   Compress data using bzip2 format.
#
#   Parameters:
#     data (Str or Bytes) - Data to compress
#     level (Int, optional) - Compression level 1-9 (default: 6)
#       1 = Fastest (least compression)
#       6 = Default (balanced)
#       9 = Best compression (slowest)
#
#   Returns: Compressed data as Bytes
#
#   Example:
#     use "std/compress/bzip2"
#     let data = "Hello World! " * 100
#     let compressed = bzip2.compress(data)
#     puts("Original: " .. data.len() .. " bytes")
#     puts("Compressed: " .. compressed.len() .. " bytes")
#
# bzip2.decompress(data) -> Bytes
#   Decompress bzip2 data.
#
#   Parameters:
#     data (Bytes) - Bzip2 compressed data
#
#   Returns: Decompressed data as Bytes
#
#   Example:
#     use "std/compress/bzip2"
#     use "std/io"
#
#     # Read compressed file
#     let compressed = io.read("file.txt.bz2").bytes()
#     let decompressed = bzip2.decompress(compressed)
#     let text = decompressed.decode("utf-8")
#     puts(text)
#
# Compression Levels:
#
# Level 1: Minimal compression (100KB blocks)
#   - Fastest
#   - Lower memory usage
#   - ~65% size reduction (typical)
#
# Level 6: Default compression (600KB blocks)
#   - Balanced speed/ratio
#   - Good for most use cases
#   - ~80% size reduction (typical)
#
# Level 9: Maximum compression (900KB blocks)
#   - Slowest
#   - Highest memory usage
#   - ~85% size reduction (typical)
#   - Best for archival and backups
#
# Comparison with gzip:
#
# - Better compression ratio (typically 10-15% smaller)
# - Slower compression and decompression
# - Higher memory usage
# - Best for archival and backups
# - Use gzip for real-time or streaming compression
#
# Error Handling:
#
# compress() errors:
#   - Invalid compression level (must be 1-9)
#   - I/O errors during compression
#
# decompress() errors:
#   - Invalid bzip2 format
#   - Corrupted data
#   - I/O errors during decompression
#
# Performance Notes:
#
# - Level 1 is ~3-5x faster than level 9
# - Level 6 offers the best speed/ratio balance
# - Higher levels provide better compression but slower speed
# - Memory usage scales with compression level
#
# Example: Compress log files for archival
#
#   use "std/compress/bzip2"
#   use "std/io"
#
#   let log_data = io.read("app.log")
#   let compressed = bzip2.compress(log_data, 9)
#   io.write("app.log.bz2", compressed)
#
#   let ratio = (1.0 - (compressed.len().to_f64() / log_data.len().to_f64())) * 100.0
#   puts("Compression ratio: " .. ratio.str() .. "%")
#
# Example: Read compressed JSON
#
#   use "std/compress/bzip2"
#   use "std/io"
#   use "std/encoding/json"
#
#   let compressed = io.read("data.json.bz2").bytes()
#   let json_text = bzip2.decompress(compressed).decode("utf-8")
#   let data = json.parse(json_text)
