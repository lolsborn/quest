# std/db/sqlite - SQLite database interface
#
# Conforms to QEP-001 Database API Specification

"""
SQLite database module for Quest.

This module provides a QEP-001 compliant interface for SQLite databases.

Example:
    use "std/db/sqlite" as db

    let conn = db.connect("test.db")
    let cursor = conn.cursor()
    cursor.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
    cursor.execute("INSERT INTO users (name) VALUES (?)", ["Alice"])
    conn.commit()
    conn.close()
"""

use "db/sqlite" as sqlite

# Module metadata
let api_level = "1.0"
let thread_safety = 1  # Threads may share module, not connections
let param_style = "qmark"  # Question mark style: WHERE id = ?

# Type objects for column type comparison
let STRING = "TEXT"
let BINARY = "BLOB"
let NUMBER = "NUMBER"
let DATETIME = "DATETIME"
let ROWID = "ROWID"

# Main connection function
fun connect(path)
    """
    Open a connection to an SQLite database.

    Args:
        path (str): Path to the database file. Use ":memory:" for in-memory database.

    Returns:
        Connection object

    Example:
        let conn = db.connect("mydb.sqlite")
        let mem_db = db.connect(":memory:")
    """
    sqlite.connect(path)
end

# Get SQLite version
fun version()
    """
    Get the SQLite library version.

    Returns:
        str: SQLite version string

    Example:
        puts("SQLite version: " .. db.version())
    """
    sqlite.version()
end
