use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::Duration;
use serde::Deserialize;
use notify::{Watcher, RecursiveMode, Event, EventKind};
use crate::scope::Scope;
use crate::types::{QNil, QValue};
use crate::{QuestParser, Rule, eval_pair, SCRIPT_ARGS, SCRIPT_PATH};
use crate::server::{ServerConfig, start_server, start_server_with_shutdown};
use pest::Parser;

/// Structure for parsing project config (quest.toml)
#[derive(Debug, Deserialize)]
pub struct ProjectConfig {
    // Project metadata
    // pub name: Option<String>,
    // pub version: Option<String>,
    // pub description: Option<String>,
    // pub authors: Option<Vec<String>>,
    // pub license: Option<String>,
    // pub homepage: Option<String>,
    // pub repository: Option<String>,
    // pub keywords: Option<Vec<String>>,

    // Scripts to run
    pub scripts: Option<HashMap<String, String>>,
}

/// Run a Quest script from source code
pub fn run_script(source: &str, args: &[String], script_path: Option<&str>) -> Result<(), String> {
    // Set global script args and path for sys module (only set once)
    let _ = SCRIPT_ARGS.set(args.to_vec());
    let _ = SCRIPT_PATH.set(script_path.map(|s| s.to_string()));

    let mut scope = Scope::new();

    // Set the current script path if provided (for relative imports)
    if let Some(path) = script_path {
        let canonical_path = std::path::Path::new(path)
            .canonicalize()
            .ok()
            .and_then(|p| p.to_str().map(|s| s.to_string()))
            .unwrap_or_else(|| path.to_string());
        *scope.current_script_path.borrow_mut() = Some(canonical_path);
    }

    // Trim trailing whitespace to avoid parse errors on empty lines
    let source = source.trim_end();

    // Parse as a program (allows comments and multiple statements)
    let pairs = QuestParser::parse(Rule::program, source)
        .map_err(|e| format!("Parse error: {}", e))?;

    // Evaluate each statement in the program
    let mut _last_result = QValue::Nil(QNil);
    for pair in pairs {
        // Skip EOI and SOI
        if matches!(pair.as_rule(), Rule::EOI) {
            continue;
        }

        for statement in pair.into_inner() {
            if matches!(statement.as_rule(), Rule::EOI) {
                continue;
            }
            _last_result = eval_pair(statement, &mut scope)?;
        }
    }

    Ok(())
}

/// Handle the 'quest run <script_name>' command
pub fn handle_run_command(script_name: &str, remaining_args: &[String]) -> Result<(), Box<dyn std::error::Error>> {
    // Look for quest.toml
    let project_path = PathBuf::from("quest.toml");
    if !project_path.exists() {
        return Err("quest.toml not found in current directory".into());
    }

    // Parse the config file
    let content = fs::read_to_string(&project_path)?;
    let project: ProjectConfig = toml::from_str(&content)
        .map_err(|e| format!("Failed to parse quest.toml: {}", e))?;

    // Find the script
    let scripts = project.scripts.ok_or_else(|| "No 'scripts' section found in quest.toml".to_string())?;
    let script_value = scripts.get(script_name)
        .ok_or_else(|| format!("Script '{}' not found in quest.toml", script_name))?;

    // Get the directory containing the config file
    // Canonicalize to get absolute path
    let project_dir = project_path
        .canonicalize()
        .ok()
        .and_then(|p| p.parent().map(|parent| parent.to_path_buf()))
        .unwrap_or_else(|| env::current_dir().unwrap_or_else(|_| PathBuf::from(".")));

    // Check if it's a shell command:
    // - Contains spaces (e.g., "cargo build --release")
    // - Is a relative path without .q extension (e.g., "./build.sh", "pwd")
    // - Starts with absolute path to system binary (e.g., "/bin/echo")
    let is_shell_command = script_value.contains(' ') ||
                          (!script_value.ends_with(".q") &&
                           (!script_value.contains('/') || script_value.starts_with('/')));

    if is_shell_command {
        // It's a shell command - execute it with sh/cmd
        let shell = if cfg!(windows) { "cmd" } else { "/bin/sh" };
        let shell_arg = if cfg!(windows) { "/C" } else { "-c" };

        let mut cmd = Command::new(shell);
        cmd.arg(shell_arg);

        // Build the full command with arguments
        let mut full_command = script_value.clone();
        for arg in remaining_args {
            full_command.push(' ');
            // Quote arguments that contain spaces
            if arg.contains(' ') {
                full_command.push_str(&format!("\"{}\"", arg));
            } else {
                full_command.push_str(arg);
            }
        }

        cmd.arg(&full_command);
        cmd.current_dir(project_dir);

        let status = cmd.status()
            .map_err(|e| format!("Failed to execute shell command '{}': {} (command: {} {} \"{}\")",
                                 script_value, e, shell, shell_arg, full_command))?;

        if !status.success() {
            std::process::exit(status.code().unwrap_or(1));
        }

        return Ok(());
    }

    // Resolve the script path relative to quest.toml
    let resolved_path = project_dir.join(script_value);

    // Check if it's a .q file
    if script_value.ends_with(".q") {
        // It's a Quest script - run it directly
        let source = fs::read_to_string(&resolved_path)
            .map_err(|e| format!("Failed to read file '{}': {}", resolved_path.display(), e))?;

        // Create args array: [script_path, ...remaining_args]
        let mut script_args = vec![resolved_path.to_string_lossy().to_string()];
        script_args.extend_from_slice(remaining_args);

        if let Err(e) = run_script(&source, &script_args, Some(&resolved_path.to_string_lossy())) {
            // Don't add "Error: " prefix if the error already has it
            if e.starts_with("Error: ") || e.contains(": ") {
                eprintln!("{}", e);
            } else {
                eprintln!("Error: {}", e);
            }
            std::process::exit(1);
        }
    } else {
        // It's an executable - spawn it
        let mut cmd = Command::new(&resolved_path);
        cmd.args(remaining_args);

        let status = cmd.status()
            .map_err(|e| format!("Failed to execute '{}': {}", resolved_path.display(), e))?;

        if !status.success() {
            std::process::exit(status.code().unwrap_or(1));
        }
    }

    Ok(())
}

