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

{ lib, rustPlatform, rust-cbindgen }:

rustPlatform.buildRustPackage rec {
  pname = "PiChudnov";
  version = "0.1.0";
  src = ./.;

  # Reads hashes straight from Cargo.lock, so there is no cargoHash to keep
  # in sync.
  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [ rust-cbindgen ];

  # A single source file keeps cbindgen from running `cargo metadata`.
  postBuild = ''
    cbindgen --config cbindgen.toml --output PiChudnov.h src/lib.rs
  '';

  # cargoInstallHook already copies libpichudnov.{so,a} into $out/lib.
  postInstall = ''
    install -Dm644 PiChudnov.h $out/include/PiChudnov.h
  '';

  outputs = [ "out" ];

  meta = {
    description = "Chudnovsky pi digits in any base 2..36 as a C library";
    homepage = "https://github.com/Viruliant/PIbench";
    license = lib.licenses.bsd2;
    platforms = lib.platforms.unix;
    maintainers = [ lib.maintainers.GlassGhost ];
  };
}
