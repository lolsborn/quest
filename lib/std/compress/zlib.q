# std/compress/zlib - Zlib Compression and Decompression
#
# This module provides zlib compression and decompression (deflate with checksums).
# Zlib adds minimal headers and Adler-32 checksums to deflate compression.
#
# Common use cases:
# - PNG image compression
# - PDF document compression
# - Data integrity with compression
# - Network protocols (HTTP, SSH, etc.)
#
# Usage:
#   use "std/compress/zlib"
#
#   # Compress data
#   let compressed = zlib.compress("Hello World!")
#
#   # Decompress data
#   let decompressed = zlib.decompress(compressed)
#   let text = decompressed.decode("utf-8")
#
#   # Compress with specific level
#   let compressed = zlib.compress(data, 9)  # Max compression
#
# Available functions:
#
# zlib.compress(data, level?) -> Bytes
#   Compress data using zlib format (deflate + checksums).
#
#   Parameters:
#     data (Str or Bytes) - Data to compress
#     level (Int, optional) - Compression level 0-9 (default: 6)
#       0 = No compression (fastest)
#       1 = Best speed
#       6 = Default (balanced)
#       9 = Best compression (slowest)
#
#   Returns: Compressed data as Bytes (with zlib headers and Adler-32 checksum)
#
#   Example:
#     use "std/compress/zlib"
#     let data = "Hello World! " * 100
#     let compressed = zlib.compress(data)
#     puts("Original: " .. data.len() .. " bytes")
#     puts("Compressed: " .. compressed.len() .. " bytes")
#
# zlib.decompress(data) -> Bytes
#   Decompress zlib data (verifies checksum).
#
#   Parameters:
#     data (Bytes) - Zlib compressed data
#
#   Returns: Decompressed data as Bytes
#
#   Raises: Error if checksum verification fails
#
#   Example:
#     use "std/compress/zlib"
#
#     let compressed = zlib.compress("Test data")
#     let decompressed = zlib.decompress(compressed)
#     let text = decompressed.decode("utf-8")
#     puts(text)
#
# When to use zlib vs gzip vs deflate:
#
# Use zlib when:
#   - Need data integrity verification (Adler-32 checksum)
#   - Working with PNG files, PDF, Git, etc.
#   - Want compact headers (smaller than gzip)
#   - Network protocols need checksum
#
# Use gzip when:
#   - Working with .gz files
#   - HTTP compression
#   - Need filename, timestamp, CRC32 checksum
#   - Standard file compression
#
# Use deflate when:
#   - Need raw compressed data
#   - Building custom protocols
#   - Minimizing overhead (no headers/checksums)
#
# Format Details:
#
# Zlib format:
#   - 2-byte header (compression method and flags)
#   - Deflate compressed data
#   - 4-byte Adler-32 checksum at end
#   - Total overhead: 6 bytes
#
# Gzip format:
#   - 10-byte header (with optional extra fields)
#   - Deflate compressed data
#   - 8-byte footer (CRC32 + size)
#   - Total overhead: ~18 bytes
#
# Deflate format:
#   - Raw compressed data
#   - No headers or checksums
#   - Total overhead: 0 bytes
#
# Compression Levels:
#
# Level 0: No compression
#   - Fastest
#   - Only adds zlib header and checksum
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
#   - Invalid zlib format
#   - Corrupted data
#   - Checksum verification failure
#   - I/O errors during decompression
#
# Performance Notes:
#
# - Slightly slower than deflate (checksum calculation)
# - Faster than gzip (smaller headers)
# - Best balance of speed, size, and integrity
# - Adler-32 is faster than CRC32
#
# Example: Compress with integrity check
#
#   use "std/compress/zlib"
#
#   let data = "Important data that needs verification"
#   let compressed = zlib.compress(data, 9)
#
#   # Later, decompress with automatic checksum verification
#   try
#       let decompressed = zlib.decompress(compressed)
#       puts("Data integrity verified!")
#   catch e
#       puts("Checksum failed - data corrupted!")
#   end
#
# Example: Network protocol with zlib
#
#   use "std/compress/zlib"
#
#   # Compress payload for network transmission
#   let payload = "Network data"
#   let compressed = zlib.compress(payload, 6)
#
#   # Send compressed data
#   # Receiver decompresses and zlib verifies integrity automatically
