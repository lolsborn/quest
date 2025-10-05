// Zlib compression and decompression module (deflate with checksums)
use std::collections::HashMap;
use crate::types::*;
use flate2::Compression;
use flate2::read::ZlibDecoder;
use flate2::write::ZlibEncoder;
use std::io::{Read, Write};

/// Create the zlib module with compress and decompress functions
pub fn create_zlib_module() -> QValue {
    let mut members = HashMap::new();

    members.insert("compress".to_string(), create_fn("zlib", "compress"));
    members.insert("decompress".to_string(), create_fn("zlib", "decompress"));

    QValue::Module(Box::new(QModule::new("zlib".to_string(), members)))
}

/// Handle zlib.* function calls
pub fn call_zlib_function(func_name: &str, args: Vec<QValue>, _scope: &mut crate::Scope) -> Result<QValue, String> {
    match func_name {
        "zlib.compress" => {
            if args.is_empty() || args.len() > 2 {
                return Err(format!("zlib.compress expects 1 or 2 arguments (data, level?), got {}", args.len()));
            }

            // Get data as bytes
            let bytes = match &args[0] {
                QValue::Str(s) => s.value.as_bytes().to_vec(),
                QValue::Bytes(b) => b.data.clone(),
                _ => return Err("zlib.compress expects Str or Bytes as first argument".to_string()),
            };

            // Get compression level (default 6)
            let level = if args.len() == 2 {
                match &args[1] {
                    QValue::Int(n) => {
                        if n.value < 0 || n.value > 9 {
                            return Err("Compression level must be between 0 and 9".to_string());
                        }
                        n.value as u32
                    }
                    QValue::Float(f) => {
                        let level = f.value as i64;
                        if level < 0 || level > 9 {
                            return Err("Compression level must be between 0 and 9".to_string());
                        }
                        level as u32
                    }
                    _ => return Err("zlib.compress level must be a number".to_string()),
                }
            } else {
                6 // Default compression level
            };

            // Compress
            let mut encoder = ZlibEncoder::new(Vec::new(), Compression::new(level));
            encoder.write_all(&bytes)
                .map_err(|e| format!("Failed to compress: {}", e))?;
            let compressed = encoder.finish()
                .map_err(|e| format!("Failed to finish compression: {}", e))?;

            Ok(QValue::Bytes(QBytes::new(compressed)))
        }

        "zlib.decompress" => {
            if args.len() != 1 {
                return Err(format!("zlib.decompress expects 1 argument (data), got {}", args.len()));
            }

            // Get compressed data as bytes
            let bytes = match &args[0] {
                QValue::Bytes(b) => b.data.clone(),
                QValue::Str(s) => s.value.as_bytes().to_vec(),
                _ => return Err("zlib.decompress expects Bytes".to_string()),
            };

            // Decompress
            let mut decoder = ZlibDecoder::new(&bytes[..]);
            let mut result = Vec::new();
            decoder.read_to_end(&mut result)
                .map_err(|e| format!("Failed to decompress: {}", e))?;

            Ok(QValue::Bytes(QBytes::new(result)))
        }

        _ => Err(format!("Unknown zlib function: {}", func_name))
    }
}
