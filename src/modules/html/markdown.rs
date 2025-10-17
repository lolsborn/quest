use crate::types::{QValue, QModule, QFun, QString, next_object_id};
use crate::control_flow::EvalError;
use crate::scope::Scope;
use pulldown_cmark::{Parser, Options, html, Event, Tag, TagEnd, HeadingLevel};
use pulldown_cmark::CowStr;
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
pub fn call_markdown_function(func_name: &str, args: Vec<QValue>, _scope: &mut Scope) -> Result<QValue, EvalError> {
    match func_name {
        "markdown.to_html" => markdown_to_html(args),
        _ => Err(format!("Unknown markdown function: {}", func_name).into()),
    }
}

/// Convert heading text to kebab-case anchor ID
fn to_kebab_case(text: &str) -> String {
    text.to_lowercase()
        .chars()
        .map(|c| {
            if c.is_alphanumeric() {
                c
            } else if c.is_whitespace() || c == '-' {
                '-'
            } else {
                // Remove other special characters
                '\0'
            }
        })
        .filter(|&c| c != '\0')
        .collect::<String>()
        .split('-')
        .filter(|s| !s.is_empty())
        .collect::<Vec<_>>()
        .join("-")
}

/// Convert markdown to HTML using pulldown-cmark with Prism-compatible code blocks and heading anchors
fn markdown_to_html(args: Vec<QValue>) -> Result<QValue, EvalError> {
    if args.is_empty() {
        return Err("to_html() requires 1 argument: markdown text".into());
    }

    let markdown_text = match &args[0] {
        QValue::Str(s) => s.value.as_str(),
        _ => return Err("to_html() requires a string argument".into()),
    };

    // Configure parser options (enable strikethrough, tables, footnotes, etc.)
    let mut options = Options::empty();
    options.insert(Options::ENABLE_STRIKETHROUGH);
    options.insert(Options::ENABLE_TABLES);
    options.insert(Options::ENABLE_FOOTNOTES);
    options.insert(Options::ENABLE_TASKLISTS);
    options.insert(Options::ENABLE_HEADING_ATTRIBUTES);

    // Parse markdown and collect events
    let parser = Parser::new_ext(&markdown_text, options);

    // Transform events to add heading anchors
    let mut events = Vec::new();
    let mut heading_text = String::new();
    let mut in_heading = false;

    for event in parser {
        match event {
            Event::Start(Tag::Heading { level, .. }) => {
                in_heading = true;
                heading_text.clear();
                events.push(Event::Start(Tag::Heading {
                    level,
                    id: None,
                    classes: vec![],
                    attrs: vec![]
                }));
            }
            Event::Text(ref text) if in_heading => {
                heading_text.push_str(text);
                events.push(event.clone());
            }
            Event::End(TagEnd::Heading(level)) => {
                in_heading = false;
                // Only add anchors for H1-H4
                if matches!(level, HeadingLevel::H1 | HeadingLevel::H2 | HeadingLevel::H3 | HeadingLevel::H4) {
                    let anchor_id = to_kebab_case(&heading_text);
                    // Insert anchor link before closing the heading
                    events.push(Event::Html(CowStr::from(format!(
                        " <a href=\"#{}\" class=\"heading-anchor\" aria-label=\"Link to section: {}\">#</a>",
                        anchor_id, heading_text
                    ))));
                }
                events.push(Event::End(TagEnd::Heading(level)));
            }
            _ => events.push(event),
        }
    }

    // Render to HTML
    let mut html_output = String::new();
    html::push_html(&mut html_output, events.into_iter());

    Ok(QValue::Str(QString::new(html_output)))
}
