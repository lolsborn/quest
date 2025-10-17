# Sidebar configuration for Quest documentation
# Returns an array of sidebar items

pub fun get_sidebar()
    let sidebar = []

    # Top-level pages
    sidebar.push({"type": "link", "id": "introduction", "label": "Introduction"})
    sidebar.push({"type": "link", "id": "getting-started", "label": "Getting Started"})

    # Language Reference
    sidebar.push({"type": "category", "label": "Language Reference"})
    sidebar.push({"type": "link", "id": "language/objects", "label": "Objects"})
    sidebar.push({"type": "link", "id": "language/types", "label": "Types"})
    sidebar.push({"type": "link", "id": "language/variables", "label": "Variables"})
    sidebar.push({"type": "link", "id": "language/control-flow", "label": "Control Flow"})
    sidebar.push({"type": "link", "id": "language/loops", "label": "Loops"})
    sidebar.push({"type": "link", "id": "language/functions", "label": "Functions"})
    sidebar.push({"type": "link", "id": "language/builtins", "label": "Builtins"})
    sidebar.push({"type": "link", "id": "language/modules", "label": "Modules"})
    sidebar.push({"type": "link", "id": "language/exceptions", "label": "Exceptions"})
    sidebar.push({"type": "link", "id": "language/context-managers", "label": "Context Managers"})

    # Built-in Types
    sidebar.push({"type": "category", "label": "Built-in Types"})
    sidebar.push({"type": "link", "id": "types/number", "label": "Int, Float, Decimal"})
    sidebar.push({"type": "link", "id": "types/bigint", "label": "BigInt"})
    sidebar.push({"type": "link", "id": "types/bool", "label": "Bool"})
    sidebar.push({"type": "link", "id": "types/nil", "label": "Nil"})
    sidebar.push({"type": "link", "id": "types/string", "label": "String"})
    sidebar.push({"type": "link", "id": "types/bytes", "label": "Bytes"})
    sidebar.push({"type": "link", "id": "types/array", "label": "Array"})
    sidebar.push({"type": "link", "id": "types/dicts", "label": "Dict"})

    # Standard Library
    sidebar.push({"type": "category", "label": "Standard Library"})
    sidebar.push({"type": "link", "id": "stdlib/index", "label": "Overview"})

    sidebar.push({"type": "subcategory", "label": "Core"})
    sidebar.push({"type": "link", "id": "stdlib/math", "label": "math"})
    sidebar.push({"type": "link", "id": "stdlib/io", "label": "io"})
    sidebar.push({"type": "link", "id": "stdlib/sys", "label": "sys"})
    sidebar.push({"type": "link", "id": "stdlib/os", "label": "os"})
    sidebar.push({"type": "link", "id": "stdlib/str", "label": "str"})
    sidebar.push({"type": "link", "id": "stdlib/time", "label": "time"})

    sidebar.push({"type": "subcategory", "label": "Encoding & Data"})
    sidebar.push({"type": "link", "id": "stdlib/json", "label": "json"})
    sidebar.push({"type": "link", "id": "stdlib/encoding", "label": "encoding"})
    sidebar.push({"type": "link", "id": "stdlib/compress", "label": "compress"})
    sidebar.push({"type": "link", "id": "stdlib/urlparse", "label": "urlparse"})

    sidebar.push({"type": "subcategory", "label": "Security & Crypto"})
    sidebar.push({"type": "link", "id": "stdlib/hash", "label": "hash"})
    sidebar.push({"type": "link", "id": "stdlib/crypto", "label": "crypto"})
    sidebar.push({"type": "link", "id": "stdlib/uuid", "label": "uuid"})
    sidebar.push({"type": "link", "id": "stdlib/rand", "label": "rand"})

    sidebar.push({"type": "subcategory", "label": "Web & Network"})
    sidebar.push({"type": "link", "id": "stdlib/http", "label": "http"})
    sidebar.push({"type": "link", "id": "stdlib/html_templates", "label": "html_templates"})
    sidebar.push({"type": "link", "id": "stdlib/serial", "label": "serial"})

    sidebar.push({"type": "subcategory", "label": "Database"})
    sidebar.push({"type": "link", "id": "stdlib/database", "label": "database"})

    sidebar.push({"type": "subcategory", "label": "Development"})
    sidebar.push({"type": "link", "id": "stdlib/test", "label": "test"})
    sidebar.push({"type": "link", "id": "stdlib/regex", "label": "regex"})
    sidebar.push({"type": "link", "id": "stdlib/conf", "label": "conf"})
    sidebar.push({"type": "link", "id": "stdlib/term", "label": "term"})
    sidebar.push({"type": "link", "id": "stdlib/process", "label": "process"})

    # Advanced Topics
    sidebar.push({"type": "category", "label": "Advanced Topics"})
    sidebar.push({"type": "link", "id": "advanced/system-variables", "label": "System Variables"})

    return sidebar
end