/// Handle the 'quest serve [OPTIONS] <script>' command
pub fn handle_serve_command(args: &[String]) -> Result<(), Box<dyn std::error::Error>> {
    let mut host = "127.0.0.1".to_string();
    let mut port = 3000u16;
    let mut script_path: Option<String> = None;
    let mut watch = false;

    // Parse arguments
    let mut i = 0;
    while i < args.len() {
        let arg = &args[i];

        match arg.as_str() {
            "--help" | "-h" => {
                println!("Usage: quest serve [OPTIONS] <SCRIPT>");
                println!();
                println!("Arguments:");
                println!("  <SCRIPT>  Path to Quest script file or directory (uses index.q)");
                println!();
                println!("Options:");
                println!("  --host <HOST>        Host to bind to [default: 127.0.0.1]");
                println!("  -p, --port <PORT>    Port to bind to [default: 3000]");
                println!("  -w, --watch          Watch for file changes and reload");
                println!("  -h, --help           Print help information");
                return Ok(());
            }
            "--host" => {
                i += 1;
                if i >= args.len() {
                    return Err("--host requires a value".into());
                }
                host = args[i].clone();
            }
            "--port" | "-p" => {
                i += 1;
                if i >= args.len() {
                    return Err(format!("{} requires a value", arg).into());
                }
                port = args[i].parse()
                    .map_err(|_| format!("Invalid port: {}", args[i]))?;
            }
            "--watch" | "-w" => {
                watch = true;
            }
            _ => {
                if arg.starts_with('-') {
                    return Err(format!("Unknown option: {}", arg).into());
                }
                if script_path.is_some() {
                    return Err("Multiple script paths provided".into());
                }
                script_path = Some(arg.clone());
            }
        }

        i += 1;
    }

    // Validate that script path was provided
    let script_path = script_path.ok_or("Missing script path. Usage: quest serve [OPTIONS] <SCRIPT>")?;

    // Resolve script path
    let path = Path::new(&script_path);
    let is_dir = path.is_dir();
    let resolved_path = if is_dir {
        // If directory, look for index.q
        let index_path = path.join("index.q");
        if !index_path.exists() {
            return Err(format!("index.q not found in directory: {}", path.display()).into());
        }
        index_path
    } else if path.is_file() {
        path.to_path_buf()
    } else {
        return Err(format!("Script not found: {}", script_path).into());
    };

    // For watch mode, track what to watch (directory or file)
    let watch_path = if is_dir {
        path.to_path_buf()
    } else {
        resolved_path.clone()
    };

    // Read the script BEFORE changing working directory
    let script_source = fs::read_to_string(&resolved_path)
        .map_err(|e| format!("Failed to read script '{}': {}", resolved_path.display(), e))?;

    // Canonicalize paths that need to be absolute (before changing working directory)
    let canonical_script_path = resolved_path.canonicalize()
        .map_err(|e| format!("Failed to canonicalize script path: {}", e))?;

    let canonical_watch_path = watch_path.canonicalize()
        .map_err(|e| format!("Failed to canonicalize watch path: {}", e))?;

    // Check for public/ directory if serving from a directory
    let public_dir = if is_dir {
        let public_path = path.join("public");
        if public_path.is_dir() {
            // Canonicalize public dir before changing working directory
            let canonical_public = public_path.canonicalize()
                .map_err(|e| format!("Failed to canonicalize public directory: {}", e))?;
            Some(canonical_public.to_string_lossy().to_string())
        } else {
            None
        }
    } else {
        None
    };

    // Change working directory to the script's directory
    // This ensures relative paths in the script (like database files) work correctly
    if let Some(script_dir) = canonical_script_path.parent() {
        std::env::set_current_dir(script_dir)
            .map_err(|e| format!("Failed to change directory to '{}': {}", script_dir.display(), e))?;
        println!("Working directory: {}", script_dir.display());
    }

    // Create server config
    let mut config = ServerConfig {
        host: host.clone(),
        port,
        script_source,
        script_path: canonical_script_path.to_string_lossy().to_string(),
        public_dir,
    };

    // Validate script has handle_request function (basic check)
    if !config.script_source.contains("handle_request") {
        eprintln!("Warning: Script does not appear to define a handle_request() function");
        eprintln!("The server requires a handle_request(request) function to be defined.");
    }

    if watch {
        // Watch mode: monitor file for changes and restart server
        println!("Watch mode enabled");
        loop {
            // Set up file watcher
            let (file_change_tx, file_change_rx) = std::sync::mpsc::channel();
            let mut watcher = notify::recommended_watcher(move |res: Result<Event, notify::Error>| {
                if let Ok(event) = res {
                    // Trigger on modify events, but ignore database files and other non-source files
                    if matches!(event.kind, EventKind::Modify(_)) {
                        // Check if any path in the event should be ignored
                        let should_ignore = event.paths.iter().any(|path| {
                            // Check file name
                            let file_name = path.file_name()
                                .and_then(|n| n.to_str())
                                .unwrap_or("");

                            // Ignore dot files (hidden files like .DS_Store, .git internals, etc.)
                            if file_name.starts_with('.') {
                                return true;
                            }

                            // Ignore SQLite temp files (journal, wal, shm)
                            if file_name.contains("-journal") || file_name.contains("-wal") || file_name.contains("-shm") {
                                return true;
                            }

                            // Check extension for database files
                            let ext = path.extension()
                                .and_then(|ext| ext.to_str());

                            let is_ignored = ext
                                .map(|ext| {
                                    matches!(ext, "sqlite" | "sqlite3" | "db" | "log" | "tmp")
                                })
                                .unwrap_or(false);
                            is_ignored
                        });

                        if !should_ignore {
                            // Print which file(s) triggered the reload
                            for path in &event.paths {
                                eprintln!("[WATCH] File changed: {}", path.display());
                            }
                            eprintln!("[WATCH] Reloading server...");
                            let _ = file_change_tx.send(());
                        }
                    }
                }
            })?;

            // Watch the script file or directory
            // If directory, watch recursively; if file, watch non-recursively
            let recursive_mode = if is_dir {
                RecursiveMode::Recursive
            } else {
                RecursiveMode::NonRecursive
            };
            watcher.watch(&canonical_watch_path, recursive_mode)?;

            // Create shutdown channel for graceful server shutdown
            let (shutdown_tx, shutdown_rx) = tokio::sync::oneshot::channel();

            // Start server in a separate thread
            let config_clone = ServerConfig {
                host: host.clone(),
                port,
                script_source: config.script_source.clone(),
                script_path: config.script_path.clone(),
                public_dir: config.public_dir.clone(),
            };

            let server_handle = std::thread::spawn(move || {
                tokio::runtime::Runtime::new()
                    .expect("Failed to create runtime")
                    .block_on(async {
                        let result = start_server_with_shutdown(config_clone, Some(shutdown_rx)).await;
                        if let Err(e) = result {
                            eprintln!("Server error: {}", e);
                        }
                    });
            });

            // Wait for file change
            loop {
                match file_change_rx.recv_timeout(Duration::from_millis(500)) {
                    Ok(_) => {
                        println!("\nFile changed, reloading...");

                        // Signal server to shutdown gracefully
                        let _ = shutdown_tx.send(());

                        // Wait for server thread to finish
                        let _ = server_handle.join();

                        // Re-read the script (use canonical path since we've changed working directory)
                        config.script_source = fs::read_to_string(&canonical_script_path)
                            .map_err(|e| format!("Failed to read script '{}': {}", canonical_script_path.display(), e))?;

                        // Validate the new script
                        if !config.script_source.contains("handle_request") {
                            eprintln!("Warning: Script does not appear to define a handle_request() function");
                        }

                        // Drop the watcher to stop watching
                        drop(watcher);

                        // Break inner loop to restart server
                        break;
                    }
                    Err(std::sync::mpsc::RecvTimeoutError::Timeout) => {
                        // No file changes, check if server is still running
                        if server_handle.is_finished() {
                            eprintln!("Server stopped unexpectedly");
                            return Ok(());
                        }
                        // Continue waiting
                        continue;
                    }
                    Err(std::sync::mpsc::RecvTimeoutError::Disconnected) => {
                        eprintln!("File watcher disconnected");
                        return Ok(());
                    }
                }
            }
        }
    } else {
        // Normal mode: start server and block
        tokio::runtime::Runtime::new()?.block_on(async {
            start_server(config).await
        })?;
    }

    Ok(())
}
