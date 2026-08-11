{
  lib,
  stdenv,
  callPackage,
  fetchFromGitHub,
  bmake,
  bmkdep,
  mk-configure,
  flex,
  bison,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "calc-example";
  version = "55a5ce31bfbb4bc215640df731908ddf6d3a7664";
  src = fetchFromGitHub {
    owner = "Viruliant";
    repo = "mk-configure";
    rev = finalAttrs.version;
    sha256 = "sha256-ZELo72rhvvPtPAmi7ARbseI0SE+S2bboebeM7rmRmLc=";
    name = "mk-configure-calc2";
  };
  sourceRoot = "mk-configure-calc2/examples/calc2";

  nativeBuildInputs = [ mk-configure bmake bmkdep flex bison ];

  configurePhase = ''
    runHook preConfigure
    export HOME="$TMPDIR"
    mkdir -p "$HOME"
    export MKCOMPILERSETTINGS=yes

    # mkc's install rules emit "-o -g ..." (empty owner) which mkc_install's
    # getopts mis-parses ("Last argument is not a directory"). Shim INSTALL to
    # drop empty -o / -g options before delegating to the real mkc_install.
    export INSTALL="$TMPDIR/mkc_install-nix"
    cat > "$INSTALL" <<'EOF'
    #!/bin/sh
    args=
    i=1
    while [ $i -le $# ]; do
      eval 'a="$'"$i"'"'
      case "$a" in
        -o|-g)
          n=$((i+1))
          eval 'nxt="$'"$n"'"'
          if [ -z "$nxt" ] || [ "''${nxt#-}" != "$nxt" ]; then
            i=$((i+1))
          else
            args="$args $a $nxt"
            i=$((i+2))
          fi
          ;;
        *)
          args="$args $a"
          i=$((i+1))
          ;;
      esac
    done
    exec mkc_install $args
    EOF
    chmod +x "$INSTALL"

    mkcmake configure PREFIX=$out INSTALL="$INSTALL"
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    mkcmake all -j$NIX_BUILD_CORES INSTALL="$INSTALL"
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkcmake install PREFIX=$out INSTALL="$INSTALL"
    runHook postInstall
  '';

  passthru = {
    tests = callPackage ./tests.nix { inherit finalAttrs; };
  };

  meta = {
    description = "calc example program (flex/bison calculator) built with mkcmake";
    homepage = "https://github.com/cheusov/mk-configure";
    license = lib.licenses.bsd2;
    platforms = lib.platforms.unix;
  };
})
