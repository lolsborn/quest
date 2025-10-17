// Deflate compression and decompression module (raw, no headers)
use crate::control_flow::EvalError;
use std::collections::HashMap;
use crate::types::*;
use crate::{arg_err, attr_err};
use flate2::Compression;
use flate2::read::DeflateDecoder;
use flate2::write::DeflateEncoder;
use std::io::{Read, Write};

/// Create the deflate module with compress and decompress functions
pub fn create_deflate_module() -> QValue {
    let mut members = HashMap::new();

    members.insert("compress".to_string(), create_fn("deflate", "compress"));
    members.insert("decompress".to_string(), create_fn("deflate", "decompress"));

    QValue::Module(Box::new(QModule::new("deflate".to_string(), members)))
}

/// Handle deflate.* function calls
pub fn call_deflate_function(func_name: &str, args: Vec<QValue>, _scope: &mut crate::Scope) -> Result<QValue, EvalError> {
    match func_name {
        "deflate.compress" => {
            if args.is_empty() || args.len() > 2 {
                return arg_err!("deflate.compress expects 1 or 2 arguments (data, level?), got {}", args.len());
            }

            // Get data as bytes
            let bytes = match &args[0] {
                QValue::Str(s) => s.value.as_bytes().to_vec(),
                QValue::Bytes(b) => b.data.clone(),
                _ => return Err("deflate.compress expects Str or Bytes as first argument".into()),
            };

            // Get compression level (default 6)
            let level = if args.len() == 2 {
                match &args[1] {
                    QValue::Int(n) => {
                        if n.value < 0 || n.value > 9 {
                            return Err("Compression level must be between 0 and 9".into());
                        }
                        n.value as u32
                    }
                    QValue::Float(f) => {
                        let level = f.value as i64;
                        if level < 0 || level > 9 {
                            return Err("Compression level must be between 0 and 9".into());
                        }
                        level as u32
                    }
                    _ => return Err("deflate.compress level must be a number".into()),
                }
            } else {
                6 // Default compression level
            };

            // Compress
            let mut encoder = DeflateEncoder::new(Vec::new(), Compression::new(level));
            encoder.write_all(&bytes)
                .map_err(|e| format!("Failed to compress: {}", e))?;
            let compressed = encoder.finish()
                .map_err(|e| format!("Failed to finish compression: {}", e))?;

            Ok(QValue::Bytes(QBytes::new(compressed)))
        }

        "deflate.decompress" => {
            if args.len() != 1 {
                return arg_err!("deflate.decompress expects 1 argument (data), got {}", args.len());
            }

            // Get compressed data as bytes
            let bytes = match &args[0] {
                QValue::Bytes(b) => b.data.clone(),
                QValue::Str(s) => s.value.as_bytes().to_vec(),
                _ => return Err("deflate.decompress expects Bytes".into()),
            };

            // Decompress
            let mut decoder = DeflateDecoder::new(&bytes[..]);
            let mut result = Vec::new();
            decoder.read_to_end(&mut result)
                .map_err(|e| format!("Failed to decompress: {}", e))?;

            Ok(QValue::Bytes(QBytes::new(result)))
        }

        _ => attr_err!("Unknown deflate function: {}", func_name)
    }
}
