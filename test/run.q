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
if !use_colors
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
use "test/functions/basic" as function_basic
use "test/functions/lambda" as function_lambda
use "test/loops/for" as loop_for
use "test/loops/while" as loop_while
use "test/encoding/basic" as encoding_basic

# IO tests skipped - need file cleanup support
# test.module("Running IO Tests...")
# use "test/io/basic" as io_basic

# System tests skipped - sys not available in module scope
# test.module("Running System Tests...")
# use "test/sys/basic" as sys_basic

# Print final results
test.run()
