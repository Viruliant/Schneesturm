{
  description = "monorepo for testing package.nix files";
  inputs = {
    nixpkgs.url = "nixpkgs"; # Follows system registry
    self.submodules = true;
    flake-parts.url = "github:hercules-ci/flake-parts";
    # Fetch git submodule checkout (resolved against the on-disk flake location,
    # so it works offline) and build from its source root instead.
  };
  # ToDo: lazy loading
  outputs =
    inputs@{ self, nixpkgs, flake-parts, ... }:
    let
      lib = nixpkgs.lib;
      overlay = final: prev:
        let
          # Names come from readDir only; values stay lazy. Don't force them here.
          localPkgs = lib.filesystem.packagesFromDirectoryRecursive {
            inherit (final) callPackage;
            directory = ./pkgs;
          };
        in
        localPkgs // { inherit localPkgs; };
      mkPkgs = system: import nixpkgs {
        inherit system;
        overlays = [ overlay ];
        config.allowUnfree = true;
      };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
      ];

      perSystem = { system, ... }:
        let
          pkgs = mkPkgs system;
          # Safe to force values here. This drops empty (uncheckout-out submodule)
          # directories, which show up as `{}` rather than derivations.
          localPkgs = lib.filterAttrs (_: lib.isDerivation) pkgs.localPkgs;
        in
        {
          packages = localPkgs // {
            default = pkgs.symlinkJoin {
              name = "monorepo-combined";
              paths = lib.attrValues localPkgs;
            };
          };

          checks = lib.concatMapAttrs
            (name: drv:
              lib.mapAttrs'
                (testName: testDrv:
                  lib.nameValuePair
                    (if lib.hasPrefix name testName then testName else "${name}-${testName}")
                    testDrv)
                (drv.tests or { })
            )
            localPkgs;

#           apps.default = {
#             type = "app";
#             program = "${localPkgs.${firstPkgName}}/bin/${firstPkgName}";
#           };
          apps.default = {
            type = "app";
            program = lib.getExe localPkgs.PIthon;
          };
          devShells.default = pkgs.mkShell {
            packages = lib.attrValues localPkgs ++ [ pkgs.mawk ];
            shellHook = ''
              echo "monorepo dev shell"
              if [[ $- == *i* ]]; then
                export PS1="[monorepo:\w] "
              fi
            '';
          };
        };
    };
}
