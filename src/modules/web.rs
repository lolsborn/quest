// Web framework module - QEP-060: Application-Centric Web Server
// Provides web.run() native function for starting HTTP servers from Quest scripts

use crate::types::{QValue, QFun, QModule, QString, QInt};
use crate::control_flow::EvalError;
use crate::scope::Scope;
use std::collections::HashMap;

/// Create the web module with native functions
pub fn create_web_module() -> QValue {
    let mut members = HashMap::new();

    // Register web.run() as a native function
    members.insert("run".to_string(), QValue::Fun(QFun::new("run".to_string(), "web".to_string())));

    QValue::Module(Box::new(QModule::new("web".to_string(), members)))
}

/// Implement web.run() native function for QEP-060
///
/// Signature: web.run() -> Nil (named args via Quest syntax)
///
/// Phase 3 Implementation:
/// - Reads configuration from quest.toml and web module
/// - Extracts runtime config (static dirs, CORS, hooks, etc.)
/// - Starts actual HTTP server with Axum
/// - Blocks until Ctrl+C or SIGTERM
/// - Returns Nil after graceful shutdown
pub fn web_run(args: Vec<QValue>, scope: &mut Scope) -> Result<QValue, EvalError> {
    // Check if arguments were provided
    let host_provided = args.len() > 0;
    let port_provided = args.len() > 1;

    // Default configuration
    let mut host = "127.0.0.1".to_string();
    let mut port = 3000u16;

    // Try to extract base config from quest.toml if available (lower priority)
    if let Some(web_module) = scope.get("web") {
        // Look for _get_base_config() function
        let get_base_config_fn = match &web_module {
            QValue::Module(m) => m.get_member("_get_base_config"),
            QValue::Dict(d) => d.get("_get_base_config"),
            _ => None,
        };

        if let Some(QValue::UserFun(base_config_fn)) = get_base_config_fn {
            // Call _get_base_config() to get configuration from quest.toml
            let call_args = crate::function_call::CallArguments::positional_only(vec![]);
            if let Ok(config_value) = crate::function_call::call_user_function(&base_config_fn, call_args, scope) {
                // Extract host and port from Configuration struct
                if let QValue::Struct(config_struct) = config_value {
                    let struct_ref = config_struct.borrow();
                    if let Some(QValue::Str(h)) = struct_ref.fields.get("host") {
                        host = h.value.as_ref().clone();
                    }
                    if let Some(QValue::Int(p)) = struct_ref.fields.get("port") {
                        port = p.value as u16;
                    }
                }
            }
        }
    }

    // Parse command-line arguments if provided (higher priority - overrides config)
    if host_provided {
        if let QValue::Str(h) = &args[0] {
            host = h.value.as_ref().clone();
        }
    }
    if port_provided {
        if let QValue::Int(p) = &args[1] {
            port = p.value as u16;
        }
    }

    // Phase 3: Create ServerConfig and start actual HTTP server
    let mut server_config = crate::server::ServerConfig::default();
    server_config.host = host.clone();
    server_config.port = port;

    // Extract script path and source from scope
    let script_path = scope.current_script_path.borrow().clone().unwrap_or_default();
    server_config.script_path = script_path.clone();

    // Phase 3: Try to read the script source from disk so worker threads can re-execute it
    // This is needed for worker threads to have access to handle_request and other definitions
    if !script_path.is_empty() {
        match std::fs::read_to_string(&script_path) {
            Ok(source) => {
                server_config.script_source = source;
            }
            Err(e) => {
                return Err(EvalError::runtime(format!("Failed to read script file '{}': {}", script_path, e)));
            }
        }
    }

    // Load runtime configuration from web module
    // Note: load_web_config also loads host/port from quest.toml, but since we already
    // have the correct values (from quest.toml or command-line), we need to preserve them
    let saved_host = server_config.host.clone();
    let saved_port = server_config.port;
    if let Err(e) = crate::server::load_web_config(scope, &mut server_config) {
        return Err(EvalError::runtime(format!("Failed to load web config: {}", e)));
    }
    // Restore host/port if they were overridden by load_web_config
    // (This preserves command-line args which have higher priority)
    if host_provided {
        server_config.host = saved_host;
    }
    if port_provided {
        server_config.port = saved_port;
    }

    // Check that handle_request exists (unless static-only mode)
    if !server_config.static_only && scope.get("handle_request").is_none() {
        return Err(EvalError::runtime("Script must define handle_request() function".to_string()));
    }

    println!("🚀 Quest Web Server (QEP-060 Phase 3)");
    println!("   Starting on http://{}:{}", host, port);
    println!();
    println!("   Press Ctrl+C to stop");
    println!();

    // Set up signal handlers for graceful shutdown
    let (shutdown_tx, shutdown_rx) = std::sync::mpsc::channel::<()>();

    // Set up Ctrl+C handler (only attempt once, ignore if already set)
    let _ = std::thread::spawn(move || {
        let _ = ctrlc::set_handler(move || {
            let _ = shutdown_tx.send(());
        }); // Ignore error if handler already set
    });

    // Start the server (blocking until shutdown)
    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| EvalError::runtime(format!("Failed to create tokio runtime: {}", e)))?;

    rt.block_on(async {
        // Convert mpsc receiver to oneshot for compatibility
        let (oneshot_tx, oneshot_rx) = tokio::sync::oneshot::channel::<()>();

        let _handle = std::thread::spawn(move || {
            if shutdown_rx.recv().is_ok() {
                let _ = oneshot_tx.send(());
            }
        });

        if let Err(e) = crate::server::start_server_with_shutdown(server_config, Some(oneshot_rx)).await {
            eprintln!("Server error: {}", e);
        }
    });

    println!();
    println!("   Server stopped gracefully");
    println!();

    Ok(QValue::Nil(crate::types::QNil))
}

pub fn call_web_function(func_name: &str, args: Vec<QValue>, scope: &mut Scope) -> Result<QValue, EvalError> {
    match func_name {
        "web.run" => web_run(args, scope),
        _ => Err(EvalError::runtime(format!("Unknown web function: {}", func_name))),
    }
}
