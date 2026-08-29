{
  description = "monorepo for testing package.nix files";
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "nixpkgs";  # Follows system registry
# Fetch git submodule checkout (resolved against the on-disk flake location, so it works offline)
# and build from its source root instead.
    minimus = {
      url = "git+file:./pkgs/minimus?submodules=1";
      flake = false;
    };
  };
  outputs =
  inputs@{ self, nixpkgs, flake-parts, ... }:
  let
    lib = nixpkgs.lib;

    # Import external helpers and pass inputs context
    repoLib = import ./lib.nix { inherit nixpkgs inputs; };
    inherit (repoLib) localPkgNames mkPkgs;
  in
  flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];

    perSystem = { system, ... }:
      let
        pkgs = mkPkgs system;
      in
      {
        packages =
          let
            pkgSet = lib.genAttrs localPkgNames (name: pkgs.${name});
          in
          pkgSet // {
            default = pkgs.symlinkJoin {
              name = "monorepo-combined";
              paths = lib.attrValues pkgSet;
            };
          };

        checks =
          let
            testsFor =
              name:
              lib.mapAttrs'
                (testName: testDrv:
                  lib.nameValuePair
                    (if lib.hasPrefix name testName
                     then testName
                     else "${name}-${testName}")
                    testDrv
                )
                (lib.filterAttrs (_: lib.isDerivation) (pkgs.${name}.tests or { }));
          in
          lib.foldl' (acc: name: acc // testsFor name) { } localPkgNames;

        apps.default = {
          type = "app";
          program = "${pkgs.${localPkgNames.__head__}}/bin/${localPkgNames.__head__}";
        };

        devShells.default = pkgs.mkShell {
          packages = (map (name: pkgs.${name}) localPkgNames);
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
