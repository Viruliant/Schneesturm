{
  description = "monorepo for testing default.nix files";
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

      # Standard tracked local directories under pkgs/
      trackedPkgNames =
        let
          entries = builtins.readDir (self.outPath + "/pkgs");
        in
        lib.filter
          (name:
            entries.${name} == "directory"
            && !lib.hasPrefix "." name
            && builtins.pathExists (self.outPath + "/pkgs/${name}/default.nix")
          )
          (builtins.attrNames entries);

      # Explicit mapping for submodules/inputs built via default.nix
      inputPkgs = {
        minimus = inputs.minimus + "/default.nix";
      };

      # Combined list of package names
      localPkgNames = trackedPkgNames ++ (builtins.attrNames inputPkgs);

      overlay = final: prev:
        let
          localDrvMap = lib.genAttrs trackedPkgNames (name:
            final.callPackage (self.outPath + "/pkgs/${name}/default.nix") { }
          );
          inputDrvMap = lib.mapAttrs (name: path:
            final.callPackage path { }
          ) inputPkgs;
        in
        localDrvMap // inputDrvMap;

      overlays = [ overlay ];

      mkPkgs =
        system:
        import nixpkgs {
          inherit system overlays;
          config.allowUnfree = true;
        };

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
