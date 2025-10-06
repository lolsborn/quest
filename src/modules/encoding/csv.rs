use std::collections::HashMap;
use csv::{ReaderBuilder, WriterBuilder};
use crate::types::*;

pub fn create_csv_module() -> QValue {
    let mut members = HashMap::new();

    members.insert("parse".to_string(), create_fn("csv", "parse"));
    members.insert("stringify".to_string(), create_fn("csv", "stringify"));

    QValue::Module(Box::new(QModule::new("csv".to_string(), members)))
}

pub fn call_csv_function(func_name: &str, args: Vec<QValue>, _scope: &mut crate::Scope) -> Result<QValue, String> {
    match func_name {
        "csv.parse" => csv_parse(args),
        "csv.stringify" => csv_stringify(args),
        _ => Err(format!("Unknown csv function: {}", func_name))
    }
}

/// csv.parse(text) or csv.parse(text, options)
fn csv_parse(args: Vec<QValue>) -> Result<QValue, String> {
    if args.is_empty() || args.len() > 2 {
        return Err(format!("parse expects 1-2 arguments (text, [options]), got {}", args.len()));
    }

    let text = args[0].as_str();

    // Parse options
    let (has_headers, delimiter, trim) = if args.len() == 2 {
        let options = match &args[1] {
            QValue::Dict(d) => d,
            _ => return Err(format!("parse options must be Dict, got {}", args[1].as_obj().cls())),
        };

        let has_headers = options.map.borrow().get("has_headers")
            .map(|v| v.as_bool())
            .unwrap_or(true);

        let delimiter = options.map.borrow().get("delimiter")
            .map(|v| v.as_str())
            .unwrap_or(",".to_string());

        let trim = options.map.borrow().get("trim")
            .map(|v| v.as_bool())
            .unwrap_or(true);

        (has_headers, delimiter, trim)
    } else {
        (true, ",".to_string(), true)
    };

    if delimiter.len() != 1 {
        return Err("Delimiter must be a single character".to_string());
    }

    let mut reader = ReaderBuilder::new()
        .delimiter(delimiter.as_bytes()[0])
        .has_headers(has_headers)
        .trim(csv::Trim::All)
        .from_reader(text.as_bytes());

    let mut rows = Vec::new();

    if has_headers {
        // Parse with headers - return array of dicts
        let headers = reader.headers()
            .map_err(|e| format!("Failed to read headers: {}", e))?
            .clone();

        for result in reader.records() {
            let record = result.map_err(|e| format!("Failed to read record: {}", e))?;
            let mut row_dict = HashMap::new();

            for (i, field) in record.iter().enumerate() {
                if let Some(header) = headers.get(i) {
                    let value = parse_csv_value(field, trim);
                    row_dict.insert(header.to_string(), value);
                }
            }

            rows.push(QValue::Dict(Box::new(QDict::new(row_dict))));
        }
    } else {
        // Parse without headers - return array of arrays
        for result in reader.records() {
            let record = result.map_err(|e| format!("Failed to read record: {}", e))?;
            let mut row_array = Vec::new();

            for field in record.iter() {
                row_array.push(parse_csv_value(field, trim));
            }

            rows.push(QValue::Array(QArray::new(row_array)));
        }
    }

    Ok(QValue::Array(QArray::new(rows)))
}

/// Parse CSV field value with automatic type detection
fn parse_csv_value(field: &str, trim: bool) -> QValue {
    let s = if trim { field.trim() } else { field };

    if s.is_empty() {
        return QValue::Str(QString::new(s.to_string()));
    }

    // Try to parse as integer
    if let Ok(i) = s.parse::<i64>() {
        return QValue::Int(QInt::new(i));
    }

    // Try to parse as float
    if let Ok(f) = s.parse::<f64>() {
        return QValue::Float(QFloat::new(f));
    }

    // Try to parse as boolean
    let lower = s.to_lowercase();
    if lower == "true" {
        return QValue::Bool(QBool::new(true));
    }
    if lower == "false" {
        return QValue::Bool(QBool::new(false));
    }

    // Default to string
    QValue::Str(QString::new(s.to_string()))
}

