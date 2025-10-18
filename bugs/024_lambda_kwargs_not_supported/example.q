let lambda_kwargs = fun (**opts)
  opts.len()
end

puts(lambda_kwargs(a: 1, b: 2, c: 3))
