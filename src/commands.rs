use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::Duration;
use serde::Deserialize;
use toml;
use notify::{Watcher, RecursiveMode, Event, EventKind};
use crate::scope::Scope;
use crate::types::{QNil, QValue};
use crate::{QuestParser, Rule, eval_pair, SCRIPT_ARGS, SCRIPT_PATH};
use crate::server::{ServerConfig, start_server, start_server_with_shutdown};
use crate::control_flow::{EvalError, ControlFlow};
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
            match eval_pair(statement, &mut scope) {
                Ok(val) => _last_result = val,
                Err(EvalError::ControlFlow(ControlFlow::FunctionReturn(_))) => {
                    // QEP-056: Top-level return: exit script cleanly (Bug #021 fix)
                    // This allows scripts to use `return` to exit early,
                    // similar to Python, Ruby, and other scripting languages
                    return Ok(());
                }
                Err(e) => return Err(e.to_string()),
            }
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

/// Handle the 'quest test [OPTIONS] [PATHS...]' command
pub fn handle_test_command(args: &[String]) -> Result<(), Box<dyn std::error::Error>> {
    // Build the test runner script inline
    let test_script = r#"
use "std/test"
use "std/sys"
use "std/io" as io
use "std/toml" as toml

# Load configuration from quest.toml if it exists
let config = {}
if io.exists("quest.toml")
    let content = io.read("quest.toml")
    let parsed = toml.parse(content)
    if parsed.contains("test")
        config = parsed["test"]
    end
end

# Get config values with defaults
fun get_config(key, default)
    if config.contains(key)
        return config[key]
    end
    return default
end

# Parse command line arguments (override config)
let use_colors = get_config("colors", true)
let use_condensed = get_config("condensed", true)
let capture_output = get_config("capture", "all")
let test_paths = get_config("paths", [])
let filter_tags = get_config("tags", [])
let skip_tags = get_config("skip_tags", [])

# Build test paths array from arguments
let i = 1
while i < sys.argv.len()
    let arg = sys.argv[i]
    if arg == "--help" or arg == "-h"
        puts("Usage: quest test [OPTIONS] [PATHS...]")
        puts("")
        puts("Run Quest test suite")
        puts("")
        puts("Arguments:")
        puts("  [PATHS...]  Test files or directories to run (default: test/)")
        puts("")
        puts("Options:")
        puts("  --no-color         Disable colored output")
        puts("  --verbose, -v      Enable verbose output")
        puts("  --condensed, -c    Enable condensed output (default)")
        puts("  --tag=<name>       Run only tests with this tag")
        puts("  --skip-tag=<name>  Skip tests with this tag")
        puts("  --cap=<mode>       Capture output: all (default), no, 0, 1, stdout, stderr")
        puts("  -h, --help         Print help information")
        sys.exit(0)
    elif arg == "--no-color"
        use_colors = false
    elif arg == "--verbose" or arg == "-v"
        use_condensed = false
    elif arg == "--condensed" or arg == "-c"
        use_condensed = true
    elif arg.startswith("--tag=")
        # Extract tag name after =
        let tag = arg.slice(6, arg.len())
        filter_tags = filter_tags.concat([tag])
    elif arg.startswith("--skip-tag=")
        # Extract tag name after =
        let tag = arg.slice(11, arg.len())
        skip_tags = skip_tags.concat([tag])
    elif arg.startswith("--cap=")
        # Extract capture mode after =
        let mode = arg.slice(6, arg.len())
        capture_output = mode
    elif arg.startswith("--") or arg.startswith("-") and arg != "-v" and arg != "-c" and arg != "-h"
        # Unknown flag
        puts("Error: Unknown flag '" .. arg .. "'")
        puts("")
        puts("Run 'quest test --help' for usage information")
        sys.exit(1)
    else
        # It's a test path (file or directory)
        test_paths = test_paths.concat([arg])
    end
    i = i + 1
end

# If no paths specified, default to test directory or current directory
if test_paths.len() == 0
    if io.is_dir("test")
        test_paths = ["test/"]
    else
        test_paths = ["./"]
    end
end

# Configure test framework
if not use_colors
    test.set_colors(false)
end

if use_condensed
    test.set_condensed(true)
end

if filter_tags.len() > 0
    test.set_filter_tags(filter_tags)
end

if skip_tags.len() > 0
    test.set_skip_tags(skip_tags)
end

# Set output capture mode
test.set_capture(capture_output)

let tests = test.find_tests(test_paths)

# Only filter out directories if we're scanning from current directory
# If user specified specific paths, run all found tests
let filtered_tests = []
if test_paths.len() == 1 and (test_paths[0] == "." or test_paths[0] == "./")
    # Filter out certain test files/directories when scanning everything:
    # - docs, examples, scripts: contain files that aren't proper tests
    filtered_tests = tests.filter(fun (t)
        # Check if path contains excluded directories
        let exclude_dirs = ["docs", "examples", "scripts"]
        let should_exclude = false

        for dir in exclude_dirs
            if t.slice(0, dir.len()) == dir or t.index_of("/" .. dir .. "/") >= 0
                should_exclude = true
            end
        end

        not should_exclude
    end)
else
    # User specified paths, don't filter
    filtered_tests = tests
end

filtered_tests.each(fun (t)
    # Loading the module automatically executes it, registering the tests
    try
        sys.load_module(t)
    catch e
        # Module loading failed - print error with context
        puts("\n" .. test.red("✗ Failed to load module: " .. t))
        puts("  " .. test.red("Error: " .. e.type() .. ": " .. e.message()))

        # Print stack trace if available
        let stack = e.stack()
        if stack != nil and stack.len() > 0
            puts("  Stack trace:")
            stack.each(fun (frame)
                puts("    " .. test.dimmed(frame))
            end)
        end

        # Exit with error status
        puts("")
        sys.exit(1)
    end
end)

# Print overall summary
let status = test.stats()
sys.exit(status)
"#;

    // Create a temporary vector with "quest test" as argv[0] and pass all args
    let mut test_args = vec!["quest test".to_string()];
    test_args.extend_from_slice(args);

    // Run the test script with the provided arguments
    run_script(test_script, &test_args, Some("<test command>"))
        .map_err(|e| {
            if e.starts_with("Error: ") || e.contains(": ") {
                e.into()
            } else {
                format!("Error: {}", e).into()
            }
        })
}

