# Notes: moving the top-level `let` into `inputs` (flake-parts)

Goal: eliminate the top-level `let` block in the repo-root `flake.nix`
(`lib`, `localPkgNames`, `overlay`, `overlays`, `mkPkgs`) by relocating those
definitions into the `inputs` section — using `flake = false` inputs plus
`_module.args` as the bridge — while keeping all logic inside `flake.nix`.

The techniques below were lifted from this `x10examples/` directory because
they show exactly how to do that.

---

## 1. `flake = false` plain-nix input (`x10examples/tmp.default.nix`, lines 4–27)

```nix
# inputs = {
#   foobar = {
#     url = "path:./x10/tmp.default.nix";
#     flake = false;
#   };
# };
# then:  foo = import "${inputs.foobar}";  ->  { foo = "baz"; }
```

**Why pertinent:** This is the canonical pattern for pulling a plain `.nix`
file into `inputs` so its value can be `import`ed in `outputs`. We use it to
turn `./localPkgNames.nix` into a real `inputs.localPkgNames` entry
(`url = "path:./localPkgNames.nix"; flake = false;`), removing the
`import ./localPkgNames.nix` that used to sit in the top-level `let`. It is
already proven working by the `foobar`/`minimus` inputs in our own `flake.nix`.

---

## 2. `_module.args` injection (`x10examples/flake.nix`, lines 155–168)

```nix
_module.args = {
  inherit repoRoot;
  packagesPaths = rec {
    systemConfig = nixos;
    nixos = [ "environment" "systemPackages" ];
    homeManager = [ "home" "packages" ];
  };
};
```

**Why pertinent (central technique):** `_module.args` is set inside the
`mkFlake` attribute set — i.e. still in `flake.nix`, not a separate file — and
it injects values into the argument scope of *every* `perSystem` module. That
is precisely how we move `lib` / `overlay` / `overlays` / `mkPkgs` out of the
top-level `let`: wrap their definitions in a `let … in { … }` assigned to
`_module.args`, sourcing `localPkgNames` from `inputs.localPkgNames` and
`minimus` from `inputs.minimus`. No top-level `let` remains.

---

## 3. `recursivelyImportNixFiles` + filtered `imports` (`x10examples/flake.nix`, lines 140–154)

```nix
recursivelyImportNixFiles =
  dir:
  lib.filesystem.listFilesRecursive dir
  |> lib.filter (f: lib.hasSuffix ".nix" <| lib.toString f);
repoRoot = ./.;
imports =
  (recursivelyImportNixFiles repoRoot
    |> lib.filter (f: !(lib.hasPrefix "_" <| lib.baseNameOf <| lib.toString f))
    |> lib.filter (f: !(lib.hasInfix "/pkgs/" <| lib.toString f))
    |> lib.filter (f: !(lib.hasSuffix "flake.nix" <| lib.baseNameOf f)))
  ++ [ inputs.flake-parts.flakeModules.modules ];
```

**Why pertinent:** If we later decide to split the `overlay` / `checks` /
`apps` / `devShells` logic out of `flake.nix` into separate flake-parts module
files, this auto-discovery pattern avoids hand-maintaining a `let` list of
modules. Not needed for the current single-file refactor, but the escape hatch
is here.

---

## 4. Consuming a flake input as a module: `inputs.X.flakeModule` (`x10examples/flake.nix` 82–85 + `x10examples/commit-hooks.nix` 1–4)

```nix
# in inputs:
#   git-hooks = { url = "github:cachix/git-hooks.nix"; inputs.nixpkgs.follows = "nixpkgs"; };
# in a module:
{ inputs, ... }:
{
  imports = [ inputs.git-hooks.flakeModule ];
  perSystem = { config, ... }: {
    pre-commit.settings.hooks.check-symlinks.enable = true;
  };
}
```

**Why pertinent:** Shows the pattern for turning a flake input into a reusable
`flakeModule` consumed via `imports`, rather than re-deriving its logic inline.
If we ever promote `flake-helpers` content into a standalone flake, this is how
the top flake would call it.

---

## 5. `addLocalPkgs` overlay + `perSystem.packages` (`x10examples/pkgs.nix`, lines 1–42)

```nix
addLocalPkgs =
  pkgs: prev:
  let
    callPackage = (lib.recursiveUpdate pkgs x10sPackages) |> lib.callPackageWith;
    x10sPackages = { bexpand = callPackage ./pkgs/bexpand.nix { }; /* ... */ };
  in x10sPackages;

# used as:
x10.overlays.allHosts = [ (final: prev: addLocalPkgs final prev) ];
perSystem = { pkgs, ... }: {
  packages = addLocalPkgs pkgs pkgs |> lib.filterAttrs (_: lib.isDerivation);
};
```

**Why pertinent:** An alternative to our single global `overlay` + `genAttrs`
approach — it registers local packages per-system through `perSystem.packages`
instead. Useful if we later want per-system (rather than overlay-driven)
package exposure without touching the global `nixpkgs` overlay.
