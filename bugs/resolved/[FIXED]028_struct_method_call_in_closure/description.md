# Bug #026: Calling methods on struct instances retrieved from arrays/dicts in closures fails

## Summary
When a struct instance is stored in an array or dict, and then retrieved within a closure (or middleware function), calling a method on that retrieved struct instance fails with "Type [StructName] not found".

## Root Cause
The type information of the struct is being lost or not properly resolved when:
1. A struct is stored in a collection (array/dict)
2. The struct is retrieved from that collection
3. A method is called on the retrieved instance from within a closure or middleware

This appears to be a scope or type resolution issue in the Rust implementation of method dispatch.

## Impact
- `web.route()` function cannot properly dispatch to routers (QEP-062)
- Any Quest code that stores structs in collections and calls methods on them from closures fails

## Workaround
Instead of storing struct instances directly, keep them as module-level variables and access them directly from closures.

For example, instead of:
```quest
let middleware = fun (req)
  let found_struct = collection[index]["struct"]
  found_struct.method()  # FAILS
end
```

Use:
```quest
# Keep the struct at module level
let my_struct = Router.new()

# In middleware, call the method directly on the module-level variable
let middleware = fun (req)
  my_struct.method()  # WORKS
end
```

## Example
See: example.q

## Error Output
```
TypeErr: Type Router not found
```
