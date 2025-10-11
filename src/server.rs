use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::{Arc, RwLock};
use std::cell::RefCell;
use axum::{
    Router,
    extract::{State, Request},
    response::IntoResponse,
    http::{StatusCode, HeaderMap, header},
    body::{Body, to_bytes},
};
use axum::response::Response;
use axum::routing::any;
use hyper::body::Bytes;
use tokio::sync::mpsc;
use tower_http::trace::TraceLayer;

use crate::scope::Scope;
use crate::types::{QValue, QDict, QString};
use pest::Parser;

// Helper to create error responses (reserved for future use)
#[allow(dead_code)]
fn error_response(status: StatusCode, message: impl Into<String>) -> Response<Body> {
    Response::builder()
        .status(status)
        .body(Body::from(message.into()))
        .unwrap()
}

/// Server configuration
#[derive(Clone)]
pub struct ServerConfig {
    pub host: String,
    pub port: u16,
    pub script_source: String,
    pub script_path: String,
}

// Thread-local storage for Quest Scope
// Each worker thread gets its own Scope initialized once
thread_local! {
    static QUEST_SCOPE: RefCell<Option<Scope>> = RefCell::new(None);
}

/// WebSocket connection registry for broadcasting (Phase 2)
#[derive(Clone)]
pub struct WebSocketRegistry {
    connections: Arc<RwLock<HashMap<String, Vec<WebSocketConnection>>>>,
}

#[derive(Clone)]
struct WebSocketConnection {
    id: String,
    #[allow(dead_code)]
    path: String,
    sender: mpsc::UnboundedSender<axum::extract::ws::Message>,
}

