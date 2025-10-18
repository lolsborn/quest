# Simple custom module for testing
# No dependencies, just basic functions

let data = []

pub fun outer(name, callback)
    puts("Outer called: " .. name)
    callback()
end

pub fun inner(msg)
    puts("Inner called: " .. msg)
    data.push(msg)
end

pub fun get_data()
    return data
end
