# HTML Test Templates

This directory contains HTML template files used for testing the Quest HTML templates module (powered by Tera).

## Template Files

### `base.html`
Base template demonstrating template inheritance with blocks.
- Provides overall HTML structure
- Defines blocks: `title`, `header`, `content`
- Used as parent for other templates

### `user_list.html`
User directory listing template.
- Extends `base.html`
- Displays a list of users with optional email and age
- Shows total user count
- Handles empty user list case

### `dashboard.html`
Admin dashboard template with statistics and recent orders.
- Extends `base.html`
- Shows admin badge conditionally
- Displays stats cards (sales, orders, customers)
- Renders recent orders table with status styling

### `product_card.html`
E-commerce product card component.
- Displays product details (name, description, price)
- Handles sale pricing with discount calculation
- Shows stock status (in stock / out of stock)
- Displays product tags

### `email.html`
Transactional email template.
- Standalone HTML email layout
- Supports optional action button
- Can include item lists
- Configurable sender information
- Safe HTML rendering for message content

### `form.html`
Dynamic form generator template.
- Extends `base.html`
- Supports multiple field types (text, email, password, textarea, select, checkbox)
- Shows validation errors
- Configurable submit and cancel buttons
- Field help text and required indicators

## Features Demonstrated

- **Template Inheritance**: `{% extends "base.html" %}`
- **Blocks**: `{% block content %}...{% endblock %}`
- **Conditionals**: `{% if condition %}...{% else %}...{% endif %}`
- **Loops**: `{% for item in items %}...{% endfor %}`
- **Filters**: `{{ value | upper }}`, `{{ number | round }}`, etc.
- **Safe HTML**: `{{ content | safe }}`
- **Default Values**: `{{ value | default(value="fallback") }}`
- **Expressions**: Mathematical operations, comparisons

## Usage Examples

See:
- `examples/html_file_templates_demo.q` - Comprehensive demonstration
- `test/html/templates_test.q` - Basic functionality tests
- `test/html/templates_extended_test.q` - Advanced features and file-based tests
