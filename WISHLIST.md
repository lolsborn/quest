# Wishlist

## Language Features
- **@Decorators**
- Pydantic-like validators
- Sane handling of bytes / binary data. (Partially done with bytes type and binary literals)
- /module/path/index.q for resolving `use "module/path"` ?

## Stdlib
- **cli/argparse** - Similar to https://docs.python.org/3/library/argparse.html
- **serial** - Library for talking to serial devices like Arduino (This is mostly there, but seems buggy)
- **net/http** - http client / server
    - Problably going to wrap tokio
- **net/ws** - websockets client / server
- **compress** - File read / write support with guards.

## Repl
- **readline** - Readline like functionality / history in repl.  Partially implemented with https://github.com/kkawakam/rustyline

## Libraries
- **Pheonix Live**-ish framework - https://www.phoenixframework.org/
- **Queues** - Queue runner lib similar to Dramatiq / Celery
- **ORM** - ORM similar to Django / Peewee / Active Record

## Misc
- **WebASM** - Can we run Quest in the browser with WebASM?
- **examples/** - Much better examples
- closures with captured variables - notes in functions tests