/// Load web configuration from Quest script (QEP-051)
/// Executes the script to load std/web module and extract configuration
fn load_quest_web_config(config: &mut ServerConfig) -> Result<(), String> {
    let mut scope = Scope::new();

    // Set the current script path for relative imports
    let canonical_path = std::path::Path::new(&config.script_path)
        .canonicalize()
        .ok()
        .and_then(|p| p.to_str().map(|s| s.to_string()))
        .unwrap_or_else(|| config.script_path.clone());
    *scope.current_script_path.borrow_mut() = Some(canonical_path);

    // Execute script to load modules and configuration
    let source = config.script_source.trim_end();
    let pairs = QuestParser::parse(Rule::program, source)
        .map_err(|e| format!("Parse error: {}", e))?;

    for pair in pairs {
        if matches!(pair.as_rule(), Rule::EOI) {
            continue;
        }
        for statement in pair.into_inner() {
            if matches!(statement.as_rule(), Rule::EOI) {
                continue;
            }
            eval_pair(statement, &mut scope)?;
        }
    }

    // Load web configuration from std/web module
    crate::server::load_web_config(&mut scope, config)?;

    Ok(())
}

/// Load web configuration from quest.toml
fn load_web_config_from_toml() -> Result<(String, u16), Box<dyn std::error::Error>> {
    // Default values
    let default_host = "127.0.0.1".to_string();
    let default_port = 3000u16;

    // Try to read quest.toml
    let toml_path = Path::new("quest.toml");
    if !toml_path.exists() {
        return Ok((default_host, default_port));
    }

    let content = fs::read_to_string(toml_path)?;
    let config: toml::Value = toml::from_str(&content)?;

    // Extract web configuration from [std.web] section
    // TOML parses [std.web] as nested: {std: {web: {...}}}
    let host = config
        .get("std")
        .and_then(|std| std.get("web"))
        .and_then(|web| web.get("host"))
        .and_then(|h| h.as_str())
        .map(|s| s.to_string())
        .unwrap_or(default_host);

    let port = config
        .get("std")
        .and_then(|std| std.get("web"))
        .and_then(|web| web.get("port"))
        .and_then(|p| p.as_integer())
        .map(|p| p as u16)
        .unwrap_or(default_port);

    Ok((host, port))
}

