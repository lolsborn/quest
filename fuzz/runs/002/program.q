# Fuzz Test 002: Type System with Traits and Advanced Features
# Tests: traits, varargs, default params, named args, static methods

trait Drawable
    fun draw()
end

trait Colorable
    fun set_color(color)
    fun get_color()
end

type Shape
    pub name: Str
    pub x: Int
    pub y: Int
    pub color: Str

    impl Drawable
        fun draw()
            "Drawing " .. self.name .. " at (" .. self.x.str() .. ", " .. self.y.str() .. ")"
        end
    end

    impl Colorable
        fun set_color(color)
            self.color = color
            nil
        end

        fun get_color()
            self.color
        end
    end

    fun move(dx = 0, dy = 0)
        self.x = self.x + dx
        self.y = self.y + dy
        self
    end

    fun apply_transformations(*transforms)
        let i = 0
        let result = []
        while i < transforms.len()
            result.push("Applied: " .. transforms[i].str())
            i = i + 1
        end
        result
    end

    static fun create_at_origin(name = "origin", color = "white")
        Shape.new(name: name, x: 0, y: 0, color: color)
    end

    fun transform(operation, scale = 1.0, *extras)
        "Transform: " .. operation .. " scale=" .. scale.str() .. " extras=" .. extras.len().str()
    end
end

type Circle
    pub radius: Float
    pub center_x: Int
    pub center_y: Int
    pub fill_color: Str

    impl Drawable
        fun draw()
            "Circle r=" .. self.radius.str() .. " at (" .. self.center_x.str() .. ", " .. self.center_y.str() .. ")"
        end
    end

    impl Colorable
        fun set_color(color)
            self.fill_color = color
            nil
        end

        fun get_color()
            self.fill_color
        end
    end

    static fun create(radius, center_x = 50, center_y = 50, color = "red")
        Circle.new(radius: radius, center_x: center_x, center_y: center_y, fill_color: color)
    end

    fun apply_filters(*filters)
        let result = "Applying " .. filters.len().str() .. " filters"
        let i = 0
        while i < filters.len()
            result = result .. " [" .. filters[i].str() .. "]"
            i = i + 1
        end
        result
    end
end

type Canvas
    pub shapes: Array
    pub width: Int
    pub height: Int

    static fun new_canvas(w = 800, h = 600)
        Canvas.new(shapes: [], width: w, height: h)
    end

    fun add_shape(shape)
        self.shapes.push(shape)
        self.shapes.len()
    end

    fun add_multiple(*shapes)
        let i = 0
        while i < shapes.len()
            self.shapes.push(shapes[i])
            i = i + 1
        end
        self.shapes.len()
    end

    fun render_all()
        let i = 0
        let output = []
        while i < self.shapes.len()
            let shape = self.shapes[i]
            output.push(shape.draw())
            i = i + 1
        end
        output
    end

    fun count_by_color(color)
        let i = 0
        let count = 0
        while i < self.shapes.len()
            let shape = self.shapes[i]
            if shape.get_color() == color
                count = count + 1
            end
            i = i + 1
        end
        count
    end
end

puts("=== Fuzz Test 002: Type System ===")
puts("")

# Test 1: Basic shape creation and traits
puts("Test 1: Shape creation and traits")
let shape1 = Shape.new(name: "rect1", x: 10, y: 20, color: "blue")
puts(shape1.draw())
shape1.set_color("red")
puts("Color: " .. shape1.get_color())
puts("")

# Test 2: Default parameters
puts("Test 2: Default parameters")
shape1.move()
puts("After move(): (" .. shape1.x.str() .. ", " .. shape1.y.str() .. ")")
shape1.move(5)
puts("After move(5): (" .. shape1.x.str() .. ", " .. shape1.y.str() .. ")")
shape1.move(5, 10)
puts("After move(5, 10): (" .. shape1.x.str() .. ", " .. shape1.y.str() .. ")")
puts("")

