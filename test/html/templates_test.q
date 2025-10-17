use "std/test" { module, describe, it, assert_eq, assert_type, assert_raises, assert }
use "std/html/templates"

module("HTML Templates")

describe("Template Creation", fun ()
    it("creates a new empty template engine", fun ()
        let tmpl = templates.create()
        assert_type(tmpl, "HtmlTemplate")    end)

    it("creates template engine from directory pattern", fun ()
        # This should not error even if no files match
        let tmpl = templates.from_dir("nonexistent/*.html")
        assert_type(tmpl, "HtmlTemplate")    end)
end)

describe("Template Registration", fun ()
    it("adds a simple template", fun ()
        let tmpl = templates.create()
        tmpl.add_template("greeting", "Hello, {{ name }}!")
        let names = tmpl.get_template_names()
        assert_eq(names.len(), 1)
    end)

    it("adds multiple templates", fun ()
        let tmpl = templates.create()
        tmpl.add_template("template1", "Content 1")
        tmpl.add_template("template2", "Content 2")
        let names = tmpl.get_template_names()
        assert_eq(names.len(), 2)
    end)

    it("lists registered template names", fun ()
        let tmpl = templates.create()
        tmpl.add_template("test", "Test content")
        let names = tmpl.get_template_names()
        assert_type(names, "Array")        assert(names.len() > 0, "Should have at least one template")
    end)
end)

describe("Basic Rendering", fun ()
    it("renders simple template with variable", fun ()
        let tmpl = templates.create()
        tmpl.add_template("greeting", "Hello, {{ name }}!")
        let result = tmpl.render("greeting", {"name": "Alice"})
        assert_eq(result, "Hello, Alice!")    end)

    it("renders template with number", fun ()
        let tmpl = templates.create()
        tmpl.add_template("count", "Count: {{ value }}")
        let result = tmpl.render("count", {"value": 42})
        assert_eq(result, "Count: 42")    end)

    it("renders template with boolean", fun ()
        let tmpl = templates.create()
        tmpl.add_template("bool", "Active: {{ is_active }}")
        let result = tmpl.render("bool", {"is_active": true})
        assert_eq(result, "Active: true")    end)
end)

describe("Inline Rendering", fun ()
    it("renders template string directly", fun ()
        let tmpl = templates.create()
        let result = tmpl.render_str("Hello, {{ name }}!", {"name": "Bob"})
        assert_eq(result, "Hello, Bob!")    end)

    it("renders inline with expression", fun ()
        let tmpl = templates.create()
        let result = tmpl.render_str("Result: {{ x + y }}", {"x": 10, "y": 20})
        assert_eq(result, "Result: 30")    end)
end)

describe("Conditional Rendering", fun ()
    it("renders if block when condition is true", fun ()
        let tmpl = templates.create()
        let template = "{% if show %}Visible{% endif %}"
        let result = tmpl.render_str(template, {"show": true})
        assert_eq(result, "Visible")    end)

    it("hides if block when condition is false", fun ()
        let tmpl = templates.create()
        let template = "{% if show %}Visible{% endif %}"
        let result = tmpl.render_str(template, {"show": false})
        assert_eq(result, "")    end)

    it("renders if-else correctly", fun ()
        let tmpl = templates.create()
        let template = "{% if admin %}Admin{% else %}User{% endif %}"

        let admin_result = tmpl.render_str(template, {"admin": true})
        assert_eq(admin_result, "Admin")
        let user_result = tmpl.render_str(template, {"admin": false})
        assert_eq(user_result, "User")    end)
end)

describe("Loop Rendering", fun ()
    it("renders for loop with array", fun ()
        let tmpl = templates.create()
        let template = "{% for item in items %}{{ item }}{% endfor %}"
        let result = tmpl.render_str(template, {"items": [1, 2, 3]})
        assert_eq(result, "123")    end)

    it("renders for loop with object properties", fun ()
        let tmpl = templates.create()
        let template = "{% for user in users %}{{ user.name }} {% endfor %}"
        let context = {
            "users": [
                {"name": "Alice"},
                {"name": "Bob"}
            ]
        }
        let result = tmpl.render_str(template, context)
        assert_eq(result, "Alice Bob ")    end)

    it("handles empty array in for loop", fun ()
        let tmpl = templates.create()
        let template = "{% for item in items %}{{ item }}{% endfor %}"
        let result = tmpl.render_str(template, {"items": []})
        assert_eq(result, "")    end)
end)

describe("Filters", fun ()
    it("applies length filter", fun ()
        let tmpl = templates.create()
        let template = "{{ items | length }}"
        let result = tmpl.render_str(template, {"items": [1, 2, 3, 4]})
        assert_eq(result, "4")    end)

    it("applies upper filter", fun ()
        let tmpl = templates.create()
        let template = "{{ name | upper }}"
        let result = tmpl.render_str(template, {"name": "alice"})
        assert_eq(result, "ALICE")    end)

    it("applies lower filter", fun ()
        let tmpl = templates.create()
        let template = "{{ name | lower }}"
        let result = tmpl.render_str(template, {"name": "ALICE"})
        assert_eq(result, "alice")    end)
end)

describe("Nested Data", fun ()
    it("accesses nested object properties", fun ()
        let tmpl = templates.create()
        let template = "{{ user.profile.name }}"
        let context = {
            "user": {
                "profile": {
                    "name": "Alice"
                }
            }
        }
        let result = tmpl.render_str(template, context)
        assert_eq(result, "Alice")    end)

    it("handles deeply nested arrays and objects", fun ()
        let tmpl = templates.create()
        let template = "{{ data.items.0.value }}"
        let context = {
            "data": {
                "items": [
                    {"value": 42}
                ]
            }
        }
        let result = tmpl.render_str(template, context)
        assert_eq(result, "42")    end)
end)

describe("Error Handling", fun ()
    it("errors on undefined template", fun ()
        let tmpl = templates.create()
        assert_raises(Err, fun ()
            tmpl.render("nonexistent", {})
        end)
    end)

    it("errors on invalid template syntax", fun ()
        let tmpl = templates.create()
        assert_raises(Err, fun ()
            tmpl.render_str("{% if %}", {})
        end)
    end)

    it("requires dict context for render", fun ()
        let tmpl = templates.create()
        tmpl.add_template("test", "Test")
        assert_raises(RuntimeErr, fun ()
            tmpl.render("test", "not a dict")
        end)
    end)
end)
