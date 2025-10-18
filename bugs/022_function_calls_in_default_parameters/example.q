fun increment()
  1
end

fun test(x = increment())
  x
end

puts(test())
puts(test(5))
