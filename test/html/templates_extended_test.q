use "std/test"
use "std/html/templates"

test.module("HTML Templates - Extended")

test.describe("Loading from Files", fun ()
    test.it("loads template from file", fun ()
        let tmpl = templates.create()
        tmpl.add_template_file("email", "test/html/templates/email.html")
        let names = tmpl.get_template_names()
        test.assert(names.len() > 0, "Should have templates loaded")
    end)

    test.it("renders template loaded from file", fun ()
        let tmpl = templates.create()
        tmpl.add_template_file("email", "test/html/templates/email.html")

        let context = {
            "subject": "Test Email",
            "recipient": {"name": "Alice"},
            "message": "This is a test message",
            "sender": {"name": "Bob", "email": "bob@example.com"}
        }

        let result = tmpl.render("email", context)
        test.assert(result.contains("Test Email"), "Should contain subject")
        test.assert(result.contains("Alice"), "Should contain recipient name")
        test.assert(result.contains("bob@example.com"), "Should contain sender email")
    end)

    test.it("loads multiple templates from directory", fun ()
        let tmpl = templates.from_dir("test/html/templates/*.html")
        let names = tmpl.get_template_names()
        test.assert(names.len() >= 5, "Should load multiple templates")
    end)
end)

test.describe("Template Inheritance", fun ()
    test.it("renders template with extends", fun ()
        let tmpl = templates.from_dir("test/html/templates/**/*.html")

        let context = {
            "users": [
                {"name": "Alice", "email": "alice@example.com", "age": 30},
                {"name": "Bob", "age": 25}
            ]
        }

        let result = tmpl.render("user_list.html", context)
        test.assert(result.contains("<!DOCTYPE html>"), "Should have HTML structure from base")
        test.assert(result.contains("User Directory"), "Should have overridden header")
        test.assert(result.contains("Alice"), "Should contain user data")
        test.assert(result.contains("alice@example.com"), "Should contain email")
        test.assert(result.contains("Total users: 2"), "Should show user count")
    end)

    test.it("renders dashboard with nested data", fun ()
        let tmpl = templates.from_dir("test/html/templates/**/*.html")

        let context = {
            "user": {
                "name": "Admin User",
                "is_admin": true
            },
            "stats": {
                "total_sales": 12345.67,
                "order_count": 42,
                "customer_count": 156
            },
            "recent_orders": [
                {"id": 1001, "customer": "Alice", "amount": 99.99, "status": "completed"},
                {"id": 1002, "customer": "Bob", "amount": 149.50, "status": "pending"}
            ]
        }

        let result = tmpl.render("dashboard.html", context)
        test.assert(result.contains("Admin User"), "Should contain user name")
        test.assert(result.contains("Administrator"), "Should show admin badge")
        test.assert(result.contains("12345.67"), "Should show sales amount")
        test.assert(result.contains("#1001"), "Should show order ID")
        test.assert(result.contains("PENDING"), "Should uppercase status")
    end)
end)

test.describe("Complex Conditionals", fun ()
    test.it("renders product card with sale pricing", fun ()
        let tmpl = templates.create()
        tmpl.add_template_file("product", "test/html/templates/product_card.html")

        let context = {
            "product": {
                "id": 123,
                "name": "Awesome Widget",
                "description": "This is a really great product that does amazing things",
                "price": 99.99,
                "sale_price": 79.99,
                "in_stock": true,
                "tags": ["new", "featured", "sale"]
            }
        }

        let result = tmpl.render("product", context)
        test.assert(result.contains("Awesome Widget"), "Should contain product name")
        test.assert(result.contains("$99.99"), "Should show original price")
        test.assert(result.contains("$79.99"), "Should show sale price")
        test.assert(result.contains("Add to Cart"), "Should show add to cart button")
        test.assert(result.contains("new"), "Should contain tags")
    end)

    test.it("renders product card without sale", fun ()
        let tmpl = templates.create()
        tmpl.add_template_file("product", "test/html/templates/product_card.html")

        let context = {
            "product": {
                "id": 456,
                "name": "Regular Item",
                "description": "Normal product",
                "price": 49.99,
                "in_stock": false
            }
        }

        let result = tmpl.render("product", context)
        test.assert(result.contains("Regular Item"), "Should contain product name")
        test.assert(result.contains("$49.99"), "Should show regular price")
        test.assert(result.contains("Out of Stock"), "Should show out of stock")
        test.assert(not result.contains("Save"), "Should not show discount")
    end)

    test.it("handles empty user list", fun ()
        let tmpl = templates.from_dir("test/html/templates/**/*.html")

        let context = {"users": []}

        let result = tmpl.render("user_list.html", context)
        test.assert(result.contains("No users found"), "Should show empty message")
        test.assert(not result.contains("Total users"), "Should not show count")
    end)
end)

