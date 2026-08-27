{
  description = "monorepo for testing default.nix files";
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "nixpkgs";  # Follows system registry
#     foobar = { url = "path:/tmp/tmp.c8SCu1myPh"; flake = false;}; # tested working
    foobar = {
      url = "path:./x10/tmp.default.nix";
      flake = false;
    };

  };
  outputs =
    inputs@{ self, nixpkgs, flake-parts, ... }:
    let
      lib = nixpkgs.lib;

      # =====================================================================
      # Flakes give you structure and reproducibility, but they easily
      # become convoluted.
      # Keep your package definitions portable: use default.nix-style
      # derivation inside a flake, to keep core build logic compatible with
      #
      # * legacy Nix workflows
      # * overlays
      # * upstream Nixpkgs.
      #
      # Each name below maps to ./<name>/default.nix, callPackage'd into
      # the overlay. Add a package by adding one word to this list.
      localPkgNames = import ./localPkgNames.nix;
#       localPkgNames = [ #the above is equivalent to this
#         "mk-configure"
#         "bmkdep"
#         "dictd"
#         "calc2"
#         "makeheaders"
#       ];

      overlay = final: prev:
        prev.lib.genAttrs localPkgNames
          (name: final.callPackage ./${name}/default.nix { });

      overlays = [ overlay ];

      mkPkgs =
        system:
        import nixpkgs {
          inherit system overlays;
          config.allowUnfree = true;
        };
      # This makes your flake package easy to reuse, contribute, or adapt
      # without rewriting it from scratch as a traditional default.nix or
      # turning it into an overlay.
      # =====================================================================

    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
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
                name = "mk-configure-monorepo-combined";
                paths = lib.attrValues pkgSet;
              };
            };
          checks =
            let
              testsFor =
                name:
                lib.mapAttrs'
                  (
                    testName: testDrv:
                    lib.nameValuePair
                      (if lib.hasPrefix name testName then testName else "${name}-${testName}")
                      testDrv
                  )
                  (lib.filterAttrs (_: lib.isDerivation) (pkgs.${name}.tests or { }));
            in
            lib.foldl' (acc: name: acc // testsFor name) { } localPkgNames;
          # To let a new package participate, all it needs is a 
          # passthru.tests = callPackage ./tests.nix { ... }; block like 
          # mk-configure's (your tests.nix returns an attrset of derivations 
          # — testers.runCommand { ... } per test). Add the package name to 
          # localPkgNames, give it a tests.nix if you want checks, and it 
          # shows up in nix flake check -L with zero changes to the flake 
          # itself.
          apps.default = {
            type = "app";
            program = "${pkgs.mk-configure}/bin/mkcmake";
          };
          devShells.default = pkgs.mkShell {
            packages = (map (name: pkgs.${name}) localPkgNames) ++ [ pkgs.bmake ];
            shellHook = ''
              echo "bnix develop shell env"
              if [[ $- == *i* ]]; then
                export PS1="[bnix-dev:\w] "
              fi
            '';
          };
        };
    };
}
