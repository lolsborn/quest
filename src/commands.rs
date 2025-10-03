use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::PathBuf;
use std::process::Command;
use serde::Deserialize;
use crate::scope::Scope;
use crate::types::{QValue, QNil};
use crate::{QuestParser, Rule, eval_pair, SCRIPT_ARGS, SCRIPT_PATH};
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
