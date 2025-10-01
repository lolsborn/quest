use os

puts("=== Current Working Directory ===")
let cwd = os.getcwd()
puts("Current directory: ", cwd)

puts()
puts("=== Environment Variables ===")
let home = os.getenv("HOME")
puts("HOME = ", home)
let current_user = os.getenv("USER")
puts("USER = ", current_user)
let nonexistent = os.getenv("NONEXISTENT_VAR_12345")
puts("Nonexistent var = ", nonexistent)

puts()
puts("=== Directory Listing ===")
let entries = os.listdir(".")
puts("Entries in current directory:")
puts(entries)

puts()
puts("=== Create and Remove Directory ===")
os.mkdir("test_dir_12345")
puts("Created test_dir_12345")
let entries2 = os.listdir(".")
puts("Directory exists in listing")
os.rmdir("test_dir_12345")
puts("Removed test_dir_12345")
