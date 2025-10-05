# Minimal reproduction of self corruption bug

# Define a simple handler type
type Handler
    str: name

    fun process()
        puts("Handler processing: " .. self.name)
    end
end

# Define a container type that holds handlers
type Container
    array: handlers

    fun run()
        puts("Starting run() - self is Container")
        let i = 0

        # BUG: After first iteration, self becomes a Handler instead of Container
        while i < self.handlers.len()
            puts("Loop iteration " .. i._str())
            let handler = self.handlers[i]

            # This method call corrupts self!
            handler.process()

            # After this point, self.handlers.len() will fail
            # because self now points to handler (Handler type)
            # instead of the Container

            i = i + 1
        end

        puts("Finished run()")
    end
end

# Create test data
let h1 = Handler.new(name: "Handler1")
let h2 = Handler.new(name: "Handler2")

let container = Container.new(handlers: [h1, h2])

puts("Calling container.run()...")
container.run()
puts("Success!")

# Expected: Both handlers process, "Success!" prints
# Actual: First handler processes, then error:
#   "Struct Handler has no field 'handlers'"
