{
  description = "monorepo for testing default.nix files";
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "nixpkgs";  # Follows system registry
    # `minimus` is a git submodule, so its files are outside the parent
    # flake's tracked tree and can't be read via `./pkgs/minimus/default.nix`
    # ("subfolder is not tracked by git"). Fetch the submodule checkout
    # explicitly as a flake input (resolved against the on-disk flake
    # location, so it works offline) and build from its source.
    minimus = {
      url = "git+file:./pkgs/minimus?submodules=1";
      flake = false;
    };
#     foobar = { url = "path:/tmp/tmp.c8SCu1myPh"; flake = false;}; # tested working
#     foobar = {
#       url = "path:./x10/tmp.default.nix";
#       flake = false;
#     };
  };
  outputs =
    inputs:
    let
      inherit (inputs.nixpkgs) lib;
      recursivelyImportNixFiles =
        dir:
        lib.filter (f: lib.hasSuffix ".nix" (toString f)) (lib.filesystem.listFilesRecursive dir);
      repoRoot = ./.;
    in
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports =
        (
          lib.pipe (recursivelyImportNixFiles repoRoot) [
            (lib.filter (f: !(lib.hasPrefix "_" (lib.baseNameOf (toString f)))))
            (lib.filter (f: !(lib.hasInfix "/pkgs/" (toString f))))
            (lib.filter (f: !(lib.hasSuffix "flake.nix" (lib.baseNameOf (toString f)))))
            (lib.filter (f: !(lib.hasSuffix "default.nix" (lib.baseNameOf (toString f)))))
            (lib.filter (f: !(lib.hasInfix "/minimus/" (toString f))))
            (lib.filter (f: !(lib.hasInfix "/x10examples/" (toString f))))
          ]
        )
        ++ [ inputs.flake-parts.flakeModules.modules ];
      _module.args = {
        inherit repoRoot;
      };

      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    };
}
