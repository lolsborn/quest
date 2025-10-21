#!/usr/bin/env quest
# Brainfuck interpreter in Quest (optimized)

use "std/sys"
use "std/io"
use "std/os"

# Operation constants
let INC = 1
let MOVE = 2
let LOOP = 3
let PRINT = 4

# Printer type
type Printer
  sum1: Int
  sum2: Int
  quiet: Bool

  fun self.create(quiet)
    Printer.new(sum1: 0, sum2: 0, quiet: quiet)
  end

  fun print_char(n)
    if self.quiet
      self.sum1 = (self.sum1 + n) % 255
      self.sum2 = (self.sum2 + self.sum1) % 255
    else
      let ch = chr(n)
      sys.stdout.write(ch)
      sys.stdout.flush()
    end
  end

  fun checksum()
    (self.sum2 << 8) | self.sum1
  end
end

# Parser - use bracket indexing (QEP-036) for string character access
fun parse(text, start_pos)
  let ops = []
  let pos = start_pos

  while pos < text.len()
    let ch = text[pos]
    pos = pos + 1

    if ch == "+"
      ops.push({op: INC, val: 1})
    elif ch == "-"
      ops.push({op: INC, val: -1})
    elif ch == ">"
      ops.push({op: MOVE, val: 1})
    elif ch == "<"
      ops.push({op: MOVE, val: -1})
    elif ch == "."
      ops.push({op: PRINT, val: 0})
    elif ch == "["
      let result = parse(text, pos)
      ops.push({op: LOOP, val: result["ops"]})
      pos = result["pos"]
    elif ch == "]"
      break
    end
  end

  {ops: ops, pos: pos}
end

# Execute brainfuck - return just position instead of dict
fun run_program(ops, tape, tape_pos, printer)
  let i = 0
  let pos = tape_pos

  while i < ops.len()
    let op = ops[i]
    let opcode = op["op"]

    if opcode == INC
      let idx = pos
      tape[idx] = tape[idx] + op["val"]
    elif opcode == MOVE
      pos = pos + op["val"]
      while pos >= tape.len()
        tape.push(0)
      end
    elif opcode == LOOP
      while tape[pos] > 0
        pos = run_program(op["val"], tape, pos, printer)
      end
    elif opcode == PRINT
      printer.print_char(tape[pos])
    end

    i = i + 1
  end

  pos
end

# Verification
fun verify()
  let text = "++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++."

  let printer_left = Printer.create(true)
  let result = parse(text, 0)
  let ops = result["ops"]
  let tape = [0]
  run_program(ops, tape, 0, printer_left)
  let left = printer_left.checksum()

  let printer_right = Printer.create(true)
  let hello = "Hello World!\n"
  let j = 0
  while j < hello.len()
    printer_right.print_char(ord(hello[j]))
    j = j + 1
  end
  let right = printer_right.checksum()

  if left != right
    puts("Verification failed: " .. left.str() .. " != " .. right.str())
    sys.exit(1)
  end
end

# Main
verify()

if sys.argc > 1
  let filename = sys.argv[1]
  let text = io.read(filename)
  let quiet = os.getenv("QUIET") != nil
  let printer = Printer.create(quiet)

  let result = parse(text, 0)
  let tape = [0]
  run_program(result["ops"], tape, 0, printer)

  if quiet
    puts("Output checksum: " .. printer.checksum().str())
  end
end
