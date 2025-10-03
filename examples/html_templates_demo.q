#!/usr/bin/env quest
# HTML Templates Demo
# Demonstrates the Tera template engine wrapper

use "std/html/templates" as templates

puts("=== HTML Templates Demo ===\n")

# 1. Create a new template engine instance
puts("1. Creating template engine...")
let tmpl = templates.create()
puts("   Created: ", tmpl, "\n")

# 2. Add a simple template from string
puts("2. Adding a simple greeting template...")
tmpl.add_template("greeting", "Hello, {{ name }}!")
puts("   Template added\n")

# 3. Render the template
puts("3. Rendering greeting template...")
let context = {"name": "Alice"}
let result = tmpl.render("greeting", context)
puts("   Result: ", result, "\n")

# 4. Add a more complex template with loops
puts("4. Adding a user list template...")
let user_list_template = """
<h1>{{ title }}</h1>
<ul>
{% for user in users %}
  <li>{{ user.name }} ({{ user.age }} years old)</li>
{% endfor %}
</ul>
<p>Total users: {{ users | length }}</p>
"""
tmpl.add_template("users", user_list_template)
puts("   Template added\n")

# 5. Render with complex data
puts("5. Rendering user list template...")
let user_context = {
    "title": "User Directory",
    "users": [
        {"name": "Alice", "age": 30},
        {"name": "Bob", "age": 25},
        {"name": "Charlie", "age": 35}
    ]
}
let user_html = tmpl.render("users", user_context)
puts("   Result:\n", user_html, "\n")

# 6. Render template directly from string (no registration)
puts("6. Rendering inline template...")
let inline_template = "The answer is {{ value * 2 }}"
let inline_context = {"value": 21}
let inline_result = tmpl.render_str(inline_template, inline_context)
puts("   Result: ", inline_result, "\n")

# 7. Conditional rendering
puts("7. Conditional rendering...")
let cond_template = """
{% if user.is_admin %}
  <p>Welcome, admin {{ user.name }}!</p>
{% else %}
  <p>Welcome, {{ user.name }}!</p>
{% endif %}
"""
tmpl.add_template("conditional", cond_template)

let admin_context = {"user": {"name": "Admin", "is_admin": true}}
let admin_result = tmpl.render("conditional", admin_context)
puts("   Admin result: ", admin_result)

let user_context2 = {"user": {"name": "User", "is_admin": false}}
let user_result = tmpl.render("conditional", user_context2)
puts("   User result: ", user_result, "\n")

# 8. List registered templates
puts("8. Listing registered templates...")
let template_names = tmpl.get_template_names()
puts("   Registered templates: ", template_names, "\n")

puts("=== Demo Complete ===")
