# Language Improvements Discovered

## 1. F-String Expression Limitations

**Current Limitation:**
F-strings cannot contain method calls or property accesses directly:

```quest
# These FAIL:
f"Count: {self.count.str()}"
f"Index {i.str()} = {arr[i].str()}"
f"Value: {obj.method()}"

# Workaround required:
let count_str = self.count.str()
f"Count: {count_str}"
```

**Suggested Improvement:**
Allow arbitrary expressions inside f-string interpolation blocks, including:
- Method calls: `{obj.method()}`
- Property access: `{self.field.str()}`
- Chained calls: `{obj.field.method().str()}`
- Indexing: `{arr[i]}`

**Benefit:**
More concise and readable code, matching f-string behavior in Python and other languages.

---

## 2. Decorator Scope Resolution

**Current Limitation:**
Decorators must be imported from modules; locally-defined decorator types cannot be used.

**Suggested Improvement:**
Allow decorators to reference types defined in the same scope:

```quest
type MyDecorator
    func
    fun _call(*args, **kwargs)
        # ...
    end
    # ... _name, _doc, _id methods
end

# Should work:
@MyDecorator.new(config: value)
fun my_function()
    # ...
end
```

**Benefit:**
- Enables custom decorators in user code
- Supports project-specific decorator patterns
- Reduces dependency on stdlib for simple decorators

---

## 3. Decorator Instance Reuse

**Current Limitation:**
Cannot pre-instantiate decorator instances and reuse them:

```quest
let my_decorator = MyDecorator.new(setting: 42)

# This should work but doesn't:
@my_decorator
fun func1() end

@my_decorator
fun func2() end
```

**Suggested Improvement:**
Allow decorator syntax to accept already-instantiated decorator objects, not just type constructors.

**Benefit:**
- Enables decorator configuration reuse
- Reduces boilerplate
- Supports dynamic decorator creation patterns

---

## 4. Operator Consistency (Minor)

**Observation:**
Quest uses `and`/`or` keywords instead of `&&`/`||` operators. While consistent, this may surprise developers coming from C-family languages.

**Current:**
```quest
if x > 0 and y < 10
if a == 1 or b == 2
```

**Consideration:**
Document this clearly, or potentially support both forms for compatibility.

---

## 5. Decorator Documentation

**Gap:**
CLAUDE.md mentions decorators (QEP-003) but doesn't explain:
- How decorator types must implement `_call`, `_name`, `_doc`, `_id`
- The requirement for `func` field
- Automatic `self.func` binding during decoration
- Limitations on decorator scope/lookup

**Suggested Addition:**
Expand decorator documentation with:
- Complete decorator implementation guide
- Scope resolution rules
- Examples of custom decorators
- Troubleshooting common decorator errors
