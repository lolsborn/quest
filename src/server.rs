use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::{Arc, RwLock};
use std::cell::RefCell;
use axum::{
    Router,
    extract::{State, Request},
    response::IntoResponse,
    http::{StatusCode, HeaderMap, header, Method},
    body::{Body, to_bytes},
};
use axum::response::Response;
use axum::routing::{any, get_service};
use hyper::body::Bytes;
use tokio::sync::mpsc;
use tower_http::trace::TraceLayer;
use tower_http::services::ServeDir;
use tower_http::cors::{CorsLayer, Any};
use multer::Multipart;

use crate::scope::Scope;
use crate::types::{QValue, QDict, QString, QInt, QUserFun};
use pest::Parser;

// Helper to create error responses (reserved for future use)
#[allow(dead_code)]
fn error_response(status: StatusCode, message: impl Into<String>) -> Response<Body> {
    Response::builder()
        .status(status)
        .body(Body::from(message.into()))
        .unwrap()
}

/// CORS configuration
#[derive(Clone, Debug)]
pub struct CorsConfig {
    pub origins: Vec<String>,
    pub methods: Vec<String>,
    pub headers: Vec<String>,
    pub credentials: bool,
}

/// Server configuration
#[derive(Clone)]
pub struct ServerConfig {
    pub host: String,
    pub port: u16,
    pub script_source: String,
    pub script_path: String,

    // Legacy: Single public directory at /public (deprecated, use static_dirs)
    pub public_dir: Option<String>,

    // QEP-051: Web Framework API
    // Static file directories: Vec of (url_path, fs_path)
    pub static_dirs: Vec<(String, String)>,

    // CORS configuration
    pub cors: Option<CorsConfig>,

    // Request limits
    pub max_body_size: usize,
    pub max_header_size: usize,

    // Timeouts
    pub request_timeout: u64,  // seconds
    pub keepalive_timeout: u64,  // seconds

    // Hooks/Error handlers configuration (QEP-051)
    // Note: Actual hook functions are stored in thread-local Quest scope (std/web module)
    // These flags indicate whether hooks/handlers are configured
    pub has_before_hooks: bool,
    pub has_after_hooks: bool,
    pub has_error_handlers: bool,

    // Redirects (from → (to, status))
    pub redirects: HashMap<String, (String, u16)>,

    // Default headers
    pub default_headers: HashMap<String, String>,

    // Static-only mode (no Quest handler required)
    pub static_only: bool,
}

impl Default for ServerConfig {
    fn default() -> Self {
        Self {
            host: "127.0.0.1".to_string(),
            port: 3000,
            script_source: String::new(),
            script_path: String::new(),
            public_dir: None,
            static_dirs: Vec::new(),
            cors: None,
            max_body_size: 10 * 1024 * 1024,  // 10MB
            max_header_size: 8 * 1024,  // 8KB
            request_timeout: 30,
            keepalive_timeout: 60,
            has_before_hooks: false,
            has_after_hooks: false,
            has_error_handlers: false,
            redirects: HashMap::new(),
            default_headers: HashMap::new(),
            static_only: false,
        }
    }
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

        // Validate handle_request exists (unless static-only mode)
        if !config.static_only && scope.get("handle_request").is_none() {
            return Err("Script must define handle_request() function".to_string());
        }

        *scope_cell.borrow_mut() = Some(scope);
        Ok(())
    })
}

/// Start the web server with optional graceful shutdown signal
pub async fn start_server(config: ServerConfig) -> Result<(), Box<dyn std::error::Error>> {
    start_server_with_shutdown(config, None).await
}

