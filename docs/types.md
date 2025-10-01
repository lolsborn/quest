# Types

All types in the language derive from `Obj` (Object), which serves as the base type for the type system.

## Core Types

- **obj** - Base type from which all other types derive
- **fun** - Function type
- **str** - String type
- **num** - Number type (can represent both ints and floats)
- **nil** - Null/nil type
- **bool** - Boolean type
- **arr** - Array type
- **dict** - Dictionary/map type

## Type Hierarchy

```
obj
├── fun
├── str
├── num
├── nil
├── bool
├── arr
└── dict
└── type # complex type
```


## Arrays

### String Array

```
arr{str}: lines = [
    "Hello",
    "World"
]
lines.each -> l:
    puts(l)
end
# Output:
# "Hello"
# "World"
```

### 2D array
```
arr{num} a[3,3] = [
    1, 2, 3;
    4, 5, 6;
    7, 8, 9;
]

a.each -> row:
    sum = 0
    row.each -> col:
        sum += col
    end
    puts(sum)
end
# Output:
# 6
# 15
# 24
```

## Multi Dimensional Matrixes
```
arr{num} x = arr.dim(3,3) # 3x3 matrix
puts(x)
# [
#   0, 0, 0
#   0, 0, 0
#   0, 0, 0
# ],[
#   0, 0, 0
#   0, 0, 0
#   0, 0, 0
# ],[
#   0, 0, 0
#   0, 0, 0
#   0, 0, 0
# ]
```
```
arr{num} y = arr.dim(num,4,2) # 4x2 matrix
puts(y)
# [
#   0, 0
#   0, 0
#   0, 0
#   0, 0
# ]
```

```
arr{num} z = arr.dim(num,2,3) # 2x3 matrix
puts(z)
# [
#   0, 0, 0
#   0, 0, 0
# ]
```


## Complex Types / Type Interfaces

The type keyword declares a new complex type.  A type can be used both as a class or an interface.

type Car {
    str: foo
    num: bar
    fun baz(num: x, num: z) -> str # function example No : at the end of declaration!
}

type Drive {
    num: speed
    fun go nil: # () optional if there are no arguments.  Must still be present when calling
}

type Fly {
    num: altitude
}

type Box {
    num: h
    num: w
    num: d
}

# the implementation of a type is declared separately from the type description / interface.
impl Car with Drive, Fly {

    fun baz(num: x, num: z) -> str:
        puts(self.foo)
        self.bar + x + z # implicit return
    end

    fun go { # implied nil return
        puts("Height: " + alt)
        puts("Speed: " + speed)
    }

}

repl[0]> c = Car.new()
repl[1]> c.is(Fly)
   true
repl[2]> c.is(Box)
   false
repl[3] c.altitutde = 1000
repl[4] c.speed = 50
repl[5] c.go()
   Height: 1000
   Speed: 50
repl[6] Box.new()
   Error: There is no impl for Box

