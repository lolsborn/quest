# Standard Library Comparison: Quest vs Python vs Ruby

**Last Updated:** 2025-10-05

This document compares Quest's standard library features with Python and Ruby to help developers understand feature parity and differences.

## Legend

- ✅ **Fully Implemented** - Feature complete and tested
- 🟡 **Partial** - Some functionality available, but incomplete
- ❌ **Not Implemented** - Feature not available
- 🎯 **Planned** - Specified but not yet implemented (see QEPs)

---

## Core Data Structures

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| **Arrays/Lists** | ✅ | ✅ | ✅ | Quest: 40+ methods, mutable |
| **Dictionaries/Hashes** | ✅ | ✅ | ✅ | Quest: Full CRUD + iteration |
| **Sets** | ✅ | ✅ | ✅ | Quest: Basic set operations |
| **Tuples** | ❌ | ✅ | ❌ | Ruby uses arrays |
| **Ranges** | 🟡 | ✅ | ✅ | Quest: Basic range support in loops |
| **Deques** | ❌ | ✅ | ❌ | Python: collections.deque |
| **Ordered Dictionaries** | ✅ | ✅ | ✅ | Quest: Insertion order preserved |
| **Frozen Sets** | ❌ | ✅ | ❌ | - |

---

## String Operations

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| **String Methods** | ✅ | ✅ | ✅ | Quest: 30+ methods |
| **String Interpolation** | 🟡 | ✅ | ✅ | Quest: Use concat (..) |
| **String Encoding** | ✅ | ✅ | ✅ | Quest: UTF-8, hex, base64 |
| **Regular Expressions** | ✅ | ✅ | ✅ | Quest: match, replace, split |
| **String Formatting** | 🟡 | ✅ | ✅ | Quest: No format strings yet |
| **Template Strings** | ✅ | 🟡 | ✅ | Quest: HTML templates (Tera) |
| **Multiline Strings** | ✅ | ✅ | ✅ | All support multiline |

---

## Numeric Operations

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| **Integers** | ✅ | ✅ | ✅ | Quest: 64-bit with overflow checking |
| **Floats** | ✅ | ✅ | ✅ | Quest: 64-bit IEEE 754 |
| **Decimals** | ✅ | ✅ | ✅ | Quest: Arbitrary precision (rust_decimal) |
| **Complex Numbers** | ❌ | ✅ | ✅ | - |
| **Fractions/Rationals** | ❌ | ✅ | ✅ | - |
| **Math Functions** | ✅ | ✅ | ✅ | Quest: Trig, rounding, constants |
| **Random Numbers** | ✅ | ✅ | ✅ | Quest: RNG with multiple algorithms |
| **BigInt** | ❌ | ✅ | ✅ | Quest: Uses i64 |

---

## File I/O

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| **Read/Write Files** | ✅ | ✅ | ✅ | Basic operations covered |
| **File Handles** | 🟡 | ✅ | ✅ | Quest: Limited file handle support |
| **Binary I/O** | ✅ | ✅ | ✅ | Quest: Bytes type |
| **StringIO** | ✅ | ✅ | ✅ | Quest: Full implementation (QEP-009) |
| **BytesIO** | 🎯 | ✅ | ✅ | Quest: Planned (QEP-009 Phase 2) |
| **Context Managers** | ✅ | ✅ | ✅ | Quest: with statement (QEP-011) |
| **File Metadata** | ✅ | ✅ | ✅ | Quest: exists, size, is_file, is_dir |
| **Glob Patterns** | ✅ | ✅ | ✅ | Quest: glob, glob_match |
| **Temporary Files** | ❌ | ✅ | ✅ | - |

---

## Networking

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| **HTTP Client** | ✅ | ✅ | ✅ | Quest: Full REST client |
| **HTTP Server** | ❌ | ✅ | ✅ | - |
| **WebSockets** | ❌ | ✅ | ✅ | - |
| **TCP Sockets** | ❌ | ✅ | ✅ | - |
| **UDP Sockets** | ❌ | ✅ | ✅ | - |
| **URL Parsing** | ✅ | ✅ | ✅ | Quest: urlparse module |
| **URL Encoding** | ✅ | ✅ | ✅ | Quest: quote, unquote |
| **DNS** | ❌ | ✅ | ✅ | - |

