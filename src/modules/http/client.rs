use std::sync::{Arc, Mutex};
use crate::control_flow::EvalError;
use std::collections::HashMap;
use reqwest;
use bytes::Bytes;
use crate::types::*;
use crate::scope::Scope;
use super::runtime::RUNTIME;
use crate::{attr_err, value_err};

// ============================================================================
// HttpClient - Reusable client with connection pooling
// ============================================================================

#[derive(Debug, Clone)]
pub struct QHttpClient {
    client: Arc<reqwest::Client>,
    default_headers: Arc<Mutex<HashMap<String, String>>>,
    timeout: Arc<Mutex<Option<u64>>>,  // seconds
    id: u64,
}

impl QHttpClient {
    pub fn new() -> Self {
        let client = reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(30))
            .cookie_store(true)  // Enable cookie handling
            .gzip(true)          // Enable gzip compression
            .build()
            .unwrap();

        QHttpClient {
            client: Arc::new(client),
            default_headers: Arc::new(Mutex::new(HashMap::new())),
            timeout: Arc::new(Mutex::new(Some(30))),
            id: next_object_id(),
        }
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, EvalError> {
        match method_name {
            "get" => self.http_get(args),
            "post" => self.http_post(args),
            "put" => self.http_put(args),
            "delete" => self.http_delete(args),
            "patch" => self.http_patch(args),
            "head" => self.http_head(args),
            "options" => self.http_options(args),
            "request" => self.create_request(args),
            "set_timeout" => self.set_timeout(args),
            "set_header" => self.set_header(args),
            "set_headers" => self.set_headers(args),
            "timeout" => {
                let timeout = *self.timeout.lock().unwrap();
                Ok(QValue::Int(QInt::new(timeout.unwrap_or(30) as i64)))
            }
            "headers" => self.get_headers(),
            "cls" => Ok(QValue::Str(QString::new(self.cls()))),
            "_id" => Ok(QValue::Int(QInt::new(self.id as i64))),
            "str" => Ok(QValue::Str(QString::new(format!("<HttpClient {}>", self.id)))),
            "_rep" => Ok(QValue::Str(QString::new(format!("<HttpClient {}>", self.id)))),
            _ => attr_err!("Unknown method '{}' on HttpClient", method_name)
        }
    }

    fn http_get(&self, args: Vec<QValue>) -> Result<QValue, EvalError> {
        if args.is_empty() {
            return Err("get expects at least 1 argument (url)".into());
        }

        let url = args[0].as_str();

        // Parse optional named arguments
        let headers = self.extract_named_arg(&args, "headers")?;
        let query = self.extract_named_arg(&args, "query")?;
        let timeout = self.extract_named_arg(&args, "timeout")?;

        self.execute_request("GET", &url, None, headers, query, timeout)
    }

    fn http_post(&self, args: Vec<QValue>) -> Result<QValue, EvalError> {
        if args.is_empty() {
            return Err("post expects at least 1 argument (url)".into());
        }

        let url = args[0].as_str();
        let body = self.extract_named_arg(&args, "body")?;
        let headers = self.extract_named_arg(&args, "headers")?;
        let query = self.extract_named_arg(&args, "query")?;
        let timeout = self.extract_named_arg(&args, "timeout")?;

        self.execute_request("POST", &url, body, headers, query, timeout)
    }

    fn http_put(&self, args: Vec<QValue>) -> Result<QValue, EvalError> {
        if args.is_empty() {
            return Err("put expects at least 1 argument (url)".into());
        }

        let url = args[0].as_str();
        let body = self.extract_named_arg(&args, "body")?;
        let headers = self.extract_named_arg(&args, "headers")?;
        let query = self.extract_named_arg(&args, "query")?;
        let timeout = self.extract_named_arg(&args, "timeout")?;

        self.execute_request("PUT", &url, body, headers, query, timeout)
    }

    fn http_delete(&self, args: Vec<QValue>) -> Result<QValue, EvalError> {
        if args.is_empty() {
            return Err("delete expects at least 1 argument (url)".into());
        }

        let url = args[0].as_str();
        let headers = self.extract_named_arg(&args, "headers")?;
        let query = self.extract_named_arg(&args, "query")?;
        let timeout = self.extract_named_arg(&args, "timeout")?;

        self.execute_request("DELETE", &url, None, headers, query, timeout)
    }

