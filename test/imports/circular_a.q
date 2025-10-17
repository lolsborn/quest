"""
Test fixture: Module A for circular import detection
This module imports module B, which imports module A - circular!
"""

use "test/imports/circular_b"

pub fun func_a()
  return "Function A"
end
