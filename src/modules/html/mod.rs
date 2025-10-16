pub mod templates;
pub mod markdown;

pub use templates::{QHtmlTemplate, create_templates_module, call_templates_function};
pub use markdown::{create_markdown_module, call_markdown_function};
