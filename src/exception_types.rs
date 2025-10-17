// Built-in exception types as Quest objects (QEP-037)
use crate::types::*;
use crate::scope::Scope;
use crate::{arg_err, type_err, attr_err};

/// Register all built-in exception types as global variables
pub fn register_exception_types(scope: &mut Scope) -> Result<(), String> {
    // Register all exception types
    scope.declare("Err", create_exception_type("Err"))?;
    scope.declare("IndexErr", create_exception_type("IndexErr"))?;
    scope.declare("TypeErr", create_exception_type("TypeErr"))?;
    scope.declare("ValueErr", create_exception_type("ValueErr"))?;
    scope.declare("ArgErr", create_exception_type("ArgErr"))?;
    scope.declare("AttrErr", create_exception_type("AttrErr"))?;
    scope.declare("NameErr", create_exception_type("NameErr"))?;
    scope.declare("RuntimeErr", create_exception_type("RuntimeErr"))?;
    scope.declare("IOErr", create_exception_type("IOErr"))?;
    scope.declare("ImportErr", create_exception_type("ImportErr"))?;
    scope.declare("KeyErr", create_exception_type("KeyErr"))?;
    scope.declare("SyntaxErr", create_exception_type("SyntaxErr"))?;
    scope.declare("ConfigurationErr", create_exception_type("ConfigurationErr"))?;

    Ok(())
}

/// Create an exception type object
fn create_exception_type(name: &str) -> QValue {
    let type_obj = QType::with_doc(
        name.to_string(),
        Vec::new(),  // No fields
        Some(format!("{} exception type", name))
    );

    QValue::Type(Box::new(type_obj))
}

/// Call a static method on an exception type (called from main.rs)
pub fn call_exception_static_method(type_name: &str, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
    match method_name {
        "new" => {
            if args.len() != 1 {
                return arg_err!("ArgErr: {}.new expects 1 argument (message), got {}", type_name, args.len());
            }

            let message = match &args[0] {
                QValue::Str(s) => s.value.to_string(),
                _ => return type_err!("TypeErr: Exception message must be str, got {}", args[0].q_type()),
            };

            let exc_type = ExceptionType::from_str(type_name);
            let exception = QException::new(exc_type, message, None, None);
            Ok(QValue::Exception(exception))
        }
        _ => attr_err!("Exception type has no static method '{}'", method_name)
    }
}
