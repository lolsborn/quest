# Regression test for Bug #008: self corruption after method calls
# Tests that self remains correct across nested method calls

use "std/test"

test.module("Self Corruption Bug Regression")

test.describe("Self isolation in nested method calls", fun ()
    test.it("self stays correct when calling methods on objects from self.field", fun ()
        # This is the exact pattern that triggered bug #008
        type Handler
            str: name

            fun process()
                return "Processed: " .. self.name
            end
        end

        type Container
            array: handlers
            str: container_name

            fun run()
                let results = []
                let i = 0
                # BUG #008: self would become Handler instead of Container
                # after handler.process() call, causing self.handlers.len() to fail
                while i < self.handlers.len()
                    let handler = self.handlers[i]
                    let result = handler.process()
                    results.push(result)
                    i = i + 1
                end
                # Verify self is still the Container
                return self.container_name .. ": " .. results.len()._str() .. " handlers processed"
            end
        end

        let h1 = Handler.new(name: "H1")
        let h2 = Handler.new(name: "H2")
        let h3 = Handler.new(name: "H3")
        let container = Container.new(handlers: [h1, h2, h3], container_name: "TestContainer")

        let result = container.run()
        test.assert_eq(result, "TestContainer: 3 handlers processed", nil)
    end)

    test.it("self is not affected by nested self in inner method", fun ()
        type Inner
            int: value

            fun modify()
                return self.value * 2
            end
        end

        type Outer
            int: outer_value
            inner: inner_obj

            fun process()
                # Before fix, calling inner_obj method would corrupt outer self
                let result = self.inner_obj.modify()
                # Accessing self.outer_value should still work
                return self.outer_value + result
            end
        end

        let inner = Inner.new(value: 10)
        let outer = Outer.new(outer_value: 5, inner_obj: inner)

        let result = outer.process()
        test.assert_eq(result, 25, nil)  # 5 + (10 * 2) = 25
    end)

    test.it("self in loops with array of objects", fun ()
        type Item
            str: name
            fun get_name()
                return self.name
            end
        end

        type Collection
            array: items
            int: count

            fun process_all()
                let names = []
                let i = 0
                while i < self.items.len()
                    let item = self.items[i]
                    names.push(item.get_name())
                    # self.count should still be accessible
                    i = i + 1
                end
                return names.len() == self.count
            end
        end

        let items = [
            Item.new(name: "A"),
            Item.new(name: "B"),
            Item.new(name: "C")
        ]
        let coll = Collection.new(items: items, count: 3)

        test.assert(coll.process_all(), "Collection count should match items processed")
    end)
end)

test.describe("Self in deeply nested calls", fun ()
    test.it("maintains correct self through multiple nesting levels", fun ()
        type Level3
            str: name
            fun identify()
                return "L3:" .. self.name
            end
        end

        type Level2
            str: name
            l3: level3
            fun identify()
                let l3_id = self.level3.identify()
                return "L2:" .. self.name .. "/" .. l3_id
            end
        end

        type Level1
            str: name
            l2: level2
            fun identify()
                let l2_id = self.level2.identify()
                return "L1:" .. self.name .. "/" .. l2_id
            end
        end

        let l3 = Level3.new(name: "deep")
        let l2 = Level2.new(name: "middle", level3: l3)
        let l1 = Level1.new(name: "top", level2: l2)

        let result = l1.identify()
        test.assert_eq(result, "L1:top/L2:middle/L3:deep", nil)
    end)
end)
