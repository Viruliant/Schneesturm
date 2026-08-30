{ nixpkgs, inputs }:

let
  lib = nixpkgs.lib;

  # Auto-discover every ./pkgs/<name>/package.nix and expose each one both
  # under `localPkgs` (for iteration in flake.nix) and at the top level of
  # `final` (so package.nix files can request each other, e.g. `{ bmkdep }: ...`).
  overlay = final: prev:
    let
      localPkgs =
        (lib.filesystem.packagesFromDirectoryRecursive {
          inherit (final) callPackage;
          directory = ./pkgs;
        })
        // {
          # minimus is a git submodule; the flake's own source tree doesn't
          # check submodules out, so it's built from its dedicated input instead.
          minimus = final.callPackage (inputs.minimus + "/package.nix") { };
        };
    in
    localPkgs // { inherit localPkgs; };

  mkPkgs = system: import nixpkgs {
    inherit system;
    overlays = [ overlay ];
    config.allowUnfree = true;
  };
in
{
  inherit mkPkgs;
}
