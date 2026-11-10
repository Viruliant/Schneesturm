# PiChudnov — Rust Chudnovsky π library with a C ABI for PIthon

Goal: a new package `PiChudnov`, derived from `pkgs/PIbench`, that

1. drops `fractional_approx.rs` and `main.rs` (no binary, no CLI),
2. merges `pi_chudnovsky.rs` + `pi_chudnovsky_factorial.rs` into one
   `src/lib.rs`, written in the `#[no_mangle] pub extern "C"` style from
   `./no_mangle_and_extern.md`,
3. changes both algorithms to take `(base, digits)` and write packed digits
   into a caller-supplied `uint64_t` array,
4. installs `lib/libpichudnov.{so,a}` + `include/PiChudnov.h` the same way
   `minimus` installs `lib/libNuClear.so` + `include/*.h`, so PIthon can
   `#include <PiChudnov.h>` and link `-lpichudnov`.

---

## 1. Where the package lives

**Recommended: plain directory `pkgs/PiChudnov/` inside this repo (not a submodule).**

- `lib.filesystem.packagesFromDirectoryRecursive` in `flake.nix` already
  picks up any `pkgs/<name>/package.nix`, so **no flake input and no
  override line are needed** — it just appears as `localPkgs.PiChudnov`.
- Avoids the submodule rev bookkeeping. Note: `stage_nix_build.sh`'s
  `sed` searches for `git+file:pkgs/...` but `flake.nix` contains
  `git+file:./pkgs/...` (the script strips the `./`), so the `rev=` in
  `flake.nix` is probably **not** being updated for submodules today. That
  doesn't affect a plain directory.

Alternative: create a `Viruliant/PiChudnov` repo and add it as a submodule
exactly like PIbench (input + `callPackage` override). Only worth it if the
lib must be reused outside this monorepo; if chosen, fix the `sed` above first.

## 2. File layout

```
pkgs/PiChudnov/
  Cargo.toml
  Cargo.lock        # regenerated (no pico-args)
  cbindgen.toml
  package.nix
  src/lib.rs        # the only Rust source
  README.md         # short API description (optional)
```

Copied from PIbench: license header, `Cargo.lock` (then regenerated).
Not copied: `main.rs`, `fractional_approx.rs`, `flake.nix`, `flake.lock`,
`Lock2LocalPkgs.sh`, `upd8cargoV2.sh` (not needed, see §6).

## 3. `Cargo.toml`

```toml
[package]
name = "PiChudnov"
version = "0.1.0"
edition = "2021"

[lib]
name = "pichudnov"                     # -> libpichudnov.so / libpichudnov.a
crate-type = ["staticlib", "cdylib"]

[dependencies]
dashu = "0.6.2"

[profile.release]
panic = "abort"                        # never unwind across the C boundary
```

(`pico-args` is dropped — it was only used by `main.rs`.)

## 4. Digit encoding (output format)

- `bits_per_digit(base) = ceil(log2(base))` — computed with integers
  (`32 - (base-1).leading_zeros()`), not floats, to avoid rounding errors.
  - base 10 → 4, base 16 → 4, base 2 → 1, base 8 → 3, base 36 → 6.
- `digits_per_word = 64 / bits_per_digit` (integer division).
  Digits **never straddle** two words; leftover low bits of each word are 0.
  (base 10 → 16 digits per word exactly; base 8 → 21 digits + 1 pad bit.)
- `words_needed(base, digits) = ceil(digits / digits_per_word)`.
- **Order: most-significant-first inside each word.** Digit `i` lives in word
  `i / dpw` at shift `64 - bits*(i % dpw + 1)`.
  Nice side effect for base 10 (and 16): printing a word with `%016llx`
  shows the digits literally — word 0 of π base 10 is
  `0x3141592653589793`. That doubles as an easy test.
- `digits` **includes the integer part**. So `digits = 5`, base 10 →
  `3 1 4 1 5`, i.e. `floor(π · base^(digits-1))`.
  In bases 2 and 3 the integer part is two digits (`11`, `10`), so there
  `digits = 4` → `1 1 0 0` (base 2). The code handles this by computing
  `digits - 1` fractional digits and keeping the first `digits` of them,
  which still rounds down correctly.
- Supported bases: `2..=36` (same range as PIbench).

C-side decode:

```c
unsigned b = pichudnov_bits_per_digit(base), dpw = 64 / b;
unsigned d = (out[i / dpw] >> (64 - b * (i % dpw + 1))) & ((1u << b) - 1);
```

> Decision point: if you'd rather have least-significant-first (digit 0 at
> bit 0), only the shift formula changes. MSB-first is recommended for the
> readable hex dump.

