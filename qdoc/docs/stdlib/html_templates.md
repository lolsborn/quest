# HTML Templates

The `std/html/templates` module provides a powerful HTML templating engine powered by [Tera](https://keats.github.io/tera/), which uses a Jinja2-like syntax. Use it to generate dynamic HTML content for web applications, emails, reports, and more.

## Quick Start

```quest
use "std/html/templates" as templates

# Create a template engine
let tmpl = templates.create()

# Add a template
tmpl.add_template("greeting", "Hello, {{ name }}!")

# Render with data
let html = tmpl.render("greeting", {"name": "Alice"})
puts(html)  # "Hello, Alice!"
```

## Creating Template Engines

### `create()`
Creates a new empty template engine instance.

```quest
let tmpl = templates.create()
```

### `from_dir(pattern)`
Creates a template engine and loads all templates matching a glob pattern.

```quest
# Load all HTML files from templates directory
let tmpl = templates.from_dir("templates/**/*.html")

# Load specific patterns
let tmpl = templates.from_dir("views/*.html")
```

**Supported glob patterns:**
- `*.html` - All HTML files in current directory
- `templates/**/*.html` - All HTML files recursively
- `{emails,pages}/*.html` - Files in multiple directories

## Template Methods

### `render(template_name, context)`
Renders a named template with the given context data.

```quest
tmpl.add_template("user", "Name: {{ user.name }}")
let html = tmpl.render("user", {"user": {"name": "Bob"}})
```

**Parameters:**
- `template_name` (String) - Name of the template to render
- `context` (Dict) - Data to pass to the template

**Returns:** String containing rendered HTML

### `render_str(template_string, context)`
Renders a template string directly without registering it.

```quest
let template = "Count: {{ count }}"
let html = tmpl.render_str(template, {"count": 42})
```

**Use cases:**
- One-off templates
- Dynamic template generation
- Testing template syntax

### `add_template(name, content)`
Registers a template from a string.

```quest
tmpl.add_template("header", "<h1>{{ title }}</h1>")
```

### `add_template_file(name, path)`
Registers a template from a file.

```quest
tmpl.add_template_file("layout", "templates/base.html")
```

### `get_template_names()`
Returns an array of all registered template names.

```quest
let names = tmpl.get_template_names()
puts(names)  # ["header", "footer", "layout"]
```

## Template Syntax

### Variables

Use `{{ variable }}` to output values:

```quest
let tmpl = templates.create()
let html = tmpl.render_str("Hello, {{ name }}!", {"name": "World"})
# Output: "Hello, World!"
```

**Nested properties:**
```quest
let context = {
    "user": {
        "profile": {
            "name": "Alice"
        }
    }
}
let html = tmpl.render_str("{{ user.profile.name }}", context)
# Output: "Alice"
```

**Array indexing:**
```quest
let context = {"items": [1, 2, 3]}
let html = tmpl.render_str("{{ items.0 }}", context)
# Output: "1"
```

### Conditionals

Use `{% if %}` for conditional rendering:

```quest
let template = """
{% if user.is_admin %}
    <span class="badge">Admin</span>
{% else %}
    <span class="badge">User</span>
{% endif %}
"""

tmpl.render_str(template, {"user": {"is_admin": true}})
```

**Conditional operators:**
- `==` - Equals
- `!=` - Not equals
- `>`, `<`, `>=`, `<=` - Comparisons
- `and`, `or`, `not` - Logical operators

```quest
{% if count > 10 and status == "active" %}
    High activity
{% elif count > 0 %}
    Some activity
{% else %}
    No activity
{% endif %}
```

### Loops

Use `{% for %}` to iterate over arrays:

```quest
let template = """
<ul>
{% for item in items %}
    <li>{{ item }}</li>
{% endfor %}
</ul>
"""

tmpl.render_str(template, {"items": [1, 2, 3]})
```

**Loop over objects:**
```quest
{% for user in users %}
    <div class="user">
        <h3>{{ user.name }}</h3>
        <p>{{ user.email }}</p>
    </div>
{% endfor %}
```

**Loop variables:**
- `loop.index` - Current iteration (1-indexed)
- `loop.index0` - Current iteration (0-indexed)
- `loop.first` - True on first iteration
- `loop.last` - True on last iteration

```quest
{% for item in items %}
    <li class="{% if loop.first %}first{% endif %}">
        {{ loop.index }}. {{ item }}
    </li>
{% endfor %}
```

### Filters

Filters transform values using the pipe `|` operator:

```quest
{{ name | upper }}              # ALICE
{{ name | lower }}              # alice
{{ items | length }}            # 5
{{ price | round }}             # 10
{{ text | truncate(length=20) }} # Truncate to 20 chars
{{ content | safe }}            # Don't escape HTML
```

**Common filters:**
- `upper` / `lower` - Change case
- `length` - Get length of array/string
- `round(precision=N)` - Round numbers
- `truncate(length=N)` - Truncate strings
- `default(value="X")` - Provide default value
- `safe` - Disable HTML escaping
- `escape` - HTML escape (default for all variables)

**Chaining filters:**
```quest
{{ name | lower | truncate(length=10) | upper }}
```

### Template Inheritance

Create reusable base templates with `{% extends %}` and `{% block %}`:

**base.html:**
```html
<!DOCTYPE html>
<html>
<head>
    <title>{% block title %}Default Title{% endblock %}</title>
</head>
<body>
    <header>
        {% block header %}Default Header{% endblock %}
    </header>

    <main>
        {% block content %}{% endblock %}
    </main>

    <footer>
        {% block footer %}&copy; 2024{% endblock %}
    </footer>
</body>
</html>
```

**page.html:**
```html
{% extends "base.html" %}

{% block title %}My Page{% endblock %}

{% block content %}
    <h1>Welcome!</h1>
    <p>This is my page content.</p>
{% endblock %}
```

**Quest code:**
```quest
let tmpl = templates.from_dir("templates/**/*.html")
let html = tmpl.render("page.html", {})
# Outputs full HTML with base layout
```

### Comments

Use `{# #}` for template comments (not included in output):

```quest
{# This is a comment and won't appear in rendered HTML #}
<p>This will appear</p>
```

### Whitespace Control

Control whitespace with `-` in tags:

```quest
{%- if true -%}
    No whitespace before or after
{%- endif -%}
```

## Common Use Cases

### Email Templates

```quest
use "std/html/templates" as templates

let tmpl = templates.create()
tmpl.add_template_file("welcome", "templates/emails/welcome.html")

let html = tmpl.render("welcome", {
    "user": {"name": "Alice"},
    "action_url": "https://example.com/verify",
    "sender": {"name": "Support Team"}
})

# Send email with html content
```

### Web Pages

```quest
# Load all templates
let tmpl = templates.from_dir("views/**/*.html")

# Render page
let html = tmpl.render("home.html", {
    "user": current_user,
    "posts": recent_posts,
    "stats": dashboard_stats
})
```

### Reports

```quest
let tmpl = templates.create()
tmpl.add_template_file("report", "reports/sales.html")

let html = tmpl.render("report", {
    "period": "Q4 2024",
    "revenue": 125000.50,
    "orders": order_list,
    "growth": 15.5
})

# Export to PDF or save as HTML
```

### Forms

```quest
let form_html = tmpl.render("form.html", {
    "form": {
        "title": "Contact Form",
        "action": "/submit",
        "fields": [
            {"name": "email", "type": "email", "required": true},
            {"name": "message", "type": "textarea", "rows": 5}
        ]
    },
    "errors": validation_errors
})
```

## Best Practices

### 1. Organize Templates by Purpose

```
templates/
├── layouts/
│   └── base.html
├── emails/
│   ├── welcome.html
│   └── notification.html
└── pages/
    ├── home.html
    └── dashboard.html
```

### 2. Use Template Inheritance

Create a base layout and extend it:

```quest
# Load once
let tmpl = templates.from_dir("templates/**/*.html")

# All pages inherit from base.html
tmpl.render("pages/home.html", data)
tmpl.render("pages/about.html", data)
```

### 3. Validate Context Data

Ensure all required data is present:

```quest
fun render_user_page(user)
    if user == nil
        raise "User required for user page template"
    end

    tmpl.render("user.html", {
        "user": user,
        "timestamp": time.now()
    })
end
```

### 4. Use Filters for Safety

Always escape user-generated content (automatic by default):

```quest
{# Automatically escaped #}
<p>{{ user_comment }}</p>

{# Only use 'safe' for trusted HTML #}
<div>{{ trusted_html | safe }}</div>
```

### 5. Cache Template Instances

Create the template engine once and reuse:

```quest
# At startup
let app_templates = templates.from_dir("templates/**/*.html")

# In handlers
fun handle_request(request)
    let html = app_templates.render("page.html", request.data)
    response.send(html)
end
```

## Error Handling

Template errors include helpful messages:

```quest
try
    let html = tmpl.render("missing.html", {})
catch e
    puts(e.message())  # "Template error: Template 'missing.html' not found"
end

try
    tmpl.render_str("{% if %}", {})
catch e
    puts(e.message())  # "Template error: Failed to parse..."
end
```

## Performance Tips

1. **Load templates once**: Create template engine at startup
2. **Use `from_dir()`**: Load all templates in one call
3. **Avoid `render_str()` in loops**: Register templates instead
4. **Keep templates simple**: Complex logic belongs in Quest code

## Template Engine Details

Quest's HTML templates module uses [Tera](https://keats.github.io/tera/), a mature Rust templating engine that provides:

- **Jinja2-compatible syntax**: Familiar to Python/Flask developers
- **Fast rendering**: Compiled templates for performance
- **Safe by default**: Automatic HTML escaping
- **Rich filter library**: Built-in text transformations
- **Template inheritance**: Reusable layouts and components

## Type Reference

### HtmlTemplate Type

**Methods:**
- `render(name, context)` - Render named template
- `render_str(template, context)` - Render string template
- `add_template(name, content)` - Add template from string
- `add_template_file(name, path)` - Add template from file
- `get_template_names()` - List registered templates
- `cls()` - Returns `"HtmlTemplate"`

## Examples

See comprehensive examples:
- `examples/html_templates_demo.q` - Basic inline templates
- `examples/html_file_templates_demo.q` - File-based templates with inheritance
- `test/html/templates/` - Real-world template examples

## See Also

- [JSON Module](./json.md) - For data serialization
- [IO Module](./io.md) - For file operations
- [String Methods](./str.md) - For string manipulation
- [Tera Documentation](https://keats.github.io/tera/docs/) - Full Tera syntax reference
