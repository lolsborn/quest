#!/usr/bin/env python3

def fib(n):
    if n <= 1:
        return n
    return fib(n - 1) + fib(n - 2)

def verify():
    expected = [0, 1, 1, 2, 3, 5, 8, 13, 21, 34]
    for i, exp in enumerate(expected):
        result = fib(i)
        if result != exp:
            raise Exception(f"Verification failed: fib({i}) = {result}, expected {exp}")

if __name__ == "__main__":
    verify()
    n = 35
    result = fib(n)
    print(f"fib({n}) = {result}")
