// Bzip2 compression and decompression module
use crate::control_flow::EvalError;
use std::collections::HashMap;
use crate::types::*;
use bzip2::Compression;
use bzip2::read::BzDecoder;
use bzip2::write::BzEncoder;
use std::io::{Read, Write};
use crate::{arg_err, attr_err};

/// Create the bzip2 module with compress and decompress functions
pub fn create_bzip2_module() -> QValue {
    let mut members = HashMap::new();

    members.insert("compress".to_string(), create_fn("bzip2", "compress"));
    members.insert("decompress".to_string(), create_fn("bzip2", "decompress"));

    QValue::Module(Box::new(QModule::new("bzip2".to_string(), members)))
}

/// Handle bzip2.* function calls
pub fn call_bzip2_function(func_name: &str, args: Vec<QValue>, _scope: &mut crate::Scope) -> Result<QValue, EvalError> {
    match func_name {
        "bzip2.compress" => {
            if args.is_empty() || args.len() > 2 {
                return arg_err!("bzip2.compress expects 1 or 2 arguments (data, level?), got {}", args.len());
            }

            // Get data as bytes
            let bytes = match &args[0] {
                QValue::Str(s) => s.value.as_bytes().to_vec(),
                QValue::Bytes(b) => b.data.clone(),
                _ => return Err("bzip2.compress expects Str or Bytes as first argument".into()),
            };

            // Get compression level (default 6)
            // Bzip2 uses levels 1-9 (1=fastest, 9=best compression)
            let level = if args.len() == 2 {
                match &args[1] {
                    QValue::Int(n) => {
                        if n.value < 1 || n.value > 9 {
                            return Err("Compression level must be between 1 and 9".into());
                        }
                        n.value as u32
                    }
                    QValue::Float(f) => {
                        let level = f.value as i64;
                        if level < 1 || level > 9 {
                            return Err("Compression level must be between 1 and 9".into());
                        }
                        level as u32
                    }
                    _ => return Err("bzip2.compress level must be a number".into()),
                }
            } else {
                6 // Default compression level
            };

            // Compress
            let mut encoder = BzEncoder::new(Vec::new(), Compression::new(level));
            encoder.write_all(&bytes)
                .map_err(|e| format!("Failed to compress: {}", e))?;
            let compressed = encoder.finish()
                .map_err(|e| format!("Failed to finish compression: {}", e))?;

            Ok(QValue::Bytes(QBytes::new(compressed)))
        }

        "bzip2.decompress" => {
            if args.len() != 1 {
                return arg_err!("bzip2.decompress expects 1 argument (data), got {}", args.len());
            }

            // Get compressed data as bytes
            let bytes = match &args[0] {
                QValue::Bytes(b) => b.data.clone(),
                QValue::Str(s) => s.value.as_bytes().to_vec(),
                _ => return Err("bzip2.decompress expects Bytes".into()),
            };

            // Decompress
            let mut decoder = BzDecoder::new(&bytes[..]);
            let mut result = Vec::new();
            decoder.read_to_end(&mut result)
                .map_err(|e| format!("Failed to decompress: {}", e))?;

            Ok(QValue::Bytes(QBytes::new(result)))
        }

        _ => attr_err!("Unknown bzip2 function: {}", func_name)
    }
}
