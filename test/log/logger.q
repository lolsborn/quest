
use "std/test"
use "std/log"

test.module("Logger Initialization")

test.describe("Logger Construction", fun ()
    test.it("create a new Logger instance", fun ()
        let logger = log.Logger.new()
        test.assert_eq(logger.log_level, log.INFO, "Default log level should be INFO (20)")
        test.assert_true(logger.is(log.Logger), "Logger instance should be of type Logger")
    end)
end)