## 5. `src/lib.rs` design

### 5.1 Private (Rust-only) part — the two algorithms, generalized to any base

Both currently return `floor(π · 10^d)`. They become
`fn …(base: u32, frac_digits: usize) -> IBig` returning `floor(π · base^frac_digits)`:

**Binary splitting (`pi_chudnovsky`)**
- `bs(a, b)` stays unchanged (it is base independent).
- Replace every `IBig::from(10u8)` with `IBig::from(base)`:
  - `d = frac_digits + GUARD`
  - `sqrt_c = sqrt(10005 · base^(2d))`
  - `pi = Q · 426880 · sqrt_c / T`
  - result `= pi / base^GUARD`
- Number of terms must track *decimal* precision:
  `terms = ceil(d · log10(base) / 14.18) + 2`.

**Factorial (`pi_chudnovsky_factorial`)**
- `bits = ceil(frac_digits · log2(base)) + 128`
- `terms = ceil(frac_digits · log10(base) / 14.18) + 2`
- `scale = base^frac_digits` instead of `10^frac_digits`.

**Shared helpers**
- `bits_per_digit(base) -> u32`, `words_needed(base, digits) -> usize`
- `pack(n: &IBig, base, digits, out: &mut [u64])`:
  get the digit string with `n.in_radix(base as u8).to_string()` (dashu's
  `in_radix` takes a `u8`), map each char `0-9a-z` → value, write each value
  MSB-first per §4. Zero the whole `out` slice first.
  Keep only the first `digits` chars (see the base 2/3 note in §4); if
  there are fewer, return `PICHUDNOV_ERR_INTERNAL`.

### 5.2 Public C ABI (`#[no_mangle] pub extern "C"`)

Caller allocates the buffer — no Rust-allocated memory crosses the
boundary, so there is no `free` function to get wrong.

```rust
use std::ffi::{c_int, c_uint};

#[no_mangle] pub extern "C" fn pichudnov_bits_per_digit(base: c_uint) -> c_uint;
#[no_mangle] pub extern "C" fn pichudnov_words_needed(base: c_uint, digits: usize) -> usize;

/// Binary-splitting Chudnovsky (fast). Returns 0 on success.
#[no_mangle] pub extern "C" fn pichudnov_bs(
    base: c_uint, digits: usize, out: *mut u64, out_words: usize) -> c_int;

/// Factorial Chudnovsky (slow, reference). Returns 0 on success.
#[no_mangle] pub extern "C" fn pichudnov_factorial(
    base: c_uint, digits: usize, out: *mut u64, out_words: usize) -> c_int;
```

Return codes (exposed as `#define`s / consts via cbindgen):

| code | meaning                         |
|------|---------------------------------|
| 0    | ok                              |
| -1   | `out` is NULL                   |
| -2   | base outside 2..=36             |
| -3   | `out_words < words_needed(...)` |
| -4   | `digits == 0`                   |
| -5   | internal error (should not happen) |

Names in the header: `PICHUDNOV_OK`, `PICHUDNOV_ERR_NULL`, `_BASE`,
`_BUFFER`, `_DIGITS`, `_INTERNAL`.

Inside: validate, then
`let out = unsafe { std::slice::from_raw_parts_mut(out, out_words) };`,
call the algorithm with `digits - 1` fractional digits, `pack`.
`words_needed` returns 0 for an invalid base.

Types: `usize` ↔ `size_t`, `u64` ↔ `uint64_t`, `c_uint`/`c_int` — all
C-compatible as the md file requires.

### 5.3 Tests (`#[cfg(test)]`, run by `cargo test` in the nix `checkPhase`)

- Both algorithms agree for base 10 and e.g. 2, 16, 36 at ~1000 digits
  (this is the old `assert_eq!` from `main.rs`).
- base 10, 16 digits → `out[0] == 0x3141592653589793`.
- base 16 → first word `0x3243F6A8885A308D`.
- error codes: NULL, base 1/37, too-small buffer, digits 0.

## 6. `package.nix`

Shaped like PIbench's, plus header generation and install like minimus:

```nix
{ lib, rustPlatform, rust-cbindgen }:

rustPlatform.buildRustPackage {
  pname = "PiChudnov";
  version = "0.1.0";
  src = ./.;

  # Reads hashes straight from Cargo.lock — no cargoHash to keep in sync,
  # so upd8cargoV2.sh isn't needed.
  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [ rust-cbindgen ];

  postBuild = ''
    cbindgen --config cbindgen.toml --output PiChudnov.h src/lib.rs
  '';

  # cargoInstallHook already copies lib*.so / lib*.a into $out/lib.
  postInstall = ''
    install -Dm644 PiChudnov.h $out/include/PiChudnov.h
  '';

  meta = { description = "Chudnovsky pi digits as a C library"; license = lib.licenses.bsd2;
           platforms = lib.platforms.unix; maintainers = [ lib.maintainers.GlassGhost ]; };
}
```

