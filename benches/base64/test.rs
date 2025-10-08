use std::time::Instant;

fn main() {
    // Test fixtures
    let fixtures = [("hello", "aGVsbG8="), ("world", "d29ybGQ=")];

    for (src, dst) in fixtures {
        let encoded = base64::encode(src);
        if encoded != dst {
            eprintln!("{} != {}", encoded, dst);
            std::process::exit(1);
        }
        let decoded = String::from_utf8(base64::decode(dst).unwrap()).unwrap();
        if decoded != src {
            eprintln!("{} != {}", decoded, src);
            std::process::exit(1);
        }
    }

    const STR_SIZE: usize = 131072;
    const TRIES: usize = 8192;

    let str1 = "a".repeat(STR_SIZE);
    let str2 = base64::encode(&str1);
    let str3 = String::from_utf8(base64::decode(&str2).unwrap()).unwrap();

    // Encode benchmark
    let start = Instant::now();
    let mut s_encoded = 0;
    for _ in 0..TRIES {
        s_encoded += base64::encode(&str1).len();
    }
    let t_encoded = start.elapsed().as_secs_f64();

    // Decode benchmark
    let start = Instant::now();
    let mut s_decoded = 0;
    for _ in 0..TRIES {
        s_decoded += base64::decode(&str2).unwrap().len();
    }
    let t_decoded = start.elapsed().as_secs_f64();

    println!("encode {}... to {}...: {}, {}", &str1[..4], &str2[..4], s_encoded, t_encoded);
    println!("decode {}... to {}...: {}, {}", &str2[..4], &str3[..4], s_decoded, t_decoded);
}
