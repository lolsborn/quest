# std/db/postgres - PostgreSQL database interface
#
# Conforms to QEP-001 Database API Specification

"""
PostgreSQL database module for Quest.

This module provides a QEP-001 compliant interface for PostgreSQL databases.

Example:
    use "std/db/postgres" as db

    let conn = db.connect("host=localhost port=6432 user=quest password=quest_password dbname=quest_test")
    let cursor = conn.cursor()
    cursor.execute("CREATE TABLE users (id SERIAL PRIMARY KEY, name TEXT)")
    cursor.execute("INSERT INTO users (name) VALUES ($1)", ["Alice"])
    conn.commit()
    conn.close()
"""

use "db/postgres" as postgres

# Module metadata
let api_level = "1.0"
let thread_safety = 1  # Threads may share module, not connections
let param_style = "numeric"  # Numeric positional style: WHERE id = $1

# Type objects for column type comparison
let STRING = "TEXT"
let BINARY = "BYTEA"
let NUMBER = "NUMERIC"
let DATETIME = "TIMESTAMP"
let ROWID = "OID"

# Main connection function
fun connect(connection_string)
    """
    Open a connection to a PostgreSQL database.

    Args:
        connection_string (str): Connection string with host, port, user, password, dbname

    Returns:
        Connection object

    Example:
        let conn = db.connect("host=localhost port=6432 user=quest password=quest_password dbname=quest_test")
    """
    postgres.connect(connection_string)
end
