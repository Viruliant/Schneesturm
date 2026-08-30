#################################################################
# `pkgs.callPackage` convention for `package.nix` files

# a Nix expression that exports a `pure` = reproducible function, 
# used to create a derivation.
# (unless there are non-relative paths)

# That function’s parameters are the package’s dependencies  
# `pkgs.callPackage` fills dependencies in automatically
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

{ lib, stdenv }:

stdenv.mkDerivation (rec {
  pname = "makeheaders";
  version = "325f0576c453cfdf7d35cfc03a8aceb249f76cc9";

  src = builtins.fetchurl {
    url = "https://raw.githubusercontent.com/Viruliant/fossil-mirror/${version}/tools/makeheaders.c";
    sha256 = "1mr09x1pwqv7g0ifhz4nfi4mc9z6pygf0p4jhmihv6xs1w0p81py";
  };

  unpackPhase = ''
    cp $src makeheaders.c
  '';

  nativeBuildInputs = [ stdenv.cc ];

  buildPhase = ''
    $CC -O2 -std=gnu99 makeheaders.c -o makeheaders
  '';

  installPhase = ''
    install -Dm755 makeheaders $out/bin/makeheaders
  '';

  meta = {
    description = "Up-to-date version of makeheaders from fossil-scm.org";
    homepage = "https://fossil-scm.org/";
    license = lib.licenses.bsd2;
    platforms = lib.platforms.unix;
    maintainers = [ lib.maintainers.GlassGhost ];
  };
})
