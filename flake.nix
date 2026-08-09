{
  description = "Combined monorepo for bmkdep and mk-configure";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

#     # nixos-version --json | jq -r '.nixpkgsRevision'
#     # 6d65bfc1bcef2ef39a239d38e577e92a89fb0f07
#     # The command above will give you a code to put here:
    nixpkgs.url = "github:NixOS/nixpkgs/6d65bfc1bcef2ef39a239d38e577e92a89fb0f07";
#     
#     #otherwise use:
#     # nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

#     nixpkgs.url = "nixpkgs";  # Follows system registry
  };

outputs = { self, nixpkgs, flake-utils }:
  flake-utils.lib.eachDefaultSystem (system:
    let
      # =====================================================================
      # Toggle: when set to true, runs additional build-time tests
      # test!". Set to false to skip it.
#       enable_runTests = false;
      # nix build .#mk-configure --no-link --rebuild -L
      # =====================================================================
#       bmkdep-drv # NetBSD version of mkdep
#         = pkgs.bmkdep; 
#       # =====================================================================
#       mk-configure-drv # Build system on top of bmake and bmkdep
#         = pkgs.mk-configure;
      # =====================================================================
      pkgs = nixpkgs.legacyPackages.${system}.extend(
        final: prev:{
            bmkdep = prev.callPackage ./bmkdep.nix {};
            mk-configure = final.callPackage ./mk-configure/default.nix {};
        }
      );
      inherit (pkgs) lib;

      # Flake Outputs Assembly
      # =====================================================================
    in {
        checks = {
            mk-configure-hello-world = pkgs.mk-configure.tests.hello-world;
            # Additional checks can go here
            # another-test = ...;
        };
        packages = { # reference drvs defined below
          default = pkgs.symlinkJoin {
            name = "mk-configure-monorepo-combined";
            paths = [ pkgs.mk-configure pkgs.bmkdep ];
          };
          mk-configure = pkgs.mk-configure;
          bmkdep = pkgs.bmkdep;
        };


        apps.default = {
          type = "app";
          program = "${pkgs.mk-configure}/bin/mkcmake";
        };


    });
}
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
      # =====================================================================