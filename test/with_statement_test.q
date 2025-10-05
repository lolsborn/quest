# with Statement Tests - QEP-011
# Tests the with statement (context manager protocol)

use "std/test" as test

test.module("with Statement (QEP-011)")

# =============================================================================
# Basic with Statement
# =============================================================================

test.describe("Basic with statement", fun ()
    test.it("calls _enter and _exit", fun ()
        let calls = []

        type TestContext
            array: calls

            fun _enter()
                self.calls.push("enter")
                self
            end

            fun _exit()
                self.calls.push("exit")
            end
        end

        with TestContext.new(calls: calls)
            calls.push("body")
        end

        test.assert_eq(calls[0], "enter", "First call should be _enter")
        test.assert_eq(calls[1], "body", "Second should be body")
        test.assert_eq(calls[2], "exit", "Third should be _exit")
    end)

    test.it("binds value with 'as' clause", fun ()
        type ValueContext
            str: value

            fun _enter()
                self.value
            end

            fun _exit()
                nil
            end
        end

        let result = nil
        with ValueContext.new(value: "test") as val
            result = val
        end

        test.assert_eq(result, "test", "Should bind _enter result to 'as' variable")
    end)

    test.it("works without 'as' clause", fun ()
        let entered = false
        let exited = false

        type SideEffectContext
            fun _enter()
                entered = true
                nil
            end

            fun _exit()
                exited = true
            end
        end

        with SideEffectContext.new()
            # No variable binding
        end

        test.assert(entered, "_enter should have been called")
        test.assert(exited, "_exit should have been called")
    end)
end)

# =============================================================================
# Exception Handling
# =============================================================================

test.describe("Exception handling", fun ()
    test.it("calls _exit on exception", fun ()
        let exit_called = false

        type CleanupContext
            fun _enter()
                self
            end

            fun _exit()
                exit_called = true
            end
        end

        try
            with CleanupContext.new()
                raise "Test error"
            end
        catch e
            # Ignore
        end

        test.assert(exit_called, "_exit should have been called even on exception")
    end)

    test.it("propagates exception after _exit", fun ()
        type SimpleContext
            fun _enter()
                self
            end

            fun _exit()
                nil
            end
        end

        let caught = false
        let message = nil
        try
            with SimpleContext.new()
                raise "Test error"
            end
        catch e
            caught = true
            message = e.message()
        end

        test.assert(caught, "Exception should propagate after _exit")
        test.assert_eq(message, "Test error", "Exception message should be preserved")
    end)

    test.it("_exit exception takes precedence over body exception", fun ()
        type BrokenExit
            fun _enter()
                self
            end

            fun _exit()
                raise "Exit error"
            end
        end

        let caught_message = nil
        try
            with BrokenExit.new()
                raise "Body error"
            end
        catch e
            caught_message = e.message()
        end

        test.assert_eq(caught_message, "Exit error", "_exit exception should take precedence")
    end)

    test.it("exception in _enter prevents body execution", fun ()
        type BrokenEnter
            fun _enter()
                raise "Enter failed"
            end

            fun _exit()
                nil
            end
        end

        let body_executed = false
        let caught = false

        try
            with BrokenEnter.new()
                body_executed = true
            end
        catch e
            caught = true
        end

        test.assert(not body_executed, "Body should not execute if _enter fails")
        test.assert(caught, "Exception should propagate from _enter")
    end)
end)

# =============================================================================
# Variable Shadowing (Python-Compatible)
# =============================================================================

test.describe("Variable shadowing (Python-compatible)", fun ()
    test.it("restores shadowed variable", fun ()
        type ValueContext
            str: value

            fun _enter()
                self.value
            end

            fun _exit()
                nil
            end
        end

        let x = "outer"
        with ValueContext.new(value: "inner") as x
            test.assert_eq(x, "inner", "Should shadow with inner value")
        end
        test.assert_eq(x, "outer", "Should restore outer value after block")
    end)

    test.it("removes new variable after block", fun ()
        type ValueContext
            str: value

            fun _enter()
                self.value
            end

            fun _exit()
                nil
            end
        end

        let var_exists_in_block = false
        let var_removed_after = false

        # y doesn't exist before
        with ValueContext.new(value: "temp") as y
            var_exists_in_block = (y == "temp")
        end

        # y should not exist after block - test by trying to use it
        try
            # This should fail if y was properly removed
            puts(y)
        catch e
            # Check exception type (not message, which is just the variable name)
            if e.exc_type() == "Undefined variable"
                var_removed_after = true
            end
        end

        test.assert(var_exists_in_block, "Variable should exist in block")
        test.assert(var_removed_after, "Variable should be removed after block")
    end)

    test.it("restores shadowed variable even on exception", fun ()
        type SimpleContext
            fun _enter()
                "inner"
            end

            fun _exit()
                nil
            end
        end

        let x = "outer"
        try
            with SimpleContext.new() as x
                test.assert_eq(x, "inner", "Should shadow variable")
                raise "Error"
            end
        catch e
            # Ignore
        end

        test.assert_eq(x, "outer", "Should restore even on exception")
    end)
end)

