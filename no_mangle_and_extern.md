
## Configure Cargo.toml

You must tell Cargo to compile the project into a library format 
that C can link against, such as a static library (.a) or a 
dynamic library (.so, .dll, or .dylib). 

```toml
[package]
name = "my_rust_lib"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["staticlib", "cdylib"]
```

-----------------------------------------------------------------

## Apply no_mangle AND extern to Rust Code you want acces to in C

`rust-cbindgen` parses your Rust files for `#[no_mangle]` and 
`pub extern "C"` declarations that must be applied to any Rust 
function you want callable from C and dynamically spits out a 
ready-to-use C/C++ .h header.  It is available from `nixpkgs`
or cargo probably has better pathing with `nixpkgs`.

```rust
// src/lib.rs
use std::ffi::{c_char, c_int, CStr};

// 1. Basic scalar example
#[no_mangle]
pub extern "C" fn rust_add(a: c_int, b: c_int) -> c_int {
    a + b
}

// 2. Complex example handling C strings safely
#[no_mangle]
pub extern "C" fn rust_print_string(s: *const c_char) -> c_int {
    if s.is_null() {
        return -1;
    }
    
    // Convert raw C string pointer to a safe Rust string slice
    unsafe {
        if let Ok(c_str) = CStr::from_ptr(s).to_str() {
            println!("Rust received: {}", c_str);
            0 // Success
        } else {
            -2 // Invalid UTF-8
        }
    }
}
```

* #[no_mangle]: Stops the Rust compiler from altering the 
function name (mangling), ensuring C can find the literal symbol 
name rust_add in the compiled binary.

* extern "C": Instructs the compiler to use the standard C 
calling convention.

* std::ffi: Always use C-compatible primitives (like c_int, 
c_char) rather than pure Rust types (i32, String), as their 
memory layouts match what C expects.

-----------------------------------------------------------------

## Compiling and Linking

When compiling your C program, you must link against the 
generated Rust library. Using gcc (Static Linking example):

```bash
gcc main.c -L./target/release -lmy_rust_lib -o main
```

(Note: Depending on your platform, you may need to pass 
additional system flags to link Rust's standard library 
dependencies, like -lpthread, -ldl, or -lm on Linux).

-----------------------------------------------------------------

## Call the Rust Library in C

read the generated .h file and figure it out
