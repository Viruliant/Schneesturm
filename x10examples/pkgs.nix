{ config, lib, ... }:
let
  generativeAi = import ./pkgs/generative-ai { inherit lib; };
  addLocalPkgs =
    pkgs: prev:
    let
      callPackage = (lib.recursiveUpdate pkgs x10sPackages) |> lib.callPackageWith;
      generativeAi = import ./pkgs/generative-ai {
        inherit lib;
        inherit (prev) llama-cpp;
        inherit (pkgs) stdenvNoCC;
        x10Lib = config.x10.lib;
      };
      x10sPackages = generativeAi.packages // {
        bexpand = callPackage ./pkgs/bexpand.nix { };
        codebook-lsp = callPackage ./pkgs/codebook-lsp.nix { };
        dashcli = callPackage ./pkgs/dashcli.nix { };
        dashcli-unwrapped = callPackage ./pkgs/dashcli-unwrapped.nix { };
        inherit (generativeAi) llama-cpp;
        nono-claude-pack = callPackage ./pkgs/nono-claude-pack.nix { };
        # nushellPlugins.bexpand = callPackage ./pkgs/bexpand.nix { };# TODO: Figure out why this one causes some sort of infinite recursion
        show-btrfs-root-snapshot-diff = callPackage ./pkgs/show-btrfs-root-snapshot-diff.nix { };
        technitium-splithorizonapp = callPackage ./pkgs/technitium-splithorizonapp.nix { };
        valheim-dedicated-server-fhsenv = callPackage ./pkgs/valheim-dedicated-server-fhsenv.nix { };
        valheim-dedicated-server-unwrapped = callPackage ./pkgs/valheim-dedicated-server-unwrapped.nix { };
        worm-scraper = callPackage ./pkgs/worm-scraper.nix { };
      };
    in
    x10sPackages;
in
{
  config = {
    x10 = {
      generative-ai.models = generativeAi.models;
      overlays.allHosts = [ (final: prev: addLocalPkgs final prev) ];
    };
    perSystem =
      { pkgs, ... }:
      {
        packages = addLocalPkgs pkgs pkgs |> lib.filterAttrs (_: lib.isDerivation);
      };
  };
}
