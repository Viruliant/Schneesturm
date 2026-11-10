// Copyright (C) 2023-2026 Roy Pfund. All rights reserved.
//
// Permission is  hereby  granted,  free  of  charge,  to  any  person
// obtaining a copy of  this  software  and  associated  documentation
// files  (the  "Software"),  to  deal   in   the   Software   without
// restriction, including without limitation the rights to use,  copy,
// modify, merge, publish, distribute, sublicense, and/or sell  copies
// of the Software, and to permit persons  to  whom  the  Software  is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and  this  permission  notice  shall  be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT  WARRANTY  OF  ANY  KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES  OF
// MERCHANTABILITY,   FITNESS   FOR   A   PARTICULAR    PURPOSE    AND
// NONINFRINGEMENT.  IN  NO  EVENT  SHALL  THE  AUTHORS  OR  COPYRIGHT
// OWNER(S) BE LIABLE FOR  ANY  CLAIM,  DAMAGES  OR  OTHER  LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING  FROM,
// OUT OF OR IN CONNECTION WITH THE  SOFTWARE  OR  THE  USE  OR  OTHER
// DEALINGS IN THE SOFTWARE.

//! Chudnovsky π digits in any base 2..=36, exposed through a C ABI.
//!
//! Digits are packed into a caller-supplied `uint64_t` array:
//! `ceil(log2(base))` bits per digit, `64 / bits` digits per word (digits
//! never straddle two words), most-significant digit first in each word.
//! The digit count includes the integer part (`3`; `11` in base 2, `10` in
//! base 3).

use dashu::base::SquareRoot;
use dashu::{float::FBig, integer::IBig};
use std::ffi::{c_int, c_uint};

pub const PICHUDNOV_OK: c_int = 0;
pub const PICHUDNOV_ERR_NULL: c_int = -1;
pub const PICHUDNOV_ERR_BASE: c_int = -2;
pub const PICHUDNOV_ERR_BUFFER: c_int = -3;
pub const PICHUDNOV_ERR_DIGITS: c_int = -4;
pub const PICHUDNOV_ERR_INTERNAL: c_int = -5;

const MIN_BASE: u32 = 2;
const MAX_BASE: u32 = 36;

const C3_OVER_24: u64 = 10_939_058_860_032_000;
// log10(640320^3 / (12^3 * 3)) ≈ 14.18 decimal digits per Chudnovsky term.
const DIGITS_PER_TERM: f64 = 14.18;

fn base_ok(base: u32) -> bool {
    (MIN_BASE..=MAX_BASE).contains(&base)
}

fn bits_per_digit(base: u32) -> u32 {
    32 - (base - 1).leading_zeros()
}

fn words_needed(base: u32, digits: usize) -> usize {
    let digits_per_word = (64 / bits_per_digit(base)) as usize;
    digits.div_ceil(digits_per_word)
}

fn terms_for(base: u32, digits: usize) -> u64 {
    let decimal_digits = digits as f64 * (base as f64).log10();
    (decimal_digits / DIGITS_PER_TERM).ceil() as u64 + 2
}

fn bs(a: u64, b: u64) -> (IBig, IBig, IBig) {
    if b - a == 1 {
        if a == 0 {
            return (IBig::from(1u8), IBig::from(1u8), IBig::from(13_591_409u64));
        }
        let p = IBig::from(6 * a - 5) * IBig::from(2 * a - 1) * IBig::from(6 * a - 1);
        let q = IBig::from(a).pow(3) * IBig::from(C3_OVER_24);
        let mut t = &p * IBig::from(13_591_409u64 + 545_140_134u64 * a);
        if a % 2 == 1 {
            t = -t;
        }
        (p, q, t)
    } else {
        let m = (a + b) / 2;
        let (p1, q1, t1) = bs(a, m);
        let (p2, q2, t2) = bs(m, b);
        let t = &t1 * &q2 + &p1 * &t2;
        (&p1 * &p2, q1 * q2, t)
    }
}

