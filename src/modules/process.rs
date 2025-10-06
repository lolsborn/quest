// std/process - External Process Execution (QEP-012)
use std::collections::HashMap;
use std::process::{Command, Stdio, Child, ChildStdin, ChildStdout, ChildStderr};
use std::io::{Write, Read, BufRead, BufReader};
use std::sync::{Arc, Mutex};
use std::time::Duration;
use std::thread;
use std::sync::mpsc;
use crate::types::*;
use crate::Scope;

// ============================================================================
// ProcessResult Type
// ============================================================================

/// Result from process.run() containing stdout, stderr, and exit code
#[derive(Debug, Clone)]
pub struct QProcessResult {
    pub stdout: String,
    pub stderr: String,
    pub stdout_bytes: Vec<u8>,
    pub stderr_bytes: Vec<u8>,
    pub code: i64,
    pub id: u64,
}

impl QProcessResult {
    pub fn new(stdout: String, stderr: String, stdout_bytes: Vec<u8>, stderr_bytes: Vec<u8>, code: i64) -> Self {
        QProcessResult {
            stdout,
            stderr,
            stdout_bytes,
            stderr_bytes,
            code,
            id: next_object_id(),
        }
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        match method_name {
            "success" => {
                if !args.is_empty() {
                    return Err(format!("success expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Bool(QBool::new(self.code == 0)))
            }
            "stdout" => {
                if !args.is_empty() {
                    return Err(format!("stdout expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Str(QString::new(self.stdout.clone())))
            }
            "stderr" => {
                if !args.is_empty() {
                    return Err(format!("stderr expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Str(QString::new(self.stderr.clone())))
            }
            "stdout_bytes" => {
                if !args.is_empty() {
                    return Err(format!("stdout_bytes expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Bytes(QBytes::new(self.stdout_bytes.clone())))
            }
            "stderr_bytes" => {
                if !args.is_empty() {
                    return Err(format!("stderr_bytes expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Bytes(QBytes::new(self.stderr_bytes.clone())))
            }
            "code" => {
                if !args.is_empty() {
                    return Err(format!("code expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Int(QInt::new(self.code)))
            }
            "_id" => Ok(QValue::Int(QInt::new(self.id as i64))),
            "_str" => Ok(QValue::Str(QString::new(format!("<ProcessResult code={}>", self.code)))),
            "cls" => Ok(QValue::Str(QString::new(self.cls()))),
            "_rep" => Ok(QValue::Str(QString::new(format!("<ProcessResult code={}>", self.code)))),
            _ => Err(format!("Unknown method '{}' on ProcessResult", method_name))
        }
    }
}

impl QObj for QProcessResult {
    fn cls(&self) -> String {
        "ProcessResult".to_string()
    }

    fn q_type(&self) -> &'static str {
        "ProcessResult"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "ProcessResult"
    }

    fn _str(&self) -> String {
        format!("<ProcessResult code={}>", self.code)
    }

    fn _rep(&self) -> String {
        format!("<ProcessResult code={}>", self.code)
    }

    fn _doc(&self) -> String {
        "Result from process execution".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

// ============================================================================
// WritableStream Type (stdin)
// ============================================================================

/// Writable stream for process stdin
#[derive(Debug)]
pub struct QWritableStream {
    stdin: Arc<Mutex<Option<ChildStdin>>>,
    pub id: u64,
}

impl QWritableStream {
    pub fn new(stdin: ChildStdin) -> Self {
        QWritableStream {
            stdin: Arc::new(Mutex::new(Some(stdin))),
            id: next_object_id(),
        }
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        match method_name {
            "write" => {
                if args.len() != 1 {
                    return Err(format!("write expects 1 argument (data), got {}", args.len()));
                }

                let data = match &args[0] {
                    QValue::Str(s) => s.value.as_bytes().to_vec(),
                    QValue::Bytes(b) => b.data.clone(),
                    _ => return Err("write expects string or bytes".to_string()),
                };

                let mut stdin_lock = self.stdin.lock().unwrap();
                if let Some(ref mut stdin) = *stdin_lock {
                    stdin.write_all(&data)
                        .map_err(|e| format!("Failed to write to stdin: {}", e))?;
                    Ok(QValue::Int(QInt::new(data.len() as i64)))
                } else {
                    Err("stdin is closed".to_string())
                }
            }
            "close" => {
                if !args.is_empty() {
                    return Err(format!("close expects 0 arguments, got {}", args.len()));
                }
                let mut stdin_lock = self.stdin.lock().unwrap();
                *stdin_lock = None; // Drop stdin to close it
                Ok(QValue::Nil(QNil))
            }
            "flush" => {
                if !args.is_empty() {
                    return Err(format!("flush expects 0 arguments, got {}", args.len()));
                }
                let mut stdin_lock = self.stdin.lock().unwrap();
                if let Some(ref mut stdin) = *stdin_lock {
                    stdin.flush()
                        .map_err(|e| format!("Failed to flush stdin: {}", e))?;
                }
                Ok(QValue::Nil(QNil))
            }
            "writelines" => {
                if args.len() != 1 {
                    return Err(format!("writelines expects 1 argument (lines array), got {}", args.len()));
                }

                let lines = match &args[0] {
                    QValue::Array(arr) => {
                        let elements = arr.elements.borrow();
                        elements.clone()
                    }
                    _ => return Err("writelines expects array of strings".to_string()),
                };

                let mut stdin_lock = self.stdin.lock().unwrap();
                if let Some(ref mut stdin) = *stdin_lock {
                    for line in &lines {
                        let data = match line {
                            QValue::Str(s) => s.value.as_bytes().to_vec(),
                            _ => return Err("writelines array must contain strings".to_string()),
                        };
                        stdin.write_all(&data)
                            .map_err(|e| format!("Failed to write line: {}", e))?;
                    }
                    Ok(QValue::Nil(QNil))
                } else {
                    Err("stdin is closed".to_string())
                }
            }
            "_id" => Ok(QValue::Int(QInt::new(self.id as i64))),
            "_str" => Ok(QValue::Str(QString::new("<WritableStream>".to_string()))),
            "cls" => Ok(QValue::Str(QString::new("WritableStream".to_string()))),
            "_rep" => Ok(QValue::Str(QString::new("<WritableStream>".to_string()))),
            _ => Err(format!("Unknown method '{}' on WritableStream", method_name))
        }
    }
}

impl Clone for QWritableStream {
    fn clone(&self) -> Self {
        QWritableStream {
            stdin: Arc::clone(&self.stdin),
            id: self.id,
        }
    }
}

impl QObj for QWritableStream {
    fn cls(&self) -> String {
        "WritableStream".to_string()
    }

    fn q_type(&self) -> &'static str {
        "WritableStream"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "WritableStream"
    }

    fn _str(&self) -> String {
        "<WritableStream>".to_string()
    }

    fn _rep(&self) -> String {
        "<WritableStream>".to_string()
    }

    fn _doc(&self) -> String {
        "Writable stream for process stdin".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

// ============================================================================
// ReadableStream Type (stdout/stderr)
// ============================================================================

/// Readable stream for process stdout/stderr
pub struct QReadableStream {
    reader: Arc<Mutex<BufReader<Box<dyn Read + Send>>>>,
    pub id: u64,
}

impl std::fmt::Debug for QReadableStream {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("QReadableStream")
            .field("id", &self.id)
            .finish()
    }
}

impl QReadableStream {
    pub fn from_stdout(stdout: ChildStdout) -> Self {
        QReadableStream {
            reader: Arc::new(Mutex::new(BufReader::new(Box::new(stdout)))),
            id: next_object_id(),
        }
    }

    pub fn from_stderr(stderr: ChildStderr) -> Self {
        QReadableStream {
            reader: Arc::new(Mutex::new(BufReader::new(Box::new(stderr)))),
            id: next_object_id(),
        }
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        match method_name {
            "read" => {
                if args.is_empty() {
                    // Read all
                    let mut reader = self.reader.lock().unwrap();
                    let mut buffer = String::new();
                    reader.read_to_string(&mut buffer)
                        .map_err(|e| format!("Failed to read from stream: {}", e))?;
                    Ok(QValue::Str(QString::new(buffer)))
                } else if args.len() == 1 {
                    // Read n bytes
                    let n = match &args[0] {
                        QValue::Int(i) => i.value as usize,
                        _ => return Err("read expects int argument for size".to_string()),
                    };
                    let mut reader = self.reader.lock().unwrap();
                    let mut buffer = vec![0u8; n];
                    let bytes_read = reader.read(&mut buffer)
                        .map_err(|e| format!("Failed to read from stream: {}", e))?;
                    buffer.truncate(bytes_read);
                    let s = String::from_utf8_lossy(&buffer).to_string();
                    Ok(QValue::Str(QString::new(s)))
                } else {
                    Err(format!("read expects 0 or 1 arguments, got {}", args.len()))
                }
            }
            "read_bytes" => {
                if args.is_empty() {
                    // Read all bytes
                    let mut reader = self.reader.lock().unwrap();
                    let mut buffer = Vec::new();
                    reader.read_to_end(&mut buffer)
                        .map_err(|e| format!("Failed to read from stream: {}", e))?;
                    Ok(QValue::Bytes(QBytes::new(buffer)))
                } else if args.len() == 1 {
                    // Read n bytes
                    let n = match &args[0] {
                        QValue::Int(i) => i.value as usize,
                        _ => return Err("read_bytes expects int argument for size".to_string()),
                    };
                    let mut reader = self.reader.lock().unwrap();
                    let mut buffer = vec![0u8; n];
                    let bytes_read = reader.read(&mut buffer)
                        .map_err(|e| format!("Failed to read from stream: {}", e))?;
                    buffer.truncate(bytes_read);
                    Ok(QValue::Bytes(QBytes::new(buffer)))
                } else {
                    Err(format!("read_bytes expects 0 or 1 arguments, got {}", args.len()))
                }
            }
            "readline" => {
                if !args.is_empty() {
                    return Err(format!("readline expects 0 arguments, got {}", args.len()));
                }
                let mut reader = self.reader.lock().unwrap();
                let mut line = String::new();
                let bytes_read = reader.read_line(&mut line)
                    .map_err(|e| format!("Failed to read line: {}", e))?;
                if bytes_read == 0 {
                    Ok(QValue::Str(QString::new(String::new())))
                } else {
                    Ok(QValue::Str(QString::new(line)))
                }
            }
            "readlines" => {
                if !args.is_empty() {
                    return Err(format!("readlines expects 0 arguments, got {}", args.len()));
                }
                let mut reader = self.reader.lock().unwrap();
                let mut lines = Vec::new();
                loop {
                    let mut line = String::new();
                    let bytes_read = reader.read_line(&mut line)
                        .map_err(|e| format!("Failed to read lines: {}", e))?;
                    if bytes_read == 0 {
                        break;
                    }
                    lines.push(QValue::Str(QString::new(line)));
                }
                Ok(QValue::Array(QArray::new(lines)))
            }
            "_id" => Ok(QValue::Int(QInt::new(self.id as i64))),
            "_str" => Ok(QValue::Str(QString::new("<ReadableStream>".to_string()))),
            "cls" => Ok(QValue::Str(QString::new("ReadableStream".to_string()))),
            "_rep" => Ok(QValue::Str(QString::new("<ReadableStream>".to_string()))),
            _ => Err(format!("Unknown method '{}' on ReadableStream", method_name))
        }
    }
}

impl Clone for QReadableStream {
    fn clone(&self) -> Self {
        QReadableStream {
            reader: Arc::clone(&self.reader),
            id: self.id,
        }
    }
}

impl QObj for QReadableStream {
    fn cls(&self) -> String {
        "ReadableStream".to_string()
    }

    fn q_type(&self) -> &'static str {
        "ReadableStream"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "ReadableStream"
    }

    fn _str(&self) -> String {
        "<ReadableStream>".to_string()
    }

    fn _rep(&self) -> String {
        "<ReadableStream>".to_string()
    }

    fn _doc(&self) -> String {
        "Readable stream for process output".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

// ============================================================================
// Process Type
// ============================================================================

/// Process handle for spawned subprocess
pub struct QProcess {
    child: Arc<Mutex<Option<Child>>>,
    pub stdin: QWritableStream,
    pub stdout: QReadableStream,
    pub stderr: QReadableStream,
    pid: u32,
    pub id: u64,
}

impl std::fmt::Debug for QProcess {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("QProcess")
            .field("pid", &self.pid)
            .field("id", &self.id)
            .finish()
    }
}

impl QProcess {
    pub fn new(mut child: Child) -> Result<Self, String> {
        let pid = child.id();

        let stdin = child.stdin.take()
            .ok_or("Failed to capture stdin")?;
        let stdout = child.stdout.take()
            .ok_or("Failed to capture stdout")?;
        let stderr = child.stderr.take()
            .ok_or("Failed to capture stderr")?;

        Ok(QProcess {
            child: Arc::new(Mutex::new(Some(child))),
            stdin: QWritableStream::new(stdin),
            stdout: QReadableStream::from_stdout(stdout),
            stderr: QReadableStream::from_stderr(stderr),
            pid,
            id: next_object_id(),
        })
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        match method_name {
            "wait" => {
                if !args.is_empty() {
                    return Err(format!("wait expects 0 arguments, got {}", args.len()));
                }
                let mut child_lock = self.child.lock().unwrap();
                if let Some(mut child) = child_lock.take() {
                    let status = child.wait()
                        .map_err(|e| format!("Failed to wait for process: {}", e))?;
                    let code = status.code().unwrap_or(-1);
                    Ok(QValue::Int(QInt::new(code as i64)))
                } else {
                    Err("Process already waited on".to_string())
                }
            }
            "wait_with_timeout" => {
                if args.len() != 1 {
                    return Err(format!("wait_with_timeout expects 1 argument (seconds), got {}", args.len()));
                }

                let timeout_secs = match &args[0] {
                    QValue::Int(i) => {
                        if i.value <= 0 {
                            return Err("timeout must be positive".to_string());
                        }
                        Duration::from_secs(i.value as u64)
                    }
                    QValue::Float(f) => {
                        if f.value <= 0.0 {
                            return Err("timeout must be positive".to_string());
                        }
                        Duration::from_secs_f64(f.value)
                    }
                    _ => return Err("wait_with_timeout expects int or float (seconds)".to_string()),
                };

                let mut child_lock = self.child.lock().unwrap();
                if let Some(mut child) = child_lock.take() {
                    // Use channel for timeout
                    let (tx, rx) = mpsc::channel();

                    thread::spawn(move || {
                        let status = child.wait();
                        let _ = tx.send(status);
                    });

                    match rx.recv_timeout(timeout_secs) {
                        Ok(Ok(status)) => {
                            let code = status.code().unwrap_or(-1);
                            Ok(QValue::Int(QInt::new(code as i64)))
                        }
                        Ok(Err(e)) => Err(format!("Failed to wait for process: {}", e)),
                        Err(_) => {
                            // Timeout - return nil
                            // Note: Process is still running, child handle moved to thread
                            Ok(QValue::Nil(QNil))
                        }
                    }
                } else {
                    Err("Process already waited on".to_string())
                }
            }
            "pid" => {
                if !args.is_empty() {
                    return Err(format!("pid expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Int(QInt::new(self.pid as i64)))
            }
            "communicate" => {
                if args.len() != 1 {
                    return Err(format!("communicate expects 1 argument (input), got {}", args.len()));
                }

                // Validate input type
                match &args[0] {
                    QValue::Str(_) | QValue::Bytes(_) => {},
                    _ => return Err("communicate expects string or bytes".to_string()),
                };

                // Write to stdin
                let stdin_result = self.stdin.call_method("write", vec![args[0].clone()]);
                if let Err(e) = stdin_result {
                    // If stdin write fails, still try to read output
                    eprintln!("Warning: Failed to write to stdin: {}", e);
                }
                self.stdin.call_method("close", vec![])?;

                // Read stdout and stderr
                let stdout_str = match self.stdout.call_method("read", vec![])? {
                    QValue::Str(s) => (*s.value).clone(),
                    _ => String::new(),
                };

                let stderr_str = match self.stderr.call_method("read", vec![])? {
                    QValue::Str(s) => (*s.value).clone(),
                    _ => String::new(),
                };

                // Wait for process
                let exit_code = match self.call_method("wait", vec![])? {
                    QValue::Int(i) => i.value,
                    _ => -1,
                };

                // Return dict with stdout, stderr, code
                let mut result_map = HashMap::new();
                result_map.insert("stdout".to_string(), QValue::Str(QString::new(stdout_str)));
                result_map.insert("stderr".to_string(), QValue::Str(QString::new(stderr_str)));
                result_map.insert("code".to_string(), QValue::Int(QInt::new(exit_code)));

                Ok(QValue::Dict(Box::new(QDict::new(result_map))))
            }
            "kill" => {
                if !args.is_empty() {
                    return Err(format!("kill expects 0 arguments, got {}", args.len()));
                }
                let mut child_lock = self.child.lock().unwrap();
                if let Some(ref mut child) = *child_lock {
                    child.kill()
                        .map_err(|e| format!("Failed to kill process: {}", e))?;
                }
                Ok(QValue::Nil(QNil))
            }
            "terminate" => {
                if !args.is_empty() {
                    return Err(format!("terminate expects 0 arguments, got {}", args.len()));
                }

                #[cfg(unix)]
                {
                    let mut child_lock = self.child.lock().unwrap();
                    if let Some(ref mut child) = *child_lock {
                        // Kill the process
                        let _ = child.kill();
                    }
                    Ok(QValue::Nil(QNil))
                }

                #[cfg(windows)]
                {
                    // On Windows, just use kill() (TerminateProcess)
                    let mut child_lock = self.child.lock().unwrap();
                    if let Some(ref mut child) = *child_lock {
                        child.kill()
                            .map_err(|e| format!("Failed to terminate process: {}", e))?;
                    }
                    Ok(QValue::Nil(QNil))
                }

                #[cfg(not(any(unix, windows)))]
                {
                    Err("terminate not supported on this platform".to_string())
                }
            }
            "_enter" => {
                // Context manager entry - return self
                if !args.is_empty() {
                    return Err(format!("_enter expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Process(self.clone()))
            }
            "_exit" => {
                // Context manager exit - wait for process to ensure cleanup
                if !args.is_empty() {
                    return Err(format!("_exit expects 0 arguments, got {}", args.len()));
                }
                let mut child_lock = self.child.lock().unwrap();
                if let Some(mut child) = child_lock.take() {
                    let _ = child.wait(); // Ignore errors on exit
                }
                Ok(QValue::Nil(QNil))
            }
            "_id" => Ok(QValue::Int(QInt::new(self.id as i64))),
            "_str" => Ok(QValue::Str(QString::new(format!("<Process pid={}>", self.pid)))),
            "cls" => Ok(QValue::Str(QString::new("Process".to_string()))),
            "_rep" => Ok(QValue::Str(QString::new(format!("<Process pid={}>", self.pid)))),
            _ => Err(format!("Unknown method '{}' on Process", method_name))
        }
    }
}

impl Clone for QProcess {
    fn clone(&self) -> Self {
        QProcess {
            child: Arc::clone(&self.child),
            stdin: self.stdin.clone(),
            stdout: self.stdout.clone(),
            stderr: self.stderr.clone(),
            pid: self.pid,
            id: self.id,
        }
    }
}

impl QObj for QProcess {
    fn cls(&self) -> String {
        "Process".to_string()
    }

    fn q_type(&self) -> &'static str {
        "Process"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "Process"
    }

    fn _str(&self) -> String {
        format!("<Process pid={}>", self.pid)
    }

    fn _rep(&self) -> String {
        format!("<Process pid={}>", self.pid)
    }

    fn _doc(&self) -> String {
        "Spawned subprocess".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

/// Create the process module
pub fn create_process_module() -> QValue {
    let mut members = HashMap::new();

    members.insert("run".to_string(), create_fn("process", "run"));
    members.insert("spawn".to_string(), create_fn("process", "spawn"));
    members.insert("check_run".to_string(), create_fn("process", "check_run"));
    members.insert("shell".to_string(), create_fn("process", "shell"));
    members.insert("pipeline".to_string(), create_fn("process", "pipeline"));

    QValue::Module(Box::new(QModule::new("process".to_string(), members)))
}

/// Handle process.* function calls
pub fn call_process_function(func_name: &str, args: Vec<QValue>, _scope: &mut Scope) -> Result<QValue, String> {
    match func_name {
        "process.run" => {
            // process.run(command: Array[Str], options?: Dict) -> ProcessResult
            if args.is_empty() || args.len() > 2 {
                return Err(format!("process.run expects 1 or 2 arguments (command, options?), got {}", args.len()));
            }

            // Parse command array - extract String values from Rc<String>
            let command = match &args[0] {
                QValue::Array(arr) => {
                    let elements = arr.elements.borrow();
                    let mut cmd_parts = Vec::new();
                    for elem in elements.iter() {
                        match elem {
                            QValue::Str(s) => cmd_parts.push((*s.value).clone()),
                            _ => return Err("process.run command must be array of strings".to_string()),
                        }
                    }
                    cmd_parts
                }
                _ => return Err("process.run expects array as first argument".to_string()),
            };

            if command.is_empty() {
                return Err("process.run command array cannot be empty".to_string());
            }

            // Parse options dict
            let mut cwd: Option<String> = None;
            let mut env: Option<HashMap<String, String>> = None;
            let mut stdin_data: Option<Vec<u8>> = None;
            let mut timeout: Option<Duration> = None;

            if args.len() == 2 {
                match &args[1] {
                    QValue::Dict(dict) => {
                        // cwd option
                        if let Some(cwd_val) = dict.map.get("cwd") {
                            match cwd_val {
                                QValue::Str(s) => cwd = Some((*s.value).clone()),
                                _ => return Err("process.run cwd option must be string".to_string()),
                            }
                        }

                        // env option
                        if let Some(env_val) = dict.map.get("env") {
                            match env_val {
                                QValue::Dict(env_dict) => {
                                    let mut env_map = HashMap::new();
                                    for (k, v) in env_dict.map.iter() {
                                        match v {
                                            QValue::Str(s) => {
                                                env_map.insert(k.clone(), (*s.value).clone());
                                            }
                                            _ => return Err("process.run env values must be strings".to_string()),
                                        }
                                    }
                                    env = Some(env_map);
                                }
                                _ => return Err("process.run env option must be dict".to_string()),
                            }
                        }

                        // stdin option
                        if let Some(stdin_val) = dict.map.get("stdin") {
                            match stdin_val {
                                QValue::Str(s) => stdin_data = Some(s.value.as_bytes().to_vec()),
                                QValue::Bytes(b) => stdin_data = Some(b.data.clone()),
                                _ => return Err("process.run stdin option must be string or bytes".to_string()),
                            }
                        }

                        // timeout option
                        if let Some(timeout_val) = dict.map.get("timeout") {
                            match timeout_val {
                                QValue::Int(secs) => {
                                    if secs.value <= 0 {
                                        return Err("timeout must be positive number of seconds".to_string());
                                    }
                                    timeout = Some(Duration::from_secs(secs.value as u64));
                                }
                                QValue::Float(secs) => {
                                    if secs.value <= 0.0 {
                                        return Err("timeout must be positive number of seconds".to_string());
                                    }
                                    timeout = Some(Duration::from_secs_f64(secs.value));
                                }
                                _ => return Err("process.run timeout option must be int or float (seconds)".to_string()),
                            }
                        }
                    }
                    _ => return Err("process.run options must be dict".to_string()),
                }
            }

            // Build command (command is Vec<String>)
            let mut cmd = Command::new(&command[0]);
            if command.len() > 1 {
                for arg in &command[1..] {
                    cmd.arg(arg);
                }
            }

            // Apply options
            if let Some(dir) = cwd {
                cmd.current_dir(dir);
            }

            if let Some(env_vars) = env {
                cmd.env_clear();
                for (k, v) in env_vars {
                    cmd.env(k, v);
                }
            }

            // Configure stdin
            if stdin_data.is_some() {
                cmd.stdin(Stdio::piped());
            }

            // Capture stdout and stderr
            cmd.stdout(Stdio::piped());
            cmd.stderr(Stdio::piped());

            // Spawn process
            let mut child = cmd.spawn()
                .map_err(|e| format!("Failed to spawn process '{}': {}", command[0], e))?;

            // Write to stdin if provided
            if let Some(data) = stdin_data {
                if let Some(mut stdin) = child.stdin.take() {
                    stdin.write_all(&data)
                        .map_err(|e| format!("Failed to write to stdin: {}", e))?;
                }
            }

            // Wait for process with optional timeout
            let output = if let Some(timeout_duration) = timeout {
                // Use thread + channel for timeout enforcement
                let (tx, rx) = mpsc::channel();

                thread::spawn(move || {
                    let result = child.wait_with_output();
                    let _ = tx.send(result);
                });

                match rx.recv_timeout(timeout_duration) {
                    Ok(result) => result.map_err(|e| format!("Failed to wait for process: {}", e))?,
                    Err(_) => {
                        // Timeout occurred - process is still running
                        return Err(format!("Process exceeded timeout of {} seconds", timeout_duration.as_secs()));
                    }
                }
            } else {
                // No timeout, wait normally
                child.wait_with_output()
                    .map_err(|e| format!("Failed to wait for process: {}", e))?
            };

            // Convert to ProcessResult struct
            let stdout_str = String::from_utf8_lossy(&output.stdout).to_string();
            let stderr_str = String::from_utf8_lossy(&output.stderr).to_string();
            let exit_code = output.status.code().unwrap_or(-1);

            // Create ProcessResult
            let result = QProcessResult::new(
                stdout_str,
                stderr_str,
                output.stdout.clone(),
                output.stderr,
                exit_code as i64
            );

            Ok(QValue::ProcessResult(result))
        }

        "process.spawn" => {
            // process.spawn(command: Array[Str], options?: Dict) -> Process
            if args.is_empty() || args.len() > 2 {
                return Err(format!("process.spawn expects 1 or 2 arguments (command, options?), got {}", args.len()));
            }

            // Parse command array
            let command = match &args[0] {
                QValue::Array(arr) => {
                    let elements = arr.elements.borrow();
                    let mut cmd_parts = Vec::new();
                    for elem in elements.iter() {
                        match elem {
                            QValue::Str(s) => cmd_parts.push((*s.value).clone()),
                            _ => return Err("process.spawn command must be array of strings".to_string()),
                        }
                    }
                    cmd_parts
                }
                _ => return Err("process.spawn expects array as first argument".to_string()),
            };

            if command.is_empty() {
                return Err("process.spawn command array cannot be empty".to_string());
            }

            // Parse options dict
            let mut cwd: Option<String> = None;
            let mut env: Option<HashMap<String, String>> = None;

            if args.len() == 2 {
                match &args[1] {
                    QValue::Dict(dict) => {
                        // cwd option
                        if let Some(cwd_val) = dict.map.get("cwd") {
                            match cwd_val {
                                QValue::Str(s) => cwd = Some((*s.value).clone()),
                                _ => return Err("process.spawn cwd option must be string".to_string()),
                            }
                        }

                        // env option
                        if let Some(env_val) = dict.map.get("env") {
                            match env_val {
                                QValue::Dict(env_dict) => {
                                    let mut env_map = HashMap::new();
                                    for (k, v) in env_dict.map.iter() {
                                        match v {
                                            QValue::Str(s) => {
                                                env_map.insert(k.clone(), (*s.value).clone());
                                            }
                                            _ => return Err("process.spawn env values must be strings".to_string()),
                                        }
                                    }
                                    env = Some(env_map);
                                }
                                _ => return Err("process.spawn env option must be dict".to_string()),
                            }
                        }
                    }
                    _ => return Err("process.spawn options must be dict".to_string()),
                }
            }

            // Build command
            let mut cmd = Command::new(&command[0]);
            if command.len() > 1 {
                for arg in &command[1..] {
                    cmd.arg(arg);
                }
            }

            // Apply options
            if let Some(dir) = cwd {
                cmd.current_dir(dir);
            }

            if let Some(env_vars) = env {
                cmd.env_clear();
                for (k, v) in env_vars {
                    cmd.env(k, v);
                }
            }

            // Configure stdin, stdout, stderr as piped
            cmd.stdin(Stdio::piped());
            cmd.stdout(Stdio::piped());
            cmd.stderr(Stdio::piped());

            // Spawn process
            let child = cmd.spawn()
                .map_err(|e| format!("Failed to spawn process '{}': {}", command[0], e))?;

            // Create Process object
            let process = QProcess::new(child)?;
            Ok(QValue::Process(process))
        }

        "process.check_run" => {
            // process.check_run(command, options?) - Runs command, raises error on non-zero exit
            // Returns stdout string on success
            if args.is_empty() || args.len() > 2 {
                return Err(format!("process.check_run expects 1 or 2 arguments (command, options?), got {}", args.len()));
            }

            // Use process.run() to execute
            let result = call_process_function("process.run", args, _scope)?;

            // Extract result fields
            match result {
                QValue::ProcessResult(ref pr) => {
                    if pr.code == 0 {
                        // Success - return stdout
                        Ok(QValue::Str(QString::new(pr.stdout.clone())))
                    } else {
                        // Failure - raise error with details
                        let stdout_preview = if pr.stdout.len() > 100 {
                            format!("{}...", &pr.stdout[..100])
                        } else {
                            pr.stdout.clone()
                        };
                        let stderr_preview = if pr.stderr.len() > 100 {
                            format!("{}...", &pr.stderr[..100])
                        } else {
                            pr.stderr.clone()
                        };
                        Err(format!(
                            "Command failed with exit code {}. stdout={}, stderr={}",
                            pr.code, stdout_preview.trim(), stderr_preview.trim()
                        ))
                    }
                }
                _ => Err("process.run returned unexpected type".to_string())
            }
        }

        "process.shell" => {
            // process.shell(command, options?) - Execute command through shell (DANGEROUS)
            if args.is_empty() || args.len() > 2 {
                return Err(format!("process.shell expects 1 or 2 arguments (command, options?), got {}", args.len()));
            }

            // Get shell command string
            let cmd_str = match &args[0] {
                QValue::Str(s) => (*s.value).clone(),
                _ => return Err("process.shell expects string command".to_string()),
            };

            // Build platform-specific shell command
            #[cfg(unix)]
            let shell_cmd = vec!["sh".to_string(), "-c".to_string(), cmd_str];

            #[cfg(windows)]
            let shell_cmd = vec!["cmd".to_string(), "/C".to_string(), cmd_str];

            #[cfg(not(any(unix, windows)))]
            return Err("process.shell not supported on this platform".to_string());

            // Wrap command in array and call process.run()
            let cmd_array = QValue::Array(QArray::new(
                shell_cmd.into_iter().map(|s| QValue::Str(QString::new(s))).collect()
            ));

            let run_args = if args.len() == 2 {
                vec![cmd_array, args[1].clone()]
            } else {
                vec![cmd_array]
            };

            call_process_function("process.run", run_args, _scope)
        }

        "process.pipeline" => {
            // process.pipeline(commands) - Chain multiple commands with pipes
            if args.len() != 1 {
                return Err(format!("process.pipeline expects 1 argument (commands array), got {}", args.len()));
            }

            let commands = match &args[0] {
                QValue::Array(arr) => {
                    let elements = arr.elements.borrow();
                    let mut cmd_list = Vec::new();

                    for elem in elements.iter() {
                        match elem {
                            QValue::Array(cmd_arr) => {
                                let cmd_elements = cmd_arr.elements.borrow();
                                let mut cmd_parts = Vec::new();
                                for cmd_elem in cmd_elements.iter() {
                                    match cmd_elem {
                                        QValue::Str(s) => cmd_parts.push((*s.value).clone()),
                                        _ => return Err("pipeline commands must be arrays of strings".to_string()),
                                    }
                                }
                                if cmd_parts.is_empty() {
                                    return Err("pipeline command cannot be empty".to_string());
                                }
                                cmd_list.push(cmd_parts);
                            }
                            _ => return Err("pipeline expects array of command arrays".to_string()),
                        }
                    }
                    cmd_list
                }
                _ => return Err("process.pipeline expects array of commands".to_string()),
            };

            if commands.is_empty() {
                return Err("pipeline must have at least one command".to_string());
            }

            // Spawn all processes with piped I/O
            let mut children = Vec::new();
            for (i, cmd) in commands.iter().enumerate() {
                let mut command = Command::new(&cmd[0]);
                if cmd.len() > 1 {
                    for arg in &cmd[1..] {
                        command.arg(arg);
                    }
                }

                // All processes need stdin and stdout piped
                command.stdin(Stdio::piped());
                command.stdout(Stdio::piped());
                command.stderr(Stdio::piped());

                let child = command.spawn()
                    .map_err(|e| format!("Failed to spawn command {}: {}", i, e))?;
                children.push(child);
            }

            // Connect pipes: stdout of i -> stdin of i+1
            for i in 0..children.len() {
                if i > 0 {
                    // Get stdout from previous process
                    if let Some(mut stdout) = children[i - 1].stdout.take() {
                        let mut buffer = Vec::new();
                        stdout.read_to_end(&mut buffer)
                            .map_err(|e| format!("Failed to read from process {}: {}", i - 1, e))?;

                        // Write to current process stdin
                        if let Some(mut stdin) = children[i].stdin.take() {
                            stdin.write_all(&buffer)
                                .map_err(|e| format!("Failed to write to process {}: {}", i, e))?;
                        }
                    }
                }
            }

            // Get output from last process
            let last_child = children.pop().unwrap();

            let output = last_child.wait_with_output()
                .map_err(|e| format!("Failed to wait for last process: {}", e))?;

            // Wait for all other processes
            for mut child in children {
                let _ = child.wait();
            }

            // Return ProcessResult from last command
            let stdout_str = String::from_utf8_lossy(&output.stdout).to_string();
            let stderr_str = String::from_utf8_lossy(&output.stderr).to_string();
            let exit_code = output.status.code().unwrap_or(-1);

            let result = QProcessResult::new(
                stdout_str,
                stderr_str,
                output.stdout.clone(),
                output.stderr,
                exit_code as i64
            );

            Ok(QValue::ProcessResult(result))
        }

        _ => Err(format!("Unknown process function: {}", func_name))
    }
}
