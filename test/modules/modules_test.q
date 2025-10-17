# Module System Tests
# Tests public/private separation and module state

use "std/test" { module, describe, it, assert_eq }
use "test/modules/_test_module_private" as tm

module("Module System")

describe("Public member access", fun ()
  it("can access public variables", fun ()
    assert_eq(tm.public_data, "visible value")  end)

  it("can call public functions", fun ()
    let secret = tm.get_secret()
    assert_eq(secret, "hidden value")  end)
end)

describe("Module encapsulation", fun ()
  it("public function can access private variables", fun ()
    # get_secret() accesses private_secret internally
    assert_eq(tm.get_secret(), "hidden value")
  end)

  it("public function can call private functions", fun ()
    # use_helper() calls private_helper() internally
    assert_eq(tm.use_helper(), "helper result")
  end)
end)

describe("Module state sharing", fun ()
  it("module state is shared and mutable", fun ()
    let c1 = tm.increment_counter()
    let c2 = tm.increment_counter()
    let c3 = tm.increment_counter()

    assert_eq(c1, 1)
    assert_eq(c2, 2)
    assert_eq(c3, 3)
    end)
end)
