use crate::types::{QValue, QModule, QFun, QString, next_object_id};
use crate::scope::Scope;
use pulldown_cmark::{Parser, Options, html};
use std::collections::HashMap;

/// Create the markdown module with to_html function
pub fn create_markdown_module() -> QValue {
    let mut members = HashMap::new();

    // Add module functions
    members.insert("to_html".to_string(), QValue::Fun(QFun {
        name: "to_html".to_string(),
        parent_type: "markdown".to_string(),
        id: next_object_id(),
    }));

    QValue::Module(Box::new(QModule::new("markdown".to_string(), members)))
}

/// Call markdown module functions
pub fn call_markdown_function(func_name: &str, args: Vec<QValue>, _scope: &mut Scope) -> Result<QValue, String> {
    match func_name {
        "markdown.to_html" => markdown_to_html(args),
        _ => Err(format!("Unknown markdown function: {}", func_name)),
    }
}

/// Convert markdown to HTML using pulldown-cmark with Prism-compatible code blocks
fn markdown_to_html(args: Vec<QValue>) -> Result<QValue, String> {
    if args.is_empty() {
        return Err("to_html() requires 1 argument: markdown text".to_string());
    }

    let markdown_text = match &args[0] {
        QValue::Str(s) => s.value.as_str(),
        _ => return Err("to_html() requires a string argument".to_string()),
    };

    // Configure parser options (enable strikethrough, tables, footnotes, etc.)
    let mut options = Options::empty();
    options.insert(Options::ENABLE_STRIKETHROUGH);
    options.insert(Options::ENABLE_TABLES);
    options.insert(Options::ENABLE_FOOTNOTES);
    options.insert(Options::ENABLE_TASKLISTS);
    options.insert(Options::ENABLE_HEADING_ATTRIBUTES);

    // Parse markdown - we'll post-process to add Prism classes
    let parser = Parser::new_ext(&markdown_text, options);

    // Render to HTML
    let mut html_output = String::new();
    html::push_html(&mut html_output, parser);

    // Post-process to add Prism language classes to code blocks
    // Replace <code class="language-xxx"> with <code class="language-xxx">
    // pulldown-cmark already adds language- prefix, so this should work with Prism

    Ok(QValue::Str(QString::new(html_output)))
}
