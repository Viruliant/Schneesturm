{
  testers,
  mk-configure,
  src,
  pkgs,
}: let
  # Fake an FHS-installed lua for mk-configure's example tests: return the
  # install dirs it would report under /usr/local instead of /nix/store.
  fakePkgConfig = pkgs.runCommand "mkc-pkg-config" { } ''
    mkdir -p "$out/bin"
    cat > "$out/bin/pkg-config" <<'EOF'
#!/bin/sh
for arg in "$@"; do
  case "$arg" in
    *INSTALL_LMOD*) echo "/usr/local/share/lua/5.2"; exit 0 ;;
    *INSTALL_CMOD*) echo "/usr/local/lib/lua/5.2"; exit 0 ;;
  esac
done
exec ${pkgs.pkg-config}/bin/pkg-config "$@"
EOF
    chmod +x "$out/bin/pkg-config"
  '';

  # Deps available ONLY to the test, never the normal build.
  testInputs = with pkgs; [
    (texlive.combine {
      scheme-medium = texlive.scheme-medium;
      relsize = texlive.relsize;
    })
    ghostscript
    graphviz
    groff
    bison
    flex
    perl
    binutils
    gawk
#     gnumake
    m4
    lua
    fakePkgConfig
    glib.dev
    automake
    autoconf
    texinfo
    zlib
    zlib.dev
    bmake
    gcc
  ];
in
{
  # The examples test-suite only makes sense against an installed
  # mk-configure (it uses $out/bin/mkcmake and the installed
  # builtins/features/libexec). src (inherited from default.nix's passthru)
  # is the full GitHub fetch of the repo (examples/ included), so unpack it
  # for the test sources.
  examples-test-suite = testers.runCommand {
    name = "mk-configure-examples-test-suite";
    src = src;
    nativeBuildInputs = testInputs;
    buildInputs = [ mk-configure ];
    script = ''
      export PS2PDF=ps2pdf DOT=dot DVIPS=dvips LATEX=latex
      unset LUA_LMODDIR LUA_CMODDIR
      export PKG_CONFIG_PATH="${pkgs.glib.dev}/lib/pkgconfig:${pkgs.zlib.dev}/lib/pkgconfig:${pkgs.lua}/lib/pkgconfig"

      cp -r "$src"/. .
      chmod -R u+w .
      chmod u+w examples/*
      patch -p1 < ${./mk-configure-libdeps.patch}

      mkdir -p "$TMPDIR/test-output"

      # Same command that works in the dev-shell, but pointed at the
      # just-installed mk-configure, and tee'd into a log kept in $TMPDIR
      # (testers.runCommand is a fixed-output derivation, so $out must stay
      # an empty file to match the outputHash).
      (
        cd examples
        set -o pipefail
        export PATH="$PWD/helpers:${fakePkgConfig}/bin:${mk-configure}/libexec/mk-configure:${mk-configure}/bin:$PATH"
        "${mk-configure}/bin/mkcmake" -f MKCmakefile test 2>&1 \
          | tee "$TMPDIR/test-output/log"
      )
      if [ ! -s "$TMPDIR/test-output/log" ]; then
        echo "ERROR: test produced no test log" >&2
        exit 1
      fi
      touch $out
    '';
  };
}
