// ============================================================================
// Embedded standard library management
// ============================================================================

use include_dir::{include_dir, Dir};
use std::path::PathBuf;
use std::fs;

// Embed the lib/ directory at compile time
static EMBEDDED_LIB: Dir = include_dir!("$CARGO_MANIFEST_DIR/lib");

/// Get the path where Quest's standard library should be installed
pub fn get_stdlib_dir() -> PathBuf {
    if let Some(home) = dirs::home_dir() {
        home.join(".quest").join("lib")
    } else {
        // Fallback if home dir not available
        PathBuf::from(".quest/lib")
    }
}

/// Check if the standard library is already extracted
pub fn is_stdlib_extracted() -> bool {
    let stdlib_dir = get_stdlib_dir();
    stdlib_dir.exists() && stdlib_dir.join("std").exists()
}

/// Extract embedded standard library to ~/.quest/lib/
/// Returns Ok(true) if extracted, Ok(false) if already exists, Err on failure
pub fn extract_stdlib() -> Result<bool, String> {
    let stdlib_dir = get_stdlib_dir();

    // If already extracted, skip
    if is_stdlib_extracted() {
        return Ok(false);
    }

    // Create ~/.quest/lib/ directory
    fs::create_dir_all(&stdlib_dir)
        .map_err(|e| format!("Failed to create stdlib directory: {}", e))?;

    // Extract all embedded files
    extract_dir(&EMBEDDED_LIB, &stdlib_dir)?;

    Ok(true)
}

/// Recursively extract a directory from embedded files
fn extract_dir(embedded_dir: &Dir, target_path: &PathBuf) -> Result<(), String> {
    // Create target directory
    fs::create_dir_all(target_path)
        .map_err(|e| format!("Failed to create directory {:?}: {}", target_path, e))?;

    // Extract all files
    for file in embedded_dir.files() {
        let file_path = target_path.join(file.path().file_name().unwrap());
        fs::write(&file_path, file.contents())
            .map_err(|e| format!("Failed to write file {:?}: {}", file_path, e))?;
    }

    // Recursively extract subdirectories
    for dir in embedded_dir.dirs() {
        let dir_name = dir.path().file_name().unwrap();
        let subdir_path = target_path.join(dir_name);
        extract_dir(dir, &subdir_path)?;
    }

    Ok(())
}

/// Read a module file - checks extracted location first, then embedded fallback
pub fn read_module_file(relative_path: &str) -> Result<String, String> {
    // Try extracted location first (~/.quest/lib/)
    let stdlib_dir = get_stdlib_dir();
    let extracted_path = stdlib_dir.join(relative_path);

    if extracted_path.exists() {
        return std::fs::read_to_string(&extracted_path)
            .map_err(|e| format!("Failed to read module file {:?}: {}", extracted_path, e));
    }

    // Fallback to embedded (for first-run before extraction)
    if let Some(embedded_file) = EMBEDDED_LIB.get_file(relative_path) {
        if let Some(content) = embedded_file.contents_utf8() {
            return Ok(content.to_string());
        }
    }

    Err(format!("Module file '{}' not found in extracted or embedded stdlib", relative_path))
}
