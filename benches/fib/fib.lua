#!/usr/bin/env lua

function fib(n)
    if n <= 1 then
        return n
    end
    return fib(n - 1) + fib(n - 2)
end

function verify()
    local expected = {0, 1, 1, 2, 3, 5, 8, 13, 21, 34}
    for i = 1, #expected do
        local result = fib(i - 1)
        if result ~= expected[i] then
            error("Verification failed: fib(" .. (i-1) .. ") = " .. result .. ", expected " .. expected[i])
        end
    end
end

verify()
local n = 35
local result = fib(n)
print("fib(" .. n .. ") = " .. result)
