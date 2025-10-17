use "std/test" { module, describe, it, assert, assert_eq, assert_raises }
use "std/html/templates"

module("HTML Templates - Extended")

describe("Loading from Files", fun ()
    it("loads template from file", fun ()
        let tmpl = templates.create()
        tmpl.add_template_file("email", "test/html/templates/email.html")
        let names = tmpl.get_template_names()
        assert(names.len() > 0, "Should have templates loaded")
    end)

    it("renders template loaded from file", fun ()
        let tmpl = templates.create()
        tmpl.add_template_file("email", "test/html/templates/email.html")

        let context = {
            "subject": "Test Email",
            "recipient": {"name": "Alice"},
            "message": "This is a test message",
            "sender": {"name": "Bob", "email": "bob@example.com"}
        }

        let result = tmpl.render("email", context)
        assert(result.contains("Test Email"), "Should contain subject")
        assert(result.contains("Alice"), "Should contain recipient name")
        assert(result.contains("bob@example.com"), "Should contain sender email")
    end)

    it("loads multiple templates from directory", fun ()
        let tmpl = templates.from_dir("test/html/templates/*.html")
        let names = tmpl.get_template_names()
        assert(names.len() >= 5, "Should load multiple templates")
    end)
end)

describe("Template Inheritance", fun ()
    it("renders template with extends", fun ()
        let tmpl = templates.from_dir("test/html/templates/**/*.html")

        let context = {
            "users": [
                {"name": "Alice", "email": "alice@example.com", "age": 30},
                {"name": "Bob", "age": 25}
            ]
        }

        let result = tmpl.render("user_list.html", context)
        assert(result.contains("<!DOCTYPE html>"), "Should have HTML structure from base")
        assert(result.contains("User Directory"), "Should have overridden header")
        assert(result.contains("Alice"), "Should contain user data")
        assert(result.contains("alice@example.com"), "Should contain email")
        assert(result.contains("Total users: 2"), "Should show user count")
    end)

    it("renders dashboard with nested data", fun ()
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
        assert(result.contains("Admin User"), "Should contain user name")
        assert(result.contains("Administrator"), "Should show admin badge")
        assert(result.contains("12345.67"), "Should show sales amount")
        assert(result.contains("#1001"), "Should show order ID")
        assert(result.contains("PENDING"), "Should uppercase status")
    end)
end)

describe("Complex Conditionals", fun ()
    it("renders product card with sale pricing", fun ()
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
        assert(result.contains("Awesome Widget"), "Should contain product name")
        assert(result.contains("$99.99"), "Should show original price")
        assert(result.contains("$79.99"), "Should show sale price")
        assert(result.contains("Add to Cart"), "Should show add to cart button")
        assert(result.contains("new"), "Should contain tags")
    end)

    it("renders product card without sale", fun ()
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
        assert(result.contains("Regular Item"), "Should contain product name")
        assert(result.contains("$49.99"), "Should show regular price")
        assert(result.contains("Out of Stock"), "Should show out of stock")
        assert(not result.contains("Save"), "Should not show discount")
    end)

    it("handles empty user list", fun ()
        let tmpl = templates.from_dir("test/html/templates/**/*.html")

        let context = {"users": []}

        let result = tmpl.render("user_list.html", context)
        assert(result.contains("No users found"), "Should show empty message")
        assert(not result.contains("Total users"), "Should not show count")
    end)
end)

describe("Form Rendering", fun ()
    it("renders form with various field types", fun ()
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
        assert(result.contains("Contact Form"), "Should contain form title")
        assert(result.contains("Your Name"), "Should contain field labels")
        assert(result.contains("type=\"email\""), "Should have email input")
        assert(result.contains("<textarea"), "Should have textarea")
        assert(result.contains("type=\"checkbox\""), "Should have checkbox")
        assert(result.contains("Send Message"), "Should have submit button")
        assert(result.contains("required"), "Should mark required fields")
    end)

    it("renders form with errors", fun ()
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
        assert(result.contains("Invalid username or password"), "Should show errors")
        assert(result.contains("Please check your credentials"), "Should show all errors")
        assert(result.contains("errors"), "Should have errors class")
    end)
end)

describe("Email Templates", fun ()
    it("renders email with action button", fun ()
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
        assert(result.contains("Verify Your Email"), "Should contain subject")
        assert(result.contains("Alice"), "Should contain recipient")
        assert(result.contains("verify?token=abc123"), "Should contain action URL")
        assert(result.contains("Verify Email"), "Should contain action text")
        assert(result.contains("Customer Support"), "Should contain sender title")
    end)

    it("renders email with item list", fun ()
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
        assert(result.contains("Order Confirmation"), "Should contain subject")
        assert(result.contains("Widget A"), "Should contain items")
        assert(result.contains("Widget B"), "Should contain all items")
        assert(result.contains("My Store"), "Should contain app name")
    end)
end)

describe("Advanced Features", fun ()
    it("handles missing optional values with defaults", fun ()
        let tmpl = templates.create()
        tmpl.add_template_file("email", "test/html/templates/email.html")

        let context = {
            "subject": "Simple Email",
            "recipient": {"name": "Charlie"},
            "message": "Just a simple message",
            "sender": {"name": "Admin"}
        }

        let result = tmpl.render("email", context)
        assert(result.contains("Simple Email"), "Should render with minimal data")
        assert(result.contains("Charlie"), "Should contain recipient")
        assert(not result.contains("Click Here"), "Should not include missing action URL")
    end)

    it("applies safe filter for HTML content", fun ()
        let tmpl = templates.create()
        tmpl.add_template_file("email", "test/html/templates/email.html")

        let context = {
            "subject": "HTML Message",
            "recipient": {"name": "Dave"},
            "message": "<strong>Bold text</strong> and <em>italic</em>",
            "sender": {"name": "System"}
        }

        let result = tmpl.render("email", context)
        assert(result.contains("<strong>Bold text</strong>"), "Should allow HTML with safe filter")
        assert(result.contains("<em>italic</em>"), "Should preserve HTML tags")
    end)

    it("renders nested loops", fun ()
        let tmpl = templates.from_dir("test/html/templates/**/*.html")

        let context = {
            "users": [
                {"name": "Alice", "email": "alice@example.com"},
                {"name": "Bob", "email": "bob@example.com"},
                {"name": "Charlie"}
            ]
        }

        let result = tmpl.render("user_list.html", context)
        assert(result.contains("Alice"), "Should render all users")
        assert(result.contains("Bob"), "Should render all users")
        assert(result.contains("Charlie"), "Should handle missing email")
        assert(result.contains("alice@example.com"), "Should show emails when present")
    end)
end)
