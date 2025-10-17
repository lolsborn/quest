"""
Test fixture: Module with public and private members
"""

# Public function - can be imported
pub fun public_function()
  return "I am public"
end

# Private function - should NOT be importable
fun private_function()
  return "I am private"
end

# Public function that uses private helper
pub fun uses_private()
  private_function() .. " (via public)"
end

# Public type
pub type PublicType
  pub field: Int

  fun public_method()
    return "Public method"
  end
end

# Private type
type PrivateType
  field: Int

  fun private_method()
    return "Private method"
  end
end

# Public constant
pub const PUBLIC_CONSTANT = 42

# Private constant
const PRIVATE_CONSTANT = 99