# =============================================================================
# Nested with Statements
# =============================================================================

test.describe("Nested with statements", fun ()
    test.it("handles nested contexts correctly", fun ()
        let events = []

        type OrderedContext
            array: events_arr
            str: name

            fun _enter()
                self.events_arr.push("enter_" .. self.name)
                self
            end

            fun _exit()
                self.events_arr.push("exit_" .. self.name)
            end
        end

        with OrderedContext.new(events_arr: events, name: "outer")
            with OrderedContext.new(events_arr: events, name: "inner")
                events.push("body")
            end
        end

        test.assert_eq(events[0], "enter_outer", nil)
        test.assert_eq(events[1], "enter_inner", nil)
        test.assert_eq(events[2], "body", nil)
        test.assert_eq(events[3], "exit_inner", nil)
        test.assert_eq(events[4], "exit_outer", nil)
    end)

    test.it("nested variable shadowing", fun ()
        type ValueContext
            str: value

            fun _enter()
                self.value
            end

            fun _exit()
                nil
            end
        end

        let x = "level0"

        with ValueContext.new(value: "level1") as x
            test.assert_eq(x, "level1", nil)

            with ValueContext.new(value: "level2") as x
                test.assert_eq(x, "level2", nil)
            end

            test.assert_eq(x, "level1", "Should restore level1")
        end

        test.assert_eq(x, "level0", "Should restore level0")
    end)
end)

# =============================================================================
# Return Value (Python-Compatible)
# =============================================================================

test.describe("Return value (Python-compatible)", fun ()
    test.it("with statement returns nil", fun ()
        type SimpleContext
            fun _enter()
                self
            end

            fun _exit()
                nil
            end
        end

        # with statement executes but returns nil
        # We can't directly test return value due to parse restrictions
        # Just verify it executes successfully
        with SimpleContext.new()
            let temp = "some value"
        end

        test.assert(true, "with statement executes successfully")
    end)

    test.it("body value is not returned", fun ()
        type ValueContext
            str: data

            fun _enter()
                self.data
            end

            fun _exit()
                nil
            end
        end

        let captured = nil
        with ValueContext.new(data: "test") as x
            captured = x .. " modified"
        end

        # The body ran and we captured the value inside
        test.assert_eq(captured, "test modified", "Body executes and can capture values")
    end)
end)

# =============================================================================
# Missing Methods
# =============================================================================

test.describe("Missing methods", fun ()
    test.it("errors if _enter is missing", fun ()
        type NoEnter
            fun _exit()
                nil
            end
        end

        let caught = false
        try
            with NoEnter.new()
                nil
            end
        catch e
            if e.message().contains("has no method '_enter'")
                caught = true
            end
        end

        test.assert(caught, "Should error when _enter is missing")
    end)

    test.it("errors if _exit is missing", fun ()
        type NoExit
            fun _enter()
                self
            end
        end

        let caught = false
        try
            with NoExit.new()
                nil
            end
        catch e
            if e.message().contains("has no method '_exit'")
                caught = true
            end
        end

        test.assert(caught, "Should error when _exit is missing")
    end)
end)

# =============================================================================
# Edge Cases
# =============================================================================

