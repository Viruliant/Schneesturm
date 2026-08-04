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
{ pkgs }:
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
      echo ">>> POSTINSTALL IS RUNNING, out=$out"
      # Ensure binaries and man directories are properly organized
      mkdir -p $out/bin
      mkdir -p $out/share/man/man1

      # If bmkdep binary was placed elsewhere, ensure it's in $out/bin/bmkdep
      if [ -f "$out/bin/bmkdep" ]; then
        true
      elif [ -f "bmkdep" ]; then
        cp bmkdep $out/bin/bmkdep
      fi

      # Create the standard 'mkdep' alias pointing to 'bmkdep'
      ln -sf bmkdep $out/bin/mkdep

      # Handle man pages safely
      if [ -f "$out/share/man/man/bmkdep.1" ]; then
        mv $out/share/man/man/bmkdep.1 $out/share/man/man1/
        rmdir $out/share/man/man 2>/dev/null || true
      fi
    '';

    meta = {
      description = "This is NetBSD version of mkdep ported to other platforms.";
      homepage = "https://github.com/trociny/bmkdep";
      license = lib.licenses.bsd2;
      platforms = lib.platforms.unix;
    };
  }
) { }
