use rustyline::error::ReadlineError;
use rustyline::DefaultEditor;
use std::path::PathBuf;
use std::env;
use crate::scope::Scope;
use crate::types::QValue;
use crate::eval_expression;

/// Get the path to the history file
fn get_history_path() -> Option<PathBuf> {
    // Try HOME on Unix-like systems, USERPROFILE on Windows
    let home = env::var("HOME")
        .or_else(|_| env::var("USERPROFILE"))
        .ok()?;

    let mut path = PathBuf::from(home);
    path.push(".quest_history");
    Some(path)
}

/// Run the Quest REPL (Read-Eval-Print Loop)
pub fn run_repl() -> rustyline::Result<()> {
    println!("Quest REPL v{}", env!("CARGO_PKG_VERSION"));
    println!("(type ':help' for help, ':exit' or ':quit' to exit)");
    println!();

    let mut rl = DefaultEditor::new()?;

    // Load history from file
    if let Some(history_path) = get_history_path() {
        // Ignore errors if history file doesn't exist yet
        let _ = rl.load_history(&history_path);
    }

    let mut buffer = String::new();
    let mut nesting_level = 0;
    let mut scope = Scope::new();

    loop {
        let prompt = if nesting_level > 0 {
            format!("{}> ", ".".repeat(nesting_level))
        } else {
            "quest> ".to_string()
        };

        let readline = rl.readline(&prompt);
        match readline {
            Ok(line) => {
                let trimmed = line.trim();

                if trimmed.is_empty() && nesting_level == 0 {
                    continue;
                }

                // Handle commands starting with : (only at top level)
                if trimmed.starts_with(':') && nesting_level == 0 {
                    match trimmed {
                        ":exit" | ":quit" => {
                            println!("Goodbye!");
                            break;
                        }
                        ":help" => {
                            print_help();
                            continue;
                        }
                        _ => {
                            eprintln!("Unknown command: {}. Type ':help' for available commands.", trimmed);
                            continue;
                        }
                    }
                }

                // Track nesting level for multi-line constructs
                let line_lower = trimmed.to_lowercase();

                // Keywords that start a block and increase nesting
                if line_lower.starts_with("if ")
                    || line_lower.starts_with("fun ")
                    || line_lower.starts_with("type ")
                    || line_lower.starts_with("trait ")
                    || line_lower.starts_with("while ")
                    || line_lower.starts_with("for ")
                    || line_lower.starts_with("try")
                    || line_lower.starts_with("pub type ")
                    || line_lower.starts_with("pub trait ")
                    || line_lower.starts_with("pub fun ")
                {
                    nesting_level += 1;
                }

                // Keywords that don't change nesting but indicate we're in a block
                if line_lower.starts_with("elif ")
                    || line_lower.starts_with("else")
                    || line_lower.starts_with("catch ")
                    || line_lower.starts_with("ensure")
                {
                    // These don't change nesting, but indicate we're still in a block
                }

                // Keywords that end a block and decrease nesting
                if trimmed == "end" {
                    nesting_level = nesting_level.saturating_sub(1);
                }

                // Add to buffer
                if !buffer.is_empty() {
                    buffer.push('\n');
                }
                buffer.push_str(trimmed);

                // If we're at nesting level 0, evaluate the complete statement
                if nesting_level == 0 && !buffer.is_empty() {
                    rl.add_history_entry(&buffer)?;

                    match eval_expression(&buffer, &mut scope) {
                        Ok(result) => {
                            // Don't print nil results (from statements like puts)
                            if !matches!(result, QValue::Nil(_)) {
                                // Special case: if calling ._doc(), print string without quotes
                                if buffer.trim().ends_with("._doc()") && matches!(result, QValue::Str(_)) {
                                    if let QValue::Str(s) = result {
                                        println!("{}", s.value);
                                    }
                                } else {
                                    // Always use the _rep() method for REPL output
                                    println!("{}", result.as_obj()._rep());
                                }
                            }
                        }
                        Err(e) => eprintln!("Error: {}", e),
                    }

                    // Clear buffer for next statement
                    buffer.clear();
                }
            }
            Err(ReadlineError::Interrupted) => {
                println!("^C");
                break;
            }
            Err(ReadlineError::Eof) => {
                println!("^D");
                break;
            }
            Err(err) => {
                eprintln!("Error: {:?}", err);
                break;
            }
        }
    }

    // Save history to file before exiting
    if let Some(history_path) = get_history_path() {
        // Ignore errors when saving history
        let _ = rl.save_history(&history_path);
    }

    Ok(())
}

