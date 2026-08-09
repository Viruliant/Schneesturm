{
  testers,
  mk-configure,
  finalAttrs,


#   defaultTestInputs = with pkgs; [
#     (texlive.combine {
#       scheme-medium = texlive.scheme-medium;
#       relsize = texlive.relsize;
#     })
#     ghostscript
#     groff
#     bison
#     flex
#     perl
#     binutils
#     gawk
#     gnumake
#     m4
#     lua
#     fakePkgConfig
#     glib.dev
#     automake
#     autoconf
#     texinfo
#     zlib
#     zlib.dev
#   ];

}: # `nix flake check -L` 

let
  testPkgName = "mk-configure";
in
{
  hello-world = testers.runCommand{
      name = "hello-world-test";
      buildInputs = [
          finalAttrs.finalPackage
      ];
      script = ''
          echo hello world
          touch $out
      '';
  };
#   # Simple help check (Sanity test)
#   usage = testers.runCommand {
#     name = "make certain the entire examples dir can compile";
#     buildInputs = [ mk-configure ];
#     script = ''
#       # export HOME=$TMPDIR
#     '';
#   };
}

#       command --help > output.txt
#       if grep -q "Usage: command" output.txt; then
#         echo "Usage check passed ✅"
#         touch $out
#       else
#         echo "Usage check failed ❌"
#         exit 1
#       fi
