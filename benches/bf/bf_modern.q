#!/usr/bin/env quest
# Brainfuck interpreter in Quest - Modern & Optimized
# Uses QEP-041 (indexed assignment), QEP-033 (default params), QEP-016 (match)

use "std/sys"
use "std/io"
use "std/os"

# Operation constants
const INC = 1
const MOVE = 2
const LOOP = 3
const PRINT = 4

# Tape type - now we can use indexed assignment (QEP-041)!
type Tape
    cells: Array
    pos: Int

    fun self.create()
        Tape.new(cells: [0], pos: 0)
    end

    fun get()
        self.cells[self.pos]
    end

    fun inc(delta)
        self.cells[self.pos] += delta
    end

    fun move(delta)
        self.pos += delta

        # Grow tape if needed
        while self.pos >= self.cells.len()
            self.cells.push(0)
        end
    end
end

# Printer type with default parameter (QEP-033)
type Printer
    sum1: Int
    sum2: Int
    quiet: Bool

    fun self.create(quiet = false)
        Printer.new(sum1: 0, sum2: 0, quiet: quiet)
    end

    fun print_char(n)
        if self.quiet
            self.sum1 = (self.sum1 + n) % 255
            self.sum2 = (self.sum2 + self.sum1) % 255
        else
            sys.stdout.write(chr(n))
            sys.stdout.flush()
        end
    end

    fun checksum()
        (self.sum2 << 8) | self.sum1
    end
end

# Parser - optimized with match statement (QEP-016)
fun parse(text, start_pos = 0)
    let ops = []
    let pos = start_pos

    while pos < text.len()
        let ch = text[pos]
        pos += 1

        match ch
            in "+"
                ops.push({op: INC, val: 1})
            in "-"
                ops.push({op: INC, val: -1})
            in ">"
                ops.push({op: MOVE, val: 1})
            in "<"
                ops.push({op: MOVE, val: -1})
            in "."
                ops.push({op: PRINT, val: 0})
            in "["
                let result = parse(text, pos)
                ops.push({op: LOOP, val: result["ops"]})
                pos = result["pos"]
            in "]"
                break
        end
    end

    {ops: ops, pos: pos}
end

# Execute brainfuck - clean implementation using Tape type
fun run_program(ops, tape, printer)
    let i = 0

    while i < ops.len()
        let op = ops[i]
        let opcode = op["op"]

        if opcode == INC
            tape.inc(op["val"])
        elif opcode == MOVE
            tape.move(op["val"])
        elif opcode == LOOP
            while tape.get() > 0
                run_program(op["val"], tape, printer)
            end
        elif opcode == PRINT
            printer.print_char(tape.get())
        end

        i += 1
    end
end

# Verification with optimized loop
fun verify()
    const HELLO_WORLD_BF = "++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++."
    const HELLO_WORLD = "Hello World!\n"

    # Test BF execution
    let printer_left = Printer.create(true)
    let result = parse(HELLO_WORLD_BF)
    let tape = Tape.create()
    run_program(result["ops"], tape, printer_left)
    let left = printer_left.checksum()

    # Compute expected checksum
    let printer_right = Printer.create(true)
    let j = 0
    while j < HELLO_WORLD.len()
        printer_right.print_char(ord(HELLO_WORLD[j]))
        j += 1
    end
    let right = printer_right.checksum()

    if left != right
        puts("Verification failed: " .. left.str() .. " != " .. right.str())
        sys.exit(1)
    end
end

# Main entry point
fun main()
    verify()

    if sys.argc > 1
        let filename = sys.argv[1]
        let text = io.read(filename)
        let quiet = os.getenv("QUIET") != nil
        let printer = Printer.create(quiet)
        let tape = Tape.create()

        let result = parse(text)
        run_program(result["ops"], tape, printer)

        if quiet
            puts("Output checksum: " .. printer.checksum().str())
        end
    end
end

main()