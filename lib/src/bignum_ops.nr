fn add<let N: u32>(a: [Field; N], b: [Field; N]) -> [Field; N] {
    let mut result = [0; N];
    for i in 0..N {
        result[i] = a[i] + b[i];
    }
    result
}

fn sub<let N: u32>(a: [Field; N], b: [Field; N]) -> [Field; N] {
    let mut result = [0; N];
    for i in 0..N {
        result[i] = a[i] - b[i];
    }
    result
}

pub fn karatsuba_mul<let N: u32>(a: [Field; N], b: [Field; N]) -> [Field; 2 * N] {
    let mut result = [0; 2 * N];

    // Base case: use simple multiplication for small N
    if N <= 4 {
        for i in 0..N {
            for j in 0..N {
                result[i + j] = result[i + j] + a[i] * b[j];
            }
        }
    } else {
        // Split point
        let k = N / 2;

        // Split the input numbers
        let mut a_low = [0; N / 2];
        let mut a_high = [0; N / 2];
        let mut b_low = [0; N / 2];
        let mut b_high = [0; N / 2];

        for i in 0..k {
            a_low[i] = a[i];
            b_low[i] = b[i];
            a_high[i] = a[i + k];
            b_high[i] = b[i + k];
        }

        // Recursive computations
        let p1 = karatsuba_mul(a_high, b_high);  // High * High
        let p2 = karatsuba_mul(a_low, b_low);    // Low * Low

        // Sum of high and low parts
        let sum_a = add(a_high, a_low);
        let sum_b = add(b_high, b_low);
        let p3 = karatsuba_mul(sum_a, sum_b);    // (High + Low) * (High + Low)

        // Combine results
        let middle_term = sub(p3, add(p1, p2));

        // Final combination: p1 * 2^(2k) + middle_term * 2^k + p2
        for i in 0..(2 * N) {
            if i < 2 * k {
                result[i] = result[i] + p2[i]; // Add p2
            }
            if i >= k & i < 2 * N {
                result[i] = result[i] + middle_term[i - k]; // Add middle term shifted
            }
            if i >= 2 * k & i < 2 * N {
                result[i] = result[i] + p1[i - 2 * k]; // Add p1 shifted
            }
        }
    }

    result
}

pub fn exp_by_squaring<let N: u32>(x: [Field; N], n: u32) -> [Field; N] {
    let mut result = [1; N];
    let mut base = x;
    let mut exponent = n;

    for _ in 0..32 {
        if exponent > 0 {
            if exponent % 2 == 1 {
                let product = karatsuba_mul(result, base);
                for i in 0..N {
                    result[i] = product[i];
                }
            }
            let squared = karatsuba_mul(base, base);
            for i in 0..N {
                base[i] = squared[i];
            }
            exponent = exponent / 2;
        }
    }

    result
}