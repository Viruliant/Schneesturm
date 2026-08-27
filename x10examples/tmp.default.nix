
{foo = "baz";}

/*

if you add this tmp.default.nix file to your inputs with

  inputs = {
. . .
    foobar = {
      url = "path:./x10/tmp.default.nix";
      flake = false;
    };
  };

then run

nix flake update foobar
nix build
nix repl
:lf .
foo= import "${inputs.foobar}"
foo

you will get:

{ foo = "baz"; }

*/