---

## Data Serialization

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| **JSON** | ✅ | ✅ | ✅ | Quest: parse, stringify |
| **Base64** | ✅ | ✅ | ✅ | Quest: encode, decode, URL-safe |
| **CSV** | ✅ | ✅ | ✅ | Quest: Basic CSV module |
| **XML** | ❌ | ✅ | ✅ | - |
| **YAML** | ❌ | ✅ | ✅ | - |
| **TOML** | ✅ | 🟡 | 🟡 | Quest: settings.toml parsing |
| **MessagePack** | ❌ | ✅ | ✅ | - |
| **Pickle/Marshal** | ❌ | ✅ | ✅ | - |

---

## Compression

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| **GZIP** | ✅ | ✅ | ✅ | Quest: Compress/decompress |
| **BZIP2** | ✅ | ✅ | ✅ | Quest: Full support |
| **DEFLATE** | ✅ | ✅ | ✅ | Quest: Raw deflate |
| **ZLIB** | ✅ | ✅ | ✅ | Quest: With headers |
| **ZIP Archives** | ❌ | ✅ | ✅ | - |
| **TAR Archives** | ❌ | ✅ | ✅ | - |
| **LZ4** | ❌ | ✅ | ✅ | - |

---

## Cryptography & Hashing

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| **MD5** | ✅ | ✅ | ✅ | Quest: hash.md5() |
| **SHA1** | ✅ | ✅ | ✅ | Quest: hash.sha1() |
| **SHA256** | ✅ | ✅ | ✅ | Quest: hash.sha256() |
| **SHA512** | ✅ | ✅ | ✅ | Quest: hash.sha512() |
| **CRC32** | ✅ | ✅ | ✅ | Quest: hash.crc32() |
| **HMAC** | ✅ | ✅ | ✅ | Quest: crypto.hmac_sha256/512 |
| **bcrypt** | ✅ | ✅ | ✅ | Quest: hash.bcrypt() |
| **SSL/TLS** | ❌ | ✅ | ✅ | - |
| **RSA** | ❌ | ✅ | ✅ | - |
| **AES** | ❌ | ✅ | ✅ | - |

---

## Date & Time

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| **Timestamps** | ✅ | ✅ | ✅ | Quest: Unix timestamps |
| **Dates** | ✅ | ✅ | ✅ | Quest: Date type |
| **Times** | ✅ | ✅ | ✅ | Quest: Time type |
| **Timezones** | ✅ | ✅ | ✅ | Quest: Zoned datetime |
| **Durations/Spans** | ✅ | ✅ | ✅ | Quest: Span type |
| **Date Ranges** | ✅ | 🟡 | 🟡 | Quest: DateRange type |
| **Parsing** | ✅ | ✅ | ✅ | Quest: ISO 8601, RFC 3339 |
| **Formatting** | ✅ | ✅ | ✅ | Quest: strftime-like |
| **Arithmetic** | ✅ | ✅ | ✅ | Quest: Add/subtract spans |

---

## Database

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| **SQLite** | ✅ | ✅ | ✅ | Quest: Full DB-API 2.0 compliance |
| **PostgreSQL** | ✅ | ✅ | ✅ | Quest: Full support + UUID/Decimal |
| **MySQL** | ✅ | ✅ | ✅ | Quest: Full support + UUID handling |
| **MongoDB** | ❌ | ✅ | ✅ | - |
| **Redis** | ❌ | ✅ | ✅ | - |
| **ORM** | ❌ | ✅ | ✅ | Python: SQLAlchemy, Ruby: ActiveRecord |
| **Migrations** | ❌ | ✅ | ✅ | - |
| **Connection Pooling** | 🟡 | ✅ | ✅ | Quest: Manual management |

---

## Testing

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| **Test Framework** | ✅ | ✅ | ✅ | Quest: describe/it pattern |
| **Assertions** | ✅ | ✅ | ✅ | Quest: 10+ assertion types |
| **Test Discovery** | ✅ | ✅ | ✅ | Quest: Automatic file discovery |
| **Test Tags** | ✅ | 🟡 | 🟡 | Quest: Tag-based filtering |
| **Mocking** | ❌ | ✅ | ✅ | - |
| **Fixtures** | 🟡 | ✅ | ✅ | Quest: Manual setup/teardown |
| **Code Coverage** | ❌ | ✅ | ✅ | - |
| **Benchmarking** | 🟡 | ✅ | ✅ | Quest: ticks_ms() available |

