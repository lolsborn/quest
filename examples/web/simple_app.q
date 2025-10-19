# Simple Quest Web Server Example (QEP-060)
# Demonstrates the application-centric web server pattern
#
# Run with: quest examples/web/simple_app.q
# Then visit: http://localhost:3000/

use "std/web" as web
use "std/time"

# Configuration: Register static directory
web.static("/public", "./public")

# Handler function (required by handle_request mechanism)
fun handle_request(request)
    let path = request["path"]
    let method = request["method"]

    # Simple routing
    if path == "/"
        {
            "status": 200,
            "body": "Welcome to Quest Web Server (QEP-060)",
            "headers": {
                "Content-Type": "text/plain"
            }
        }
    elif path == "/hello"
        {
            "status": 200,
            "body": "Hello from Quest!",
            "headers": {
                "Content-Type": "text/plain"
            }
        }
    elif path == "/time"
        {
            "status": 200,
            "body": "Server time: " .. time.now().str(),
            "headers": {
                "Content-Type": "text/plain"
            }
        }
    else
        {
            "status": 404,
            "body": "Not Found: " .. path,
            "headers": {
                "Content-Type": "text/plain"
            }
        }
    end
end

# Start the server (QEP-060 Phase 2)
# This will display startup info and block until Ctrl+C
println("Starting Quest web server...")
println("Configuration: host=127.0.0.1, port=3000")
println("Press Ctrl+C to stop")
println!()

web.run()

# Server has stopped - cleanup happens here
println("Server stopped.")
