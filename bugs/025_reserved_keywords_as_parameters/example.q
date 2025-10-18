# Test reserved keywords as parameter names

# Fails: 'step' is reserved
fun make_range_step(start, step = 1)
  start + step
end

# Fails: 'end' is reserved
fun make_range_end(start, end = 10)
  start + end
end

puts(make_range_step(10))
puts(make_range_end(5))
