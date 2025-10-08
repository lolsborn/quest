use std::collections::HashMap;
use crate::{arg_err, attr_err, value_err};
use std::sync::{Arc, Mutex};
use rusqlite::{Connection, Row, Statement, ToSql, types::ValueRef};
use crate::types::*;
use crate::scope::Scope;

/// Wrapper for SQLite Connection that implements QObj
#[derive(Debug, Clone)]
pub struct QSqliteConnection {
    conn: Arc<Mutex<Connection>>,
    id: u64,
}

impl QSqliteConnection {
    pub fn new(conn: Connection) -> Self {
        QSqliteConnection {
            conn: Arc::new(Mutex::new(conn)),
            id: next_object_id(),
        }
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        match method_name {
            "close" => {
                // Connection will be closed when dropped
                Ok(QValue::Nil(QNil))
            }

            "commit" => {
                let conn = self.conn.lock().unwrap();
                conn.execute_batch("COMMIT")
                    .map_err(|e| format!("DatabaseError: {}", e))?;
                Ok(QValue::Nil(QNil))
            }

            "rollback" => {
                let conn = self.conn.lock().unwrap();
                conn.execute_batch("ROLLBACK")
                    .map_err(|e| format!("DatabaseError: {}", e))?;
                Ok(QValue::Nil(QNil))
            }

            "cursor" => {
                Ok(QValue::SqliteCursor(QSqliteCursor::new(self.conn.clone())))
            }

            "execute" => {
                if args.is_empty() {
                    return Err("execute expects at least 1 argument (sql)".to_string());
                }
                let sql = args[0].as_str();
                let params = if args.len() > 1 {
                    Some(&args[1])
                } else {
                    None
                };

                let mut conn = self.conn.lock().unwrap();
                let count = execute_with_params(&mut conn, &sql, params)?;
                Ok(QValue::Int(QInt::new(count as i64)))
            }

            "_id" => Ok(QValue::Int(QInt::new(self.id as i64))),
            "str" => Ok(QValue::Str(QString::new(format!("<SqliteConnection {}>", self.id)))),
            "_rep" => Ok(QValue::Str(QString::new(format!("<SqliteConnection {}>", self.id)))),

            _ => attr_err!("Unknown method '{}' on SqliteConnection", method_name)
        }
    }
}

impl QObj for QSqliteConnection {
    fn cls(&self) -> String {
        "SqliteConnection".to_string()
    }

