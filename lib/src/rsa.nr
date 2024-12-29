use dep::bignum::{params::BigNumParams, RuntimeBigNum};

fn karatsuba_multiply<let NumLimbs: u32, let ModBits: u32>(
    x: RuntimeBigNum<NumLimbs, ModBits>,
    y: RuntimeBigNum<NumLimbs, ModBits>,
    params: BigNumParams<NumLimbs, ModBits>
) -> RuntimeBigNum<NumLimbs, ModBits> {
    let mut result = x * y;
    
    if NumLimbs > 4 {
        // Create low parts
        let mut x_low_limbs = [0; NumLimbs];
        let mut y_low_limbs = [0; NumLimbs];
        
        // Create high parts
        let mut x_high_limbs = [0; NumLimbs];
        let mut y_high_limbs = [0; NumLimbs];
        
        let mid = NumLimbs / 2;
        
        // Split the numbers
        for i in 0..mid {
            x_low_limbs[i] = x.limbs[i];
            y_low_limbs[i] = y.limbs[i];
        }
        
        for i in mid..NumLimbs {
            x_high_limbs[i - mid] = x.limbs[i];
            y_high_limbs[i - mid] = y.limbs[i];
        }
        
        // Create BigNum instances for low and high parts
        let x_low = RuntimeBigNum { params, limbs: x_low_limbs };
        let x_high = RuntimeBigNum { params, limbs: x_high_limbs };
        let y_low = RuntimeBigNum { params, limbs: y_low_limbs };
        let y_high = RuntimeBigNum { params, limbs: y_high_limbs };
        
        // Compute sub-products
        let z0: RuntimeBigNum<NumLimbs, ModBits> = x_low * y_low;
        let z2: RuntimeBigNum<NumLimbs, ModBits> = x_high * y_high;
        
        let x_sum: RuntimeBigNum<NumLimbs, ModBits> = x_low + x_high;
        let y_sum: RuntimeBigNum<NumLimbs, ModBits> = y_low + y_high;
        let z1: RuntimeBigNum<NumLimbs, ModBits> = x_sum * y_sum;
        
        // Combine results
        let mut result = RuntimeBigNum { params, limbs: [0; NumLimbs] };
        
        // Combine results (with proper shifts)
        for i in 0..NumLimbs {
            let idx = i as u32;
            if idx < mid * 2 {
                result.limbs[i] = z0.limbs[i];
            }
            if idx >= mid & idx < NumLimbs {
                let diff_idx = (idx - mid) as u32;
                result.limbs[i] += z1.limbs[diff_idx] - z2.limbs[diff_idx] - z0.limbs[diff_idx];
            }
            if idx >= mid * 2 {
                let diff_idx = (idx - mid * 2) as u32;
                result.limbs[i] += z2.limbs[diff_idx];
            }
        }
    }
    
    result
}

pub fn verify_sha256_pkcs1v15_karatsuba<let NumLimbs: u32, let ModBits: u32>(
    msg_hash: [u8; 32],
    sig: RuntimeBigNum<NumLimbs, ModBits>,
    exponent: u32,
) -> bool {
    let params = sig.params;
    let mut exponentiated = karatsuba_multiply(sig, sig, params);
    
    if exponent == 65537 {
        for _ in 0..15 {
            exponentiated = karatsuba_multiply(exponentiated, exponentiated, params);
        }
    }
    
    exponentiated = karatsuba_multiply(exponentiated, sig, params);
    
    // For 2048-bit RSA, we need 256 bytes
    let padded_hash: [u8; 256] = exponentiated.to_le_bytes();
    compare_signature_sha256(padded_hash, msg_hash)
}

fn compare_signature_sha256<let N: u32>(padded_sha256_hash: [u8; N], msg_hash: [u8; 32]) -> bool {
    // Get length of sig (e.g. 1048 = 128 bytes, 2048 = 256 bytes)
    for i in 0..32 {
        assert(padded_sha256_hash[31 - i] == msg_hash[i]);
    }

    let hash_prefix: [u8; 19] = [32, 4, 0, 5, 1, 2, 4, 3, 101, 1, 72, 134, 96, 9, 6, 13, 48, 49, 48];

    for i in 32..51 {
        assert(hash_prefix[i - 32] == padded_sha256_hash[i]);
    }

    assert(padded_sha256_hash[51] == 0);

    // Sub 32 bytes for hash, 19 bytes for prefix, 1 byte for 0, 1 byte for 1, 1 byte for 0
    let ps_len = N - 54;
    for i in 52..N {
        if i < 52 + ps_len {
            assert(padded_sha256_hash[i] == 255);
        } else if i == 52 + ps_len {
            assert(padded_sha256_hash[i] == 1);
        } else if i == 53 + ps_len {
            assert(padded_sha256_hash[i] == 0);
        } else {
            assert(padded_sha256_hash[i] == 0);
        }
    }

    true
}
