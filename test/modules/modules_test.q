# Module System Tests
# Tests public/private separation and module state

use "std/test" as test
use "test/modules/_test_module_private" as tm

test.module("Module System")

test.describe("Public member access", fun ()
    test.it("can access public variables", fun ()
        test.assert_eq(tm.public_data, "visible value", nil)
    end)

    test.it("can call public functions", fun ()
        let secret = tm.get_secret()
        test.assert_eq(secret, "hidden value", nil)
    end)
end)

test.describe("Module encapsulation", fun ()
    test.it("public function can access private variables", fun ()
        # get_secret() accesses private_secret internally
        test.assert_eq(tm.get_secret(), "hidden value", nil)
    end)

    test.it("public function can call private functions", fun ()
        # use_helper() calls private_helper() internally
        test.assert_eq(tm.use_helper(), "helper result", nil)
    end)
end)

test.describe("Module state sharing", fun ()
    test.it("module state is shared and mutable", fun ()
        let c1 = tm.increment_counter()
        let c2 = tm.increment_counter()
        let c3 = tm.increment_counter()

        test.assert_eq(c1, 1, nil)
        test.assert_eq(c2, 2, nil)
        test.assert_eq(c3, 3, nil)
    end)
end)
