use lazy_static::lazy_static;
use tokio::runtime::Runtime;

lazy_static! {
    /// Global Tokio runtime for all HTTP operations
    /// This bridges Quest's synchronous model with async Rust HTTP libraries
    pub static ref RUNTIME: Runtime = Runtime::new()
        .expect("Failed to create Tokio runtime for HTTP module");
}
