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

test.module("Running Math Tests...")
use "test/math/basic" as math_basic
use "test/math/trig" as math_trig

test.module("Running Array Tests...")
use "test/arrays/basic" as array_basic

test.module("Running String Tests...")
use "test/string/basic" as string_basic
use "test/string/interpolation" as string_interpolation

test.module("Running Dictionary Tests...")
use "test/dict/basic" as dict_basic

test.module("Running Boolean Tests...")
use "test/bool/basic" as bool_basic

test.module("Running Module Tests...")
use "test/modules/basic" as module_basic

test.module("Running Operator Tests...")
use "test/operators/assignment" as assignment_ops

test.module("Running Function Tests...")
use "test/functions/basic" as function_basic
use "test/functions/lambda" as function_lambda

test.module("Running Loop Tests...")
use "test/loops/for" as loop_for
# While loops skipped - not implemented yet
# use "test/loops/while" as loop_while

# IO tests skipped - need file cleanup support
# test.module("Running IO Tests...")
# use "test/io/basic" as io_basic

# System tests skipped - sys not available in module scope
# test.module("Running System Tests...")
# use "test/sys/basic" as sys_basic

# Print final results
test.run()
