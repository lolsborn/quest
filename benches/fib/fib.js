#!/usr/bin/env node

function fib(n) {
    if (n <= 1) {
        return n;
    }
    return fib(n - 1) + fib(n - 2);
}

function verify() {
    const expected = [0, 1, 1, 2, 3, 5, 8, 13, 21, 34];
    for (let i = 0; i < expected.length; i++) {
        const result = fib(i);
        if (result !== expected[i]) {
            throw new Error(`Verification failed: fib(${i}) = ${result}, expected ${expected[i]}`);
        }
    }
}

verify();
const n = 35;
const result = fib(n);
console.log(`fib(${n}) = ${result}`);