/// Start the web server with optional graceful shutdown signal
pub async fn start_server_with_shutdown(
    config: ServerConfig,
    shutdown_rx: Option<tokio::sync::oneshot::Receiver<()>>,
) -> Result<(), Box<dyn std::error::Error>> {
    let host = config.host.clone();
    let port = config.port;

    // Create application state
    let state = AppState {
        config: Arc::new(config),
        ws_registry: WebSocketRegistry::new(),
    };

    // Build CORS layer if configured
    let cors_layer = if let Some(ref cors_config) = state.config.cors {
        let mut cors = CorsLayer::new();

        // Set allowed origins
        if cors_config.origins.contains(&"*".to_string()) {
            cors = cors.allow_origin(Any);
        } else {
            for origin in &cors_config.origins {
                if let Ok(origin_val) = origin.parse::<axum::http::HeaderValue>() {
                    cors = cors.allow_origin(origin_val);
                }
            }
        }

        // Set allowed methods
        let methods: Vec<Method> = cors_config.methods.iter()
            .filter_map(|m| m.parse::<Method>().ok())
            .collect();
        cors = cors.allow_methods(methods);

        // Set allowed headers
        if !cors_config.headers.is_empty() {
            let headers: Vec<axum::http::HeaderName> = cors_config.headers.iter()
                .filter_map(|h| h.parse::<axum::http::HeaderName>().ok())
                .collect();
            cors = cors.allow_headers(headers);
        }

        // Set credentials
        if cors_config.credentials {
            cors = cors.allow_credentials(true);
        }

        println!("CORS enabled with origins: {:?}", cors_config.origins);
        Some(cors)
    } else {
        None
    };

    // Build the router starting with dynamic routes
    let mut app = Router::new();

    // Note: Static file serving is now handled at runtime via try_serve_static_file()
    // This allows web.add_static() to work dynamically without server restart

    // Static-only mode: serve entire directory at root
    if let Some(ref public_dir) = state.config.public_dir {
        if state.config.static_only {
            println!("Serving static files from: {}", public_dir);
            let serve_dir = ServeDir::new(public_dir);
            app = app.fallback_service(get_service(serve_dir));
        }
    }

    // Add dynamic routes (skip if static-only mode)
    if !state.config.static_only {
        app = app
            .route("/", any(handle_http_request))
            .route("/*path", any(handle_http_request));
    }

    // Apply CORS layer if configured (before with_state)
    if let Some(cors) = cors_layer {
        app = app.layer(cors);
    }

    // Apply trace layer (before with_state)
    app = app.layer(TraceLayer::new_for_http());

    // Add state (this converts Router<AppState> to Router<()>)
    let app = app.with_state(state);

    // Parse address
    let addr: SocketAddr = format!("{}:{}", host, port).parse()?;

    println!("Quest server starting on http://{}:{}", host, port);

    // Start server
    let listener = tokio::net::TcpListener::bind(addr).await?;

    // Serve the app with ConnectInfo
    if let Some(rx) = shutdown_rx {
        // With graceful shutdown
        axum::serve(listener, app.into_make_service_with_connect_info::<SocketAddr>())
            .with_graceful_shutdown(async {
                rx.await.ok();
            })
            .await?;
    } else {
        // Without graceful shutdown
        axum::serve(listener, app.into_make_service_with_connect_info::<SocketAddr>()).await?;
    }

    Ok(())
}

/// Main HTTP request handler
async fn handle_http_request(
    State(state): State<AppState>,
    axum::extract::ConnectInfo(addr): axum::extract::ConnectInfo<SocketAddr>,
    req: Request,
) -> impl IntoResponse {
    // Extract client IP before moving req into blocking task
    let client_ip = addr.ip().to_string();

    // Process request in blocking task since Quest types use Rc (not Send)
    let result = tokio::task::spawn_blocking(move || {
        handle_request_sync(state, req, client_ip)
    }).await;

    match result {
        Ok(response) => response,
        Err(e) => {
            eprintln!("Handler task panicked: {}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Internal error").into_response()
        }
    }
}

