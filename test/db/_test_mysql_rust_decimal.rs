// Quick test to see if mysql crate supports rust_decimal directly

use mysql::*;
use mysql::prelude::*;

fn main() {
    // Check if rust_decimal::Decimal implements FromValue
    println!("Testing rust_decimal with mysql crate...");

    // Try to see if we can convert Value to Decimal
    let value = Value::Bytes(b"123.456".to_vec());

    // This will fail at compile time if rust_decimal isn't supported
    match rust_decimal::Decimal::from_value_opt(value) {
        Ok(decimal) => println!("Successfully converted to Decimal: {}", decimal),
        Err(e) => println!("Failed to convert: {:?}", e),
    }
}
