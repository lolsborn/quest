# Object types

In quest everything is an `obj`.  Similar to Ruby even integers are objects!  This means

`5 + 5` is equivalent to `5.plus(5)` becuase 5 is a `num` type which inherits `obj`

## Object type members

- **obj.cls()** - str representation of object type def
- **obj.type()** - pointer to the the interface representation for that type instance
- **obj.new() nil** - Creates and returns an instance of that type
- **obj.del() nil** - deletes / frees that object
- **obj.is(type) bool** - returns bool if obj implements type

### _under functions

Functions starting with an underscore are reserved for top level types (not implementations)

#### String representations

- **obj._str()** str - returns string representation of the object
- **obj._rep()** str - string representation in repl
- **obj._doc()** str - documentation string

### Special functions
- **obj._id()** num - unique integer identifier for that object

### Object functions

