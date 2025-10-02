#!/usr/bin/env quest
# Demonstrates sys.script_path feature

puts("=== sys.script_path Demo ===")
puts()

# Show script path information
puts("Current script path:", sys.script_path)
puts("Script name (argv[0]):", sys.argv[0])
puts()

# Show that it's an absolute path
if sys.script_path != nil
    puts("✓ Script path is available")
    puts("✓ It's an absolute path:", sys.script_path.startswith("/"))
else
    puts("✗ Script path is nil (REPL or stdin)")
end
puts()

puts("Note: For relative imports demo, see test/rel_import/")
puts("      Example: use \".module\" as m")
puts()

puts("=== Demo Complete ===")