    fn http_patch(&self, args: Vec<QValue>) -> Result<QValue, EvalError> {
        if args.is_empty() {
            return Err("patch expects at least 1 argument (url)".into());
        }

        let url = args[0].as_str();
        let body = self.extract_named_arg(&args, "body")?;
        let headers = self.extract_named_arg(&args, "headers")?;
        let query = self.extract_named_arg(&args, "query")?;
        let timeout = self.extract_named_arg(&args, "timeout")?;

        self.execute_request("PATCH", &url, body, headers, query, timeout)
    }

    fn http_head(&self, args: Vec<QValue>) -> Result<QValue, EvalError> {
        if args.is_empty() {
            return Err("head expects at least 1 argument (url)".into());
        }

        let url = args[0].as_str();
        let headers = self.extract_named_arg(&args, "headers")?;
        let query = self.extract_named_arg(&args, "query")?;
        let timeout = self.extract_named_arg(&args, "timeout")?;

        self.execute_request("HEAD", &url, None, headers, query, timeout)
    }

    fn http_options(&self, args: Vec<QValue>) -> Result<QValue, EvalError> {
        if args.is_empty() {
            return Err("options expects at least 1 argument (url)".into());
        }

        let url = args[0].as_str();
        let headers = self.extract_named_arg(&args, "headers")?;
        let query = self.extract_named_arg(&args, "query")?;
        let timeout = self.extract_named_arg(&args, "timeout")?;

        self.execute_request("OPTIONS", &url, None, headers, query, timeout)
    }

    fn create_request(&self, args: Vec<QValue>) -> Result<QValue, EvalError> {
        if args.len() < 2 {
            return Err("request expects 2 arguments (method, url)".into());
        }

        let method = args[0].as_str();
        let url = args[1].as_str();

        let request = QHttpRequest::new(self.client.clone(), method, url);
        Ok(QValue::HttpRequest(request))
    }

    fn set_timeout(&self, args: Vec<QValue>) -> Result<QValue, EvalError> {
        if args.len() != 1 {
            return Err("set_timeout expects 1 argument (seconds)".into());
        }

        let seconds = args[0].as_num()? as u64;
        *self.timeout.lock().unwrap() = Some(seconds);
        Ok(QValue::Nil(QNil))
    }

    fn set_header(&self, args: Vec<QValue>) -> Result<QValue, EvalError> {
        if args.len() != 2 {
            return Err("set_header expects 2 arguments (name, value)".into());
        }

        let name = args[0].as_str();
        let value = args[1].as_str();
        self.default_headers.lock().unwrap().insert(name, value);
        Ok(QValue::Nil(QNil))
    }

    fn set_headers(&self, args: Vec<QValue>) -> Result<QValue, EvalError> {
        if args.len() != 1 {
            return Err("set_headers expects 1 argument (headers dict)".into());
        }

        match &args[0] {
            QValue::Dict(dict) => {
                let mut headers = self.default_headers.lock().unwrap();
                for (key, value) in dict.map.borrow().iter() {
                    headers.insert(key.clone(), value.as_str());
                }
                Ok(QValue::Nil(QNil))
            }
            _ => Err("set_headers expects a Dict argument".into())
        }
    }

    fn get_headers(&self) -> Result<QValue, EvalError> {
        let headers = self.default_headers.lock().unwrap();
        let mut dict = HashMap::new();
        for (key, value) in headers.iter() {
            dict.insert(key.clone(), QValue::Str(QString::new(value.clone())));
        }
        Ok(QValue::Dict(Box::new(QDict::new(dict))))
    }

    fn extract_named_arg(&self, _args: &[QValue], _name: &str) -> Result<Option<QValue>, String> {
        // Named arguments would be passed as part of the args
        // This is a placeholder - actual implementation depends on how Quest handles named args
        // For now, return None (no named arg found)
        Ok(None)
    }

