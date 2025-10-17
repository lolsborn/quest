# QEP-037 Phase 2: User-Defined Exception Types with Error Trait

use "std/test"
use "std/error"

# Import Error trait into local scope
let Error = error.Error

test.module("QEP-037 Phase 2: User-Defined Exceptions")

test.describe("Error trait implementation", fun ()
    test.it("allows custom exception types", fun ()
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
        test.assert_eq(err.code, 400)
        test.assert_eq(err.msg, "Invalid input")
    end)

    test.it("raises and catches custom exceptions", fun ()
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

        test.assert(caught, "Should catch NetworkError")
        test.assert_eq(caught_url, "https://example.com")
        test.assert_eq(caught_status, 404)
    end)

    test.it("preserves all custom fields", fun ()
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
            test.assert_eq(e.query, "SELECT * FROM users")
            test.assert_eq(e.line_number, 42)
            test.assert_eq(e.column, 15)
            test.assert_eq(e.msg, "Syntax error")
        end
    end)

    test.it("rejects types that don't implement Error trait", fun ()
        type NotAnError
            pub value: Int
        end

        let caught_type_error = false
        try
            raise NotAnError._new()
        catch e
            caught_type_error = true
        end

        test.assert(caught_type_error, "Should raise TypeErr for non-Error types")
    end)

    test.it("works with catch-all clause", fun ()
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

        test.assert(caught, "Should catch with catch-all")
        test.assert_eq(caught_msg, "test error")
    end)

    test.it("supports custom methods on exceptions", fun ()
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
            raise FileError.new("/tmp/test.txt", "read", "Permission denied")
        catch e: FileError
            let details = e.get_details()
            test.assert_eq(details["file"], "/tmp/test.txt")
            test.assert_eq(details["op"], "read")
            test.assert_eq(details["msg"], "Permission denied")
        end
    end)
end)

test.describe("Error trait hierarchy", fun ()
    test.it("catches custom exceptions with specific type", fun ()
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

        test.assert_eq(which, "app", "Should catch specific type")
    end)
end)

test.describe("std/error module", fun ()
    test.it("provides BasicError type", fun ()
        let err = error.BasicError.new("test message")
        test.assert_eq(err.message, "test message")
        test.assert_eq(err.str(), "BasicError: test message")
    end)

    test.it("BasicError can be raised and caught", fun ()
        let caught = false
        let caught_msg = nil
        try
            raise error.BasicError.new("error from BasicError")
        catch e
            caught = true
            caught_msg = e.message
        end

        test.assert(caught, "Should catch BasicError")
        test.assert_eq(caught_msg, "error from BasicError")
    end)
end)