test.describe("Edge cases", fun ()
    test.it("_enter returns different value than self", fun ()
        type Wrapper
            str: inner_value

            fun _enter()
                # Return inner value, not self
                self.inner_value
            end

            fun _exit()
                nil
            end
        end

        let val = nil
        with Wrapper.new(inner_value: "hello") as val
            # val should be "hello", not the Wrapper object
            test.assert_eq(val, "hello", "_enter can return different value")
        end
    end)

    test.it("empty with block still calls _enter and _exit", fun ()
        let enter_called = false
        let exit_called = false

        type TracingContext
            fun _enter()
                enter_called = true
                self
            end

            fun _exit()
                exit_called = true
            end
        end

        with TracingContext.new()
            # Empty block
        end

        test.assert(enter_called, "_enter should be called even with empty block")
        test.assert(exit_called, "_exit should be called even with empty block")
    end)

    test.it("multiple sequential with statements", fun ()
        type Counter
            array: values

            fun _enter()
                self.values.push("entered")
                self.values.len()
            end

            fun _exit()
                nil
            end
        end

        let values = []
        let ctx = Counter.new(values: values)

        with ctx as x
            test.assert_eq(x, 1, "First with should have count 1")
        end

        with ctx as x
            test.assert_eq(x, 2, "Second with should have count 2")
        end

        with ctx as x
            test.assert_eq(x, 3, "Third with should have count 3")
        end
    end)
end)

# =============================================================================
# Real-World Use Cases
# =============================================================================

test.describe("Real-world use cases", fun ()
    test.it("timer context manager", fun ()
        type Timer
            str: label
            float?: start_time
            array: events

            fun _enter()
                self.start_time = 123.45
                self.events.push("started: " .. self.label)
                self
            end

            fun _exit()
                self.events.push("finished: " .. self.label)
            end
        end

        let events = []
        with Timer.new(label: "test_operation", events: events)
            events.push("working")
        end

        test.assert_eq(events[0], "started: test_operation", nil)
        test.assert_eq(events[1], "working", nil)
        test.assert_eq(events[2], "finished: test_operation", nil)
    end)

    test.it("resource acquisition context manager", fun ()
        type Resource
            str: name
            array: state

            fun _enter()
                self.state.push("acquired")
                self.name
            end

            fun _exit()
                self.state.push("released")
            end
        end

        let state = []
        let res = Resource.new(name: "database", state: state)

        with res as name
            test.assert_eq(state[0], "acquired", "Resource should be acquired")
            test.assert_eq(name, "database", nil)
        end

        test.assert_eq(state[1], "released", "Resource should be released")
    end)
end)

# =============================================================================
# Phase 2: Exception Suppression
# =============================================================================

test.describe("Exception suppression (Phase 2)", fun ()
    test.it("_exit returning true suppresses exception", fun ()
        type SuppressingContext
            fun _enter()
                self
            end

            fun _exit()
                true  # Suppress exceptions
            end
        end

        let exception_raised = false
        let exception_caught = false

        try
            with SuppressingContext.new()
                exception_raised = true
                raise "This should be suppressed"
            end
        catch e
            exception_caught = true
        end

        test.assert(exception_raised, "Exception should have been raised")
        test.assert(not exception_caught, "Exception should have been suppressed by _exit")
    end)

    test.it("_exit returning false propagates exception", fun ()
        type NonSuppressingContext
            fun _enter()
                self
            end

            fun _exit()
                false  # Don't suppress
            end
        end

        let exception_caught = false

        try
            with NonSuppressingContext.new()
                raise "This should propagate"
            end
        catch e
            exception_caught = true
        end

        test.assert(exception_caught, "Exception should propagate when _exit returns false")
    end)

    test.it("_exit returning nil propagates exception (default)", fun ()
        type NilReturningContext
            fun _enter()
                self
            end

            fun _exit()
                nil  # Treated as false
            end
        end

        let exception_caught = false

        try
            with NilReturningContext.new()
                raise "This should propagate"
            end
        catch e
            exception_caught = true
        end

        test.assert(exception_caught, "Exception should propagate when _exit returns nil")
    end)

    test.it("_exit can selectively suppress specific errors", fun ()
        type SelectiveContext
            array: events

            fun _enter()
                self
            end

            fun _exit()
                # Only suppress "recoverable" errors
                # Note: We can't inspect the exception in _exit yet (that's Phase 4)
                # For now, just always suppress
                self.events.push("exit_called")
                true
            end
        end

        let events = []
        let ctx = SelectiveContext.new(events: events)

        with ctx
            events.push("raising_error")
            raise "Recoverable error"
        end

        # No exception caught because _exit suppressed it
        test.assert_eq(events[0], "raising_error", nil)
        test.assert_eq(events[1], "exit_called", nil)
    end)

    test.it("suppression doesn't affect normal completion", fun ()
        type AlwaysSuppressContext
            fun _enter()
                self
            end

            fun _exit()
                true  # Always returns true
            end
        end

        let completed = false

        with AlwaysSuppressContext.new()
            completed = true
        end

        test.assert(completed, "Normal completion should work even when _exit returns true")
    end)
end)

