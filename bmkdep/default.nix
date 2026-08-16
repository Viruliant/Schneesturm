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

{ lib, stdenv, fetchFromGitHub, pkg-config, bmake, patchelf, installShellFiles }:
stdenv.mkDerivation rec {
  pname = "bmkdep";
  version = "f76db982a71c817423e0609ec9625e351e9e9e7d";
  src = fetchFromGitHub {
    owner = "Viruliant";
    repo = pname;
    rev = version;
    sha256 = "sha256-dpLLYRY5lpV0jUURyvjr/Mf1JPUEnD0bm9ZJNTKb27Y=";
  };

  nativeBuildInputs = [ pkg-config patchelf bmake installShellFiles ];
  buildInputs = [];
  outputs = [ "out" ];

  preConfigure = ''
    substituteInPlace Makefile --replace "/man/man" "/man"
  '';


  installPhase = ''
    runHook preInstall
    bmake install PREFIX=$out
    runHook postInstall
  '';

  postInstall = ''
    # Install manpage properly
    installManPage bmkdep.1

    # Provide mkdep alias in a nixpkgs‑style way
    ln -s $out/bin/bmkdep $out/bin/mkdep
  '';

  meta = {
    description = "This is NetBSD version of mkdep ported to other platforms.";
    homepage = "https://github.com/trociny/bmkdep";
    license = lib.licenses.bsd2;
    platforms = lib.platforms.unix;
    maintainers = [ lib.maintainers.GlassGhost ];

  };
}
