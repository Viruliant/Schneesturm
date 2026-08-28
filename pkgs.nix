{ lib, repoRoot, inputs, ... }:
let
  localPkgNames = import (repoRoot + "/localPkgNames.nix");

  overlay = final: prev:
    prev.lib.genAttrs localPkgNames
      (name: final.callPackage (repoRoot + "/${name}/default.nix") { });

  overlays = [ overlay ];

  mkPkgs = system:
    import inputs.nixpkgs {
      inherit system overlays;
      config.allowUnfree = true;
    };
in
{
  _module.args = {
    inherit lib localPkgNames mkPkgs;
  };
}
