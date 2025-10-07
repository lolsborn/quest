// Error macros for typed exceptions
// QEP-037: Typed Exception System

/// Raise an IndexErr
#[macro_export]
macro_rules! index_err {
    ($($arg:tt)*) => {
        Err(format!("IndexErr: {}", format!($($arg)*)))
    };
}

/// Raise a TypeErr
#[macro_export]
macro_rules! type_err {
    ($($arg:tt)*) => {
        Err(format!("TypeErr: {}", format!($($arg)*)))
    };
}

/// Raise a ValueErr
#[macro_export]
macro_rules! value_err {
    ($($arg:tt)*) => {
        Err(format!("ValueErr: {}", format!($($arg)*)))
    };
}

/// Raise an ArgErr
#[macro_export]
macro_rules! arg_err {
    ($($arg:tt)*) => {
        Err(format!("ArgErr: {}", format!($($arg)*)))
    };
}

/// Raise an AttrErr
#[macro_export]
macro_rules! attr_err {
    ($($arg:tt)*) => {
        Err(format!("AttrErr: {}", format!($($arg)*)))
    };
}

/// Raise a NameErr
#[macro_export]
macro_rules! name_err {
    ($($arg:tt)*) => {
        Err(format!("NameErr: {}", format!($($arg)*)))
    };
}

/// Raise a RuntimeErr
#[macro_export]
macro_rules! runtime_err {
    ($($arg:tt)*) => {
        Err(format!("RuntimeErr: {}", format!($($arg)*)))
    };
}

/// Raise an IOErr
#[macro_export]
macro_rules! io_err {
    ($($arg:tt)*) => {
        Err(format!("IOErr: {}", format!($($arg)*)))
    };
}

/// Raise an ImportErr
#[macro_export]
macro_rules! import_err {
    ($($arg:tt)*) => {
        Err(format!("ImportErr: {}", format!($($arg)*)))
    };
}

/// Raise a KeyErr
#[macro_export]
macro_rules! key_err {
    ($($arg:tt)*) => {
        Err(format!("KeyErr: {}", format!($($arg)*)))
    };
}

/// Raise a SyntaxErr
#[macro_export]
macro_rules! syntax_err {
    ($($arg:tt)*) => {
        Err(format!("SyntaxErr: {}", format!($($arg)*)))
    };
}