    fn execute_request(
        &self,
        method: &str,
        url: &str,
        body: Option<QValue>,
        headers: Option<QValue>,
        query: Option<QValue>,
        timeout: Option<QValue>,
    ) -> Result<QValue, EvalError> {
        let client = self.client.clone();
        let url = url.to_string();
        let method_str = method.to_string();

        // Get default headers
        let default_headers = self.default_headers.lock().unwrap().clone();

        // Get timeout (use provided or default)
        let timeout_secs = match timeout {
            Some(QValue::Int(n)) => n.value as u64,
            Some(QValue::Float(n)) => n.value as u64,
            _ => self.timeout.lock().unwrap().unwrap_or(30)
        };

        RUNTIME.block_on(async move {
            // Build request
            let mut req_builder = match method_str.as_str() {
                "GET" => client.get(&url),
                "POST" => client.post(&url),
                "PUT" => client.put(&url),
                "DELETE" => client.delete(&url),
                "PATCH" => client.patch(&url),
                "HEAD" => client.head(&url),
                "OPTIONS" => client.request(reqwest::Method::OPTIONS, &url),
                _ => return value_err!("Unsupported HTTP method: {}", method_str),
            };

            // Add default headers
            for (key, value) in default_headers {
                req_builder = req_builder.header(&key, &value);
            }

            // Add custom headers if provided
            if let Some(QValue::Dict(dict)) = headers {
                for (key, value) in dict.map.borrow().iter() {
                    req_builder = req_builder.header(key, value.as_str());
                }
            }

            // Add query parameters if provided
            if let Some(QValue::Dict(dict)) = query {
                let mut params = Vec::new();
                for (key, value) in dict.map.borrow().iter() {
                    params.push((key.clone(), value.as_str()));
                }
                req_builder = req_builder.query(&params);
            }

            // Add body if provided
            if let Some(body_val) = body {
                req_builder = match body_val {
                    QValue::Str(s) => req_builder.body(s.value.as_ref().clone()),
                    QValue::Bytes(b) => req_builder.body(b.data.clone()),
                    QValue::Dict(_) | QValue::Array(_) => {
                        // Convert to JSON
                        let json_val = crate::modules::encoding::json_utils::qvalue_to_json(&body_val)
                            .map_err(|e| format!("Failed to serialize body as JSON: {}", e))?;
                        req_builder.json(&json_val)
                    }
                    _ => return Err("Unsupported body type".into()),
                };
            }

            // Set timeout
            req_builder = req_builder.timeout(std::time::Duration::from_secs(timeout_secs));

            // Execute request
            let response = req_builder.send().await
                .map_err(|e| format!("HTTP request failed: {}", e))?;

            // Convert to QHttpResponse
            QHttpResponse::from_reqwest_response(response).await
        })
    }
}

impl QObj for QHttpClient {
    fn cls(&self) -> String {
        "HttpClient".to_string()
    }

