{
  description = "monorepo for testing package.nix files";
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "nixpkgs"; # Follows system registry
    # Fetch git submodule checkout (resolved against the on-disk flake location,
    # so it works offline) and build from its source root instead.
  # instead of: inputs.foo.url = "git+file://./my-submodule";
#     self.submodules = true;
    minimus = {
      url = "git+file:./pkgs/minimus?submodules=1&rev=1b42091ebe23e280a6d4c421f1424a12a1377b8a";
#       url = ./pkgs/minimus;
      flake = false;
    };
    PIthon = {
      url = "git+file:./pkgs/PIthon?submodules=1&rev=a101e7b9e57fbe63a805ed3a73b8ba60baca0e52";
#       url = ./pkgs/PIthon;
      flake = false;
    };
  };

  outputs =
    inputs@{ self, nixpkgs, flake-parts, ... }:
    let
      lib = nixpkgs.lib;

      overlay = final: prev:
        let
          localPkgs =
            (lib.filesystem.packagesFromDirectoryRecursive {
              inherit (final) callPackage;
              directory = ./pkgs;
            })
            // { # attribute‑set override for localPkgs overlay
              # minimus is a git submodule; the flake's own source tree doesn't
              # check submodules out, so it's built from its dedicated input instead.
              minimus = final.callPackage (inputs.minimus + "/package.nix") { };
#               PIthon = final.callPackage (inputs.PIthon + "/package.nix") { };
              PIthon = null;
            };
        in
        localPkgs // { inherit localPkgs; };

      mkPkgs = system: import nixpkgs {
        inherit system;
        overlays = [ overlay ];
        config.allowUnfree = true;
      };
    in
#     let
#       lib = nixpkgs.lib;
#       inherit (import ./lib.nix { inherit nixpkgs inputs; }) mkPkgs;
#     in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      perSystem = { system, ... }:
        let
          pkgs = mkPkgs system;
          localPkgs = pkgs.localPkgs;
          firstPkgName = lib.head (lib.attrNames localPkgs);
        in
        {
          packages = localPkgs // {
            default = pkgs.symlinkJoin {
              name = "monorepo-combined";
              paths = lib.attrValues localPkgs;
            };
          };

          checks = lib.concatMapAttrs
            (name: drv:
              lib.mapAttrs'
                (testName: testDrv:
                  lib.nameValuePair
                    (if lib.hasPrefix name testName then testName else "${name}-${testName}")
                    testDrv)
                (drv.tests or { })
            )
            localPkgs;

          apps.default = {
            type = "app";
            program = "${localPkgs.${firstPkgName}}/bin/${firstPkgName}";
          };

          devShells.default = pkgs.mkShell {
            packages = lib.attrValues localPkgs;
            shellHook = ''
              echo "monorepo dev shell"
              if [[ $- == *i* ]]; then
                export PS1="[monorepo:\w] "
              fi
            '';
          };
        };
    };
}