impl WebSocketRegistry {
    pub fn new() -> Self {
        Self {
            connections: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    #[allow(dead_code)]
    pub fn register(&self, path: &str, id: &str, sender: mpsc::UnboundedSender<axum::extract::ws::Message>) {
        let mut conns = self.connections.write().unwrap();
        let conn = WebSocketConnection {
            id: id.to_string(),
            path: path.to_string(),
            sender,
        };
        conns.entry(path.to_string()).or_insert_with(Vec::new).push(conn);
    }

    #[allow(dead_code)]
    pub fn unregister(&self, id: &str) {
        let mut conns = self.connections.write().unwrap();
        for (_path, connections) in conns.iter_mut() {
            connections.retain(|c| c.id != id);
        }
    }

    #[allow(dead_code)]
    pub fn broadcast(&self, path: &str, message: &str) {
        let conns = self.connections.read().unwrap();
        if let Some(connections) = conns.get(path) {
            for conn in connections {
                let _ = conn.sender.send(axum::extract::ws::Message::Text(message.to_string()));
            }
        }
    }
}

/// Application state shared across handlers
#[derive(Clone)]
struct AppState {
    config: Arc<ServerConfig>,
    #[allow(dead_code)]
    ws_registry: WebSocketRegistry,
}

/// Initialize thread-local Scope (called once per worker thread)
fn init_thread_scope(config: &ServerConfig) -> Result<(), String> {
    QUEST_SCOPE.with(|scope_cell| {
        if scope_cell.borrow().is_some() {
            // Already initialized
            return Ok(());
        }

        let mut scope = Scope::new();

        // Set the current script path for relative imports
        let canonical_path = std::path::Path::new(&config.script_path)
            .canonicalize()
            .ok()
            .and_then(|p| p.to_str().map(|s| s.to_string()))
            .unwrap_or_else(|| config.script_path.clone());
        *scope.current_script_path.borrow_mut() = Some(canonical_path);

        // Execute script (module-level code: imports, templates, connections, functions)
        // Use the same approach as run_script to support comments
        let source = config.script_source.trim_end();
        let pairs = crate::QuestParser::parse(crate::Rule::program, source)
            .map_err(|e| format!("Parse error: {}", e))?;

        for pair in pairs {
            if matches!(pair.as_rule(), crate::Rule::EOI) {
                continue;
            }
            for statement in pair.into_inner() {
                if matches!(statement.as_rule(), crate::Rule::EOI) {
                    continue;
                }
                crate::eval_pair(statement, &mut scope)?;
            }
        }

        // Validate handle_request exists
        if scope.get("handle_request").is_none() {
            return Err("Script must define handle_request() function".to_string());
        }

        *scope_cell.borrow_mut() = Some(scope);
        Ok(())
    })
}

/// Start the web server
pub async fn start_server(config: ServerConfig) -> Result<(), Box<dyn std::error::Error>> {
    let host = config.host.clone();
    let port = config.port;

    // Create application state
    let state = AppState {
        config: Arc::new(config),
        ws_registry: WebSocketRegistry::new(),
    };

    // Build the router - route THEN with_state
    let app = Router::new()
        .route("/", any(handle_http_request))
        .route("/*path", any(handle_http_request))
        .with_state(state)
        .layer(TraceLayer::new_for_http());

    // Parse address
    let addr: SocketAddr = format!("{}:{}", host, port).parse()?;

    println!("Quest server starting on http://{}:{}", host, port);

    // Start server
    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}

/// Main HTTP request handler
async fn handle_http_request(
    State(state): State<AppState>,
    req: Request,
) -> impl IntoResponse {
    // Process request in blocking task since Quest types use Rc (not Send)
    let result = tokio::task::spawn_blocking(move || {
        handle_request_sync(state, req)
    }).await;

    match result {
        Ok(response) => response,
        Err(e) => {
            eprintln!("Handler task panicked: {}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Internal error").into_response()
        }
    }
}

/// Synchronous request handler (runs in blocking thread pool)
fn handle_request_sync(state: AppState, req: Request) -> Response {
    // Ensure thread is initialized
    if let Err(e) = init_thread_scope(&state.config) {
        eprintln!("Failed to initialize thread scope: {}", e);
        return (StatusCode::INTERNAL_SERVER_ERROR, e).into_response();
    }

    // Convert HTTP request to Quest Dict (synchronous version needed)
    let request_dict = match http_request_to_dict_sync(req) {
        Ok(dict) => dict,
        Err(e) => {
            eprintln!("Failed to convert request: {}", e);
            return (StatusCode::BAD_REQUEST, e).into_response();
        }
    };

    // Use thread-local Scope to call handle_request
    let response_value = match QUEST_SCOPE.with(|scope_cell| {
        let mut scope_ref = scope_cell.borrow_mut();
        let scope = scope_ref.as_mut().ok_or("Scope not initialized")?;

        // Get handle_request function
        let handler = scope.get("handle_request")
            .ok_or("handle_request function not found")?;

        // Call it with request Dict
        match handler {
            QValue::UserFun(func) => {
                let args = crate::function_call::CallArguments::positional_only(vec![QValue::Dict(Box::new(request_dict))]);
                crate::function_call::call_user_function(&func, args, scope)
            }
            _ => Err("handle_request is not a function".to_string())
        }
    }) {
        Ok(val) => val,
        Err(e) => {
            eprintln!("Error calling handle_request: {}", e);
            return (StatusCode::INTERNAL_SERVER_ERROR, format!("Script error: {}", e)).into_response();
        }
    };

    // Convert Quest response to HTTP response
    match dict_to_http_response(response_value) {
        Ok(response) => response,
        Err(e) => {
            eprintln!("Invalid response from script: {}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, format!("Invalid response: {}", e)).into_response()
        }
    }
}

/// Check if request is a WebSocket upgrade (reserved for Phase 2)
#[allow(dead_code)]
fn is_websocket_upgrade(req: &Request) -> bool {
    req.headers()
        .get(header::UPGRADE)
        .and_then(|v| v.to_str().ok())
        .map(|v| v.eq_ignore_ascii_case("websocket"))
        .unwrap_or(false)
}

/// Convert HTTP request to Quest Dict (synchronous version for blocking context)
fn http_request_to_dict_sync(req: Request) -> Result<QDict, String> {
    let (parts, body) = req.into_parts();

    // Extract body synchronously using futures::executor::block_on
    let body_bytes = futures::executor::block_on(to_bytes(body, usize::MAX))
        .map_err(|e| format!("Failed to read body: {}", e))?;

    build_request_dict_from_parts(parts, body_bytes)
}

/// Build Quest Dict from HTTP request parts and body bytes
fn build_request_dict_from_parts(parts: axum::http::request::Parts, body_bytes: Bytes) -> Result<QDict, String> {
    // Extract method
    let method = QString::new(parts.method.as_str().to_string());

    // Extract path
    let path = QString::new(parts.uri.path().to_string());

    // Extract query parameters
    let query = if let Some(query_str) = parts.uri.query() {
        parse_query_string(query_str)
    } else {
        QDict::new(HashMap::new())
    };

    // Extract headers
    let headers = headers_to_dict(&parts.headers);

    // Extract cookies
    let cookies = parse_cookies(&parts.headers);

    // Extract body
    let body_str = String::from_utf8_lossy(&body_bytes).to_string();
    let body_value = QString::new(body_str);

    // Extract remote address (if available)
    let remote_addr = QString::new("unknown".to_string());

    // Extract HTTP version
    let version = QString::new(format!("{:?}", parts.version));

    // Build request dict
    let mut map = HashMap::new();
    map.insert("method".to_string(), QValue::Str(method));
    map.insert("path".to_string(), QValue::Str(path));
    map.insert("query".to_string(), QValue::Dict(Box::new(query)));
    map.insert("headers".to_string(), QValue::Dict(Box::new(headers)));
    map.insert("body".to_string(), QValue::Str(body_value));
    map.insert("cookies".to_string(), QValue::Dict(Box::new(cookies)));
    map.insert("remote_addr".to_string(), QValue::Str(remote_addr));
    map.insert("version".to_string(), QValue::Str(version));

    Ok(QDict::new(map))
}

/// Parse query string into Dict
fn parse_query_string(query: &str) -> QDict {
    let mut map = HashMap::new();

    for pair in query.split('&') {
        if let Some((key, value)) = pair.split_once('=') {
            let key = urlencoding::decode(key).unwrap_or_else(|_| key.into()).to_string();
            let value = urlencoding::decode(value).unwrap_or_else(|_| value.into()).to_string();
            map.insert(key, QValue::Str(QString::new(value)));
        } else {
            let key = urlencoding::decode(pair).unwrap_or_else(|_| pair.into()).to_string();
            map.insert(key, QValue::Str(QString::new("".to_string())));
        }
    }

    QDict::new(map)
}

/// Convert HTTP headers to Quest Dict
fn headers_to_dict(headers: &HeaderMap) -> QDict {
    let mut map = HashMap::new();

    for (name, value) in headers.iter() {
        let name_str = name.as_str().to_lowercase();
        let value_str = value.to_str().unwrap_or("").to_string();
        map.insert(name_str, QValue::Str(QString::new(value_str)));
    }

    QDict::new(map)
}

/// Parse cookies from headers
fn parse_cookies(headers: &HeaderMap) -> QDict {
    let mut map = HashMap::new();

    if let Some(cookie_header) = headers.get(header::COOKIE) {
        if let Ok(cookie_str) = cookie_header.to_str() {
            for cookie in cookie_str.split(';') {
                if let Some((name, value)) = cookie.trim().split_once('=') {
                    map.insert(name.to_string(), QValue::Str(QString::new(value.to_string())));
                }
            }
        }
    }

    QDict::new(map)
}

/// Convert Quest response Dict to HTTP response
fn dict_to_http_response(value: QValue) -> Result<Response, String> {
    let dict = match value {
        QValue::Dict(d) => d,
        _ => return Err("Response must be a Dict".to_string()),
    };

    // Extract status code
    let status = dict.get("status")
        .and_then(|v| match v {
            QValue::Int(i) => Some(i.value as u16),
            _ => None,
        })
        .ok_or("Response must have 'status' field (Int)")?;

    let status_code = StatusCode::from_u16(status)
        .map_err(|_| format!("Invalid status code: {}", status))?;

    // Check for json shorthand
    let body = if let Some(json_value) = dict.get("json") {
        // Serialize to JSON
        let json_str = value_to_json_string(&json_value)?;
        Body::from(json_str)
    } else if let Some(body_value) = dict.get("body") {
        // Extract body
        match body_value {
            QValue::Str(s) => Body::from(s.value.as_ref().clone()),
            QValue::Bytes(b) => Body::from(Bytes::copy_from_slice(&b.data)),
            _ => return Err("Response 'body' must be Str or Bytes".to_string()),
        }
    } else {
        Body::empty()
    };

    // Build response
    let mut response = Response::builder().status(status_code);

    // Add headers
    if let Some(QValue::Dict(headers)) = dict.get("headers") {
        let map = headers.map.borrow();
        for (name, value) in map.iter() {
            if let QValue::Str(s) = value {
                response = response.header(name.as_str(), s.value.as_ref().as_str());
            }
        }
    } else if dict.get("json").is_some() {
        // Auto-add content-type for json shorthand
        response = response.header(header::CONTENT_TYPE, "application/json");
    }

    // Add cookies
    if let Some(QValue::Dict(cookies)) = dict.get("cookies") {
        let map = cookies.map.borrow();
        for (name, cookie_value) in map.iter() {
            let cookie_str = match cookie_value {
                QValue::Str(s) => {
                    // Simple cookie: name=value
                    format!("{}={}", name, s.value)
                }
                QValue::Dict(cookie_dict) => {
                    // Complex cookie with options
                    build_cookie_string(name, cookie_dict)?
                }
                _ => continue,
            };
            response = response.header(header::SET_COOKIE, cookie_str);
        }
    }

    response.body(body)
        .map_err(|e| format!("Failed to build response: {}", e))
}

/// Build Set-Cookie header string from cookie dict
fn build_cookie_string(name: &str, cookie: &QDict) -> Result<String, String> {
    let value = cookie.get("value")
        .and_then(|v| match v {
            QValue::Str(s) => Some(s.value.as_ref().clone()),
            _ => None,
        })
        .ok_or("Cookie must have 'value' field")?;

    let mut parts = vec![format!("{}={}", name, value)];

    if let Some(QValue::Int(max_age)) = cookie.get("max_age") {
        parts.push(format!("Max-Age={}", max_age.value));
    }

    if let Some(QValue::Str(path)) = cookie.get("path") {
        parts.push(format!("Path={}", path.value));
    }

    if let Some(QValue::Str(domain)) = cookie.get("domain") {
        parts.push(format!("Domain={}", domain.value));
    }

    if let Some(QValue::Bool(secure)) = cookie.get("secure") {
        if secure.value {
            parts.push("Secure".to_string());
        }
    }

    if let Some(QValue::Bool(http_only)) = cookie.get("http_only") {
        if http_only.value {
            parts.push("HttpOnly".to_string());
        }
    }

    if let Some(QValue::Str(same_site)) = cookie.get("same_site") {
        parts.push(format!("SameSite={}", same_site.value));
    }

    Ok(parts.join("; "))
}

/// Convert Quest value to JSON string
fn value_to_json_string(value: &QValue) -> Result<String, String> {
    match value {
        QValue::Nil(_) => Ok("null".to_string()),
        QValue::Bool(b) => Ok(b.value.to_string()),
        QValue::Int(i) => Ok(i.value.to_string()),
        QValue::Float(f) => Ok(f.value.to_string()),
        QValue::Decimal(d) => Ok(d.value.to_string()),
        QValue::BigInt(b) => Ok(b.value.to_string()),
        QValue::Str(s) => Ok(serde_json::to_string(s.value.as_ref()).unwrap()),
        QValue::Array(arr) => {
            let elements = arr.elements.borrow();
            let items: Result<Vec<String>, String> = elements
                .iter()
                .map(value_to_json_string)
                .collect();
            Ok(format!("[{}]", items?.join(",")))
        }
        QValue::Dict(dict) => {
            let map = dict.map.borrow();
            let items: Result<Vec<String>, String> = map
                .iter()
                .map(|(k, v)| {
                    let key_json = serde_json::to_string(k).unwrap();
                    let value_json = value_to_json_string(v)?;
                    Ok(format!("{}:{}", key_json, value_json))
                })
                .collect();
            Ok(format!("{{{}}}", items?.join(",")))
        }
        _ => Err(format!("Cannot convert {} to JSON", value.q_type())),
    }
}
