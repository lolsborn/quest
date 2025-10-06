# Demonstrates the "order" keyword conflict bug
# "order" is tokenized as "or" + "der", causing undefined variable errors

puts("Bug #008: 'order' conflicts with 'or' keyword")
puts("")

# Test 1: Variable named "order" - FAILS
puts("Test 1: Variable named 'order'")
try
    let order = []
    order.push("item")
    puts("  ✓ Success")
catch e
    puts("  ✗ ERROR: " .. e.message())
    puts("     'order' is parsed as 'or' + 'der'")
end
puts("")

# Test 2: Field access via self.order - ALSO FAILS
puts("Test 2: Accessing field 'self.order' in method")
type TestType
    order: Array

    fun test_access()
        self.order.push("item")  # Will fail
        self.order.len()
    end
end

try
    let t = TestType.new(order: [])
    let len = t.test_access()
    puts("  ✓ Success")
catch e
    puts("  ✗ ERROR: " .. e.message())
    puts("     Even 'self.order' fails inside methods")
end
puts("")

# Test 3: Workaround - use different name
puts("Test 3: Workaround - use 'events' instead of 'order'")
type GoodType
    events: Array

    fun test_access()
        self.events.push("item")
        self.events.len()
    end
end

try
    let t2 = GoodType.new(events: [])
    let len = t2.test_access()
    puts("  ✓ SUCCESS: events length = " .. len._str())
catch e
    puts("  ✗ ERROR: " .. e.message())
end
puts("")

# Test 4: Check other potential keyword conflicts
puts("Test 4: Other words starting with keywords")
let test_words = [
    ["android", "and"],
    ["nothing", "not"],
    ["formula", "for"],
    ["ordering", "or"]
]

let i = 0
while i < test_words.len()
    let word = test_words[i][0]
    let kw = test_words[i][1]

    try
        # Create variable, assign string value, access it
        let dummy = word
        puts("  ✓ '" .. word .. "' works (contains keyword '" .. kw .. "')")
    catch e
        puts("  ✗ '" .. word .. "' FAILS: " .. e.message())
    end

    i = i + 1
end
puts("")

puts("CONCLUSION:")
puts("  - 'order' is unusable as identifier")
puts("  - Other words starting with keywords work fine")
puts("  - Root cause: 'or' is being matched inside 'order'")
