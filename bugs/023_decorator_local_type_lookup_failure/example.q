type LogArgs
  func
  fun _call(*args, **kwargs)
    self.func(*args, **kwargs)
  end
  fun _name() self.func._name() end
  fun _doc() self.func._doc() end
  fun _id() self.func._id() end
end

@LogArgs.new()
fun test_func()
  "hello"
end

puts(test_func())
