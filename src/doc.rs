use pest::Parser;
use crate::{QuestParser, Rule, QValue, eval_expression};
use crate::scope::Scope;
use crate::module_loader::load_external_module;

/// Get documentation for a module or item, loading from overlay file
pub fn get_or_load_doc(module_path: &str, item_name: &str) -> String {
    let raw_doc = load_doc_from_overlay(module_path, item_name);
    if raw_doc.is_empty() {
        return raw_doc;
    }

    // Format with Quest's markdown formatter
    match format_with_quest(&raw_doc) {
        Ok(formatted) => formatted,
        Err(e) => {
            eprintln!("Warning: Failed to format documentation: {}", e);
            raw_doc
        }
    }
}

/// Call Quest's doc.format_markdown() to format documentation
pub fn format_with_quest(text: &str) -> Result<String, String> {
    // Create a temporary scope
    let mut scope = Scope::new();

    // Add os module so search paths are available
    let os_module = crate::modules::os::create_os_module();
    scope.set("os", os_module);

    // Load the doc module
    load_external_module(&mut scope, "std/doc", "doc")?;

    // Escape the text for use in Quest string literal
    let escaped = text.replace('\\', "\\\\").replace('"', "\\\"").replace('\n', "\\n");

    // Build Quest code to call format_markdown
    let quest_code = format!(r#"doc.format_markdown("{}")"#, escaped);

    // Evaluate it
    let result = eval_expression(&quest_code, &mut scope)?;

    // Extract the string
    if let QValue::Str(s) = result {
        Ok(s.value)
    } else {
        Err("Expected string result from doc.format_markdown".to_string())
    }
}

/// Load documentation from overlay file
fn load_doc_from_overlay(module_path: &str, item_name: &str) -> String {
    // For builtin modules, try both with and without "std/" prefix
    // This handles the case where parent_type is "math" but overlay is at "lib/std/math.q"
    let paths_to_try = if !module_path.starts_with("std/") {
        vec![
            (format!("lib/std/{}.q", module_path), format!("lib/std/{}/index.q", module_path)),
            (format!("lib/{}.q", module_path), format!("lib/{}/index.q", module_path)),
        ]
    } else {
        vec![
            (format!("lib/{}.q", module_path), format!("lib/{}/index.q", module_path)),
        ]
    };

    let mut overlay_path = None;
    for (file_path, dir_path) in paths_to_try {
        if std::path::Path::new(&file_path).exists() {
            overlay_path = Some(file_path);
            break;
        } else if std::path::Path::new(&dir_path).exists() {
            overlay_path = Some(dir_path);
            break;
        }
    }

    let Some(path) = overlay_path else {
        return String::new();  // No overlay file
    };

    let source = match std::fs::read_to_string(&path) {
        Ok(s) => s,
        Err(_) => return String::new(),
    };

    // Parse file for documentation
    if item_name == "__module__" {
        // Looking for module doc (first string literal in file)
        extract_module_doc(&source)
    } else {
        // Looking for %fun/%type/%trait/%const declaration
        extract_item_doc(&source, item_name)
    }
}

/// Extract module-level documentation (first string literal in file)
fn extract_module_doc(source: &str) -> String {
    // Parse the file
    let pairs = match QuestParser::parse(Rule::program, source) {
        Ok(p) => p,
        Err(_) => return String::new(),
    };

    // Look for first string literal in the program
    for pair in pairs {
        for statement in pair.into_inner() {
            if matches!(statement.as_rule(), Rule::EOI) {
                continue;
            }

            // Check if this statement is an expression_statement containing a string
            if statement.as_rule() == Rule::expression_statement {
                if let Some(expr) = statement.into_inner().next() {
                    if let Some(doc) = try_extract_string(expr) {
                        return doc;
                    }
                }
            }
        }
    }

    String::new()
}

/// Extract documentation for a specific item (from % declarations)
fn extract_item_doc(source: &str, item_name: &str) -> String {
    // Parse the file
    let pairs = match QuestParser::parse(Rule::program, source) {
        Ok(p) => p,
        Err(_) => return String::new(),
    };

    // Look for doc_declaration matching the item name
    for pair in pairs {
        for statement in pair.into_inner() {
            if matches!(statement.as_rule(), Rule::EOI) {
                continue;
            }

            // Check for doc_declaration
            if statement.as_rule() == Rule::statement {
                if let Some(inner) = statement.into_inner().next() {
                    if inner.as_rule() == Rule::doc_declaration {
                        if let Some((name, doc)) = parse_doc_declaration(inner) {
                            if name == item_name {
                                return doc;
                            }
                        }
                    }
                }
            }
        }
    }

    String::new()
}

/// Parse a doc_declaration and extract name and docstring
fn parse_doc_declaration(pair: pest::iterators::Pair<Rule>) -> Option<(String, String)> {
    // doc_declaration contains one of: doc_fun, doc_const, doc_type, doc_trait
    let inner = pair.into_inner().next()?;

    match inner.as_rule() {
        Rule::doc_fun => {
            // %fun name(...) "docstring"
            let mut parts = inner.into_inner();
            let name = parts.next()?.as_str().to_string();
            // Skip parameter_list if present
            let last = parts.last()?;
            let doc = parse_string_literal(last)?;
            Some((name, doc))
        }
        Rule::doc_const => {
            // %const name "docstring"
            let mut parts = inner.into_inner();
            let name = parts.next()?.as_str().to_string();
            let doc_pair = parts.next()?;
            let doc = parse_string_literal(doc_pair)?;
            Some((name, doc))
        }
        Rule::doc_type => {
            // %type name "docstring"
            let mut parts = inner.into_inner();
            let name = parts.next()?.as_str().to_string();
            let doc_pair = parts.next()?;
            let doc = parse_string_literal(doc_pair)?;
            Some((name, doc))
        }
        Rule::doc_trait => {
            // %trait name "docstring"
            let mut parts = inner.into_inner();
            let name = parts.next()?.as_str().to_string();
            let doc_pair = parts.next()?;
            let doc = parse_string_literal(doc_pair)?;
            Some((name, doc))
        }
        _ => None,
    }
}

/// Try to extract a string from an expression
fn try_extract_string(pair: pest::iterators::Pair<Rule>) -> Option<String> {
    match pair.as_rule() {
        Rule::string => parse_string_literal(pair),
        Rule::expression => {
            // Recurse into expression
            let inner = pair.into_inner().next()?;
            try_extract_string(inner)
        }
        Rule::primary => {
            // Recurse into primary
            let inner = pair.into_inner().next()?;
            try_extract_string(inner)
        }
        _ => None,
    }
}

/// Parse a string literal (handles both regular and triple-quoted strings)
fn parse_string_literal(pair: pest::iterators::Pair<Rule>) -> Option<String> {
    if pair.as_rule() != Rule::string {
        return None;
    }

    let s = pair.as_str();

    // Check for triple-quoted string
    if s.starts_with("\"\"\"") && s.ends_with("\"\"\"") && s.len() >= 6 {
        return Some(s[3..s.len() - 3].to_string());
    }

    // Regular string - remove quotes and handle escapes
    if s.starts_with('"') && s.ends_with('"') && s.len() >= 2 {
        let content = &s[1..s.len() - 1];
        return Some(unescape_string(content));
    }

    None
}

/// Unescape a string (handle \n, \t, \r, \\, \")
fn unescape_string(s: &str) -> String {
    let mut result = String::new();
    let mut chars = s.chars();

    while let Some(ch) = chars.next() {
        if ch == '\\' {
            if let Some(next) = chars.next() {
                match next {
                    'n' => result.push('\n'),
                    't' => result.push('\t'),
                    'r' => result.push('\r'),
                    '\\' => result.push('\\'),
                    '"' => result.push('"'),
                    _ => {
                        result.push('\\');
                        result.push(next);
                    }
                }
            }
        } else {
            result.push(ch);
        }
    }

    result
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_unescape_string() {
        assert_eq!(unescape_string("hello\\nworld"), "hello\nworld");
        assert_eq!(unescape_string("tab\\there"), "tab\there");
        assert_eq!(unescape_string("quote\\\"test"), "quote\"test");
        assert_eq!(unescape_string("backslash\\\\test"), "backslash\\test");
    }
}