# Test 3: Named arguments
puts("Test 3: Named arguments")
shape1.move(dx: 3, dy: 7)
puts("After move(dx: 3, dy: 7): (" .. shape1.x.str() .. ", " .. shape1.y.str() .. ")")
shape1.move(dy: 2)
puts("After move(dy: 2): (" .. shape1.x.str() .. ", " .. shape1.y.str() .. ")")
puts("")

# Test 4: Variadic parameters
puts("Test 4: Variadic parameters")
let transforms = shape1.apply_transformations("rotate", "flip", "skew")
let i = 0
while i < transforms.len()
    puts(transforms[i])
    i = i + 1
end
puts("")

# Test 5: Static methods with defaults
puts("Test 5: Static methods")
let shape2 = Shape.create_at_origin()
puts(shape2.draw() .. " color=" .. shape2.color)
let shape3 = Shape.create_at_origin(name: "custom")
puts(shape3.draw() .. " color=" .. shape3.color)
let shape4 = Shape.create_at_origin("named", "green")
puts(shape4.draw() .. " color=" .. shape4.color)
puts("")

# Test 6: Mixed parameters (required, defaults, varargs)
puts("Test 6: Mixed parameters")
puts(shape1.transform("rotate"))
puts(shape1.transform("scale", 2.5))
puts(shape1.transform("skew", 1.5, "extra1", "extra2"))
puts("")

# Test 7: Circle with all features
puts("Test 7: Circle type")
let circle1 = Circle.create(radius: 25.0)
let circle2 = Circle.create(radius: 30.0, center_x: 100)
let circle3 = Circle.create(radius: 15.0, center_x: 200, center_y: 200, color: "blue")
puts(circle1.draw())
puts(circle2.draw())
puts(circle3.draw())
puts("")

# Test 8: Circle traits
puts("Test 8: Circle traits")
circle1.set_color("green")
puts("Circle1 color: " .. circle1.get_color())
puts(circle1.apply_filters("blur", "sharpen"))
puts(circle2.apply_filters())
puts("")

# Test 9: Canvas operations
puts("Test 9: Canvas")
let canvas = Canvas.new_canvas()
canvas.add_shape(shape1)
canvas.add_shape(circle1)
canvas.add_shape(circle2)
puts("Canvas has " .. canvas.shapes.len().str() .. " shapes")
let rendered = canvas.render_all()
i = 0
while i < rendered.len()
    puts("  " .. rendered[i])
    i = i + 1
end
puts("")

# Test 10: Canvas varargs
puts("Test 10: Canvas varargs")
let canvas2 = Canvas.new_canvas(1024, 768)
let count = canvas2.add_multiple(shape2, shape3, circle3)
puts("Added " .. count.str() .. " shapes")
puts("")

# Test 11: Canvas custom size
puts("Test 11: Custom canvas")
let canvas3 = Canvas.new_canvas(640)
puts("Canvas size: " .. canvas3.width.str() .. "x" .. canvas3.height.str())
let canvas4 = Canvas.new_canvas()
puts("Default size: " .. canvas4.width.str() .. "x" .. canvas4.height.str())
puts("")

# Test 12: Color counting
puts("Test 12: Color counting")
canvas.add_shape(shape4)
canvas.add_shape(circle3)
puts("Red shapes: " .. canvas.count_by_color("red").str())
puts("Green shapes: " .. canvas.count_by_color("green").str())
puts("Blue shapes: " .. canvas.count_by_color("blue").str())
puts("")

# Test 13: Stress test
puts("Test 13: Stress test")
let big_canvas = Canvas.new_canvas()
i = 0
while i < 100
    let s = Shape.create_at_origin("s" .. i.str())
    big_canvas.add_shape(s)
    i = i + 1
end
puts("Big canvas has " .. big_canvas.shapes.len().str() .. " shapes")
let big_render = big_canvas.render_all()
puts("Rendered " .. big_render.len().str() .. " shapes")
puts("")

puts("=== All Tests Complete ===")
