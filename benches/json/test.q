#!/usr/bin/env quest

use "std/encoding/json" as json
use "std/io" as io
use "std/sys" as sys

# Coordinate type (using dict instead of struct for simplicity)
fun Coordinate(x, y, z)
    {"x": x, "y": y, "z": z}
end

fun calc(text)
    let jobj = json.parse(text)
    let coordinates = jobj["coordinates"]
    let len = coordinates.len()
    let len_f = len.to_f64()
    let x = 0.0
    let y = 0.0
    let z = 0.0

    let i = 0
    while i < len
        let coord = coordinates[i]
        x = x + coord["x"]
        y = y + coord["y"]
        z = z + coord["z"]
        i = i + 1
    end

    Coordinate(x / len_f, y / len_f, z / len_f)
end

# Test with small examples
let right = Coordinate(2.0, 0.5, 0.25)
let test1 = calc("{\"coordinates\":[{\"x\":2.0,\"y\":0.5,\"z\":0.25}]}")
let test2 = calc("{\"coordinates\":[{\"y\":0.5,\"x\":2.0,\"z\":0.25}]}")

if (test1["x"] - right["x"]).abs() > 0.0001
    puts("Test failed: " .. test1["x"].str() .. " != " .. right["x"].str())
    sys.exit(1)
end

# Read and process the big JSON file
let text = io.read("/tmp/1.json")
let results = calc(text)

puts("Coordinate(" .. results["x"].str() .. ", " .. results["y"].str() .. ", " .. results["z"].str() .. ")")