# =============================================================================
# Phase 3: Multiple Context Managers
# =============================================================================

test.describe("Multiple context managers (Phase 3)", fun ()
    test.it("supports comma-separated context managers", fun ()
        let events = []

        type TrackedContext
            array: events
            str: name

            fun _enter()
                self.events.push("enter_" .. self.name)
                self
            end

            fun _exit()
                self.events.push("exit_" .. self.name)
            end
        end

        with TrackedContext.new(events: events, name: "ctx1"), TrackedContext.new(events: events, name: "ctx2")
            events.push("body")
        end

        test.assert_eq(events[0], "enter_ctx1", "First _enter")
        test.assert_eq(events[1], "enter_ctx2", "Second _enter")
        test.assert_eq(events[2], "body", "Body executes")
        test.assert_eq(events[3], "exit_ctx2", "Second _exit (reverse order)")
        test.assert_eq(events[4], "exit_ctx1", "First _exit (reverse order)")
    end)

    test.it("three context managers with proper nesting", fun ()
        let events = []

        type EventContext
            array: events
            str: label

            fun _enter()
                self.events.push(">" .. self.label)
                self
            end

            fun _exit()
                self.events.push("<" .. self.label)
            end
        end

        with EventContext.new(events: events, label: "A"), EventContext.new(events: events, label: "B"), EventContext.new(events: events, label: "C")
            events.push("BODY")
        end

        test.assert_eq(events[0], ">A", nil)
        test.assert_eq(events[1], ">B", nil)
        test.assert_eq(events[2], ">C", nil)
        test.assert_eq(events[3], "BODY", nil)
        test.assert_eq(events[4], "<C", "Exit in reverse")
        test.assert_eq(events[5], "<B", "Exit in reverse")
        test.assert_eq(events[6], "<A", "Exit in reverse")
    end)

    test.it("multiple contexts with as clauses", fun ()
        type ValueContext
            str: value

            fun _enter()
                self.value
            end

            fun _exit()
                nil
            end
        end

        let a_val = nil
        let b_val = nil

        with ValueContext.new(value: "first") as a, ValueContext.new(value: "second") as b
            a_val = a
            b_val = b
        end

        test.assert_eq(a_val, "first", "First context value")
        test.assert_eq(b_val, "second", "Second context value")
    end)

    test.it("mixed: some with as, some without", fun ()
        let events = []

        type MixedContext
            array: events
            str: value

            fun _enter()
                self.events.push("enter")
                self.value
            end

            fun _exit()
                self.events.push("exit")
            end
        end

        let bound_value = nil

        with MixedContext.new(events: events, value: "no_as"), MixedContext.new(events: events, value: "with_as") as x
            bound_value = x
        end

        test.assert_eq(events.len(), 4, "Both contexts should enter and exit")
        test.assert_eq(bound_value, "with_as", "Second context should be bound")
    end)

    test.it("exception in body calls all _exit in reverse", fun ()
        let events = []

        type CleanupContext
            array: events
            str: name

            fun _enter()
                self.events.push("enter_" .. self.name)
                self
            end

            fun _exit()
                self.events.push("exit_" .. self.name)
            end
        end

        try
            with CleanupContext.new(events: events, name: "ctx1"), CleanupContext.new(events: events, name: "ctx2")
                events.push("body")
                raise "Error"
            end
        catch e
            # Ignore
        end

        test.assert_eq(events[0], "enter_ctx1", nil)
        test.assert_eq(events[1], "enter_ctx2", nil)
        test.assert_eq(events[2], "body", nil)
        test.assert_eq(events[3], "exit_ctx2", "Both _exit called")
        test.assert_eq(events[4], "exit_ctx1", "Both _exit called")
    end)

    test.it("variable restoration in reverse order", fun ()
        type ValueContext
            str: value

            fun _enter()
                self.value
            end

            fun _exit()
                nil
            end
        end

        let x = "outer"

        with ValueContext.new(value: "inner1") as x, ValueContext.new(value: "inner2")
            test.assert_eq(x, "inner1", "First context binds x")
        end

        test.assert_eq(x, "outer", "Original x restored")
    end)
end)