`cbindgen.toml`:

```toml
language = "C"
include_guard = "PICHUDNOV_H"
sys_includes = ["stdint.h", "stddef.h"]
no_includes = true
usize_is_size_t = true    # otherwise cbindgen emits uintptr_t for usize
```

Things to verify during implementation:
- Passing `src/lib.rs` (a single file) to cbindgen avoids `cargo metadata`,
  which keeps it working offline in the sandbox. If cbindgen still needs
  metadata, the fallback is to generate `PiChudnov.h` once in
  `nix develop` and commit it.
- Confirm `$out/lib` really contains `libpichudnov.so` and `.a` (if the
  hook skips them, add an explicit `install -Dm644 target/*/release/libpichudnov.* $out/lib/`).
- `apps.default` in `flake.nix` uses `lib.head (lib.attrNames localPkgs)`.
  Attr names sort `PIbench`, `PIthon`, `PiChudnov`, … (uppercase `I` <
  lowercase `i`), so the default app stays `PIbench`. `PiChudnov` has no
  `bin/`, which is fine for `symlinkJoin` and the devShell.

## 7. Future PIthon integration (not part of this step)

In `pkgs/PIthon/package.nix`:

```nix
{ lib, stdenv, makeheaders, minimus, ncurses, PiChudnov }:
  buildInputs = [ minimus ncurses PiChudnov ];
  # compile:  -I${PiChudnov}/include  ... -L${PiChudnov}/lib -lpichudnov
  # preFixup: add ${PiChudnov}/lib to the patchelf --set-rpath list
```

`PiChudnov` is resolvable as a `callPackage` argument because the overlay
puts every local package at the top level of `final`.

Linking the `.so` needs nothing extra (Rust std is bundled inside the cdylib).
Linking the `.a` statically would also need `-lpthread -ldl -lm`.

C usage:

```c
#include <PiChudnov.h>
size_t n = 1000, w = pichudnov_words_needed(10, n);
uint64_t *buf = calloc(w, sizeof *buf);
if (pichudnov_bs(10, n, buf, w) == 0) { /* decode per §4 -> snake segments */ }
free(buf);
```

## 8. Steps (in order)

1. Create `pkgs/PiChudnov` and write the crate files.
   - [x] `mkdir pkgs/PiChudnov` and copy PIbench into it (tracked files from
         PIbench `HEAD` b9bc17c, plain directory with no `.git`).
   - [x] Remove `src/main.rs`, `src/fractional_approx.rs`, `flake.nix`,
         `flake.lock`, `Lock2LocalPkgs.sh`, `upd8cargoV2.sh` (see §2).
   - [x] Merge `src/pi_chudnovsky.rs` + `src/pi_chudnovsky_factorial.rs`
         into `src/lib.rs` (§5); both old files removed.
   - [x] Rewrite `Cargo.toml` (§3) and `package.nix` (§6); add `cbindgen.toml`.
   - [x] Checked in a scratch copy (`/tmp/opencode/pc`, outside the repo):
         `cargo test --release` passes 5/5 with no warnings, and
         `cbindgen src/lib.rs` produces the header from §5.2 using
         `size_t`/`uint64_t`.
   - [x] Rewrite `README.md` for PiChudnov (build outputs, C API, return
         codes, digit encoding, C example, dev notes).
2. Regenerate the lock: `nix-shell -p cargo --run "cargo generate-lockfile"`
   inside `pkgs/PiChudnov`.
3. `./stage_nix_build.sh && nix build` (and check `.#PiChudnov` separately:
   `nix build .#PiChudnov && ls result/lib result/include`).
4. Check `result/include/PiChudnov.h` matches the API in §5.2.
5. Optional sanity check in `nix develop`: a ten-line C program printing
   `%016llx` of word 0 → `3141592653589793`.
6. Ask: "Do you wish to run `./unstage_nix_build.sh` and prepare an actual commit?"

## Open questions

- ~~Plain directory (recommended) or its own GitHub repo + submodule?~~
  **Decided: plain directory** (done in step 1).
- MSB-first (recommended) or LSB-first packing inside each `uint64_t`?
- Should `digits` count the integer part (as implemented), or only digits after the point?
