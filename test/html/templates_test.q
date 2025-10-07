use "std/test"
use "std/html/templates"

test.module("HTML Templates")

test.describe("Template Creation", fun ()
    test.it("creates a new empty template engine", fun ()
        let tmpl = templates.create()
        test.assert_type(tmpl, "HtmlTemplate", nil)
    end)

    test.it("creates template engine from directory pattern", fun ()
        # This should not error even if no files match
        let tmpl = templates.from_dir("nonexistent/*.html")
        test.assert_type(tmpl, "HtmlTemplate", nil)
    end)
end)

test.describe("Template Registration", fun ()
    test.it("adds a simple template", fun ()
        let tmpl = templates.create()
        tmpl.add_template("greeting", "Hello, {{ name }}!")
        let names = tmpl.get_template_names()
        test.assert_eq(names.len(), 1, nil)
    end)

    test.it("adds multiple templates", fun ()
        let tmpl = templates.create()
        tmpl.add_template("template1", "Content 1")
        tmpl.add_template("template2", "Content 2")
        let names = tmpl.get_template_names()
        test.assert_eq(names.len(), 2, nil)
    end)

    test.it("lists registered template names", fun ()
        let tmpl = templates.create()
        tmpl.add_template("test", "Test content")
        let names = tmpl.get_template_names()
        test.assert_type(names, "Array", nil)
        test.assert(names.len() > 0, "Should have at least one template")
    end)
end)

test.describe("Basic Rendering", fun ()
    test.it("renders simple template with variable", fun ()
        let tmpl = templates.create()
        tmpl.add_template("greeting", "Hello, {{ name }}!")
        let result = tmpl.render("greeting", {"name": "Alice"})
        test.assert_eq(result, "Hello, Alice!", nil)
    end)

    test.it("renders template with number", fun ()
        let tmpl = templates.create()
        tmpl.add_template("count", "Count: {{ value }}")
        let result = tmpl.render("count", {"value": 42})
        test.assert_eq(result, "Count: 42", nil)
    end)

    test.it("renders template with boolean", fun ()
        let tmpl = templates.create()
        tmpl.add_template("bool", "Active: {{ is_active }}")
        let result = tmpl.render("bool", {"is_active": true})
        test.assert_eq(result, "Active: true", nil)
    end)
end)

test.describe("Inline Rendering", fun ()
    test.it("renders template string directly", fun ()
        let tmpl = templates.create()
        let result = tmpl.render_str("Hello, {{ name }}!", {"name": "Bob"})
        test.assert_eq(result, "Hello, Bob!", nil)
    end)

    test.it("renders inline with expression", fun ()
        let tmpl = templates.create()
        let result = tmpl.render_str("Result: {{ x + y }}", {"x": 10, "y": 20})
        test.assert_eq(result, "Result: 30", nil)
    end)
end)

test.describe("Conditional Rendering", fun ()
    test.it("renders if block when condition is true", fun ()
        let tmpl = templates.create()
        let template = "{% if show %}Visible{% endif %}"
        let result = tmpl.render_str(template, {"show": true})
        test.assert_eq(result, "Visible", nil)
    end)

    test.it("hides if block when condition is false", fun ()
        let tmpl = templates.create()
        let template = "{% if show %}Visible{% endif %}"
        let result = tmpl.render_str(template, {"show": false})
        test.assert_eq(result, "", nil)
    end)

    test.it("renders if-else correctly", fun ()
        let tmpl = templates.create()
        let template = "{% if admin %}Admin{% else %}User{% endif %}"

        let admin_result = tmpl.render_str(template, {"admin": true})
        test.assert_eq(admin_result, "Admin", nil)

        let user_result = tmpl.render_str(template, {"admin": false})
        test.assert_eq(user_result, "User", nil)
    end)
end)

test.describe("Loop Rendering", fun ()
    test.it("renders for loop with array", fun ()
        let tmpl = templates.create()
        let template = "{% for item in items %}{{ item }}{% endfor %}"
        let result = tmpl.render_str(template, {"items": [1, 2, 3]})
        test.assert_eq(result, "123", nil)
    end)

    test.it("renders for loop with object properties", fun ()
        let tmpl = templates.create()
        let template = "{% for user in users %}{{ user.name }} {% endfor %}"
        let context = {
            "users": [
                {"name": "Alice"},
                {"name": "Bob"}
            ]
        }
        let result = tmpl.render_str(template, context)
        test.assert_eq(result, "Alice Bob ", nil)
    end)

    test.it("handles empty array in for loop", fun ()
        let tmpl = templates.create()
        let template = "{% for item in items %}{{ item }}{% endfor %}"
        let result = tmpl.render_str(template, {"items": []})
        test.assert_eq(result, "", nil)
    end)
end)

test.describe("Filters", fun ()
    test.it("applies length filter", fun ()
        let tmpl = templates.create()
        let template = "{{ items | length }}"
        let result = tmpl.render_str(template, {"items": [1, 2, 3, 4]})
        test.assert_eq(result, "4", nil)
    end)

    test.it("applies upper filter", fun ()
        let tmpl = templates.create()
        let template = "{{ name | upper }}"
        let result = tmpl.render_str(template, {"name": "alice"})
        test.assert_eq(result, "ALICE", nil)
    end)

    test.it("applies lower filter", fun ()
        let tmpl = templates.create()
        let template = "{{ name | lower }}"
        let result = tmpl.render_str(template, {"name": "ALICE"})
        test.assert_eq(result, "alice", nil)
    end)
end)

test.describe("Nested Data", fun ()
    test.it("accesses nested object properties", fun ()
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
        test.assert_eq(result, "Alice", nil)
    end)

    test.it("handles deeply nested arrays and objects", fun ()
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
        test.assert_eq(result, "42", nil)
    end)
end)

test.describe("Error Handling", fun ()
    test.it("errors on undefined template", fun ()
        let tmpl = templates.create()
        test.assert_raises(Err, fun ()
            tmpl.render("nonexistent", {})
        end, nil)
    end)

    test.it("errors on invalid template syntax", fun ()
        let tmpl = templates.create()
        test.assert_raises(Err, fun ()
            tmpl.render_str("{% if %}", {})
        end, nil)
    end)

    test.it("requires dict context for render", fun ()
        let tmpl = templates.create()
        tmpl.add_template("test", "Test")
        test.assert_raises(RuntimeErr, fun ()
            tmpl.render("test", "not a dict")
        end, nil)
    end)
end)
