# QEP-037 Phase 2: User-Defined Exception Types with Error Trait

use "std/test" { module, describe, it, assert_eq, assert, assert_type }
use "std/error" { Error, BasicError }

module("QEP-037 Phase 2: User-Defined Exceptions")

describe("Error trait implementation", fun ()
  it("allows custom exception types", fun ()
    type ValidationError
      pub code: Int
      pub msg: Str

      impl Error
        fun message()
          return self.msg
        end

        fun str()
          return "ValidationError[" .. self.code.str() .. "]: " .. self.msg
        end
      end

      static fun new(code, msg)
        let err = ValidationError._new()
        err.code = code
        err.msg = msg
        return err
      end
    end

    let err = ValidationError.new(400, "Invalid input")
    assert_eq(err.code, 400)
    assert_eq(err.msg, "Invalid input")
  end)

  it("raises and catches custom exceptions", fun ()
    type NetworkError
      pub url: Str
      pub status_code: Int
      pub msg: Str

      impl Error
        fun message()
          return self.msg
        end

        fun str()
          return "NetworkError(" .. self.status_code.str() .. ") at " .. self.url .. ": " .. self.msg
        end
      end

      static fun new(url, status, msg)
        let err = NetworkError._new()
        err.url = url
        err.status_code = status
        err.msg = msg
        return err
      end
    end

    let caught = false
    let caught_url = nil
    let caught_status = nil

    try
      raise NetworkError.new("https://example.com", 404, "Not found")
    catch e: NetworkError
      caught = true
      caught_url = e.url
      caught_status = e.status_code
    end

    assert(caught, "Should catch NetworkError")
    assert_eq(caught_url, "https://example.com")
    assert_eq(caught_status, 404)
  end)

  it("preserves all custom fields", fun ()
    type DatabaseError
      pub query: Str
      pub line_number: Int
      pub column: Int
      pub msg: Str

      impl Error
        fun message()
          return self.msg
        end

        fun str()
          return "DatabaseError at " .. self.line_number.str() .. ":" .. self.column.str() .. ": " .. self.msg
        end
      end

      static fun new(query, line, col, msg)
        let err = DatabaseError._new()
        err.query = query
        err.line_number = line
        err.column = col
        err.msg = msg
        return err
      end
    end

    try
      raise DatabaseError.new("SELECT * FROM users", 42, 15, "Syntax error")
    catch e: DatabaseError
      assert_eq(e.query, "SELECT * FROM users")
      assert_eq(e.line_number, 42)
      assert_eq(e.column, 15)
      assert_eq(e.msg, "Syntax error")
    end
  end)

  it("rejects types that don't implement Error trait", fun ()
    type NotAnError
      pub value: Int
    end

    let caught_type_error = false
    try
      raise NotAnError._new()
    catch e
      caught_type_error = true
    end

    assert(caught_type_error, "Should raise TypeErr for non-Error types")
  end)

  it("works with catch-all clause", fun ()
    type CustomErr
      pub msg: Str

      impl Error
        fun message()
          return self.msg
        end

        fun str()
          return "CustomErr: " .. self.msg
        end
      end

      static fun new(msg)
        let err = CustomErr._new()
        err.msg = msg
        return err
      end
    end

    let caught = false
    let caught_msg = nil
    try
      raise CustomErr.new("test error")
    catch e
      caught = true
      caught_msg = e.msg
    end

    assert(caught, "Should catch with catch-all")
    assert_eq(caught_msg, "test error")
  end)

  it("supports custom methods on exceptions", fun ()
    type FileError
      pub filename: Str
      pub operation: Str
      pub msg: Str

      impl Error
        fun message()
          return self.msg
        end

        fun str()
          return "FileError: " .. self.operation .. " failed on " .. self.filename
        end
      end

      fun get_details()
        return {
          file: self.filename,
          op: self.operation,
          msg: self.msg
        }
      end

      static fun new(filename, operation, msg)
        let err = FileError._new()
        err.filename = filename
        err.operation = operation
        err.msg = msg
        return err
      end
    end

    try
      raise FileError.new("/tmp/txt", "read", "Permission denied")
    catch e: FileError
      let details = e.get_details()
      assert_eq(details["file"], "/tmp/txt")
      assert_eq(details["op"], "read")
      assert_eq(details["msg"], "Permission denied")
    end
  end)
end)

describe("Error trait hierarchy", fun ()
  it("catches custom exceptions with specific type", fun ()
    type AppError
      pub msg: Str

      impl Error
        fun message()
          return self.msg
        end

        fun str()
          return "AppError: " .. self.msg
        end
      end

      static fun new(msg)
        let err = AppError._new()
        err.msg = msg
        return err
      end
    end

    let which = nil
    try
      raise AppError.new("something went wrong")
    catch e: IndexErr
      which = "index"
    catch e: AppError
      which = "app"
    catch e
      which = "generic"
    end

    assert_eq(which, "app", "Should catch specific type")
  end)
end)

describe("std/error module", fun ()
  it("provides BasicError type", fun ()
    let err = BasicError.new("test message")
    assert_eq(err.message, "test message")
    assert_eq(err.str(), "BasicError: test message")
  end)

  it("BasicError can be raised and caught", fun ()
    let caught = false
    let caught_msg = nil
    try
      raise BasicError.new("error from BasicError")
    catch e
      caught = true
      caught_msg = e.message
    end

    assert(caught, "Should catch BasicError")
    assert_eq(caught_msg, "error from BasicError")
  end)
end)