/// Print help message for REPL - displayed when user types :help inside the REPL
pub fn print_help() {
    println!("Quest REPL Commands:");
    println!("  :help    - Show this help message");
    println!("  :exit    - Exit the REPL");
    println!("  :quit    - Exit the REPL");
    println!();
    println!("Supported operators:");
    println!("  Arithmetic: + - * / %");
    println!("  Comparison: == != < > <= >=");
    println!("  Logical: and or !");
    println!("  Bitwise: & |");
    println!();
    println!("Number methods:");
    println!("  Arithmetic: plus(n) minus(n) times(n) div(n) mod(n)");
    println!("  Comparison: eq(n) neq(n) gt(n) lt(n) gte(n) lte(n)");
    println!();
    println!("Boolean methods:");
    println!("  eq(b) neq(b)");
    println!();
    println!("String methods:");
    println!("  len() concat(s) upper() lower() eq(s) neq(s)");
    println!();
    println!("Built-in functions:");
    println!("  puts(...)  - Print values with newline");
    println!("  print(...) - Print values without newline");
    println!();
    println!("Control flow:");
    println!("  if condition");
    println!("    statements");
    println!("  elif condition");
    println!("    statements");
    println!("  else");
    println!("    statements");
    println!("  end");
    println!();
    println!("  Inline: value if condition else other_value");
    println!();
    println!("Examples:");
    println!("  puts(\"Hello World\")");
    println!("  puts(\"Answer: \", 42)");
    println!("  2 + 3 * 4        or  2.plus(3.times(4))");
    println!("  \"yes\" if true else \"no\"");
    println!("  if 5.gt(3)");
    println!("    puts(\"5 is greater\")");
    println!("  end");
}

/// Display the main help message - shown when user runs `quest --help` or `quest -h`
pub fn show_help() {
    println!("Quest - A vibe coded scripting language focused on developer happiness.");
    println!();
    println!("USAGE:");
    println!("    quest [OPTIONS] [FILE] [ARGS...]");
    println!("    quest [COMMAND] [ARGS...]");
    println!();
    println!("MODES:");
    println!("    quest              Start interactive REPL");
    println!("    quest <file.q>     Execute a Quest script file");
    println!("    quest run <name>   Run a script from quest.toml");
    println!("    cat file.q | quest Read and execute from stdin");
    println!();
    println!("OPTIONS:");
    println!("    -h, --help         Display this help message");
    println!("    -v, --version      Display version information");
    println!("        --search-path  Display module search paths");
    println!();
    println!("COMMANDS:");
    println!("    run <script_name> [args...]");
    println!("        Execute a named script defined in quest.toml");
    println!("        Similar to 'npm run' - looks up the script path");
    println!("        and executes it with optional arguments.");
    println!();
    println!("        Example quest.toml:");
    println!("            [scripts]");
    println!("            test = \"scripts/test.q\"");
    println!("            install = \"cargo install --path .\"");
    println!();
    println!("        Usage:");
    println!("            quest run test");
    println!("            quest run install");
    println!();
    println!("ARGUMENTS:");
    println!("    When running a script file, arguments are accessible via:");
    println!("        sys.argv - Array of arguments (including script name)");
    println!("        sys.argc - Number of arguments");
    println!();
    println!("EXAMPLES:");
    println!("    quest                      # Start REPL");
    println!("    quest script.q             # Run script.q");
    println!("    quest script.q arg1 arg2   # Run with arguments");
    println!("    quest run test             # Run 'test' from quest.toml");
    println!("    echo 'puts(\"hi\")' | quest  # Execute from stdin");
    println!();
    println!("For more information, visit: https://github.com/quest-lang/quest");
}
