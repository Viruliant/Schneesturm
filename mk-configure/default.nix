#################################################################
# official mkDerivation attrs:
  # https://nix.dev/tutorials/callpackage.html
  # https://nixos.org/manual/nixpkgs/stable/#sec-stdenv-phases
  # https://nixos.org/manual/nixpkgs/stable/#var-stdenv-phases
# Default Phase order: 1 unpack, 2 patch, 3 configure, 4 build,
# 5 check, 6 install, 7 fixup, 8 installCheck, 9 dist
# where {$var} is the phase name there is a 
# `pre{$var}`, `{$var}Phase`, and `post{$var}` for each phase
#################################################################
{   lib
  , stdenv
  , fetchFromGitHub
  , pkg-config
  , patchelf
  , bmake
  , bmkdep
  , texlive
  , graphviz
  , ghostscript
  , testers
  , callPackage
  , installShellFiles
}: let
  in

  stdenv.mkDerivation (rec {
    pname = "mk-configure";
    version = "55a5ce31bfbb4bc215640df731908ddf6d3a7664";
    # nix-shell -p nix-prefetch-github --run "nix-prefetch-github Viruliant mk-configure --rev 55a5ce31bfbb4bc215640df731908ddf6d3a7664"
    src = fetchFromGitHub {
      owner = "Viruliant";
      repo = pname;
      rev = version;
      sha256 = "sha256-ZELo72rhvvPtPAmi7ARbseI0SE+S2bboebeM7rmRmLc=";
    };

    # examples/libdeps/test.mk blanks any absolute token whose path does not
    # contain the literal substring "mk-configure". In the nix build the source
    # lives under /build/source, so cross-directory headers resolved through
    # -I (progs/foobaz -> libs/libfoo/foo.h, ...) were stripped and the
    # libdeps "depends" subsection failed. Key the filter on the project root
    # (${.CURDIR}) instead of the name substring.
    patches = [ ./mk-configure-libdeps.patch ];

    nativeBuildInputs = [
      pkg-config patchelf bmake bmkdep installShellFiles
      (texlive.combine {
        scheme-medium = texlive.scheme-medium;
        relsize = texlive.relsize;
      })
      graphviz ghostscript
    ];
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
      BPATH="$PWD/.bootstrap-bin:${bmake}/bin:${bmkdep}/bin:$PATH"
      export PATH="$BPATH"

      echo "bootstrap-bin contents:"
      ls -l .bootstrap-bin/ || true

      echo "=== Running configure ==="
      MKC_VERBOSE=1 bmake configure \
        PREFIX=$out \
        "mkc.environ=CC=gcc CXX=g++ PATH=$BPATH"
    '';

    buildPhase = ''
      BPATH="$PWD/.bootstrap-bin:${bmake}/bin:${bmkdep}/bin:$PATH"
      export PATH="$BPATH"
      bmake all \
        PREFIX=$out \
        "mkc.environ=CC=gcc CXX=g++ PATH=$BPATH"
    '';

    installPhase = ''
    BPATH="$PWD/.bootstrap-bin:${bmake}/bin:${bmkdep}/bin:$PATH"
    export PATH="$BPATH"

    bmake install \
      PREFIX=$out \
      MKC_LIBEXECDIR=$out/libexec/mk-configure \
      MKC_SHAREDIR=$out/share/mk-configure \
      MKC_INCLUDEDIR=$out/include \
      "mkc.environ=CC=gcc CXX=g++ PATH=$BPATH"

    # --- Install the regression-test helper scripts ---
    # (main.mk excludes them from the default install via
    #  NODEPS += install-examples/helpers:install; the examples/MKCmakefile
    #  test flow needs mkc_test_helper etc. on PATH)
    bmake install-examples/helpers \
      PREFIX=$out \
      MKC_LIBEXECDIR=$out/libexec/mk-configure \
      MKC_SHAREDIR=$out/share/mk-configure \
      MKC_INCLUDEDIR=$out/include \
      "mkc.environ=CC=gcc CXX=g++ PATH=$BPATH"

    # examples/helpers/Makefile has an upstream bug: mkc_test_helper is listed
    # twice in SCRIPTS and mkc_test_helper3 is omitted, so install-examples/helpers
    # never ships it. examples/requirements and tests/create_cachedir need it.
    install -m 0755 examples/helpers/mkc_test_helper3 "$out/libexec/mk-configure/mkc_test_helper3"

    # bmake >= 20260313 emits .error as "bmake[N]: <file>:<line>: \"msg\"" instead
    # of "bmake: ... line <N>: \"msg\"". Update mkc_test_helper's normalization
    # rule so the test-suite comparisons still match (tests/test_subprj_dash).
    sed -i 's|bmake:\.\*line \[0-9\]\[0-9\]\*: "|bmake:\[^"\]\*: "|' "$out/libexec/mk-configure/mkc_test_helper"

    # --- Build the presentation and install its PDF ---
    # (custom installPhase bypasses the postInstall hook, so it must run here)
    echo "=== Building presentation ==="
    export PATH="$out/bin:$PATH"
    cd presentation
    "$out/bin/mkcmake" all PS2PDF=ps2pdf DOT=dot DVIPS=dvips LATEX=latex
    install -D -m 0644 presentation.pdf "$out/share/doc/mk-configure/presentation.pdf"
    '';

    postInstall = ''
      # Install manpages properly
      if [ -d "$out/man" ]; then
        for f in $(find "$out/man" -name "*.1"); do
          installManPage "$f"
        done

        for f in $(find "$out/man" -name "*.7"); do
          installManPage "$f"
        done
        rm -rf "$out/man"
      fi

      # Ensure mkdep and bmkdep are available
      ln -s $out/bin/bmkdep $out/bin/mkdep
    '';

    checkPhase = ''
      runHook preCheck
      # Remember the source/build root: installPhase leaves the shell inside
      # presentation/, so installCheckPhase must not rely on $PWD.
      export MK_ROOT="$PWD"
      echo "pre-install sanity check (source root: $MK_ROOT)"
      runHook postCheck
    '';

    passthru = {
        # tests.nix resolves mk-configure itself via callPackage (final
        # overlay) and gets src inherited here.
        tests = callPackage ./tests.nix { inherit src; };
    };

    meta = {
      description = "Build system on top of bmake";
      homepage = "https://github.com/cheusov/mk-configure";
      license = lib.licenses.bsd2;
      platforms = lib.platforms.unix;
      maintainers = [ lib.maintainers.GlassGhost ];
    };
  })
