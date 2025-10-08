#!/usr/bin/env quest

puts("Testing dict mutation...")

fun test_mutation(d)
    puts("Before: d['x'] = " .. d["x"].str())
    d["x"] = d["x"] + 1
    puts("Inside: d['x'] = " .. d["x"].str())
end

let mydict = {x: 5, y: 10}
puts("Initial: mydict['x'] = " .. mydict["x"].str())

test_mutation(mydict)

puts("After: mydict['x'] = " .. mydict["x"].str() .. " (should be 6)")

if mydict["x"] == 6
    puts("✅ Dict mutation persisted!")
else
    puts("❌ Dict mutation did NOT persist!")
end
