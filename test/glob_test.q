#!/usr/bin/env ./target/release/quest

use io

puts("=== Glob Tests ===")

puts("")
puts("Find all .q files in test directory:")
let test_files = io.glob("test/*.q")
puts("Found files: ", test_files)
puts("Count: ", test_files.len())

puts("")
puts("Find all .md files in docs:")
let docs = io.glob("docs/**/*.md")
puts("Found ", docs.len(), " documentation files")
puts("First few: ", docs[0], ", ", docs[1])

puts("")
puts("=== Glob Match Tests ===")
puts("Does 'test_utils.q' match 'test_*.q'? ", io.glob_match("test_utils.q", "test_*.q"))
puts("Does 'main.rs' match 'test_*.q'? ", io.glob_match("main.rs", "test_*.q"))
puts("Does 'src/main.rs' match 'src/*.rs'? ", io.glob_match("src/main.rs", "src/*.rs"))
puts("Does 'foo/bar.txt' match '**/*.txt'? ", io.glob_match("foo/bar.txt", "**/*.txt"))

puts("")
puts("=== All Glob Tests Passed ===")