test.describe("Form Rendering", fun ()
    test.it("renders form with various field types", fun ()
        let tmpl = templates.from_dir("test/html/templates/**/*.html")

        let context = {
            "form": {
                "title": "Contact Form",
                "action": "/submit",
                "fields": [
                    {
                        "name": "name",
                        "label": "Your Name",
                        "type": "text",
                        "required": true,
                        "placeholder": "Enter your name"
                    },
                    {
                        "name": "email",
                        "label": "Email Address",
                        "type": "email",
                        "required": true
                    },
                    {
                        "name": "message",
                        "label": "Message",
                        "type": "textarea",
                        "rows": 5,
                        "required": true
                    },
                    {
                        "name": "subscribe",
                        "label": "Subscribe to newsletter",
                        "type": "checkbox",
                        "value": false
                    }
                ],
                "submit_text": "Send Message"
            }
        }

        let result = tmpl.render("form.html", context)
        test.assert(result.contains("Contact Form"), "Should contain form title")
        test.assert(result.contains("Your Name"), "Should contain field labels")
        test.assert(result.contains("type=\"email\""), "Should have email input")
        test.assert(result.contains("<textarea"), "Should have textarea")
        test.assert(result.contains("type=\"checkbox\""), "Should have checkbox")
        test.assert(result.contains("Send Message"), "Should have submit button")
        test.assert(result.contains("required"), "Should mark required fields")
    end)

    test.it("renders form with errors", fun ()
        let tmpl = templates.from_dir("test/html/templates/**/*.html")

        let context = {
            "form": {
                "title": "Login",
                "action": "/login",
                "fields": [
                    {"name": "username", "label": "Username", "type": "text", "required": true},
                    {"name": "password", "label": "Password", "type": "password", "required": true}
                ]
            },
            "errors": [
                "Invalid username or password",
                "Please check your credentials"
            ]
        }

        let result = tmpl.render("form.html", context)
        test.assert(result.contains("Invalid username or password"), "Should show errors")
        test.assert(result.contains("Please check your credentials"), "Should show all errors")
        test.assert(result.contains("errors"), "Should have errors class")
    end)
end)

test.describe("Email Templates", fun ()
    test.it("renders email with action button", fun ()
        let tmpl = templates.create()
        tmpl.add_template_file("email", "test/html/templates/email.html")

        let context = {
            "subject": "Verify Your Email",
            "recipient": {"name": "Alice"},
            "message": "Please click the button below to verify your email address.",
            "action_url": "https://example.com/verify?token=abc123",
            "action_text": "Verify Email",
            "sender": {
                "name": "Support Team",
                "title": "Customer Support",
                "email": "support@example.com"
            }
        }

        let result = tmpl.render("email", context)
        test.assert(result.contains("Verify Your Email"), "Should contain subject")
        test.assert(result.contains("Alice"), "Should contain recipient")
        test.assert(result.contains("verify?token=abc123"), "Should contain action URL")
        test.assert(result.contains("Verify Email"), "Should contain action text")
        test.assert(result.contains("Customer Support"), "Should contain sender title")
    end)

    test.it("renders email with item list", fun ()
        let tmpl = templates.create()
        tmpl.add_template_file("email", "test/html/templates/email.html")

        let context = {
            "subject": "Order Confirmation",
            "recipient": {"name": "Bob"},
            "message": "Thank you for your order! Here are the items:",
            "items": [
                "Widget A - $29.99",
                "Widget B - $39.99",
                "Widget C - $19.99"
            ],
            "sender": {"name": "Sales Team", "email": "sales@example.com"},
            "app_name": "My Store"
        }

        let result = tmpl.render("email", context)
        test.assert(result.contains("Order Confirmation"), "Should contain subject")
        test.assert(result.contains("Widget A"), "Should contain items")
        test.assert(result.contains("Widget B"), "Should contain all items")
        test.assert(result.contains("My Store"), "Should contain app name")
    end)
end)

test.describe("Advanced Features", fun ()
    test.it("handles missing optional values with defaults", fun ()
        let tmpl = templates.create()
        tmpl.add_template_file("email", "test/html/templates/email.html")

        let context = {
            "subject": "Simple Email",
            "recipient": {"name": "Charlie"},
            "message": "Just a simple message",
            "sender": {"name": "Admin"}
        }

        let result = tmpl.render("email", context)
        test.assert(result.contains("Simple Email"), "Should render with minimal data")
        test.assert(result.contains("Charlie"), "Should contain recipient")
        test.assert(not result.contains("Click Here"), "Should not include missing action URL")
    end)

    test.it("applies safe filter for HTML content", fun ()
        let tmpl = templates.create()
        tmpl.add_template_file("email", "test/html/templates/email.html")

        let context = {
            "subject": "HTML Message",
            "recipient": {"name": "Dave"},
            "message": "<strong>Bold text</strong> and <em>italic</em>",
            "sender": {"name": "System"}
        }

        let result = tmpl.render("email", context)
        test.assert(result.contains("<strong>Bold text</strong>"), "Should allow HTML with safe filter")
        test.assert(result.contains("<em>italic</em>"), "Should preserve HTML tags")
    end)

    test.it("renders nested loops", fun ()
        let tmpl = templates.from_dir("test/html/templates/**/*.html")

        let context = {
            "users": [
                {"name": "Alice", "email": "alice@example.com"},
                {"name": "Bob", "email": "bob@example.com"},
                {"name": "Charlie"}
            ]
        }

        let result = tmpl.render("user_list.html", context)
        test.assert(result.contains("Alice"), "Should render all users")
        test.assert(result.contains("Bob"), "Should render all users")
        test.assert(result.contains("Charlie"), "Should handle missing email")
        test.assert(result.contains("alice@example.com"), "Should show emails when present")
    end)
end)