/// Handle the 'quest serve [OPTIONS] <script>' command
pub fn handle_serve_command(args: &[String]) -> Result<(), Box<dyn std::error::Error>> {
    // Load configuration from quest.toml if it exists
    let (config_host, config_port) = load_web_config_from_toml()?;

    let mut host = config_host;
    let mut port = config_port;
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
                println!("  <SCRIPT>  Path to Quest script file or directory");
                println!("            If directory: looks for index.q first");
                println!("            If no index.q: looks for index.html and serves as static files");
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
    let (resolved_path, serve_static) = if is_dir {
        // If directory, look for index.q first
        let index_q_path = path.join("index.q");
        let index_html_path = path.join("index.html");

        if index_q_path.exists() {
            (index_q_path, false)
        } else if index_html_path.exists() {
            // Found index.html - serve entire directory as static files
            println!("Found index.html - serving directory as static files");
            (index_html_path, true)
        } else {
            return Err(format!("Neither index.q nor index.html found in directory: {}", path.display()).into());
        }
    } else if path.is_file() {
        (path.to_path_buf(), false)
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
    // For static serving, use a minimal dummy script
    let script_source = if serve_static {
        "# Static file server - no Quest handler needed".to_string()
    } else {
        fs::read_to_string(&resolved_path)
            .map_err(|e| format!("Failed to read script '{}': {}", resolved_path.display(), e))?
    };

    // Canonicalize paths that need to be absolute (before changing working directory)
    let canonical_script_path = resolved_path.canonicalize()
        .map_err(|e| format!("Failed to canonicalize script path: {}", e))?;

    let canonical_watch_path = watch_path.canonicalize()
        .map_err(|e| format!("Failed to canonicalize watch path: {}", e))?;

    // Save original project root's lib/ directory for module search path
    // This ensures std library modules can be found after changing directories
    let original_lib_dir = {
        let current_dir = env::current_dir()
            .map_err(|e| format!("Failed to get current directory: {}", e))?;
        let lib_path = current_dir.join("lib");
        if lib_path.is_dir() {
            lib_path.canonicalize()
                .ok()
                .and_then(|p| p.to_str().map(|s| s.to_string()))
        } else {
            None
        }
    };

    // Check for public/ directory if serving from a directory
    let public_dir = if serve_static {
        // For static serving, serve the entire directory
        let canonical_dir = path.canonicalize()
            .map_err(|e| format!("Failed to canonicalize directory: {}", e))?;
        Some(canonical_dir.to_string_lossy().to_string())
    } else if is_dir {
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

    // Add original lib/ directory to QUEST_INCLUDE if it exists
    // This allows modules to be found from the project root even after changing directories
    if let Some(ref lib_dir) = original_lib_dir {
        let separator = if cfg!(windows) { ';' } else { ':' };
        let current_include = env::var("QUEST_INCLUDE").unwrap_or_default();
        let new_include = if current_include.is_empty() {
            lib_dir.clone()
        } else {
            format!("{}{}{}", lib_dir, separator, current_include)
        };
        env::set_var("QUEST_INCLUDE", new_include);
    }

    // Create server config (start with defaults)
    let mut config = ServerConfig {
        host: host.clone(),
        port,
        script_source,
        script_path: canonical_script_path.to_string_lossy().to_string(),
        public_dir,
        static_only: serve_static,
        ..ServerConfig::default()
    };

    // Load web configuration from Quest module (QEP-051)
    // Execute script to load std/web module and extract configuration
    // Skip for static file serving
    if !serve_static {
        if let Err(e) = load_quest_web_config(&mut config) {
            eprintln!("Warning: Failed to load web configuration: {}", e);
            eprintln!("Continuing with defaults...");
        }

        // Validate script has handle_request function (basic check)
        if !config.script_source.contains("handle_request") {
            eprintln!("Warning: Script does not appear to define a handle_request() function");
            eprintln!("The server requires a handle_request(request) function to be defined.");
        }
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
            let config_clone = config.clone();

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

                        // Reload web configuration
                        if let Err(e) = load_quest_web_config(&mut config) {
                            eprintln!("Warning: Failed to reload web configuration: {}", e);
                            eprintln!("Continuing with previous configuration...");
                        }

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
