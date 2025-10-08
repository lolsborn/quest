// System stream types (stdout, stderr, stdin singletons)
use crate::types::*;
use crate::{arg_err, attr_err};
use std::io::{self, Write};

/// QSystemStream - Singleton objects for system I/O streams
#[derive(Debug, Clone)]
pub struct QSystemStream {
    pub stream_id: u8,  // 0=stdout, 1=stderr, 2=stdin
}

impl QSystemStream {
    pub fn stdout() -> Self {
        Self { stream_id: 0 }
    }

    pub fn stderr() -> Self {
        Self { stream_id: 1 }
    }

    pub fn stdin() -> Self {
        Self { stream_id: 2 }
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        // Try QObj trait methods first
        if let Some(result) = try_call_qobj_method(self, method_name, &args) {
            return result;
        }

        match (self.stream_id, method_name) {
            (0 | 1, "write") => {
                if args.len() != 1 {
                    return arg_err!("write expects 1 argument, got {}", args.len());
                }
                let data = args[0].as_str();

                if self.stream_id == 0 {
                    print!("{}", data);
                    io::stdout().flush().ok();
                } else {
                    eprint!("{}", data);
                    io::stderr().flush().ok();
                }

                Ok(QValue::Int(QInt::new(data.len() as i64)))
            }
            (0 | 1, "flush") => {
                if !args.is_empty() {
                    return arg_err!("flush expects 0 arguments, got {}", args.len());
                }

                if self.stream_id == 0 {
                    io::stdout().flush().ok();
                } else {
                    io::stderr().flush().ok();
                }

                Ok(QValue::Nil(QNil))
            }
            (2, "read") => {
                // stdin.read() - read all available input
                if !args.is_empty() {
                    return arg_err!("read expects 0 arguments, got {}", args.len());
                }

                use std::io::Read;
                let mut buffer = String::new();
                io::stdin().read_to_string(&mut buffer)
                    .map_err(|e| format!("Failed to read from stdin: {}", e))?;

                Ok(QValue::Str(QString::new(buffer)))
            }
            (2, "readline") => {
                // stdin.readline() - read one line
                if !args.is_empty() {
                    return arg_err!("readline expects 0 arguments, got {}", args.len());
                }

                use std::io::BufRead;
                let stdin = io::stdin();
                let mut line = String::new();
                stdin.lock().read_line(&mut line)
                    .map_err(|e| format!("Failed to read line from stdin: {}", e))?;

                Ok(QValue::Str(QString::new(line)))
            }
            _ => attr_err!("SystemStream has no method '{}'", method_name)
        }
    }
}

impl QObj for QSystemStream {
    fn cls(&self) -> String {
        match self.stream_id {
            0 => "stdout".to_string(),
            1 => "stderr".to_string(),
            2 => "stdin".to_string(),
            _ => "SystemStream".to_string()
        }
    }

    fn q_type(&self) -> &'static str {
        "SystemStream"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "SystemStream" || type_name == &self.cls()
    }

    fn str(&self) -> String {
        format!("<system {}>", self.cls())
    }

    fn _rep(&self) -> String {
        self.str()
    }

    fn _doc(&self) -> String {
        format!("System {} stream", self.cls())
    }

    fn _id(&self) -> u64 {
        // Singletons have fixed IDs
        self.stream_id as u64
    }
}
