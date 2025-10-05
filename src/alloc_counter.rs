// Allocation counter module for tracking object allocations and deallocations
use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};

static DEBUG_ENABLED: OnceLock<bool> = OnceLock::new();
static ALLOC_COUNTS: OnceLock<Mutex<HashMap<String, usize>>> = OnceLock::new();
static DEALLOC_COUNTS: OnceLock<Mutex<HashMap<String, usize>>> = OnceLock::new();

/// Check if QUEST_CLONE_DEBUG is enabled
pub fn is_debug_enabled() -> bool {
    *DEBUG_ENABLED.get_or_init(|| {
        std::env::var("QUEST_CLONE_DEBUG").is_ok()
    })
}

/// Get the allocation counts map
fn alloc_counts() -> &'static Mutex<HashMap<String, usize>> {
    ALLOC_COUNTS.get_or_init(|| Mutex::new(HashMap::new()))
}

/// Get the deallocation counts map
fn dealloc_counts() -> &'static Mutex<HashMap<String, usize>> {
    DEALLOC_COUNTS.get_or_init(|| Mutex::new(HashMap::new()))
}

/// Track an object allocation
pub fn track_alloc(type_name: &str, id: u64) {
    if !is_debug_enabled() {
        return;
    }

    // Increment count
    if let Ok(mut counts) = alloc_counts().lock() {
        *counts.entry(type_name.to_string()).or_insert(0) += 1;
    }

    // Print allocation
    eprintln!("[QUEST_CLONE_DEBUG] ALLOC: {} (id={})", type_name, id);
}

/// Track an object deallocation
pub fn track_dealloc(type_name: &str, id: u64) {
    if !is_debug_enabled() {
        return;
    }

    // Increment count
    if let Ok(mut counts) = dealloc_counts().lock() {
        *counts.entry(type_name.to_string()).or_insert(0) += 1;
    }

    // Print deallocation
    eprintln!("[QUEST_CLONE_DEBUG] DEALLOC: {} (id={})", type_name, id);
}

/// Print allocation/deallocation statistics
pub fn print_stats() {
    if !is_debug_enabled() {
        return;
    }

    eprintln!("\n=== QUEST_CLONE_DEBUG: Object Allocation Statistics ===");

    let alloc_map = alloc_counts().lock().unwrap();
    let dealloc_map = dealloc_counts().lock().unwrap();

    // Collect all unique types
    let mut types: Vec<String> = alloc_map.keys()
        .chain(dealloc_map.keys())
        .cloned()
        .collect();
    types.sort();
    types.dedup();

    eprintln!("\n{:<20} {:>12} {:>12} {:>12}", "Type", "Allocated", "Deallocated", "Live");
    eprintln!("{}", "-".repeat(60));

    let mut total_alloc = 0;
    let mut total_dealloc = 0;

    for type_name in &types {
        let alloc = *alloc_map.get(type_name).unwrap_or(&0);
        let dealloc = *dealloc_map.get(type_name).unwrap_or(&0);
        let live = alloc.saturating_sub(dealloc);

        total_alloc += alloc;
        total_dealloc += dealloc;

        eprintln!("{:<20} {:>12} {:>12} {:>12}", type_name, alloc, dealloc, live);
    }

    eprintln!("{}", "-".repeat(60));
    eprintln!("{:<20} {:>12} {:>12} {:>12}",
        "TOTAL", total_alloc, total_dealloc, total_alloc.saturating_sub(total_dealloc));
    eprintln!();
}