---

## Logging

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| **Logging Framework** | ✅ | ✅ | ✅ | Quest: Python-inspired (QEP-004) |
| **Log Levels** | ✅ | ✅ | ✅ | Quest: DEBUG, INFO, WARN, ERROR, CRITICAL |
| **Handlers** | ✅ | ✅ | ✅ | Quest: Stream, File handlers |
| **Formatters** | ✅ | ✅ | ✅ | Quest: Custom format strings |
| **Filters** | ✅ | ✅ | ✅ | Quest: Logger name filtering |
| **Hierarchical Loggers** | ✅ | ✅ | ✅ | Quest: Full hierarchy support |
| **Colored Output** | ✅ | 🟡 | 🟡 | Quest: Built-in color support |
| **Rotating Logs** | ❌ | ✅ | ✅ | - |

---

## Operating System

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| **Environment Variables** | ✅ | ✅ | ✅ | Quest: getenv, setenv, unsetenv |
| **Process Management** | 🟡 | ✅ | ✅ | Quest: sys.exit() only |
| **Working Directory** | ✅ | ✅ | ✅ | Quest: getcwd, chdir |
| **Directory Listing** | ✅ | ✅ | ✅ | Quest: listdir |
| **File Operations** | ✅ | ✅ | ✅ | Quest: remove, rename, mkdir |
| **Path Manipulation** | ✅ | ✅ | ✅ | Quest: Via io module |
| **System Info** | ✅ | ✅ | ✅ | Quest: sys.platform, sys.version |
| **Shell Commands** | ❌ | ✅ | ✅ | - |
| **Signals** | ❌ | ✅ | ✅ | - |

---

## Concurrency

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| **Threads** | ❌ | ✅ | ✅ | - |
| **Async/Await** | ❌ | ✅ | 🟡 | Python: asyncio, Ruby: Fiber |
| **Coroutines** | ❌ | ✅ | ✅ | - |
| **Event Loop** | ❌ | ✅ | ✅ | - |
| **Thread Pools** | ❌ | ✅ | ✅ | - |
| **Locks/Semaphores** | ❌ | ✅ | ✅ | - |
| **Queues** | ❌ | ✅ | ✅ | - |

---

## Web Development

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| **HTTP Client** | ✅ | ✅ | ✅ | Quest: Full REST client |
| **HTML Templates** | ✅ | ✅ | ✅ | Quest: Tera (Jinja2-like) |
| **URL Routing** | ❌ | ✅ | ✅ | - |
| **Forms** | ❌ | ✅ | ✅ | - |
| **Sessions** | ❌ | ✅ | ✅ | - |
| **Cookies** | 🟡 | ✅ | ✅ | Quest: HTTP client can read cookies |
| **WebSockets** | ❌ | ✅ | ✅ | - |
| **Web Framework** | ❌ | ✅ | ✅ | Python: Flask/Django, Ruby: Rails |

---

## Hardware/IoT

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| **Serial Port** | ✅ | ✅ | ✅ | Quest: Full serial communication |
| **GPIO** | ❌ | ✅ | ✅ | Python: RPi.GPIO |
| **I2C** | ❌ | ✅ | ✅ | - |
| **SPI** | ❌ | ✅ | ✅ | - |
| **USB** | ❌ | ✅ | ✅ | - |
| **Bluetooth** | ❌ | ✅ | 🟡 | - |

---

## Data Science (Not Core Focus)

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| **NumPy-like** | ❌ | ✅ | 🟡 | - |
| **DataFrames** | ❌ | ✅ | 🟡 | Python: pandas |
| **Plotting** | ❌ | ✅ | ✅ | - |
| **Machine Learning** | ❌ | ✅ | 🟡 | - |
| **Statistics** | 🟡 | ✅ | ✅ | Quest: Basic math only |

---

## Unique Quest Features

