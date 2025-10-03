use "std/sys"

try
  puts("Hello, World!")
  sys.fail("This is a test exception")
catch e
  puts("Caught an exception: " .. e.message())
  sys.fail("This is a test exception2")
end