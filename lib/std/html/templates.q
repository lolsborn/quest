# HTML Templates Module
# Wrapper for the std/html/templates module using Tera template engine
# Tera is a Jinja2-like templating engine with powerful features

use "html/templates" as templates

# Create a new empty Tera template engine instance
# Returns: HtmlTemplate object
fun create()
    templates.create()
end

# Create a Tera instance from a directory glob pattern
# pattern: Glob pattern like "templates/**/*.html" or "views/*.html"
# Returns: HtmlTemplate object or raises error if pattern is invalid
# Example: from_dir("templates/**/*.html")
fun from_dir(pattern)
    templates.from_dir(pattern)
end
