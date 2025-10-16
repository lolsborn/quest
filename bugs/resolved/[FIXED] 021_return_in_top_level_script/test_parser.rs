// Quick test to see how Quest parses the return statement
// Compile with: rustc test_parser.rs

fn main() {
    let code = r#"
puts("Statement 1")
return
puts("Statement 2")
"#;

    // We can't easily test this without importing Quest's parser
    // Instead, let's look at the evaluator more carefully
    println!("Code to parse:\n{}", code);
}
