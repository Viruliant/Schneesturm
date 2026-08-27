{
  description = "x10an14's nix configs flake-part'ed";
  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    system-manager = {
      url = "github:numtide/system-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak";
    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        utils.follows = "flake-utils";
      };
    };
    clan = {
      url = "git+https://git.clan.lol/clan/clan-core?ref=26.05";
      inputs = {
        disko.follows = "disko";
        flake-parts.follows = "flake-parts";
        nixpkgs.follows = "nixpkgs";
        treefmt-nix.follows = "treefmt-nix";
        systems.follows = "systems";
      };
    };
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur = {
      url = "github:nix-community/NUR";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
      };
    };

    uterranix = {
      url = "sourcehut:~magic_rb/uterranix";
      inputs = {
        flake-parts.follows = "flake-parts";
        nixpkgs.follows = "nixpkgs";
      };
    };
    dnscontrol-nix = {
      url = "git+https://codeberg.org/hu5ky/dnscontrol-nix.git";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        treefmt-nix.follows = "treefmt-nix";
        flake-utils.follows = "flake-utils";
      };
    };
    robotnix = {
      url = "github:nix-community/robotnix";
      # inputs.nixpkgs.follows = "nixpkgs"; # TODO: Await merge
      inputs.treefmt-nix.follows = "treefmt-nix";
    };

    nixGL = {
      url = "github:guibou/nixGL";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nuScripts = {
      url = "github:nushell/nu_scripts";
      flake = false;
    };

    helix-editor = {
      url = "github:x10an14/helix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    naisdevice = {
      url = "github:nais/device";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
      };
    };
    nais-nur = {
      url = "github:nais/nur";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    steam-fetcher = {
      url = "github:nix-community/steam-fetcher";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    peon-ping = {
      url = "github:PeonPing/peon-ping";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };

    ######
    # No-op inputs for `follows` deduplication:
    ######
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
    systems.url = "github:nix-systems/default";
  };

  outputs =
    inputs:
    let
      inherit (inputs.nixpkgs) lib;
      recursivelyImportNixFiles =
        dir:
        lib.filesystem.listFilesRecursive dir |> lib.filter (f: lib.hasSuffix ".nix" <| lib.toString f);
      repoRoot = ./.;
    in
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports =
        (
          recursivelyImportNixFiles repoRoot
          |> lib.filter (f: !(lib.hasPrefix "_" <| lib.baseNameOf <| lib.toString f))
          |> lib.filter (f: !(lib.hasInfix "/pkgs/" <| lib.toString f))
          |> lib.filter (f: !(lib.hasSuffix "flake.nix" <| lib.baseNameOf f))
        )
        ++ [ inputs.flake-parts.flakeModules.modules ];
      _module.args = {
        inherit repoRoot;
        packagesPaths = rec {
          systemConfig = nixos;
          nixos = [
            "environment"
            "systemPackages"
          ];
          homeManager = [
            "home"
            "packages"
          ];
        };
      };
    };
}
