{
  description = "Combined monorepo for bmkdep and mk-configure";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

#     # nixos-version --json | jq -r '.nixpkgsRevision'
#     # 597283ad8aa0b331c788e97c4c262d58877074ef
#     # The command above will give you a code to put here:
    nixpkgs.url = "github:NixOS/nixpkgs/597283ad8aa0b331c788e97c4c262d58877074ef";
#     
#     #otherwise use:
#     # nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

#     nixpkgs.url = "nixpkgs";  # Follows system registry
  };

outputs = { self, nixpkgs, flake-utils }:
  flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; };
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
        packages = { # reference drvs defined below
          default = mk-configure-drv;
          mk-configure = mk-configure-drv;
          bmkdep = bmkdep-drv;
        };

        apps.default = {
          type = "app";
          program = "${mk-configure-drv}/bin/mkcmake";
        };

        devShells.default = pkgs.mkShell {
          name = "mk-configure-monorepo-shell";
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

# Shell functions and utilities 
# makeWrapper <executable> <wrapperfile> <args>
# remove-references-to -t <storepath> [ -t <storepath> … ] <file> …
# runHook <hook>
# substitute <infile> <outfile> <subs>
# substituteInPlace <multiple files> <subs>
# substituteAll <infile> <outfile>
# substituteAllInPlace <file>
# stripHash <path>
# wrapProgram <executable> <makeWrapperArgs>
# prependToVar <variableName> <elements…>
# appendToVar <variableName> <elements…>

# You can change the order in which phases are executed, or add new 
# phases, by setting this variable. If it’s not set, the default 
# value is used, which is
# 
#  1 $prePhases
#  2 unpackPhase
#  3 patchPhase
#  4 $preConfigurePhases
#  5 configurePhase
#  6 $preBuildPhases
#  7 buildPhase
#  8 checkPhase
#  9 $preInstallPhases
# 10 installPhase
# 11 fixupPhase
# 12 installCheckPhase
# 13 $preDistPhases
# 14 distPhase
# 15 $postPhases
      # =====================================================================
      bmkdep-drv = # NetBSD version of mkdep in `default.nix` style
      # =====================================================================
      # official mkDerivation attrs:
        # https://nix.dev/tutorials/callpackage.html
        # https://nixos.org/manual/nixpkgs/stable/#sec-stdenv-phases
        # https://nixos.org/manual/nixpkgs/stable/#var-stdenv-phases
# 
      pkgs.callPackage (
        { lib, stdenv, fetchFromGitHub, pkg-config, bmake, patchelf }:
        stdenv.mkDerivation rec {
          pname = "bmkdep";
          version = "f76db982a71c817423e0609ec9625e351e9e9e7d";
          src = fetchFromGitHub {
            owner = "Viruliant";
            repo = pname;
            rev = version;
            sha256 = "sha256-dpLLYRY5lpV0jUURyvjr/Mf1JPUEnD0bm9ZJNTKb27Y=";
          };

          nativeBuildInputs = [ pkg-config patchelf bmake ];
          buildInputs = [];
          outputs = [ "out" ];

          preConfigure = ''
            mkdir -p $out/bin
            mkdir -p $out/share/man/man1
            substituteInPlace Makefile --replace "/man/man" "/man"
          '';

          installPhase = ''
            bmake install PREFIX=$out
          '';

          postInstall = ''
            mv $out/bin/bmkdep $out/bin/
            mv $out/share/man/man/bmkdep.1 $out/share/man/man1/
          '';

          meta = {
            description = "This is NetBSD version of mkdep ported to other platforms.";
            homepage = "https://github.com/trociny/bmkdep";
            license = lib.licenses.bsd2;
            platforms = lib.platforms.unix;
          };
        }
      ) {};

      # =====================================================================
      mk-configure-drv = # Build system on top of bmake and bmkdep
      # =====================================================================
      pkgs.callPackage (
        { lib
        , stdenv
        , fetchFromGitHub
        , pkg-config
        , patchelf
        , bmake
        , makedepend
        , bmkdep
        }:
        stdenv.mkDerivation rec {
          pname = "mk-configure";
          version = "f3dd0ad13679f06570ca887516c4d7f1e785469c";
          src = fetchFromGitHub {
            owner = "Viruliant";
            repo = pname;
            rev = version;
            sha256 = "sha256-Y59CpaIhTxuUS+lJ05fowHI2cS1rwy2KACFik6+cqJA=";
          };

          nativeBuildInputs = [ pkg-config patchelf bmake makedepend ];
          buildInputs = [];
          outputs = [ "out" ];

          configurePhase = ''
            echo "=== Bootstrap mkc helpers ==="
            mkdir -p .bootstrap-bin

            # 1. Compile C checkers
            for src in mk/mkc_check_*.c; do
              [ -f "$src" ] || continue
              name=$(basename "''${src%.c}")
              gcc -O2 -o ".bootstrap-bin/$name" "$src"
              chmod +x ".bootstrap-bin/$name"
            done

            # 2. Improved mkc_check_prog shim (handles more flags)
            cat << 'EOF' > .bootstrap-bin/mkc_check_prog
            #!/bin/sh
            while [ $# -gt 0 ]; do
              case "$1" in
                -i) shift; id="$1" ;;
                -d) debug=1 ;;
                *) prog="$1" ;;
              esac
              shift
            done
            found=$(which "$prog" 2>/dev/null || true)
            if [ -n "$found" ] && [ -x "$found" ]; then
              echo "$found"
              exit 0
            fi
            [ -n "$debug" ] && echo "DEBUG: mkc_check_prog failed for $prog" >&2
            exit 1
            EOF
            chmod +x .bootstrap-bin/mkc_check_prog

            # 3. Copy all scripts (including any .in files)
            for script in scripts/*; do
              [ -f "$script" ] || continue
              name=$(basename "$script" .in)
              cp "$script" ".bootstrap-bin/$name"
              chmod +x ".bootstrap-bin/$name"
            done

            # Ensure mkdep from bmake is available
            BPATH="$PWD/.bootstrap-bin:${pkgs.bmake}/bin:${pkgs.makedepend}/bin:$PATH"
            export PATH="$BPATH"

            echo "bootstrap-bin contents:"
            ls -l .bootstrap-bin/ || true

            echo "=== Running configure ==="
            MKC_VERBOSE=1 bmake configure \
              "mkc.environ=CC=gcc CXX=g++ PATH=$BPATH"
          '';

          buildPhase = ''
            BPATH="$PWD/.bootstrap-bin:${pkgs.makedepend}/bin:${pkgs.bmake}/bin:$PATH"
            export PATH="$BPATH"
            bmake all "mkc.environ=CC=gcc CXX=g++ PATH=$BPATH"
          '';

          installPhase = ''
          BPATH="$PWD/.bootstrap-bin:${pkgs.makedepend}/bin:${pkgs.bmake}/bin:$PATH"
          export PATH="$BPATH"

          bmake install \
            PREFIX=$out \
            MKC_LIBEXECDIR=$out/libexec/mk-configure \
            MKC_SHAREDIR=$out/share/mk-configure \
            MKC_INCLUDEDIR=$out/include \
            "mkc.environ=CC=gcc CXX=g++ PATH=$BPATH"
          '';

          postInstall = ''
            BPATH="$PWD/.bootstrap-bin:${pkgs.makedepend}/bin:${pkgs.bmake}/bin:$PATH"
            export PATH="$BPATH"

            # --- FIX: Move man pages to canonical location ---
            
            # 1. Move all .1 files to share/man/man1
            if [ -d "$out/man" ]; then
              find "$out/man" -name "*.1" | while read file; do
                mv "$file" "$out/share/man/man1/"
              done
              rmdir "$out/man" 2>/dev/null || true
            fi

            # 2. Move all .7 files to share/man/man7
            if [ -d "$out/man/man7" ]; then
              find "$out/man/man7" -name "*.7" | while read file; do
                mv "$file" "$out/share/man/man7/"
              done
              # Note: rmdir only if man7 becomes empty, but usually it has files
              [ ! $(ls -A "$out/man/man7" 2>/dev/null) ] && rmdir "$out/man/man7" 2>/dev/null || true
            fi

            # 3. Move any stray .1 files found at root of $out if they existed (safety check)
            find "$out" -maxdepth 1 -name "*.1" | while read file; do
                mv "$file" "$out/share/man/man1/"
              done

            echo "Manual pages have been moved to $out/share/man/"
          '';

          meta = {
            description = "Build system on top of bmake";
            homepage = "https://github.com/cheusov/mk-configure";
            license = lib.licenses.bsd2;
            platforms = lib.platforms.unix;
          };
        }
      ) {
        # Satisfies the input definition with the sibling derivation output
        bmkdep = bmkdep-drv;
      };

      # =====================================================================

    in result);
}