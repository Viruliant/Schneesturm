{
  description = "Combined monorepo for bmkdep and mk-configure";
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
#     # nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs.url = "nixpkgs";  # Follows system registry
  };
outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    perSystem = { system, ... }:
    let
      # =====================================================================
      # Flakes give you structure and reproducibility, but they easily
      # become convoluted.
      # Keep your package definitions portable: use default.nix‑style
      # derivation inside a flake, to Keep core build logic compatible with
      #
      # * legacy Nix workflows
      # * overlays
      # * upstream Nixpkgs.
      #
      # Each name below maps to ./<name>/default.nix, callPackage'd into
      # the overlay. Add a package by adding one word to this list.
      localPkgNames = [
        "mk-configure"
        "bmkdep"
        "dictd"
        "calc2"
        "makeheaders"
      ];
      inherit (pkgs) lib;
      pkgs = nixpkgs.legacyPackages.${system}.extend (
        final: prev:
        prev.lib.genAttrs localPkgNames
          (name: final.callPackage ./${name}/default.nix { })
      );
      # This makes your flake package easy to reuse, contribute, or adapt
      # without rewriting it from scratch as a traditional default.nix or
      # turning it into an overlay.
      # =====================================================================
    in { # Flake Outputs Assembly
      checks = {
        mk-configure-examples-test-suite = pkgs.mk-configure.tests.examples-test-suite;
        calc2-example-test = pkgs.calc2.tests.calc2-example-test;
      };
      # Toggle: when set to true, runs additional build-time tests
      # test!". Set to false to skip it.
      # enable_runTests = false;
      # nix build .#mk-configure --no-link --rebuild -L
      # nix build check -L
      # nix flake check -L
      # nix flake
      # =====================================================================
      packages = (lib.genAttrs localPkgNames (name: pkgs.${name})) // {
        default = pkgs.symlinkJoin {
          name = "mk-configure-monorepo-combined";
          paths = [ pkgs.mk-configure pkgs.bmkdep pkgs.calc2 ];
        };
      };

      apps.default = {
        type = "app";
        program = "${pkgs.mk-configure}/bin/mkcmake";
      };

      devShells.default = pkgs.mkShell {
        # Dynamically maps localPkgNames to packages and adds bmake
        packages = (map (name: pkgs.${name}) localPkgNames) ++ [ pkgs.bmake ];

        shellHook = ''
          echo "bnix develop shell env"
          if [[ $- == *i* ]]; then
            export PS1="[bnix-dev:\w] "
          fi
        '';
      };
    };
  };
}
