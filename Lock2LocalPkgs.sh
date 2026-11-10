#!/usr/bin/env bash
set -euo pipefail

# # Run from the repo root (flake.nix lives one level above this script).
# cd "$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# Run from the script's directory (flake.nix location depends on your setup).
cd "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

Lock2LocalPkgs (){
  rev=$(nixos-version --json | jq -r '.nixpkgsRevision')

  if [[ -z "$rev" ]]; then
    echo "Failed to extract nixpkgsRevision" >&2
    exit 1
  fi

  echo "Updating flake to nixpkgs revision: $rev"

  nix flake update \
    --override-input nixpkgs "github:NixOS/nixpkgs/${rev}"
}

Lock2LocalPkgs