    fn q_type(&self) -> &'static str {
        "SqliteConnection"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "SqliteConnection"
    }

    fn str(&self) -> String {
        format!("<SqliteConnection {}>", self.id)
    }

    fn _rep(&self) -> String {
        format!("<SqliteConnection {}>", self.id)
    }

    fn _doc(&self) -> String {
        "SQLite database connection".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

/// Column description for cursor.description
#[derive(Debug, Clone)]
struct ColumnDescription {
    name: String,
    type_code: String,
}

/// Wrapper for SQLite cursor (statement + results)
#[derive(Debug, Clone)]
pub struct QSqliteCursor {
    conn: Arc<Mutex<Connection>>,
    current_results: Arc<Mutex<Vec<HashMap<String, QValue>>>>,
    position: Arc<Mutex<usize>>,
    row_count: Arc<Mutex<i64>>,
    description: Arc<Mutex<Option<Vec<ColumnDescription>>>>,
    id: u64,
}

impl QSqliteCursor {
    pub fn new(conn: Arc<Mutex<Connection>>) -> Self {
        QSqliteCursor {
            conn,
            current_results: Arc::new(Mutex::new(Vec::new())),
            position: Arc::new(Mutex::new(0)),
            row_count: Arc::new(Mutex::new(-1)),
            description: Arc::new(Mutex::new(None)),
            id: next_object_id(),
        }
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        match method_name {
            "execute" => {
                if args.is_empty() {
                    return Err("execute expects at least 1 argument (sql)".to_string());
                }
                let sql = args[0].as_str();
                let params = if args.len() > 1 {
                    Some(&args[1])
                } else {
                    None
                };

                self.execute_internal(&sql, params)?;
                Ok(QValue::Nil(QNil))
            }

            "execute_many" => {
                if args.len() != 2 {
                    return arg_err!("execute_many expects 2 arguments (sql, params_seq), got {}", args.len());
                }
                let sql = args[0].as_str();
                let params_seq = match &args[1] {
                    QValue::Array(arr) => arr,
                    _ => return Err("execute_many expects second argument to be an array".to_string()),
                };

                let mut total_count = 0;
                let elements = params_seq.elements.borrow();
                for params in elements.iter() {
                    let count = {
                        let mut conn = self.conn.lock().unwrap();
                        execute_with_params(&mut conn, &sql, Some(params))?
                    };
                    total_count += count;
                }

                *self.row_count.lock().unwrap() = total_count as i64;
                Ok(QValue::Nil(QNil))
            }

            "fetch_one" => {
                let mut pos = self.position.lock().unwrap();
                let results = self.current_results.lock().unwrap();

                if *pos < results.len() {
                    let row = results[*pos].clone();
                    *pos += 1;
                    Ok(QValue::Dict(Box::new(QDict::new(row))))
                } else {
                    Ok(QValue::Nil(QNil))
                }
            }

            "fetch_many" => {
                let size = if args.is_empty() {
                    10
                } else {
                    args[0].as_num()? as usize
                };

                let mut pos = self.position.lock().unwrap();
                let results = self.current_results.lock().unwrap();

                let end = std::cmp::min(*pos + size, results.len());
                let rows: Vec<QValue> = results[*pos..end]
                    .iter()
                    .map(|row| QValue::Dict(Box::new(QDict::new(row.clone()))))
                    .collect();

                *pos = end;
                Ok(QValue::Array(QArray::new(rows)))
            }

            "fetch_all" => {
                let mut pos = self.position.lock().unwrap();
                let results = self.current_results.lock().unwrap();

                let rows: Vec<QValue> = results[*pos..]
                    .iter()
                    .map(|row| QValue::Dict(Box::new(QDict::new(row.clone()))))
                    .collect();

                *pos = results.len();
                Ok(QValue::Array(QArray::new(rows)))
            }

            "close" => {
                // Clear results
                self.current_results.lock().unwrap().clear();
                *self.position.lock().unwrap() = 0;
                *self.row_count.lock().unwrap() = -1;
                *self.description.lock().unwrap() = None;
                Ok(QValue::Nil(QNil))
            }

            "description" => {
                let desc = self.description.lock().unwrap();
                match &*desc {
                    Some(columns) => {
                        let result: Vec<QValue> = columns.iter().map(|col| {
                            let mut map = HashMap::new();
                            map.insert("name".to_string(), QValue::Str(QString::new(col.name.clone())));
                            map.insert("type_code".to_string(), QValue::Str(QString::new(col.type_code.clone())));
                            map.insert("display_size".to_string(), QValue::Nil(QNil));
                            map.insert("internal_size".to_string(), QValue::Nil(QNil));
                            map.insert("precision".to_string(), QValue::Nil(QNil));
                            map.insert("scale".to_string(), QValue::Nil(QNil));
                            map.insert("null_ok".to_string(), QValue::Bool(QBool::new(true)));
                            QValue::Dict(Box::new(QDict::new(map)))
                        }).collect();
                        Ok(QValue::Array(QArray::new(result)))
                    }
                    None => Ok(QValue::Nil(QNil))
                }
            }

            "row_count" => {
                let count = *self.row_count.lock().unwrap();
                Ok(QValue::Int(QInt::new(count as i64)))
            }

            "_id" => Ok(QValue::Int(QInt::new(self.id as i64))),
            "str" => Ok(QValue::Str(QString::new(format!("<SqliteCursor {}>", self.id)))),
            "_rep" => Ok(QValue::Str(QString::new(format!("<SqliteCursor {}>", self.id)))),

            _ => attr_err!("Unknown method '{}' on SqliteCursor", method_name)
        }
    }

    fn execute_internal(&self, sql: &str, params: Option<&QValue>) -> Result<(), String> {
        let mut conn = self.conn.lock().unwrap();

        // Check if this is a SELECT query
        let is_query = sql.trim().to_uppercase().starts_with("SELECT");

        if is_query {
            // Execute query and fetch all results
            let mut stmt = conn.prepare(sql)
                .map_err(|e| format!("ProgrammingError: {}", e))?;

            // Get column names and types
            let column_count = stmt.column_count();
            let mut columns = Vec::new();
            for i in 0..column_count {
                let name = stmt.column_name(i)
                    .map_err(|e| format!("DatabaseError: {}", e))?
                    .to_string();
                columns.push(ColumnDescription {
                    name,
                    type_code: "TEXT".to_string(), // SQLite is dynamically typed
                });
            }

            // Execute and collect results
            let rows = if let Some(params_value) = params {
                query_with_params(&mut stmt, params_value, &columns)?
            } else {
                query_without_params(&mut stmt, &columns)?
            };

            let row_count = rows.len() as i64;

            // Store results
            *self.current_results.lock().unwrap() = rows;
            *self.position.lock().unwrap() = 0;
            *self.row_count.lock().unwrap() = row_count;
            *self.description.lock().unwrap() = Some(columns);
        } else {
            // Execute non-query statement
            let count = execute_with_params(&mut conn, sql, params)?;
            *self.row_count.lock().unwrap() = count as i64;
            *self.description.lock().unwrap() = None;
            *self.current_results.lock().unwrap() = Vec::new();
            *self.position.lock().unwrap() = 0;
        }

        Ok(())
    }
}

impl QObj for QSqliteCursor {
    fn cls(&self) -> String {
        "SqliteCursor".to_string()
    }

    fn q_type(&self) -> &'static str {
        "SqliteCursor"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "SqliteCursor"
    }

    fn str(&self) -> String {
        format!("<SqliteCursor {}>", self.id)
    }

    fn _rep(&self) -> String {
        format!("<SqliteCursor {}>", self.id)
    }

    fn _doc(&self) -> String {
        "SQLite database cursor".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

/// Convert QValue to SQLite parameter
fn qvalue_to_sql_param(value: &QValue) -> Result<Box<dyn ToSql>, String> {
    match value {
        QValue::Nil(_) => Ok(Box::new(rusqlite::types::Null)),
        QValue::Int(i) => Ok(Box::new(i.value)),
        QValue::Float(f) => Ok(Box::new(f.value)),
        QValue::Str(s) => Ok(Box::new(s.value.clone())),
        QValue::Bool(b) => Ok(Box::new(if b.value { 1i64 } else { 0i64 })),
        QValue::Bytes(b) => Ok(Box::new(b.data.clone())),
        _ => value_err!("Cannot convert {} to SQL parameter", value.q_type())
    }
}

/// Execute statement with parameters
fn execute_with_params(conn: &mut Connection, sql: &str, params: Option<&QValue>) -> Result<usize, String> {
    if let Some(params_value) = params {
        match params_value {
            QValue::Array(arr) => {
                // Positional parameters
                let elements = arr.elements.borrow();
                let sql_params: Result<Vec<Box<dyn ToSql>>, String> = elements.iter()
                    .map(qvalue_to_sql_param)
                    .collect();
                let sql_params = sql_params?;
                let params_refs: Vec<&dyn ToSql> = sql_params.iter()
                    .map(|p| p.as_ref())
                    .collect();

                conn.execute(sql, params_refs.as_slice())
                    .map_err(|e| map_sqlite_error(e))
            }
            QValue::Dict(dict) => {
                // Named parameters
                let mut stmt = conn.prepare(sql)
                    .map_err(|e| format!("ProgrammingError: {}", e))?;

                let mut named_params: Vec<(String, Box<dyn ToSql>)> = Vec::new();
                for (key, value) in dict.map.borrow().iter() {
                    let param_name = if key.starts_with(':') {
                        key.clone()
                    } else {
                        format!(":{}", key)
                    };
                    named_params.push((param_name, qvalue_to_sql_param(value)?));
                }

                // Convert to &str and &dyn ToSql
                let params_refs: Vec<(&str, &dyn ToSql)> = named_params.iter()
                    .map(|(name, value)| (name.as_str(), value.as_ref()))
                    .collect();

                stmt.execute(params_refs.as_slice())
                    .map_err(|e| map_sqlite_error(e))
            }
            _ => Err("Parameters must be an array or dict".to_string())
        }
    } else {
        conn.execute(sql, [])
            .map_err(|e| map_sqlite_error(e))
    }
}

/// Query with parameters and return rows
fn query_with_params(stmt: &mut Statement, params: &QValue, columns: &[ColumnDescription]) -> Result<Vec<HashMap<String, QValue>>, String> {
    match params {
        QValue::Array(arr) => {
            // Positional parameters
            let elements = arr.elements.borrow();
            let sql_params: Result<Vec<Box<dyn ToSql>>, String> = elements.iter()
                .map(qvalue_to_sql_param)
                .collect();
            let sql_params = sql_params?;
            let params_refs: Vec<&dyn ToSql> = sql_params.iter()
                .map(|p| p.as_ref())
                .collect();

            let mut rows_result = stmt.query(params_refs.as_slice())
                .map_err(|e| map_sqlite_error(e))?;

            let mut results = Vec::new();
            while let Some(row) = rows_result.next().map_err(|e| map_sqlite_error(e))? {
                results.push(row_to_dict(row, columns)?);
            }
            Ok(results)
        }
        QValue::Dict(dict) => {
            // Named parameters
            let mut named_params: Vec<(String, Box<dyn ToSql>)> = Vec::new();
            for (key, value) in dict.map.borrow().iter() {
                let param_name = if key.starts_with(':') {
                    key.clone()
                } else {
                    format!(":{}", key)
                };
                named_params.push((param_name, qvalue_to_sql_param(value)?));
            }

            let params_refs: Vec<(&str, &dyn ToSql)> = named_params.iter()
                .map(|(name, value)| (name.as_str(), value.as_ref()))
                .collect();

            let mut rows_result = stmt.query(params_refs.as_slice())
                .map_err(|e| map_sqlite_error(e))?;

            let mut results = Vec::new();
            while let Some(row) = rows_result.next().map_err(|e| map_sqlite_error(e))? {
                results.push(row_to_dict(row, columns)?);
            }
            Ok(results)
        }
        _ => Err("Parameters must be an array or dict".to_string())
    }
}

/// Query without parameters and return rows
fn query_without_params(stmt: &mut Statement, columns: &[ColumnDescription]) -> Result<Vec<HashMap<String, QValue>>, String> {
    let mut rows_result = stmt.query([])
        .map_err(|e| map_sqlite_error(e))?;

    let mut results = Vec::new();
    while let Some(row) = rows_result.next().map_err(|e| map_sqlite_error(e))? {
        results.push(row_to_dict(row, columns)?);
    }
    Ok(results)
}

/// Convert SQLite row to Quest dict
fn row_to_dict(row: &Row, columns: &[ColumnDescription]) -> Result<HashMap<String, QValue>, String> {
    let mut dict = HashMap::new();

    for (idx, col) in columns.iter().enumerate() {
        let value = match row.get_ref(idx).map_err(|e| format!("DatabaseError: {}", e))? {
            ValueRef::Null => QValue::Nil(QNil),
            ValueRef::Integer(i) => QValue::Int(QInt::new(i)),
            ValueRef::Real(f) => QValue::Float(QFloat::new(f)),
            ValueRef::Text(s) => {
                let string = String::from_utf8(s.to_vec())
                    .map_err(|e| format!("UTF-8 error: {}", e))?;
                QValue::Str(QString::new(string))
            }
            ValueRef::Blob(b) => QValue::Bytes(QBytes::new(b.to_vec())),
        };
        dict.insert(col.name.clone(), value);
    }

    Ok(dict)
}

/// Map rusqlite errors to QEP-001 exception hierarchy
fn map_sqlite_error(err: rusqlite::Error) -> String {
    match err {
        rusqlite::Error::SqliteFailure(err, msg) => {
            match err.extended_code {
                19 => format!("IntegrityError: {}", msg.unwrap_or_else(|| "Constraint violation".to_string())),
                5 => format!("OperationalError: Database is locked"),
                _ => format!("DatabaseError: {}", msg.unwrap_or_else(|| err.to_string()))
            }
        }
        rusqlite::Error::InvalidQuery => {
            format!("ProgrammingError: Invalid SQL query")
        }
        rusqlite::Error::ExecuteReturnedResults => {
            format!("ProgrammingError: Execute returned results (use query instead)")
        }
        rusqlite::Error::QueryReturnedNoRows => {
            format!("DataError: Query returned no rows")
        }
        _ => format!("DatabaseError: {}", err)
    }
}

/// Create the sqlite module
pub fn create_sqlite_module() -> QValue {
    let mut members = HashMap::new();

    // Add module functions
    members.insert("connect".to_string(), QValue::Fun(QFun {
        name: "connect".to_string(),
        parent_type: "sqlite".to_string(),
        id: next_object_id(),
    }));

    members.insert("version".to_string(), QValue::Fun(QFun {
        name: "version".to_string(),
        parent_type: "sqlite".to_string(),
        id: next_object_id(),
    }));

    QValue::Module(Box::new(QModule::new("sqlite".to_string(), members)))
}

/// Call sqlite module functions
pub fn call_sqlite_function(func_name: &str, args: Vec<QValue>, _scope: &mut Scope) -> Result<QValue, String> {
    match func_name {
        "sqlite.connect" => {
            if args.len() != 1 {
                return arg_err!("sqlite.connect expects 1 argument (path), got {}", args.len());
            }
            let path = args[0].as_str();

            let conn = Connection::open(&path)
                .map_err(|e| format!("DatabaseError: Failed to open database: {}", e))?;

            Ok(QValue::SqliteConnection(QSqliteConnection::new(conn)))
        }

        "sqlite.version" => {
            if !args.is_empty() {
                return arg_err!("sqlite.version expects 0 arguments, got {}", args.len());
            }
            let version = rusqlite::version();
            Ok(QValue::Str(QString::new(version.to_string())))
        }

        _ => attr_err!("Unknown function: {}", func_name)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_connect_memory() {
        let mut scope = Scope::new();
        let result = call_sqlite_function(
            "sqlite.connect",
            vec![QValue::Str(QString::new(":memory:".to_string()))],
            &mut scope
        );
        assert!(result.is_ok());
        match result.unwrap() {
            QValue::SqliteConnection(_) => {},
            _ => panic!("Expected SqliteConnection"),
        }
    }

    #[test]
    fn test_version() {
        let mut scope = Scope::new();
        let result = call_sqlite_function("sqlite.version", vec![], &mut scope);
        assert!(result.is_ok());
        match result.unwrap() {
            QValue::Str(s) => {
                assert!(!s.value.is_empty());
            },
            _ => panic!("Expected string version"),
        }
    }

    #[test]
    fn test_create_table() {
        let mut scope = Scope::new();
        let conn_result = call_sqlite_function(
            "sqlite.connect",
            vec![QValue::Str(QString::new(":memory:".to_string()))],
            &mut scope
        );
        assert!(conn_result.is_ok());

        if let QValue::SqliteConnection(conn) = conn_result.unwrap() {
            let cursor_result = conn.call_method("cursor", vec![]);
            assert!(cursor_result.is_ok());

            if let QValue::SqliteCursor(cursor) = cursor_result.unwrap() {
                let sql = "CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)";
                let result = cursor.call_method(
                    "execute",
                    vec![QValue::Str(QString::new(sql.to_string()))]
                );
                assert!(result.is_ok());
            }
        }
    }

    #[test]
    fn test_insert_and_query() {
        let mut scope = Scope::new();
        let conn_result = call_sqlite_function(
            "sqlite.connect",
            vec![QValue::Str(QString::new(":memory:".to_string()))],
            &mut scope
        );

        if let QValue::SqliteConnection(conn) = conn_result.unwrap() {
            if let QValue::SqliteCursor(cursor) = conn.call_method("cursor", vec![]).unwrap() {
                // Create table
                cursor.call_method(
                    "execute",
                    vec![QValue::Str(QString::new("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)".to_string()))]
                ).unwrap();

                // Insert with positional params
                cursor.call_method(
                    "execute",
                    vec![
                        QValue::Str(QString::new("INSERT INTO users (name) VALUES (?)".to_string())),
                        QValue::Array(QArray::new(vec![QValue::Str(QString::new("Alice".to_string()))]))
                    ]
                ).unwrap();

                // Query
                cursor.call_method(
                    "execute",
                    vec![QValue::Str(QString::new("SELECT * FROM users".to_string()))]
                ).unwrap();

                let rows_result = cursor.call_method("fetch_all", vec![]);
                assert!(rows_result.is_ok());

                if let QValue::Array(rows) = rows_result.unwrap() {
                    assert_eq!(rows.elements.borrow().len(), 1);
                }
            }
        }
    }
}