/// Compute floor(pi * base^frac_digits) using Chudnovsky with binary splitting.
fn pi_chudnovsky(base: u32, frac_digits: usize) -> IBig {
    // ~10 decimal digits of guard, expressed in `base` digits.
    let guard = (10.0 / (base as f64).log10()).ceil() as usize;
    let d = frac_digits + guard;

    let (_p, q, t) = bs(0, terms_for(base, d));

    // sqrt(10005) * base^d via integer square root.
    let one_sq = IBig::from(base).pow(2 * d);
    let sqrt_c = (IBig::from(10005u32) * one_sq).sqrt();

    // pi * base^d = 426880 * sqrt(10005) * Q / T
    let pi = (q * IBig::from(426_880u32) * sqrt_c) / t;

    // Drop the guard digits (truncation == floor for positive values).
    pi / IBig::from(base).pow(guard)
}

fn factorial(n: u32) -> IBig {
    (1..=n).fold(IBig::from(1u8), |acc, x| acc * x)
}

/// Compute floor(pi * base^frac_digits) using Chudnovsky with factorials.
fn pi_chudnovsky_factorial(base: u32, frac_digits: usize) -> IBig {
    // Base digits -> binary precision.
    let bits = (frac_digits as f64 * (base as f64).log2()).ceil() as usize + 128;

    let terms = terms_for(base, frac_digits) as usize;

    let mut sum: FBig = FBig::ZERO.with_precision(bits).value();

    for k in 0..terms {
        let k_u32 = k as u32;

        let numer = factorial(6 * k_u32)
            * IBig::from(13591409u64 + 545140134u64 * k as u64);

        let denom = factorial(3 * k_u32)
            * factorial(k_u32).pow(3)
            * IBig::from(640320u64).pow((3 * k_u32) as usize);

        // Ensure FBig conversions inherit high precision
        let term =
            FBig::try_from(numer).unwrap().with_precision(bits).value()
            / FBig::try_from(denom).unwrap().with_precision(bits).value();

        if k % 2 == 0 {
            sum += term;
        } else {
            sum -= term;
        }
    }

    let c =
        FBig::try_from(426880u64)
            .unwrap()
            .with_precision(bits)
            .value()
        * FBig::try_from(10005u64)
            .unwrap()
            .with_precision(bits)
            .value()
            .sqrt();

    let pi = (c / sum).with_precision(bits).value();
    let scale = IBig::from(base).pow(frac_digits);
    let scaled = pi * FBig::try_from(scale).unwrap().with_precision(bits).value();

    // Truncation toward zero == floor for positive values.
    scaled.to_int().value()
}

/// Write the base-`base` digits of `n` into `out`, MSB-first per word.
fn pack(n: &IBig, base: u32, digits: usize, out: &mut [u64]) -> Result<(), c_int> {
    // `base` was validated as 2..=36 by the caller, so it fits in a u8.
    let s = n.in_radix(base as u8).to_string();
    // The integer part of pi is 2 digits in bases 2 and 3 ("11", "10"), so
    // `n` can hold one digit more than requested; truncating keeps the floor.
    if s.len() < digits {
        return Err(PICHUDNOV_ERR_INTERNAL);
    }
    let s = &s[..digits];

    let bits = bits_per_digit(base);
    let digits_per_word = (64 / bits) as usize;

    out.fill(0);
    for (i, ch) in s.chars().enumerate() {
        let value = ch.to_digit(base).ok_or(PICHUDNOV_ERR_INTERNAL)? as u64;
        let shift = 64 - bits * (i % digits_per_word + 1) as u32;
        out[i / digits_per_word] |= value << shift;
    }
    Ok(())
}

fn run(
    algo: fn(u32, usize) -> IBig,
    base: c_uint,
    digits: usize,
    out: *mut u64,
    out_words: usize,
) -> c_int {
    if out.is_null() {
        return PICHUDNOV_ERR_NULL;
    }
    if !base_ok(base) {
        return PICHUDNOV_ERR_BASE;
    }
    if digits == 0 {
        return PICHUDNOV_ERR_DIGITS;
    }
    if out_words < words_needed(base, digits) {
        return PICHUDNOV_ERR_BUFFER;
    }

    let out = unsafe { std::slice::from_raw_parts_mut(out, out_words) };
    let n = algo(base, digits - 1);
    match pack(&n, base, digits, out) {
        Ok(()) => PICHUDNOV_OK,
        Err(code) => code,
    }
}

/// Bits used per digit for `base`: ceil(log2(base)). Returns 0 if `base`
/// is outside 2..=36.
#[no_mangle]
pub extern "C" fn pichudnov_bits_per_digit(base: c_uint) -> c_uint {
    if !base_ok(base) {
        return 0;
    }
    bits_per_digit(base)
}

