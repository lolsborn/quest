fn fib(n: i64) -> i64 {
    if n <= 1 {
        return n;
    }
    fib(n - 1) + fib(n - 2)
}

fn verify() {
    let expected = [0, 1, 1, 2, 3, 5, 8, 13, 21, 34];
    for (i, &exp) in expected.iter().enumerate() {
        let result = fib(i as i64);
        if result != exp {
            panic!("Verification failed: fib({}) = {}, expected {}", i, result, exp);
        }
    }
}

fn main() {
    verify();
    let n = 35;
    let result = fib(n);
    println!("fib({}) = {}", n, result);
}
