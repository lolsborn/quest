# std/db/mysql - MySQL database interface
#
# Conforms to QEP-001 Database API Specification

"""
MySQL database module for Quest.

This module provides a QEP-001 compliant interface for MySQL databases.

Example:
    use "std/db/mysql" as db

    let conn = db.connect("mysql://quest:quest_password@localhost:6603/quest_test")
    let cursor = conn.cursor()
    cursor.execute("CREATE TABLE users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255))")
    cursor.execute("INSERT INTO users (name) VALUES (?)", ["Alice"])
    conn.commit()
    conn.close()
"""

use "db/mysql" as mysql

# Module metadata
let api_level = "1.0"
let thread_safety = 1  # Threads may share module, not connections
let param_style = "qmark"  # Question mark style: WHERE id = ?

# Type objects for column type comparison
let STRING = "VARCHAR"
let BINARY = "BLOB"
let NUMBER = "INT"
let DATETIME = "DATETIME"
let ROWID = "BIGINT"

# Main connection function
fun connect(connection_string)
    """
    Open a connection to a MySQL database.

    Args:
        connection_string (str): Connection string in format mysql://user:password@host:port/database

    Returns:
        Connection object

    Example:
        let conn = db.connect("mysql://quest:quest_password@localhost:6603/quest_test")
    """
    mysql.connect(connection_string)
end
