# Bugs Found in Session 002

## Bug 1: Decorators Not Supported on Type Methods

**Severity:** Medium (Missing Feature)

**Description:**
Decorators cannot be applied to type methods (instance or static methods within type definitions). The error occurs at runtime with message: "Decorators on methods are not yet fully supported."

**Reproduction:**
```quest
use "std/decorators" as dec
let Timing = dec.Timing

type Shape
    impl SomeTrait
        @Timing
        fun draw()
            # ...
        end
    end
end
```

**Expected:**
Decorator should wrap the method call and measure timing.

**Actual:**
TypeErr: "Decorators on methods are not yet fully supported. Decorators work on standalone functions and will be extended to methods in a future update."

**Status:** Known limitation per error message, needs implementation

## Bug 2: Private Field Access Error Message Could Be Clearer

**Severity:** Low (UX Improvement)

**Description:**
When accessing a private field from outside the type, the error "Field 'color' of type Shape is private" is correct but doesn't indicate where the illegal access occurred or suggest using a public getter method.

**Reproduction:**
```quest
type Shape
    color: Str  # Private by default
end

let s = Shape.new(color: "red")
puts(s.color)  # Error: Field 'color' of type Shape is private
```

**Expected:**
Error message with line number and suggestion to use a getter or make field public.

**Actual:**
Basic error message without context.

**Status:** Works correctly, could be enhanced with better diagnostics