/// Try to serve a static file from runtime-configured static directories
fn try_serve_static_file(request_path: &str) -> Option<Response> {
    use std::path::Path;
    use std::fs;

    QUEST_SCOPE.with(|scope_cell| {
        let scope_ref = scope_cell.borrow();
        let scope = scope_ref.as_ref()?;

        // Get web module
        let web_module = scope.get("web")?;

        // Get _get_config function (handle both Module and Dict)
        let get_config_fn = match &web_module {
            QValue::Module(m) => match m.get_member("_get_config") {
                Some(QValue::UserFun(f)) => f,
                _ => return None,
            },
            QValue::Dict(d) => match d.get("_get_config") {
                Some(QValue::UserFun(f)) => f,
                _ => return None,
            },
            _ => return None,
        };

        // Call _get_config()
        let args = crate::function_call::CallArguments::positional_only(vec![]);
        let mut temp_scope = scope.clone();
        let config = crate::function_call::call_user_function(&get_config_fn, args, &mut temp_scope).ok()?;

        let config_dict = match config {
            QValue::Dict(d) => d,
            _ => return None,
        };

        // Get static_dirs array
        let static_dirs = match config_dict.get("static_dirs") {
            Some(QValue::Array(arr)) => arr,
            _ => return None,
        };

        // Check each static dir (longest path first for precedence)
        let dirs = static_dirs.elements.borrow();
        let mut matches: Vec<(String, String, usize)> = vec![];

        for dir_entry in dirs.iter() {
            if let QValue::Array(pair) = dir_entry {
                let pair_elements = pair.elements.borrow();
                if pair_elements.len() == 2 {
                    if let (QValue::Str(url_path), QValue::Str(fs_path)) =
                        (&pair_elements[0], &pair_elements[1]) {
                        let url = url_path.value.as_ref().clone();
                        if request_path.starts_with(&url) {
                            matches.push((url.clone(), fs_path.value.as_ref().clone(), url.len()));
                        }
                    }
                }
            }
        }

        // Sort by URL path length (longest first)
        matches.sort_by(|a, b| b.2.cmp(&a.2));

        // Try to serve from the first (most specific) match
        if let Some((url_path, fs_path, _)) = matches.first() {
            // Remove the URL prefix to get the file path
            let rel_path = request_path.strip_prefix(url_path).unwrap_or(request_path);
            let rel_path = rel_path.trim_start_matches('/');

            let file_path = if rel_path.is_empty() {
                format!("{}/index.html", fs_path)
            } else {
                format!("{}/{}", fs_path, rel_path)
            };

            let path = Path::new(&file_path);

            // Security: prevent path traversal
            if let Ok(canonical) = path.canonicalize() {
                let base = Path::new(fs_path).canonicalize().ok()?;
                if !canonical.starts_with(&base) {
                    return None; // Path traversal attempt
                }

                // Serve the file
                if canonical.is_file() {
                    if let Ok(contents) = fs::read(&canonical) {
                        // Basic MIME type detection
                        let mime_type = match canonical.extension().and_then(|s| s.to_str()) {
                            Some("html") | Some("htm") => "text/html",
                            Some("css") => "text/css",
                            Some("js") => "application/javascript",
                            Some("json") => "application/json",
                            Some("png") => "image/png",
                            Some("jpg") | Some("jpeg") => "image/jpeg",
                            Some("gif") => "image/gif",
                            Some("svg") => "image/svg+xml",
                            Some("ico") => "image/x-icon",
                            Some("pdf") => "application/pdf",
                            Some("txt") => "text/plain",
                            _ => "application/octet-stream",
                        };

                        return Response::builder()
                            .status(StatusCode::OK)
                            .header(header::CONTENT_TYPE, mime_type)
                            .body(Body::from(contents))
                            .ok();
                    }
                }
            }
        }

        None
    })
}

