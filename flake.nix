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
      bmkdep-drv # NetBSD version of mkdep
        = pkgs.bmkdep; 
      # =====================================================================
      mk-configure-drv # Build system on top of bmake and bmkdep
        = pkgs.mk-configure;
      # =====================================================================
      # all nix files above here in `default.nix` style
      pkgs = (import nixpkgs { inherit system; }).extend (final: prev: {
        bmkdep       = import ./bmkdep.nix       { pkgs = final; };
        mk-configure = import ./mk-configure.nix { pkgs = final; };
        # my-new-pkg   = import ./my-new-pkg.nix   { pkgs = final; };
      }); # all nix files above here in `default.nix` style
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
      # Flake Outputs Assembly
      # =====================================================================
      result = {
#         packages = { # reference drvs defined below
#           default = mk-configure-drv;
#           mk-configure = mk-configure-drv;
#           bmkdep = bmkdep-drv;
#         };

        packages = { # reference drvs defined below
          default = pkgs.symlinkJoin {
            name = "mk-configure-monorepo-combined";
            paths = [ mk-configure-drv bmkdep-drv ];
          };
          mk-configure = mk-configure-drv;
          bmkdep = bmkdep-drv;
        };


        apps.default = {
          type = "app";
          program = "${mk-configure-drv}/bin/mkcmake";
        };

        devShells.default = pkgs.mkShell {
          name = "mk-configure-monorepo-shell";
          packages = [
            mk-configure-drv
            bmkdep-drv
            (pkgs.texlive.combine {
              scheme-medium = pkgs.texlive.scheme-medium;
              relsize = pkgs.texlive.relsize;
            })
            pkgs.graphviz
            pkgs.ghostscript
          ];
          inputsFrom = [ mk-configure-drv bmkdep-drv ];
          shellHook = ''
            echo "mk-configure + bmkdep development shell ready!"
            export PS1="[mk-configure-mono:\u@\h:\w] "
            if [ -L "$PWD/result" ]; then
              export MANPATH="$MANPATH:$(readlink -f "$PWD/result")/share/man"
            fi
          '';
        };
      };
 
    in result);
}