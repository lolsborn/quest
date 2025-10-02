use ".module" as base

let enhanced_greeting = base.greeting .. " (enhanced)"

fun greet(name)
    return base.greet(name) .. " - enhanced!"
end