/// Synchronous request handler (runs in blocking thread pool)
fn handle_request_sync(state: AppState, req: Request, client_ip: String) -> Response {
    // Ensure thread is initialized
    if let Err(e) = init_thread_scope(&state.config) {
        eprintln!("Failed to initialize thread scope: {}", e);
        return (StatusCode::INTERNAL_SERVER_ERROR, e).into_response();
    }

    // Convert HTTP request to Quest Dict (synchronous version needed)
    let mut request_dict = match http_request_to_dict_sync(req, client_ip) {
        Ok(dict) => dict,
        Err(e) => {
            eprintln!("Failed to convert request: {}", e);
            return (StatusCode::BAD_REQUEST, e).into_response();
        }
    };

    // Check for redirects first (QEP-051)
    let path = match request_dict.get("path") {
        Some(QValue::Str(s)) => s.value.as_ref().clone(),
        _ => String::new(),
    };

    if let Some((to_path, status)) = state.config.redirects.get(&path) {
        let mut response = Response::builder()
            .status(StatusCode::from_u16(*status).unwrap_or(StatusCode::FOUND));
        response = response.header(header::LOCATION, to_path.as_str());
        return response.body(Body::empty()).unwrap();
    }

    // Check for runtime static file matches (QEP-051)
    // This allows web.add_static() to work without restarting the server
    if let Some(file_response) = try_serve_static_file(&path) {
        return file_response;
    }

    // Skip Quest handler if static-only mode
    let response_value = if state.config.static_only {
        // Return a simple 404 dict to signal "not found, try static files"
        let mut map = HashMap::new();
        map.insert("status".to_string(), QValue::Int(QInt::new(404)));
        map.insert("body".to_string(), QValue::Str(QString::new("Not found".to_string())));
        Ok(QValue::Dict(Box::new(QDict::new(map))))
    } else {
        // Execute before hooks (QEP-051)
        QUEST_SCOPE.with(|scope_cell| {
            let mut scope_ref = scope_cell.borrow_mut();
            let scope = scope_ref.as_mut().ok_or("Scope not initialized")?;

        // Run before hooks (retrieve from web module in scope)
        if state.config.has_before_hooks {
            let hooks = get_web_hooks(scope, "before_hooks")?;
            for hook in hooks {
                let args = crate::function_call::CallArguments::positional_only(vec![
                    QValue::Dict(Box::new(request_dict.clone()))
                ]);
                let result = crate::function_call::call_user_function(&hook, args, scope)?;

                // Check if hook returned a response (has 'status' field)
                if let QValue::Dict(ref result_dict) = result {
                    if result_dict.get("status").is_some() {
                        // Short-circuit: hook returned a response
                        return Ok(result);
                    }
                }

                // Hook returned modified request, update request_dict
                if let QValue::Dict(modified_req) = result {
                    request_dict = *modified_req;
                }
            }
        }

        // Get handle_request function
        let handler = scope.get("handle_request")
            .ok_or("handle_request function not found")?;

        // Call handle_request with (potentially modified) request
        let response = match handler {
            QValue::UserFun(func) => {
                let args = crate::function_call::CallArguments::positional_only(vec![
                    QValue::Dict(Box::new(request_dict.clone()))
                ]);
                crate::function_call::call_user_function(&func, args, scope)?
            }
            _ => return Err("handle_request is not a function".to_string())
        };

        // Run after hooks (retrieve from web module in scope)
        let mut final_response = response;
        if state.config.has_after_hooks {
            let hooks = get_web_hooks(scope, "after_hooks")?;
            for hook in hooks {
                let args = crate::function_call::CallArguments::positional_only(vec![
                    QValue::Dict(Box::new(request_dict.clone())),
                    final_response.clone(),
                ]);
                final_response = crate::function_call::call_user_function(&hook, args, scope)?;
            }
        }

            Ok(final_response)
        })
    };

    // Handle errors from hooks or handle_request
    let response_value = match response_value {
        Ok(val) => val,
        Err(e) => {
            eprintln!("Error in request handling: {}", e);

            // Try to call error handler (status 500)
            let error_response = try_call_error_handler(&state, 500, &request_dict, Some(&e));
            if let Some(resp) = error_response {
                return resp;
            }

            // Fallback to generic 500 error
            return (StatusCode::INTERNAL_SERVER_ERROR, format!("Script error: {}", e)).into_response();
        }
    };

    // Convert Quest response to HTTP response
    let mut response = match dict_to_http_response(response_value) {
        Ok(resp) => resp,
        Err(e) => {
            eprintln!("Invalid response from script: {}", e);
            return (StatusCode::INTERNAL_SERVER_ERROR, format!("Invalid response: {}", e)).into_response();
        }
    };

    // Apply default headers (QEP-051)
    // Response-specific headers take precedence
    let headers = response.headers_mut();
    for (name, value) in &state.config.default_headers {
        // Only add if not already present
        if let Ok(header_name) = name.parse::<axum::http::HeaderName>() {
            if !headers.contains_key(&header_name) {
                if let Ok(header_value) = value.parse::<axum::http::HeaderValue>() {
                    headers.insert(header_name, header_value);
                }
            }
        }
    }

    response
}

