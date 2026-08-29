{ nixpkgs, inputs }:

let
  lib = nixpkgs.lib;

  # Standard tracked local directories under pkgs/
  trackedPkgNames =
    let
      entries = builtins.readDir (inputs.self.outPath + "/pkgs");
    in
    lib.filter
      (name:
        entries.${name} == "directory"
        && !lib.hasPrefix "." name
        && builtins.pathExists (inputs.self.outPath + "/pkgs/${name}/package.nix")
      )
      (builtins.attrNames entries);

  # Explicit mapping for submodules/inputs built via package.nix
  inputPkgs = {
    minimus = inputs.minimus + "/package.nix";
  };

  # Combined list of package names
  localPkgNames = trackedPkgNames ++ (builtins.attrNames inputPkgs);

  overlay = final: prev:
    let
      localDrvMap = lib.genAttrs trackedPkgNames (name:
        final.callPackage (inputs.self.outPath + "/pkgs/${name}/package.nix") { }
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
{
  inherit localPkgNames overlays mkPkgs;
}
