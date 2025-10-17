# std/error - Error trait for user-defined exceptions (QEP-037 Phase 2)
#
# This module defines the Error trait that custom exception types should implement.
# Implementing this trait allows types to be raised and caught in try/catch blocks
# while preserving all custom fields and behavior.

# Error trait - interface for exception types
# Types implementing this trait can be raised and caught in try/catch blocks
pub trait Error
    # Required: Get the error message
    fun message()

    # Required: Get string representation
    fun str()
end

# Helper function to check if a value implements the Error trait
pub fun is_error(value)
    # Check if value's type implements Error trait
    if value.is("struct")
        let type_obj = value._type()
        return type_obj.implements("Error")
    end
    return false
end

# Create a basic error type for examples
pub type BasicError
    pub message: Str

    impl Error
        fun message()
            return self.message
        end

        fun str()
            return "BasicError: " .. self.message
        end
    end

    static fun new(msg)
        let err = BasicError._new()
        err.message = msg
        return err
    end
end
