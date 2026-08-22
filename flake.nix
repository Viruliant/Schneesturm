{
  description = "Combined monorepo for bmkdep and mk-configure";
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
#nix flake update \
#      --override-input nixpkgs "github:NixOS/nixpkgs/5880666fd9eb563038431edb35c2d0aa595884e6"
#     # nixos-version --json | jq -r '.nixpkgsRevision'
#     # 6d65bfc1bcef2ef39a239d38e577e92a89fb0f07
#     # The command above will give you a code to put here:
#     nixpkgs.url = "github:NixOS/nixpkgs/6d65bfc1bcef2ef39a239d38e577e92a89fb0f07";
#     #otherwise use:
#     # nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs.url = "nixpkgs";  # Follows system registry
  };
outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    perSystem = { system, ... }:
    let
      # =====================================================================
      # Toggle: when set to true, runs additional build-time tests
      # test!". Set to false to skip it.
      # enable_runTests = false;
      # nix build .#mk-configure --no-link --rebuild -L
      # =====================================================================
      # Keep your package definitions portable: use default.nix‑style
      # derivation inside a flake
      #
      # Flakes give you structure and reproducibility, but they easily
      # become convoluted. use default.nix‑style derivation inside a
      # flake, to Keep core build logic compatible with
      #
      # * legacy Nix workflows
      # * overlays
      # * upstream Nixpkgs.
      #
      # This makes your flake package easy to reuse, contribute, or adapt
      # without rewriting it from scratch as a traditional default.nix or
      # turning it into an overlay.
      #
      # The same `mkDerivation` block can be lifted almost unchanged into
      # a standalone `default.nix` later.
      # Each name below maps to ./<name>/default.nix, callPackage'd into
      # the overlay. Add a package by adding one word to this list.
      localPkgNames = [
        "bmkdep"
        "mk-configure"
        "dictd"
        "calc2"
        "makeheaders"
      ];
      # =====================================================================
      pkgs = nixpkgs.legacyPackages.${system}.extend (
        final: prev:
        prev.lib.genAttrs localPkgNames
          (name: final.callPackage ./${name}/default.nix { })
      );
      inherit (pkgs) lib;
      # =====================================================================
      # Flake Outputs Assembly
      # =====================================================================
    in {
        checks = {
            mk-configure-examples-test-suite = pkgs.mk-configure.tests.examples-test-suite;
            calc2-example-test = pkgs.calc2.tests.calc2-example-test;
            # Additional checks can go here
            # another-test = ...;
        };
        packages = { # reference drvs defined below
          default = pkgs.symlinkJoin {
            name = "mk-configure-monorepo-combined";
            paths = [ pkgs.mk-configure pkgs.bmkdep pkgs.calc2 ];
          };
          mk-configure = pkgs.mk-configure;
          bmkdep = pkgs.bmkdep;
          dictd = pkgs.dictd;
          calc2 = pkgs.calc2;
          makeheaders = pkgs.makeheaders;
        };
        apps.default = {
          type = "app";
          program = "${pkgs.mk-configure}/bin/mkcmake";
        };
        devShells = {
          default = pkgs.mkShell {
            packages = [ pkgs.makeheaders pkgs.calc2 pkgs.mk-configure pkgs.bmake pkgs.bmkdep ];
            shellHook = ''
              echo "bnix develop shell env"
              if [[ $- == *i* ]]; then
                export PS1="[bnix-dev:\w] "
              fi
            '';
          };
        };
    };
  };
}