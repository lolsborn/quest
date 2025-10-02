#!./target/release/quest

# Quest Test Suite Runner
# Loads and executes all test files

use "std/test" as test

# Check for --no-color flag in command line arguments
let use_colors = true
sys.argv.each(fun (arg)
    if arg == "--no-color"
        use_colors = false
    end
end)

# Configure test framework
if not use_colors
    test.set_colors(false)
end

# Load all test modules (test.module() calls are in each file)
use "test/math/basic" as math_basic
use "test/math/trig" as math_trig
use "test/arrays/basic" as array_basic
use "test/string/basic" as string_basic
use "test/string/interpolation" as string_interpolation
use "test/dict/basic" as dict_basic
use "test/bool/basic" as bool_basic
use "test/modules/basic" as module_basic
use "test/operators/assignment" as assignment_ops
use "test/operators/logical" as logical_ops
use "test/functions/basic" as function_basic
use "test/functions/lambda" as function_lambda
use "test/loops/for" as loop_for
use "test/loops/while" as loop_while
use "test/encoding/basic" as encoding_basic
use "test/crypto/basic" as crypto_basic

# Type system tests
use "test/types/basic" as types_basic
use "test/types/methods" as types_methods
use "test/types/traits" as types_traits
use "test/types/introspection" as types_introspection

# System tests - sys module now importable via use "std/sys"
use "test/sys/basic" as sys_basic

# IO tests
use "test/io/file_operations" as io_file_operations
use "test/io/basic" as io_basic

# Print final results
test.run()