/// Number of `uint64_t` words needed to hold `digits` digits of `base`.
/// Returns 0 if `base` is outside 2..=36.
#[no_mangle]
pub extern "C" fn pichudnov_words_needed(base: c_uint, digits: usize) -> usize {
    if !base_ok(base) {
        return 0;
    }
    words_needed(base, digits)
}

/// Write the first `digits` digits of pi (including the integer part) in
/// `base` into `out`, using binary-splitting Chudnovsky (fast).
/// `out_words` must be at least `pichudnov_words_needed(base, digits)`.
/// Returns PICHUDNOV_OK or a negative PICHUDNOV_ERR_* code.
#[no_mangle]
pub extern "C" fn pichudnov_bs(
    base: c_uint,
    digits: usize,
    out: *mut u64,
    out_words: usize,
) -> c_int {
    run(pi_chudnovsky, base, digits, out, out_words)
}

/// Same as `pichudnov_bs`, using factorial Chudnovsky (slow, reference).
#[no_mangle]
pub extern "C" fn pichudnov_factorial(
    base: c_uint,
    digits: usize,
    out: *mut u64,
    out_words: usize,
) -> c_int {
    run(pi_chudnovsky_factorial, base, digits, out, out_words)
}

#[cfg(test)]
mod tests {
    use super::*;

    type Ffi = extern "C" fn(c_uint, usize, *mut u64, usize) -> c_int;

    fn digits_of(f: Ffi, base: u32, digits: usize) -> Vec<u64> {
        let mut out = vec![0u64; words_needed(base, digits)];
        assert_eq!(f(base, digits, out.as_mut_ptr(), out.len()), PICHUDNOV_OK);
        out
    }

    #[test]
    fn base10_first_word() {
        assert_eq!(digits_of(pichudnov_bs, 10, 16), [0x3141592653589793]);
        assert_eq!(digits_of(pichudnov_factorial, 10, 16), [0x3141592653589793]);
    }

    #[test]
    fn base16_first_word() {
        assert_eq!(digits_of(pichudnov_bs, 16, 16), [0x3243F6A8885A308D]);
        assert_eq!(digits_of(pichudnov_factorial, 16, 16), [0x3243F6A8885A308D]);
    }

    #[test]
    fn short_and_padded() {
        // 5 digits "31415" in the top 20 bits; the rest of the word is zero.
        assert_eq!(digits_of(pichudnov_bs, 10, 5), [0x3141500000000000]);
        // Base 2: integer part is "11", so 4 digits are 1,1,0,0.
        assert_eq!(digits_of(pichudnov_bs, 2, 4), [0b1100 << 60]);
        // Base 8: 3 bits per digit, 21 digits per word, 1 pad bit.
        assert_eq!(words_needed(8, 21), 1);
        assert_eq!(words_needed(8, 22), 2);
    }

    #[test]
    fn algorithms_agree() {
        for base in [2, 8, 10, 16, 36] {
            assert_eq!(
                pi_chudnovsky(base, 1000),
                pi_chudnovsky_factorial(base, 1000),
                "base {base}"
            );
        }
        for base in [2, 10, 36] {
            assert_eq!(digits_of(pichudnov_bs, base, 500), digits_of(pichudnov_factorial, base, 500));
        }
    }

    #[test]
    fn error_codes() {
        let mut out = [0u64; 1];
        let p = out.as_mut_ptr();
        assert_eq!(pichudnov_bs(10, 16, std::ptr::null_mut(), 1), PICHUDNOV_ERR_NULL);
        assert_eq!(pichudnov_bs(1, 16, p, 1), PICHUDNOV_ERR_BASE);
        assert_eq!(pichudnov_bs(37, 16, p, 1), PICHUDNOV_ERR_BASE);
        assert_eq!(pichudnov_bs(10, 17, p, 1), PICHUDNOV_ERR_BUFFER);
        assert_eq!(pichudnov_bs(10, 0, p, 1), PICHUDNOV_ERR_DIGITS);
        assert_eq!(pichudnov_bits_per_digit(10), 4);
        assert_eq!(pichudnov_bits_per_digit(37), 0);
        assert_eq!(pichudnov_words_needed(1, 16), 0);
    }
}
