// Gzip compression and decompression module
use crate::control_flow::EvalError;
use std::collections::HashMap;
use crate::types::*;
use crate::{arg_err, attr_err};
use flate2::Compression;
use flate2::read::GzDecoder;
use flate2::write::GzEncoder;
use std::io::{Read, Write};

/// Create the gzip module with compress and decompress functions
pub fn create_gzip_module() -> QValue {
    let mut members = HashMap::new();

    members.insert("compress".to_string(), create_fn("gzip", "compress"));
    members.insert("decompress".to_string(), create_fn("gzip", "decompress"));

    QValue::Module(Box::new(QModule::new("gzip".to_string(), members)))
}

/// Handle gzip.* function calls
pub fn call_gzip_function(func_name: &str, args: Vec<QValue>, _scope: &mut crate::Scope) -> Result<QValue, EvalError> {
    match func_name {
        "gzip.compress" => {
            if args.is_empty() || args.len() > 2 {
                return arg_err!("gzip.compress expects 1 or 2 arguments (data, level?), got {}", args.len());
            }

            // Get data as bytes
            let bytes = match &args[0] {
                QValue::Str(s) => s.value.as_bytes().to_vec(),
                QValue::Bytes(b) => b.data.clone(),
                _ => return Err("gzip.compress expects Str or Bytes as first argument".into()),
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
                    _ => return Err("gzip.compress level must be a number".into()),
                }
            } else {
                6 // Default compression level
            };

            // Compress
            let mut encoder = GzEncoder::new(Vec::new(), Compression::new(level));
            encoder.write_all(&bytes)
                .map_err(|e| format!("Failed to compress: {}", e))?;
            let compressed = encoder.finish()
                .map_err(|e| format!("Failed to finish compression: {}", e))?;

            Ok(QValue::Bytes(QBytes::new(compressed)))
        }

        "gzip.decompress" => {
            if args.len() != 1 {
                return arg_err!("gzip.decompress expects 1 argument (data), got {}", args.len());
            }

            // Get compressed data as bytes
            let bytes = match &args[0] {
                QValue::Bytes(b) => b.data.clone(),
                QValue::Str(s) => s.value.as_bytes().to_vec(),
                _ => return Err("gzip.decompress expects Bytes".into()),
            };

            // Decompress
            let mut decoder = GzDecoder::new(&bytes[..]);
            let mut result = Vec::new();
            decoder.read_to_end(&mut result)
                .map_err(|e| format!("Failed to decompress: {}", e))?;

            Ok(QValue::Bytes(QBytes::new(result)))
        }

        _ => attr_err!("Unknown gzip function: {}", func_name)
    }
}
