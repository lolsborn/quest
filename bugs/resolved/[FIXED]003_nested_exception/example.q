
try
  puts("Hello, World!")
  raise "This is a test exception"
catch e
  puts("Caught an exception: " .. e.message())
  raise e
end