/// Try to call an error handler if one is registered
fn try_call_error_handler(
    state: &AppState,
    status: u16,
    request_dict: &QDict,
    error: Option<&str>,
) -> Option<Response> {
    if !state.config.has_error_handlers {
        return None;
    }

    QUEST_SCOPE.with(|scope_cell| {
        let mut scope_ref = scope_cell.borrow_mut();
        let scope = match scope_ref.as_mut() {
            Some(s) => s,
            None => return None,
        };

        // Get error handler from web module
        let handler = match get_web_error_handler(scope, status) {
            Ok(h) => h,
            Err(_) => return None,
        };

        // For 5xx errors, pass error message as second argument
        let args = if status >= 500 && status < 600 {
            if let Some(err_msg) = error {
                crate::function_call::CallArguments::positional_only(vec![
                    QValue::Dict(Box::new(request_dict.clone())),
                    QValue::Str(QString::new(err_msg.to_string())),
                ])
            } else {
                crate::function_call::CallArguments::positional_only(vec![
                    QValue::Dict(Box::new(request_dict.clone())),
                    QValue::Str(QString::new("Unknown error".to_string())),
                ])
            }
        } else {
            // For 4xx errors, just pass request
            crate::function_call::CallArguments::positional_only(vec![
                QValue::Dict(Box::new(request_dict.clone())),
            ])
        };

        match crate::function_call::call_user_function(&handler, args, scope) {
            Ok(response_value) => {
                match dict_to_http_response(response_value) {
                    Ok(response) => Some(response),
                    Err(e) => {
                        eprintln!("Error handler returned invalid response: {}", e);
                        None
                    }
                }
            }
            Err(e) => {
                eprintln!("Error handler failed: {}", e);
                None
            }
        }
    })
}

/// Get hooks array from web module in scope
fn get_web_hooks(scope: &mut Scope, hook_name: &str) -> Result<Vec<QUserFun>, String> {
    // Get web module (can be Module or Dict)
    let web_value = scope.get("web");

    let get_config_fn = match &web_value {
        Some(QValue::Module(m)) => match m.get_member("_get_config") {
            Some(QValue::UserFun(f)) => f.clone(),
            _ => return Ok(Vec::new()),
        },
        Some(QValue::Dict(d)) => match d.get("_get_config") {
            Some(QValue::UserFun(f)) => f.clone(),
            _ => return Ok(Vec::new()),
        },
        _ => return Ok(Vec::new()), // No web module
    };

    // Call _get_config()
    let args = crate::function_call::CallArguments::positional_only(vec![]);
    let runtime_config = crate::function_call::call_user_function(&get_config_fn, args, scope)?;

    let runtime_dict = match runtime_config {
        QValue::Dict(d) => d,
        _ => return Ok(Vec::new()),
    };

    // Get hooks array
    let mut hooks = Vec::new();
    if let Some(QValue::Array(hooks_arr)) = runtime_dict.get(hook_name) {
        let elements = hooks_arr.elements.borrow();
        for hook in elements.iter() {
            if let QValue::UserFun(func) = hook {
                hooks.push((**func).clone());
            }
        }
    }

    Ok(hooks)
}

