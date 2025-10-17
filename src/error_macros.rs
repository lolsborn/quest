// Error macros for typed exceptions
// QEP-037: Typed Exception System
// QEP-056: Updated to support both String and EvalError return types via .into()

/// Raise an IndexErr
#[macro_export]
macro_rules! index_err {
    ($($arg:tt)*) => {
        Err(format!("IndexErr: {}", format!($($arg)*)).into())
    };
}

/// Raise a TypeErr
#[macro_export]
macro_rules! type_err {
    ($($arg:tt)*) => {
        Err(format!("TypeErr: {}", format!($($arg)*)).into())
    };
}

/// Raise a ValueErr
#[macro_export]
macro_rules! value_err {
    ($($arg:tt)*) => {
        Err(format!("ValueErr: {}", format!($($arg)*)).into())
    };
}

/// Raise an ArgErr
#[macro_export]
macro_rules! arg_err {
    ($($arg:tt)*) => {
        Err(format!("ArgErr: {}", format!($($arg)*)).into())
    };
}

/// Raise an AttrErr
#[macro_export]
macro_rules! attr_err {
    ($($arg:tt)*) => {
        Err(format!("AttrErr: {}", format!($($arg)*)).into())
    };
}

/// Raise a NameErr
#[macro_export]
macro_rules! name_err {
    ($($arg:tt)*) => {
        Err(format!("NameErr: {}", format!($($arg)*)).into())
    };
}

/// Raise a RuntimeErr
#[macro_export]
macro_rules! runtime_err {
    ($($arg:tt)*) => {
        Err(format!("RuntimeErr: {}", format!($($arg)*)).into())
    };
}

/// Raise an IOErr
#[macro_export]
macro_rules! io_err {
    ($($arg:tt)*) => {
        Err(format!("IOErr: {}", format!($($arg)*)).into())
    };
}

/// Raise an ImportErr
#[macro_export]
macro_rules! import_err {
    ($($arg:tt)*) => {
        Err(format!("ImportErr: {}", format!($($arg)*)).into())
    };
}

/// Raise a KeyErr
#[macro_export]
macro_rules! key_err {
    ($($arg:tt)*) => {
        Err(format!("KeyErr: {}", format!($($arg)*)).into())
    };
}

/// Raise a SyntaxErr
#[macro_export]
macro_rules! syntax_err {
    ($($arg:tt)*) => {
        Err(format!("SyntaxErr: {}", format!($($arg)*)).into())
    };
}
