"""
Test fixture: Module B for circular import detection
This module imports module A, which imports module B - circular!
"""

use "test/imports/circular_a"

pub fun func_b()
    return "Function B"
end