/// Get error handler for specific status code from web module
fn get_web_error_handler(scope: &mut Scope, status: u16) -> Result<QUserFun, String> {
    // Get web module (can be Module or Dict)
    let web_value = scope.get("web");

    let get_config_fn = match &web_value {
        Some(QValue::Module(m)) => match m.get_member("_get_config") {
            Some(QValue::UserFun(f)) => f.clone(),
            _ => return Err("No _get_config function".to_string()),
        },
        Some(QValue::Dict(d)) => match d.get("_get_config") {
            Some(QValue::UserFun(f)) => f.clone(),
            _ => return Err("No _get_config function".to_string()),
        },
        _ => return Err("No web module".to_string()),
    };

    // Call _get_config()
    let args = crate::function_call::CallArguments::positional_only(vec![]);
    let runtime_config = crate::function_call::call_user_function(&get_config_fn, args, scope)?;

    let runtime_dict = match runtime_config {
        QValue::Dict(d) => d,
        _ => return Err("_get_config didn't return dict".to_string()),
    };

    // Get error handlers dict
    if let Some(QValue::Dict(handlers_dict)) = runtime_dict.get("error_handlers") {
        let map = handlers_dict.map.borrow();

        // Look for specific status handler
        if let Some(QValue::UserFun(func)) = map.get(&status.to_string()) {
            return Ok((**func).clone());
        }

        // Look for generic handler (status 0)
        if let Some(QValue::UserFun(func)) = map.get("0") {
            return Ok((**func).clone());
        }
    }

    Err(format!("No error handler for status {}", status))
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
fn http_request_to_dict_sync(req: Request, client_ip: String) -> Result<QDict, String> {
    let (parts, body) = req.into_parts();

    // Extract body synchronously using futures::executor::block_on
    let body_bytes = futures::executor::block_on(to_bytes(body, usize::MAX))
        .map_err(|e| format!("Failed to read body: {}", e))?;

    build_request_dict_from_parts(parts, body_bytes, client_ip)
}

/// Parse multipart/form-data body
async fn parse_multipart_body(content_type: &str, body_bytes: Bytes) -> Result<QValue, String> {
    use futures::stream;
    use crate::types::{QBytes, QArray};

    // Extract boundary from Content-Type header
    let boundary = multer::parse_boundary(content_type)
        .map_err(|e| format!("Failed to parse boundary: {}", e))?;

    // Convert Bytes to a Stream<Item = Result<Bytes, std::io::Error>>
    // multer expects a stream, so we create a single-item stream
    let stream = stream::once(async move { Ok::<_, std::io::Error>(body_bytes) });

    // Create multipart parser
    let mut multipart = Multipart::new(stream, boundary);

    // Storage for fields and files
    let mut fields = HashMap::new();
    let mut files = Vec::new();

    // Parse all fields
    while let Some(field) = multipart.next_field().await
        .map_err(|e| format!("Failed to read field: {}", e))? {

        let field_name = field.name()
            .unwrap_or("unknown")
            .to_string();

        let content_type = field.content_type()
            .map(|m| m.to_string())
            .unwrap_or_else(|| "text/plain".to_string());

        // Check if this is a file field (has filename)
        if let Some(filename) = field.file_name() {
            let filename = filename.to_string();
            let data = field.bytes().await
                .map_err(|e| format!("Failed to read file data: {}", e))?;

            // Create file metadata dict
            let mut file_map = HashMap::new();
            file_map.insert("name".to_string(), QValue::Str(QString::new(field_name.clone())));
            file_map.insert("filename".to_string(), QValue::Str(QString::new(filename)));
            file_map.insert("mime_type".to_string(), QValue::Str(QString::new(content_type)));
            file_map.insert("size".to_string(), QValue::Int(QInt::new(data.len() as i64)));
            file_map.insert("data".to_string(), QValue::Bytes(QBytes::new(data.to_vec())));

            files.push(QValue::Dict(Box::new(QDict::new(file_map))));
        } else {
            // Regular text field
            let value = field.text().await
                .map_err(|e| format!("Failed to read field value: {}", e))?;
            fields.insert(field_name, QValue::Str(QString::new(value)));
        }
    }

    // Build result dict with fields and files
    let mut result = HashMap::new();
    result.insert("fields".to_string(), QValue::Dict(Box::new(QDict::new(fields))));
    result.insert("files".to_string(), QValue::Array(QArray::new(files)));

    Ok(QValue::Dict(Box::new(QDict::new(result))))
}

/// Build Quest Dict from HTTP request parts and body bytes
fn build_request_dict_from_parts(parts: axum::http::request::Parts, body_bytes: Bytes, client_ip: String) -> Result<QDict, String> {
    // Extract method
    let method = QString::new(parts.method.as_str().to_string());

    // Extract path
    let path = QString::new(parts.uri.path().to_string());

    // Extract query string (raw string)
    let query_string = QString::new(parts.uri.query().unwrap_or("").to_string());

    // Extract query parameters (parsed dict)
    let query = if let Some(query_str) = parts.uri.query() {
        parse_query_string(query_str)
    } else {
        QDict::new(HashMap::new())
    };

    // Extract headers
    let headers = headers_to_dict(&parts.headers);

    // Extract cookies
    let cookies = parse_cookies(&parts.headers);

    // Extract content type early
    let content_type = parts.headers.get(header::CONTENT_TYPE)
        .and_then(|h| h.to_str().ok())
        .unwrap_or("")
        .to_string();

    // Parse body based on Content-Type
    let body_value = if content_type.starts_with("multipart/form-data") {
        // Parse multipart data using async parser
        futures::executor::block_on(parse_multipart_body(&content_type, body_bytes.clone()))
            .unwrap_or_else(|e| {
                eprintln!("Warning: Failed to parse multipart body: {}", e);
                // Fallback to raw string on error
                QValue::Str(QString::new(String::from_utf8_lossy(&body_bytes).to_string()))
            })
    } else {
        // Keep existing behavior for non-multipart requests
        let body_str = String::from_utf8_lossy(&body_bytes).to_string();
        QValue::Str(QString::new(body_str))
    };

    // Extract HTTP version
    let version = QString::new(format!("{:?}", parts.version));

    // Extract scheme (http/https) from URI
    let scheme = parts.uri.scheme_str()
        .unwrap_or("http")
        .to_string();

    // Extract host from Host header or URI
    let host = parts.headers.get(header::HOST)
        .and_then(|h| h.to_str().ok())
        .or_else(|| parts.uri.host())
        .unwrap_or("unknown")
        .to_string();

    // Extract commonly used headers
    let user_agent = parts.headers.get(header::USER_AGENT)
        .and_then(|h| h.to_str().ok())
        .unwrap_or("")
        .to_string();

    let referer = parts.headers.get(header::REFERER)
        .and_then(|h| h.to_str().ok())
        .unwrap_or("")
        .to_string();

    let content_length = parts.headers.get(header::CONTENT_LENGTH)
        .and_then(|h| h.to_str().ok())
        .and_then(|s| s.parse::<i64>().ok())
        .unwrap_or(0);

    // Build request dict
    let mut map = HashMap::new();
    map.insert("method".to_string(), QValue::Str(method));
    map.insert("path".to_string(), QValue::Str(path));
    map.insert("query_string".to_string(), QValue::Str(query_string));
    map.insert("query".to_string(), QValue::Dict(Box::new(query)));
    map.insert("headers".to_string(), QValue::Dict(Box::new(headers)));
    map.insert("body".to_string(), body_value);
    map.insert("cookies".to_string(), QValue::Dict(Box::new(cookies)));
    map.insert("client_ip".to_string(), QValue::Str(QString::new(client_ip)));
    map.insert("version".to_string(), QValue::Str(version));
    map.insert("scheme".to_string(), QValue::Str(QString::new(scheme)));
    map.insert("host".to_string(), QValue::Str(QString::new(host)));
    map.insert("user_agent".to_string(), QValue::Str(QString::new(user_agent)));
    map.insert("referer".to_string(), QValue::Str(QString::new(referer)));
    map.insert("content_type".to_string(), QValue::Str(QString::new(content_type)));
    map.insert("content_length".to_string(), QValue::Int(QInt::new(content_length)));

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

/// Load web configuration from Quest module (QEP-051)
/// Called after script execution to extract configuration from std/web module
pub fn load_web_config(scope: &mut Scope, config: &mut ServerConfig) -> Result<(), String> {
    // Try to get the std/web module
    let web_value = scope.get("web");

    // Helper function to get a member from either Module or Dict
    let get_member = |name: &str| -> Option<QValue> {
        match &web_value {
            Some(QValue::Module(module)) => module.get_member(name),
            Some(QValue::Dict(dict)) => dict.get(name),
            _ => None,
        }
    };

    // Check that we have a valid web module
    if !matches!(web_value, Some(QValue::Module(_)) | Some(QValue::Dict(_))) {
        return Ok(());
    }

    // Get _get_config function
    let get_config_fn = match get_member("_get_config") {
        Some(QValue::UserFun(func)) => func.clone(),
        _ => return Ok(())
    };

    // Call _get_config()
    let args = crate::function_call::CallArguments::positional_only(vec![]);
    let runtime_config = crate::function_call::call_user_function(&get_config_fn, args, scope)?;

    let runtime_dict = match runtime_config {
        QValue::Dict(d) => d,
        _ => return Err("web._get_config() must return a Dict".to_string()),
    };

    // Get base configuration via _get_base_config() function
    let get_base_config_fn = match get_member("_get_base_config") {
        Some(QValue::UserFun(func)) => func.clone(),
        _ => return Ok(()), // No base config function, use defaults
    };

    let args = crate::function_call::CallArguments::positional_only(vec![]);
    let base_config = crate::function_call::call_user_function(&get_base_config_fn, args, scope)?;

    let base_struct = match base_config {
        QValue::Struct(s) => s,
        _ => return Err("web._get_base_config() must return Configuration struct".to_string()),
    };

    // Load base configuration (from quest.toml)
    let struct_ref = base_struct.borrow();
    if let Some(QValue::Str(host)) = struct_ref.fields.get("host") {
        config.host = host.value.as_ref().clone();
    }
    if let Some(QValue::Int(port)) = struct_ref.fields.get("port") {
        config.port = port.value as u16;
    }
    if let Some(QValue::Int(max_body)) = struct_ref.fields.get("max_body_size") {
        config.max_body_size = max_body.value as usize;
    }
    if let Some(QValue::Int(max_header)) = struct_ref.fields.get("max_header_size") {
        config.max_header_size = max_header.value as usize;
    }
    if let Some(QValue::Int(req_timeout)) = struct_ref.fields.get("request_timeout") {
        config.request_timeout = req_timeout.value as u64;
    }
    if let Some(QValue::Int(keepalive)) = struct_ref.fields.get("keepalive_timeout") {
        config.keepalive_timeout = keepalive.value as u64;
    }
    drop(struct_ref);

    // Load runtime configuration (from script)
    // Clear any previous runtime config to avoid accumulation on reload
    config.static_dirs.clear();
    config.cors = None;
    config.has_before_hooks = false;
    config.has_after_hooks = false;
    config.has_error_handlers = false;
    config.redirects.clear();
    config.default_headers.clear();

    // 1. Static directories
    match runtime_dict.get("static_dirs") {
        Some(QValue::Array(static_dirs)) => {
            let dirs = static_dirs.elements.borrow();
            for dir_entry in dirs.iter() {
                if let QValue::Array(pair) = dir_entry {
                    let pair_elements = pair.elements.borrow();
                    if pair_elements.len() == 2 {
                        if let (QValue::Str(url_path), QValue::Str(fs_path)) =
                            (&pair_elements[0], &pair_elements[1]) {
                            config.static_dirs.push((
                                url_path.value.as_ref().clone(),
                                fs_path.value.as_ref().clone()
                            ));
                        }
                    }
                }
            }
        }
        _ => {}
    }

    // 2. CORS configuration
    if let Some(QValue::Dict(cors_dict)) = runtime_dict.get("cors") {
        let mut origins = Vec::new();
        if let Some(QValue::Array(origins_arr)) = cors_dict.get("origins") {
            let elements = origins_arr.elements.borrow();
            for origin in elements.iter() {
                if let QValue::Str(s) = origin {
                    origins.push(s.value.as_ref().clone());
                }
            }
        }

        let mut methods = Vec::new();
        if let Some(QValue::Array(methods_arr)) = cors_dict.get("methods") {
            let elements = methods_arr.elements.borrow();
            for method in elements.iter() {
                if let QValue::Str(s) = method {
                    methods.push(s.value.as_ref().clone());
                }
            }
        }

        let mut headers = Vec::new();
        if let Some(QValue::Array(headers_arr)) = cors_dict.get("headers") {
            let elements = headers_arr.elements.borrow();
            for hdr in elements.iter() {
                if let QValue::Str(s) = hdr {
                    headers.push(s.value.as_ref().clone());
                }
            }
        }

        let credentials = if let Some(QValue::Bool(b)) = cors_dict.get("credentials") {
            b.value
        } else {
            false
        };

        config.cors = Some(CorsConfig {
            origins,
            methods,
            headers,
            credentials,
        });
    }

    // 3. Check for before hooks (store flag, hooks stay in Quest scope)
    if let Some(QValue::Array(hooks_arr)) = runtime_dict.get("before_hooks") {
        let elements = hooks_arr.elements.borrow();
        config.has_before_hooks = !elements.is_empty();
    }

    // 4. Check for after hooks
    if let Some(QValue::Array(hooks_arr)) = runtime_dict.get("after_hooks") {
        let elements = hooks_arr.elements.borrow();
        config.has_after_hooks = !elements.is_empty();
    }

    // 5. Check for error handlers
    if let Some(QValue::Dict(handlers_dict)) = runtime_dict.get("error_handlers") {
        let map = handlers_dict.map.borrow();
        config.has_error_handlers = !map.is_empty();
    }

    // 6. Redirects
    if let Some(QValue::Dict(redirects_dict)) = runtime_dict.get("redirects") {
        let map = redirects_dict.map.borrow();
        for (from_path, redirect_data) in map.iter() {
            if let QValue::Array(redirect_arr) = redirect_data {
                let elements = redirect_arr.elements.borrow();
                if elements.len() == 2 {
                    if let (QValue::Str(to_path), QValue::Int(status)) =
                        (&elements[0], &elements[1]) {
                        config.redirects.insert(
                            from_path.clone(),
                            (to_path.value.as_ref().clone(), status.value as u16)
                        );
                    }
                }
            }
        }
    }

    // 7. Default headers
    if let Some(QValue::Dict(headers_dict)) = runtime_dict.get("default_headers") {
        let map = headers_dict.map.borrow();
        for (name, value) in map.iter() {
            if let QValue::Str(s) = value {
                config.default_headers.insert(name.clone(), s.value.as_ref().clone());
            }
        }
    }

    Ok(())
}
