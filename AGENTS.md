
## Git Workflow for nix build Testing

We have a rather simple test environment, but there are some
things we need to take in to consideration.

Uncommitted edits are invisible to `nix build`.

Both minimus and PIthon are git submodules.

We will make a temporary commit adding any uncommitted changes
with the message `"staging temp test commit for nix build"`
do all of this by simply running:

    ./stage_nix_build.sh

to see if everything compiles, run:

    nix build

to enter develop env, run:

    nix develop

if the package we are working on is failing to build, and we must 
enter a develop env to gain access to other packages in the 
flake, we don't need to do anything fancy, just temporarily mark 
the entry as null and comment out the existing entry(if there is 
one) for the package that is failing in the "attribute‑set 
override for localPkgs overlay" let's say both dictd and PIthon 
were failing 

            // { # attribute‑set override for localPkgs overlay
              minimus = final.callPackage (inputs.minimus + "/package.nix") { };
              PIthon = final.callPackage (inputs.PIthon + "/package.nix") { };
            };

would get changed to:

            // { # attribute‑set override for localPkgs overlay
              minimus = final.callPackage (inputs.minimus + "/package.nix") { };
#               PIthon = final.callPackage (inputs.PIthon + "/package.nix") { };
              PIthon = null;
              dictd = null;
            };

Remember our goal is to fix the problem not to diagnose or mess
with git.

Follow the protocol above, and after you are done getting things
working, ask the user:

"Do you wish to run `./unstage_nix_build.sh` and prepare an 
actual commit?"

---

## `#if INTERFACE` Pattern (makeheaders)

makeheaders generates `.h` files from `.c` files. The `INTERFACE`
macro controls what goes into the generated header vs stays local.

### How it works:

- When **makeheaders runs**: `INTERFACE` is implicitly 1
  - Code inside `#if INTERFACE` → extracted to the `.h` file
  - Code inside `#if !INTERFACE` → skipped (stays in `.c` only)

- When **gcc compiles** the `.c` file: `INTERFACE` is 0 (undefined)
  - Code inside `#if INTERFACE` → skipped (already in `.h`)
  - Code inside `#if !INTERFACE` → compiled locally (types, macros, static funcs)

### The generated `.h` file:

- Starts with `#undef INTERFACE` (resets to 0)
- Contains: function prototypes, exported types, exported macros
- Does NOT contain: function bodies, local types, static functions

### Rule of thumb:

- `#if !INTERFACE` → local implementation (types, macros, static funcs)
- `#if INTERFACE` → public API (types/macros other files need)
- Function definitions outside any guard → auto-exported by makeheaders
