#!/usr/bin/env ruby

def fib(n)
  return n if n <= 1
  fib(n - 1) + fib(n - 2)
end

def verify
  expected = [0, 1, 1, 2, 3, 5, 8, 13, 21, 34]
  expected.each_with_index do |exp, i|
    result = fib(i)
    raise "Verification failed: fib(#{i}) = #{result}, expected #{exp}" if result != exp
  end
end

verify
n = 35
result = fib(n)
puts "fib(#{n}) = #{result}"
