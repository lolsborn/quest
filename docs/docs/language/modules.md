# Modules

## Import Syntax

Quest supports flexible module import syntax:

### Standard Library Modules

Import built-in modules by name (no quotes):

```quest
use math
use os
use term
use hash
use json
use io
```

Available standard library modules:
- **math** - Mathematical functions and constants (sin, cos, pi, etc.)
- **os** - Operating system utilities and module search paths
- **term** - Terminal colors and formatting
- **hash** - Hashing functions (MD5, SHA, etc.)
- **json** - JSON parsing and serialization

### External Files with Automatic Aliases

Import `.q` files and Quest automatically derives the alias from the filename:

```quest
use "utils/helpers"      # Imports as "helpers" (derived from filename)
use "lib/math/advanced"  # Imports as "advanced"
use "std/test"           # Imports as "test"
```

The `.q` extension is optional and will be added automatically:

```quest
use "utils/helpers.q"    # Same as use "utils/helpers"
use "utils/helpers"      # Automatically becomes "utils/helpers.q"
```

### Explicit Aliases with `as` Keyword

Use the `as` keyword to specify a custom alias:

```quest
use "std/test" as test_framework
use "utils/helpers" as utils
use "lib/math/advanced" as math
```

## External Modules

## Module Search Path

When importing external modules with `use "path"` or `use "path" as alias`, Quest searches for the module file in the following order:

1. **Current working directory** - Always checked first
2. **Directories in `os.search_path`** - User-modifiable at runtime
3. **Directories from `QUEST_INCLUDE` environment variable** - Set before starting Quest

### Search Path Priority

The search path is constructed with this precedence:
1. Current directory (implicit, always first)
2. Paths prepended to `os.search_path` at runtime (highest priority for user additions)
3. Paths from `QUEST_INCLUDE` environment variable (loaded at startup)

### Using QUEST_INCLUDE

Set the `QUEST_INCLUDE` environment variable to add default module search directories:

```bash
# Unix/Linux/macOS (colon-separated)
export QUEST_INCLUDE="/usr/local/lib/quest:/home/user/quest_modules"
./quest

# Windows (semicolon-separated)
set QUEST_INCLUDE=C:\quest\lib;C:\Users\user\quest_modules
quest.exe
```

### Runtime Path Inspection

You can inspect the search path at runtime using array methods:

```quest
use os

# View current search paths
puts("Search paths:", os.search_path)
puts("Length:", os.search_path.len())

# Get first and last paths
if os.search_path.len() > 0
    puts("First path:", os.search_path.first())
    puts("Last path:", os.search_path.last())
end
```

**Note:** Direct assignment to module members (`os.search_path = ...`) is not yet supported. The search path must be set via the `QUEST_INCLUDE` environment variable before starting Quest.

See [arrays.md](arrays.md) for available array methods: `push`, `pop`, `shift`, `unshift`, `first`, `last`, `get`, `len`.

### Example: Module Resolution

Given this search configuration:
- Current directory: `/home/user/project`
- `os.search_path`: `["/opt/quest/modules", "/usr/local/share/quest"]`

When you execute `use "utils/helper"` or `use "utils/helper" as helper`, Quest searches in order:
1. `/home/user/project/utils/helper.q`
2. `/opt/quest/modules/utils/helper.q`
3. `/usr/local/share/quest/utils/helper.q`

The first file found is loaded as the module.

### Module Not Found Error

If a module cannot be found in any search location, Quest reports an error:

```text
use "nonexistent.q" missing
# Error: Module 'nonexistent.q' not found in current directory or search paths: [/opt/quest/modules, /usr/local/share/quest]
```
