#!/usr/bin/env quest
# HTML File Templates Demo
# Demonstrates using real HTML template files with Tera

use "std/html/templates" as templates

puts("=== HTML File Templates Demo ===\n")

# 1. Load all templates from directory
puts("1. Loading templates from directory...")
let tmpl = templates.from_dir("test/html/templates/**/*.html")
let template_names = tmpl.get_template_names()
puts("   Loaded ", template_names.len(), " templates")
puts("   Templates: ", template_names, "\n")

# 2. Render User List with Template Inheritance
puts("2. Rendering user list (uses template inheritance)...")
let user_context = {
    "users": [
        {"name": "Alice Johnson", "email": "alice@example.com", "age": 30},
        {"name": "Bob Smith", "email": "bob@example.com", "age": 25},
        {"name": "Charlie Brown", "age": 35},
        {"name": "Diana Prince", "email": "diana@example.com"}
    ]
}
let user_html = tmpl.render("user_list.html", user_context)
puts("   Generated HTML length: ", user_html.len(), " characters")
puts("   Contains 'User Directory': ", user_html.contains("User Directory"))
puts("   Contains 'Total users: 4': ", user_html.contains("Total users: 4"), "\n")

# 3. Render Dashboard with Complex Data
puts("3. Rendering dashboard with stats and orders...")
let dashboard_context = {
    "user": {
        "name": "Admin User",
        "is_admin": true
    },
    "stats": {
        "total_sales": 52450.75,
        "order_count": 127,
        "customer_count": 89
    },
    "recent_orders": [
        {"id": 2001, "customer": "Alice", "amount": 299.99, "status": "completed"},
        {"id": 2002, "customer": "Bob", "amount": 149.50, "status": "pending"},
        {"id": 2003, "customer": "Charlie", "amount": 89.99, "status": "shipped"}
    ]
}
let dashboard_html = tmpl.render("dashboard.html", dashboard_context)
puts("   Generated HTML length: ", dashboard_html.len(), " characters")
puts("   Contains 'Administrator': ", dashboard_html.contains("Administrator"))
puts("   Contains sales amount: ", dashboard_html.contains("52450.75"), "\n")

# 4. Render Product Card with Sale
puts("4. Rendering product card with sale pricing...")
let product_context = {
    "product": {
        "id": 1001,
        "name": "Quest Programming Book",
        "description": "Learn Quest programming from scratch with practical examples and real-world projects. Perfect for beginners and advanced developers alike.",
        "price": 49.99,
        "sale_price": 34.99,
        "in_stock": true,
        "tags": ["programming", "quest", "bestseller", "sale"]
    }
}
let product_html = tmpl.render("product_card.html", product_context)
puts("   Generated HTML length: ", product_html.len(), " characters")
puts("   Contains product name: ", product_html.contains("Quest Programming Book"))
puts("   Shows sale price: ", product_html.contains("$34.99"))
puts("   Has tags: ", product_html.contains("programming"), "\n")

# 5. Render Email Template
puts("5. Rendering welcome email...")
let email_context = {
    "subject": "Welcome to Quest!",
    "recipient": {
        "name": "New User"
    },
    "message": "Thank you for joining Quest! We're excited to have you on board. Get started by exploring our documentation and examples.",
    "action_url": "https://quest-lang.org/docs/getting-started",
    "action_text": "Get Started",
    "sender": {
        "name": "Quest Team",
        "title": "Developer Relations",
        "email": "hello@quest-lang.org"
    },
    "app_name": "Quest Programming Language"
}
let email_html = tmpl.render("email.html", email_context)
puts("   Generated HTML length: ", email_html.len(), " characters")
puts("   Contains subject: ", email_html.contains("Welcome to Quest!"))
puts("   Has action button: ", email_html.contains("Get Started"))
puts("   Includes sender: ", email_html.contains("Developer Relations"), "\n")

# 6. Render Contact Form
puts("6. Rendering contact form...")
let form_context = {
    "form": {
        "title": "Contact Us",
        "action": "/contact/submit",
        "fields": [
            {
                "name": "name",
                "label": "Your Name",
                "type": "text",
                "required": true,
                "placeholder": "John Doe"
            },
            {
                "name": "email",
                "label": "Email Address",
                "type": "email",
                "required": true,
                "placeholder": "you@example.com"
            },
            {
                "name": "subject",
                "label": "Subject",
                "type": "text",
                "required": true
            },
            {
                "name": "message",
                "label": "Your Message",
                "type": "textarea",
                "rows": 8,
                "required": true,
                "help": "Please provide as much detail as possible"
            },
            {
                "name": "subscribe",
                "label": "Subscribe to our newsletter",
                "type": "checkbox",
                "value": true
            }
        ],
        "submit_text": "Send Message",
        "cancel_url": "/"
    }
}
let form_html = tmpl.render("form.html", form_context)
puts("   Generated HTML length: ", form_html.len(), " characters")
puts("   Contains form title: ", form_html.contains("Contact Us"))
puts("   Has textarea: ", form_html.contains("<textarea"))
puts("   Has cancel button: ", form_html.contains("Cancel"), "\n")

# 7. Render Empty User List
puts("7. Rendering empty user list...")
let empty_context = {"users": []}
let empty_html = tmpl.render("user_list.html", empty_context)
puts("   Generated HTML length: ", empty_html.len(), " characters")
puts("   Shows empty message: ", empty_html.contains("No users found"))
puts("   No user count: ", not empty_html.contains("Total users"), "\n")

# 8. Load Single Template from File
puts("8. Loading single template from file...")
let email_tmpl = templates.create()
email_tmpl.add_template_file("alert", "test/html/templates/email.html")
let alert_ctx = {
    "subject": "System Notification",
    "recipient": {"name": "System Admin"},
    "message": "The backup completed successfully at 2:00 AM.",
    "sender": {"name": "Automated System"}
}
let alert_html = email_tmpl.render("alert", alert_ctx)
puts("   Generated HTML length: ", alert_html.len(), " characters")
puts("   Contains notification: ", alert_html.contains("System Notification"), "\n")

puts("=== Demo Complete ===")
puts("\nAll templates rendered successfully!")
puts("Templates support:")
puts("  ✓ Template inheritance (extends/blocks)")
puts("  ✓ Conditionals (if/elif/else)")
puts("  ✓ Loops (for..in)")
puts("  ✓ Filters (upper, lower, length, round, truncate, etc.)")
puts("  ✓ Nested data structures")
puts("  ✓ Default values")
puts("  ✓ Safe HTML rendering")
