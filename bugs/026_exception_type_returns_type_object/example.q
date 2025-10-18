try
  raise ValueErr.new("test")
catch e: ValueErr
  let t = e.type()
  puts(t)
  if t == "ValueErr"
    puts("String match works")
  else
    puts("Not a string - it's a Type object")
  end
end
