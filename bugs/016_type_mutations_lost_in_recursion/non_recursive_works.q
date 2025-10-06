#!/usr/bin/env quest

type Printer
    pub sum1: Int
    pub sum2: Int
    pub quiet: Bool

    static fun create(quiet)
        Printer.new(sum1: 0, sum2: 0, quiet: quiet)
    end

    fun print_char(n)
        puts("  print_char(" .. n._str() .. ") called, sum1=" .. self.sum1._str() .. ", sum2=" .. self.sum2._str())
        if self.quiet
            self.sum1 = (self.sum1 + n) % 255
            self.sum2 = (self.sum2 + self.sum1) % 255
            puts("    updated: sum1=" .. self.sum1._str() .. ", sum2=" .. self.sum2._str())
        else
            let ch = chr(n)
            puts("    printing: '" .. ch .. "'")
        end
    end

    fun checksum()
        (self.sum2 << 8) | self.sum1
    end
end

puts("Creating printer (quiet mode)...")
let p = Printer.create(true)
puts("Initial checksum: " .. p.checksum()._str())
puts("")

puts("Printing 'H' (72)...")
p.print_char(72)
puts("After H: checksum = " .. p.checksum()._str())
puts("")

puts("Printing 'i' (105)...")
p.print_char(105)
puts("After i: checksum = " .. p.checksum()._str())
puts("")

puts("Final checksum: " .. p.checksum()._str())