    fn q_type(&self) -> &'static str {
        "HttpClient"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "HttpClient"
    }

    fn str(&self) -> String {
        format!("<HttpClient {}>", self.id)
    }

    fn _rep(&self) -> String {
        format!("<HttpClient {}>", self.id)
    }

    fn _doc(&self) -> String {
        "HTTP client for making web requests".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

// ============================================================================
// HttpRequest - Builder for outgoing requests
// ============================================================================

#[derive(Debug, Clone)]
pub struct QHttpRequest {
    client: Arc<reqwest::Client>,
    method: String,
    url: String,
    headers: Arc<Mutex<HashMap<String, String>>>,
    query_params: Arc<Mutex<HashMap<String, String>>>,
    body: Arc<Mutex<Option<RequestBody>>>,
    timeout: Arc<Mutex<Option<u64>>>,
    id: u64,
}

#[derive(Debug, Clone)]
enum RequestBody {
    Text(String),
    Json(serde_json::Value),
    Bytes(Bytes),
    Form(HashMap<String, String>),
}

impl QHttpRequest {
    pub fn new(client: Arc<reqwest::Client>, method: String, url: String) -> Self {
        QHttpRequest {
            client,
            method,
            url,
            headers: Arc::new(Mutex::new(HashMap::new())),
            query_params: Arc::new(Mutex::new(HashMap::new())),
            body: Arc::new(Mutex::new(None)),
            timeout: Arc::new(Mutex::new(None)),
            id: next_object_id(),
        }
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, EvalError> {
        match method_name {
            "header" => self.set_header(args),
            "headers" => self.set_headers(args),
            "query" => self.set_query(args),
            "queries" => self.set_queries(args),
            "body" => self.set_body(args),
            "json" => self.set_json(args),
            "form" => self.set_form(args),
            "text" => self.set_text(args),
            "bytes" => self.set_bytes(args),
            "timeout" => self.set_timeout(args),
            "send" => self.send(),
            "url" => Ok(QValue::Str(QString::new(self.url.clone()))),
            "method" => Ok(QValue::Str(QString::new(self.method.clone()))),
            "get_header" => self.get_header(args),
            "get_headers" => self.get_headers(),
            "get_query" => self.get_query(args),
            "get_queries" => self.get_queries(),
            "_id" => Ok(QValue::Int(QInt::new(self.id as i64))),
            "str" => Ok(QValue::Str(QString::new(format!("<HttpRequest {} {}>", self.method, self.url)))),
            "cls" => Ok(QValue::Str(QString::new(self.cls()))),
            "_rep" => Ok(QValue::Str(QString::new(format!("<HttpRequest {} {}>", self.method, self.url)))),
            _ => attr_err!("Unknown method '{}' on HttpRequest", method_name)
        }
    }

    fn set_header(&self, args: Vec<QValue>) -> Result<QValue, EvalError> {
        if args.len() != 2 {
            return Err("header expects 2 arguments (name, value)".into());
        }

        let name = args[0].as_str();
        let value = args[1].as_str();
        self.headers.lock().unwrap().insert(name, value);

        // Return self for chaining
        Ok(QValue::HttpRequest(self.clone()))
    }

    fn set_headers(&self, args: Vec<QValue>) -> Result<QValue, EvalError> {
        if args.len() != 1 {
            return Err("headers expects 1 argument (dict)".into());
        }

        match &args[0] {
            QValue::Dict(dict) => {
                let mut headers = self.headers.lock().unwrap();
                for (key, value) in dict.map.borrow().iter() {
                    headers.insert(key.clone(), value.as_str());
                }
                Ok(QValue::HttpRequest(self.clone()))
            }
            _ => Err("headers expects a Dict argument".into())
        }
    }

    fn set_query(&self, args: Vec<QValue>) -> Result<QValue, EvalError> {
        if args.len() != 2 {
            return Err("query expects 2 arguments (key, value)".into());
        }

        let key = args[0].as_str();
        let value = args[1].as_str();
        self.query_params.lock().unwrap().insert(key, value);

        Ok(QValue::HttpRequest(self.clone()))
    }

    fn set_queries(&self, args: Vec<QValue>) -> Result<QValue, EvalError> {
        if args.len() != 1 {
            return Err("queries expects 1 argument (dict)".into());
        }

        match &args[0] {
            QValue::Dict(dict) => {
                let mut params = self.query_params.lock().unwrap();
                for (key, value) in dict.map.borrow().iter() {
                    params.insert(key.clone(), value.as_str());
                }
                Ok(QValue::HttpRequest(self.clone()))
            }
            _ => Err("queries expects a Dict argument".into())
        }
    }

    fn set_body(&self, args: Vec<QValue>) -> Result<QValue, EvalError> {
        if args.len() != 1 {
            return Err("body expects 1 argument".into());
        }

        let body = match &args[0] {
            QValue::Str(s) => RequestBody::Text(s.value.as_ref().clone()),
            QValue::Bytes(b) => RequestBody::Bytes(Bytes::from(b.data.clone())),
            QValue::Dict(_) | QValue::Array(_) => {
                let json_val = crate::modules::encoding::json_utils::qvalue_to_json(&args[0])
                    .map_err(|e| format!("Failed to serialize as JSON: {}", e))?;
                RequestBody::Json(json_val)
            }
            _ => return Err("Unsupported body type".into()),
        };

        *self.body.lock().unwrap() = Some(body);
        Ok(QValue::HttpRequest(self.clone()))
    }

    fn set_json(&self, args: Vec<QValue>) -> Result<QValue, EvalError> {
        if args.len() != 1 {
            return Err("json expects 1 argument".into());
        }

        let json_val = crate::modules::encoding::json_utils::qvalue_to_json(&args[0])
            .map_err(|e| format!("Failed to serialize as JSON: {}", e))?;

        *self.body.lock().unwrap() = Some(RequestBody::Json(json_val));
        Ok(QValue::HttpRequest(self.clone()))
    }

    fn set_form(&self, args: Vec<QValue>) -> Result<QValue, EvalError> {
        if args.len() != 1 {
            return Err("form expects 1 argument (dict)".into());
        }

        match &args[0] {
            QValue::Dict(dict) => {
                let mut form_data = HashMap::new();
                for (key, value) in dict.map.borrow().iter() {
                    form_data.insert(key.clone(), value.as_str());
                }
                *self.body.lock().unwrap() = Some(RequestBody::Form(form_data));
                Ok(QValue::HttpRequest(self.clone()))
            }
            _ => Err("form expects a Dict argument".into())
        }
    }

    fn set_text(&self, args: Vec<QValue>) -> Result<QValue, EvalError> {
        if args.len() != 1 {
            return Err("text expects 1 argument".into());
        }

        let text = args[0].as_str();
        *self.body.lock().unwrap() = Some(RequestBody::Text(text));
        Ok(QValue::HttpRequest(self.clone()))
    }

    fn set_bytes(&self, args: Vec<QValue>) -> Result<QValue, EvalError> {
        if args.len() != 1 {
            return Err("bytes expects 1 argument".into());
        }

        match &args[0] {
            QValue::Bytes(b) => {
                *self.body.lock().unwrap() = Some(RequestBody::Bytes(Bytes::from(b.data.clone())));
                Ok(QValue::HttpRequest(self.clone()))
            }
            _ => Err("bytes expects a Bytes argument".into())
        }
    }

    fn set_timeout(&self, args: Vec<QValue>) -> Result<QValue, EvalError> {
        if args.len() != 1 {
            return Err("timeout expects 1 argument (seconds)".into());
        }

        let seconds = args[0].as_num()? as u64;
        *self.timeout.lock().unwrap() = Some(seconds);
        Ok(QValue::HttpRequest(self.clone()))
    }

    fn get_header(&self, args: Vec<QValue>) -> Result<QValue, EvalError> {
        if args.len() != 1 {
            return Err("get_header expects 1 argument (name)".into());
        }

        let name = args[0].as_str();
        let headers = self.headers.lock().unwrap();

        match headers.get(&name) {
            Some(value) => Ok(QValue::Str(QString::new(value.clone()))),
            None => Ok(QValue::Nil(QNil))
        }
    }

    fn get_headers(&self) -> Result<QValue, EvalError> {
        let headers = self.headers.lock().unwrap();
        let mut dict = HashMap::new();
        for (key, value) in headers.iter() {
            dict.insert(key.clone(), QValue::Str(QString::new(value.clone())));
        }
        Ok(QValue::Dict(Box::new(QDict::new(dict))))
    }

    fn get_query(&self, args: Vec<QValue>) -> Result<QValue, EvalError> {
        if args.len() != 1 {
            return Err("get_query expects 1 argument (key)".into());
        }

        let key = args[0].as_str();
        let params = self.query_params.lock().unwrap();

        match params.get(&key) {
            Some(value) => Ok(QValue::Str(QString::new(value.clone()))),
            None => Ok(QValue::Nil(QNil))
        }
    }

    fn get_queries(&self) -> Result<QValue, EvalError> {
        let params = self.query_params.lock().unwrap();
        let mut dict = HashMap::new();
        for (key, value) in params.iter() {
            dict.insert(key.clone(), QValue::Str(QString::new(value.clone())));
        }
        Ok(QValue::Dict(Box::new(QDict::new(dict))))
    }

    fn send(&self) -> Result<QValue, EvalError> {
        let client = self.client.clone();
        let method = self.method.clone();
        let url = self.url.clone();
        let headers = self.headers.lock().unwrap().clone();
        let query_params = self.query_params.lock().unwrap().clone();
        let body = self.body.lock().unwrap().clone();
        let timeout = *self.timeout.lock().unwrap();

        RUNTIME.block_on(async move {
            // Build request
            let mut req_builder = client.request(
                method.parse().map_err(|e| format!("Invalid HTTP method: {}", e))?,
                &url
            );

            // Add headers
            for (key, value) in headers {
                req_builder = req_builder.header(&key, &value);
            }

            // Add query parameters
            if !query_params.is_empty() {
                let params: Vec<_> = query_params.into_iter().collect();
                req_builder = req_builder.query(&params);
            }

            // Add body
            if let Some(body) = body {
                req_builder = match body {
                    RequestBody::Text(text) => req_builder.body(text),
                    RequestBody::Bytes(bytes) => req_builder.body(bytes),
                    RequestBody::Json(json) => req_builder.json(&json),
                    RequestBody::Form(form) => req_builder.form(&form),
                };
            }

            // Set timeout
            if let Some(secs) = timeout {
                req_builder = req_builder.timeout(std::time::Duration::from_secs(secs));
            }

            // Execute request
            let response = req_builder.send().await
                .map_err(|e| format!("HTTP request failed: {}", e))?;

            // Convert to QHttpResponse
            QHttpResponse::from_reqwest_response(response).await
        })
    }
}

impl QObj for QHttpRequest {
    fn cls(&self) -> String {
        "HttpRequest".to_string()
    }

    fn q_type(&self) -> &'static str {
        "HttpRequest"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "HttpRequest"
    }

    fn str(&self) -> String {
        format!("<HttpRequest {} {}>", self.method, self.url)
    }

    fn _rep(&self) -> String {
        format!("<HttpRequest {} {}>", self.method, self.url)
    }

    fn _doc(&self) -> String {
        "HTTP request builder".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

// ============================================================================
// HttpResponse - Parsed response from server
// ============================================================================

#[derive(Debug, Clone)]
pub struct QHttpResponse {
    status: u16,
    headers: HashMap<String, String>,
    cookies: HashMap<String, String>,
    body: Arc<Mutex<Option<Bytes>>>,
    body_text: Arc<Mutex<Option<String>>>,  // Cached text
    url: String,
    content_length: Option<u64>,
    id: u64,
}

impl QHttpResponse {
    pub async fn from_reqwest_response(resp: reqwest::Response) -> Result<QValue, EvalError> {
        let status = resp.status().as_u16();
        let url = resp.url().to_string();

        // Extract headers (convert to lowercase keys for case-insensitive access)
        let mut headers = HashMap::new();
        for (key, value) in resp.headers() {
            headers.insert(
                key.as_str().to_lowercase(),
                value.to_str().unwrap_or("").to_string()
            );
        }

        // Extract cookies (placeholder - reqwest cookie store is complex)
        let cookies = HashMap::new();

        // Get content length
        let content_length = resp.content_length();

        // Read body as bytes
        let body_bytes = resp.bytes().await
            .map_err(|e| format!("Failed to read response body: {}", e))?;

        let response = QHttpResponse {
            status,
            headers,
            cookies,
            body: Arc::new(Mutex::new(Some(body_bytes))),
            body_text: Arc::new(Mutex::new(None)),
            url,
            content_length,
            id: next_object_id(),
        };

        Ok(QValue::HttpResponse(response))
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, EvalError> {
        match method_name {
            "status" => Ok(QValue::Int(QInt::new(self.status as i64))),
            "ok" => Ok(QValue::Bool(QBool::new(self.status >= 200 && self.status < 300))),
            "is_redirect" => Ok(QValue::Bool(QBool::new(self.status >= 300 && self.status < 400))),
            "is_client_error" => Ok(QValue::Bool(QBool::new(self.status >= 400 && self.status < 500))),
            "is_server_error" => Ok(QValue::Bool(QBool::new(self.status >= 500 && self.status < 600))),
            "is_success" => Ok(QValue::Bool(QBool::new(self.status >= 200 && self.status < 300))),
            "is_informational" => Ok(QValue::Bool(QBool::new(self.status >= 100 && self.status < 200))),
            "header" => self.get_header(args),
            "headers" => self.get_headers(),
            "has_header" => self.has_header(args),
            "cookie" => self.get_cookie(args),
            "cookies" => self.get_cookies(),
            "content_type" => self.get_content_type(),
            "is_json" => self.is_json(),
            "is_html" => self.is_html(),
            "is_text" => self.is_text(),
            "url" => Ok(QValue::Str(QString::new(self.url.clone()))),
            "text" => self.body_text(),
            "json" => self.body_json(),
            "bytes" => self.body_bytes(),
            "body" => self.body_bytes(),
            "content_length" => self.get_content_length(),
            "_id" => Ok(QValue::Int(QInt::new(self.id as i64))),
            "str" => Ok(QValue::Str(QString::new(format!("<HttpResponse {}>", self.status)))),
            "cls" => Ok(QValue::Str(QString::new(self.cls()))),
            "_rep" => Ok(QValue::Str(QString::new(format!("<HttpResponse {}>", self.status)))),
            _ => attr_err!("Unknown method '{}' on HttpResponse", method_name)
        }
    }

    fn get_header(&self, args: Vec<QValue>) -> Result<QValue, EvalError> {
        if args.len() != 1 {
            return Err("header expects 1 argument (name)".into());
        }

        let name = args[0].as_str().to_lowercase();
        match self.headers.get(&name) {
            Some(value) => Ok(QValue::Str(QString::new(value.clone()))),
            None => Ok(QValue::Nil(QNil))
        }
    }

    fn get_headers(&self) -> Result<QValue, EvalError> {
        let mut dict = HashMap::new();
        for (key, value) in &self.headers {
            dict.insert(key.clone(), QValue::Str(QString::new(value.clone())));
        }
        Ok(QValue::Dict(Box::new(QDict::new(dict))))
    }

    fn has_header(&self, args: Vec<QValue>) -> Result<QValue, EvalError> {
        if args.len() != 1 {
            return Err("has_header expects 1 argument (name)".into());
        }

        let name = args[0].as_str().to_lowercase();
        Ok(QValue::Bool(QBool::new(self.headers.contains_key(&name))))
    }

    fn get_cookie(&self, args: Vec<QValue>) -> Result<QValue, EvalError> {
        if args.len() != 1 {
            return Err("cookie expects 1 argument (name)".into());
        }

        let name = args[0].as_str();
        match self.cookies.get(&name) {
            Some(value) => Ok(QValue::Str(QString::new(value.clone()))),
            None => Ok(QValue::Nil(QNil))
        }
    }

    fn get_cookies(&self) -> Result<QValue, EvalError> {
        let mut dict = HashMap::new();
        for (key, value) in &self.cookies {
            dict.insert(key.clone(), QValue::Str(QString::new(value.clone())));
        }
        Ok(QValue::Dict(Box::new(QDict::new(dict))))
    }

    fn get_content_type(&self) -> Result<QValue, EvalError> {
        match self.headers.get("content-type") {
            Some(ct) => Ok(QValue::Str(QString::new(ct.clone()))),
            None => Ok(QValue::Nil(QNil))
        }
    }

    fn is_json(&self) -> Result<QValue, EvalError> {
        let is_json = self.headers.get("content-type")
            .map(|ct| ct.contains("application/json"))
            .unwrap_or(false);
        Ok(QValue::Bool(QBool::new(is_json)))
    }

    fn is_html(&self) -> Result<QValue, EvalError> {
        let is_html = self.headers.get("content-type")
            .map(|ct| ct.contains("text/html"))
            .unwrap_or(false);
        Ok(QValue::Bool(QBool::new(is_html)))
    }

    fn is_text(&self) -> Result<QValue, EvalError> {
        let is_text = self.headers.get("content-type")
            .map(|ct| ct.starts_with("text/"))
            .unwrap_or(false);
        Ok(QValue::Bool(QBool::new(is_text)))
    }

    fn body_text(&self) -> Result<QValue, EvalError> {
        // Check cache first
        let mut text_cache = self.body_text.lock().unwrap();
        if let Some(ref text) = *text_cache {
            return Ok(QValue::Str(QString::new(text.clone())));
        }

        // Convert body bytes to text
        let body = self.body.lock().unwrap();
        if let Some(ref bytes) = *body {
            let text = String::from_utf8(bytes.to_vec())
                .map_err(|e| format!("Failed to decode response as UTF-8: {}", e))?;
            *text_cache = Some(text.clone());
            Ok(QValue::Str(QString::new(text)))
        } else {
            Err("Response body already consumed".into())
        }
    }

    fn body_json(&self) -> Result<QValue, EvalError> {
        // Get text (uses cache if available)
        let text = match self.body_text()? {
            QValue::Str(s) => s.value.clone(),
            _ => return Err("Unexpected non-string response".into()),
        };

        // Parse as JSON
        let json_value: serde_json::Value = serde_json::from_str(&text)
            .map_err(|e| format!("Failed to parse response as JSON: {}", e))?;

        // Convert serde_json::Value to QValue
        crate::modules::encoding::json_utils::json_to_qvalue(json_value)
    }

    fn body_bytes(&self) -> Result<QValue, EvalError> {
        let body = self.body.lock().unwrap();
        if let Some(ref bytes) = *body {
            Ok(QValue::Bytes(QBytes::new(bytes.to_vec())))
        } else {
            Err("Response body already consumed".into())
        }
    }

    fn get_content_length(&self) -> Result<QValue, EvalError> {
        match self.content_length {
            Some(len) => Ok(QValue::Int(QInt::new(len as i64))),
            None => Ok(QValue::Nil(QNil))
        }
    }
}

impl QObj for QHttpResponse {
    fn cls(&self) -> String {
        "HttpResponse".to_string()
    }

    fn q_type(&self) -> &'static str {
        "HttpResponse"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "HttpResponse"
    }

    fn str(&self) -> String {
        format!("<HttpResponse {}>", self.status)
    }

    fn _rep(&self) -> String {
        format!("<HttpResponse {}>", self.status)
    }

    fn _doc(&self) -> String {
        "HTTP response from server".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

// ============================================================================
// Module Registration
// ============================================================================

pub fn create_http_client_module() -> QValue {
    let mut members = HashMap::new();

    // Client creation
    members.insert("client".to_string(), create_fn("http", "client"));

    // Convenience functions for one-off requests
    members.insert("get".to_string(), create_fn("http", "get"));
    members.insert("post".to_string(), create_fn("http", "post"));
    members.insert("put".to_string(), create_fn("http", "put"));
    members.insert("delete".to_string(), create_fn("http", "delete"));
    members.insert("patch".to_string(), create_fn("http", "patch"));
    members.insert("head".to_string(), create_fn("http", "head"));
    members.insert("options".to_string(), create_fn("http", "options"));

    QValue::Module(Box::new(QModule::new("http".to_string(), members)))
}

pub fn call_http_client_function(func_name: &str, args: Vec<QValue>, _scope: &mut Scope) -> Result<QValue, EvalError> {
    match func_name {
        "http.client" => {
            // TODO: Parse optional named args: timeout, headers
            Ok(QValue::HttpClient(QHttpClient::new()))
        }
        "http.get" => {
            let client = QHttpClient::new();
            client.call_method("get", args)
        }
        "http.post" => {
            let client = QHttpClient::new();
            client.call_method("post", args)
        }
        "http.put" => {
            let client = QHttpClient::new();
            client.call_method("put", args)
        }
        "http.delete" => {
            let client = QHttpClient::new();
            client.call_method("delete", args)
        }
        "http.patch" => {
            let client = QHttpClient::new();
            client.call_method("patch", args)
        }
        "http.head" => {
            let client = QHttpClient::new();
            client.call_method("head", args)
        }
        "http.options" => {
            let client = QHttpClient::new();
            client.call_method("options", args)
        }
        _ => attr_err!("Unknown function: {}", func_name)
    }
}