Features that Quest has that Python/Ruby don't (or handle differently):

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| **Type System** | ✅ | 🟡 | 🟡 | Quest: Rust-inspired types, traits |
| **Trait System** | ✅ | 🟡 | 🟡 | Quest: Explicit trait implementation |
| **UUID Built-in** | ✅ | 🟡 | 🟡 | Quest: First-class UUID type |
| **Decimal Built-in** | ✅ | ✅ | ✅ | Quest: Native Decimal type |
| **Bytes Type** | ✅ | ✅ | 🟡 | Quest: Distinct from strings |
| **Set Type** | ✅ | ✅ | ✅ | Quest: Basic operations |
| **Exception Stack Traces** | ✅ | ✅ | ✅ | Quest: Full stack capture |
| **Module Search Path** | ✅ | ✅ | ✅ | Quest: QUEST_INCLUDE env var |

---

## Summary Statistics

### Overall Coverage

| Category | Quest Coverage | Notes |
|----------|---------------|-------|
| **Core Data Structures** | 🟢 85% | Arrays, dicts, sets well-covered |
| **String Operations** | 🟢 80% | Good coverage, missing format strings |
| **Numeric Operations** | 🟡 70% | Missing complex numbers, BigInt |
| **File I/O** | 🟢 75% | StringIO complete, limited file handles |
| **Networking** | 🟡 40% | HTTP client only, no server |
| **Data Serialization** | 🟡 60% | JSON, Base64, CSV; missing XML, YAML |
| **Compression** | 🟢 100% | All major formats covered |
| **Cryptography** | 🟡 60% | Hashing complete, missing encryption |
| **Date & Time** | 🟢 90% | Comprehensive datetime support |
| **Database** | 🟢 85% | SQLite, Postgres, MySQL covered |
| **Testing** | 🟢 85% | Full framework, missing mocking |
| **Logging** | 🟢 90% | Python-compatible logging system |
| **OS Operations** | 🟡 60% | File ops good, missing process management |
| **Concurrency** | 🔴 0% | Not implemented |
| **Web Development** | 🟡 35% | HTTP client + templates only |
| **Hardware/IoT** | 🟡 20% | Serial port only |

### Quest Strengths

1. ✅ **Database connectivity** - SQLite, PostgreSQL, MySQL with full type support
2. ✅ **Date/time handling** - Comprehensive timezone-aware datetime library
3. ✅ **Type system** - Rust-inspired types and traits
4. ✅ **Testing** - Modern describe/it framework with tags
5. ✅ **HTTP client** - Full REST client with connection pooling
6. ✅ **Compression** - All major formats (gzip, bzip2, deflate, zlib)
7. ✅ **Logging** - Python-compatible hierarchical logging
8. ✅ **UUID** - First-class UUID type with all versions
9. ✅ **StringIO** - Full in-memory buffer with context manager support
10. ✅ **HTML templates** - Tera (Jinja2-like) templating

### Areas for Growth

1. ❌ **Concurrency** - No threading, async/await, or event loop
2. ❌ **Web server** - Only HTTP client, no server framework
3. ❌ **Process management** - Limited to sys.exit()
4. ❌ **XML/YAML** - Missing common serialization formats
5. ❌ **Encryption** - Only hashing, no AES/RSA
6. ❌ **Mocking** - Testing framework lacks mocking support
7. ❌ **Archive formats** - No ZIP/TAR support
8. ❌ **ORM** - Direct SQL only, no object-relational mapping
9. ❌ **WebSockets** - No bidirectional communication
10. ❌ **Data science** - Not a focus area

---

## Conclusion

**Quest's standard library is production-ready for:**
- Database-driven applications (SQLite, PostgreSQL, MySQL)
- REST API clients (HTTP + JSON)
- CLI tools with file I/O and text processing
- IoT/hardware projects (serial communication)
- Testing and logging infrastructure
- Data compression and hashing
- Datetime-heavy applications

**Quest needs additional development for:**
- Web servers and frameworks
- Concurrent/parallel programming
- Real-time applications (WebSockets)
- Data science workflows
- Complex cryptography
- Process orchestration

**Quest's unique value proposition:**
- Strong type system with traits (Rust-inspired)
- Excellent database support with type safety
- Modern testing framework
- First-class datetime and UUID handling
- Focus on developer happiness and clarity