/// csv.stringify(data) or csv.stringify(data, options)
fn csv_stringify(args: Vec<QValue>) -> Result<QValue, String> {
    if args.is_empty() || args.len() > 2 {
        return Err(format!("stringify expects 1-2 arguments (data, [options]), got {}", args.len()));
    }

    let data = match &args[0] {
        QValue::Array(a) => a,
        _ => return Err(format!("stringify expects Array, got {}", args[0].as_obj().cls())),
    };

    // Parse options
    let (delimiter, headers_opt) = if args.len() == 2 {
        let options = match &args[1] {
            QValue::Dict(d) => d,
            _ => return Err(format!("stringify options must be Dict, got {}", args[1].as_obj().cls())),
        };

        let delimiter = options.map.borrow().get("delimiter")
            .map(|v| v.as_str())
            .unwrap_or(",".to_string());

        let headers = options.map.borrow().get("headers")
            .map(|v| match v {
                QValue::Array(a) => {
                    let headers_vec: Vec<String> = a.elements.borrow()
                        .iter()
                        .map(|h| h.as_str())
                        .collect();
                    Some(headers_vec)
                }
                _ => None,
            })
            .flatten();

        (delimiter, headers)
    } else {
        (",".to_string(), None)
    };

    if delimiter.len() != 1 {
        return Err("Delimiter must be a single character".to_string());
    }

    let mut writer = WriterBuilder::new()
        .delimiter(delimiter.as_bytes()[0])
        .from_writer(Vec::new());

    let elements = data.elements.borrow();

    if elements.is_empty() {
        return Ok(QValue::Str(QString::new(String::new())));
    }

    // Determine if data is array of dicts or array of arrays
    match &elements[0] {
        QValue::Dict(first_row) => {
            // Array of dicts - extract headers
            let headers = if let Some(h) = headers_opt {
                h
            } else {
                // Infer headers from first row keys
                first_row.map.borrow().keys().cloned().collect::<Vec<String>>()
            };

            // Write headers
            writer.write_record(&headers)
                .map_err(|e| format!("Failed to write headers: {}", e))?;

            // Write rows
            for row_value in elements.iter() {
                if let QValue::Dict(row_dict) = row_value {
                    let mut record = Vec::new();
                    for header in &headers {
                        let value = row_dict.map.borrow().get(header)
                            .map(|v| qvalue_to_csv_string(v))
                            .unwrap_or_default();
                        record.push(value);
                    }
                    writer.write_record(&record)
                        .map_err(|e| format!("Failed to write record: {}", e))?;
                } else {
                    return Err("All rows must be Dict when first row is Dict".to_string());
                }
            }
        }
        QValue::Array(_) => {
            // Array of arrays - write headers if provided
            if let Some(headers) = headers_opt {
                writer.write_record(&headers)
                    .map_err(|e| format!("Failed to write headers: {}", e))?;
            }

            for row_value in elements.iter() {
                if let QValue::Array(row_array) = row_value {
                    let record: Vec<String> = row_array.elements.borrow()
                        .iter()
                        .map(|v| qvalue_to_csv_string(v))
                        .collect();
                    writer.write_record(&record)
                        .map_err(|e| format!("Failed to write record: {}", e))?;
                } else {
                    return Err("All rows must be Array when first row is Array".to_string());
                }
            }
        }
        _ => return Err("Data must be array of Dict or array of Array".to_string()),
    }

    let csv_bytes = writer.into_inner()
        .map_err(|e| format!("Failed to finalize CSV: {}", e))?;

    let csv_string = String::from_utf8(csv_bytes)
        .map_err(|e| format!("Invalid UTF-8 in CSV: {}", e))?;

    Ok(QValue::Str(QString::new(csv_string)))
}

/// Convert QValue to CSV string representation
fn qvalue_to_csv_string(value: &QValue) -> String {
    match value {
        QValue::Nil(_) => String::new(),
        _ => value.as_str(),
    }
}
