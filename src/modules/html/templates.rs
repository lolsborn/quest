use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use tera::{Tera, Context};
use crate::types::*;
use crate::scope::Scope;
use crate::modules::encoding::json_utils;

/// Wrapper for Tera template engine
#[derive(Clone)]
pub struct QHtmlTemplate {
    tera: Arc<Mutex<Tera>>,
    id: u64,
}

impl std::fmt::Debug for QHtmlTemplate {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("QHtmlTemplate")
            .field("id", &self.id)
            .finish()
    }
}

impl QHtmlTemplate {
    pub fn new(tera: Tera) -> Self {
        QHtmlTemplate {
            tera: Arc::new(Mutex::new(tera)),
            id: next_object_id(),
        }
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        match method_name {
            "render" => {
                if args.len() != 2 {
                    return Err(format!("render expects 2 arguments (template_name, context), got {}", args.len()));
                }
                let template_name = args[0].as_str();
                let context_dict = match &args[1] {
                    QValue::Dict(d) => d,
                    _ => return Err("render expects second argument to be a Dict".to_string()),
                };

                // Convert Quest Dict to Tera Context via serde_json
                let context = dict_to_tera_context(context_dict)?;

                let tera = self.tera.lock().unwrap();
                let rendered = tera.render(&template_name, &context)
                    .map_err(|e| format!("Template error: {}", e))?;

                Ok(QValue::Str(QString::new(rendered)))
            }

            "render_str" => {
                if args.len() != 2 {
                    return Err(format!("render_str expects 2 arguments (template, context), got {}", args.len()));
                }
                let template_str = args[0].as_str();
                let context_dict = match &args[1] {
                    QValue::Dict(d) => d,
                    _ => return Err("render_str expects second argument to be a Dict".to_string()),
                };

                // Convert Quest Dict to Tera Context via serde_json
                let context = dict_to_tera_context(context_dict)?;

                let mut tera = self.tera.lock().unwrap();
                let rendered = tera.render_str(&template_str, &context)
                    .map_err(|e| format!("Template error: {}", e))?;

                Ok(QValue::Str(QString::new(rendered)))
            }

            "add_template" => {
                if args.len() != 2 {
                    return Err(format!("add_template expects 2 arguments (name, content), got {}", args.len()));
                }
                let name = args[0].as_str();
                let content = args[1].as_str();

                let mut tera = self.tera.lock().unwrap();
                tera.add_raw_template(&name, &content)
                    .map_err(|e| format!("Template error: {}", e))?;

                Ok(QValue::Nil(QNil))
            }

            "add_template_file" => {
                if args.len() != 2 {
                    return Err(format!("add_template_file expects 2 arguments (name, path), got {}", args.len()));
                }
                let name = args[0].as_str();
                let path = args[1].as_str();

                // Read file content
                let content = std::fs::read_to_string(&path)
                    .map_err(|e| format!("Failed to read template file: {}", e))?;

                let mut tera = self.tera.lock().unwrap();
                tera.add_raw_template(&name, &content)
                    .map_err(|e| format!("Template error: {}", e))?;

                Ok(QValue::Nil(QNil))
            }

            "get_template_names" => {
                if !args.is_empty() {
                    return Err(format!("get_template_names expects 0 arguments, got {}", args.len()));
                }

                let tera = self.tera.lock().unwrap();
                let names: Vec<QValue> = tera.get_template_names()
                    .map(|name| QValue::Str(QString::new(name.to_string())))
                    .collect();

                Ok(QValue::Array(QArray::new(names)))
            }

            "cls" => Ok(QValue::Str(QString::new("HtmlTemplate".to_string()))),
            "_id" => Ok(QValue::Num(QNum::new(self.id as f64))),
            "_str" => Ok(QValue::Str(QString::new(format!("<HtmlTemplate {}>", self.id)))),
            "_rep" => Ok(QValue::Str(QString::new(format!("<HtmlTemplate {}>", self.id)))),

            _ => Err(format!("Unknown method '{}' on HtmlTemplate", method_name))
        }
    }
}

impl QObj for QHtmlTemplate {
    fn cls(&self) -> String {
        "HtmlTemplate".to_string()
    }

    fn q_type(&self) -> &'static str {
        "HtmlTemplate"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "HtmlTemplate"
    }

    fn _str(&self) -> String {
        format!("<HtmlTemplate {}>", self.id)
    }

    fn _rep(&self) -> String {
        format!("<HtmlTemplate {}>", self.id)
    }

    fn _doc(&self) -> String {
        "HTML template engine instance".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

/// Convert Quest Dict to Tera Context via serde_json
fn dict_to_tera_context(dict: &QDict) -> Result<Context, String> {
    // Convert QDict to serde_json::Value
    let json_value = json_utils::qvalue_to_json(&QValue::Dict(dict.clone()))?;

    // Create Tera context from JSON value
    let context = Context::from_serialize(&json_value)
        .map_err(|e| format!("Failed to create template context: {}", e))?;

    Ok(context)
}

/// Create the templates module
pub fn create_templates_module() -> QValue {
    let mut members = HashMap::new();

    // Add module functions
    members.insert("create".to_string(), QValue::Fun(QFun {
        name: "create".to_string(),
        parent_type: "templates".to_string(),
        doc: "Create a new Tera template engine instance".to_string(),
        id: next_object_id(),
    }));

    members.insert("from_dir".to_string(), QValue::Fun(QFun {
        name: "from_dir".to_string(),
        parent_type: "templates".to_string(),
        doc: "Create a Tera instance from a directory glob pattern".to_string(),
        id: next_object_id(),
    }));

    QValue::Module(QModule::new("templates".to_string(), members))
}

/// Call templates module functions
pub fn call_templates_function(func_name: &str, args: Vec<QValue>, _scope: &mut Scope) -> Result<QValue, String> {
    match func_name {
        "templates.create" => {
            if !args.is_empty() {
                return Err(format!("templates.create expects 0 arguments, got {}", args.len()));
            }

            // Create empty Tera instance
            let tera = Tera::default();
            Ok(QValue::HtmlTemplate(QHtmlTemplate::new(tera)))
        }

        "templates.from_dir" => {
            if args.len() != 1 {
                return Err(format!("templates.from_dir expects 1 argument (pattern), got {}", args.len()));
            }
            let pattern = args[0].as_str();

            // Create Tera instance from glob pattern
            let tera = Tera::new(&pattern)
                .map_err(|e| format!("Failed to create Tera from pattern '{}': {}", pattern, e))?;

            Ok(QValue::HtmlTemplate(QHtmlTemplate::new(tera)))
        }

        _ => Err(format!("Unknown function: {}", func_name))
    }
}
