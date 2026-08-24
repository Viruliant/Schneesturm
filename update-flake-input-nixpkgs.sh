#!/usr/bin/env bash
set -euo pipefail

rev=$(nixos-version --json | jq -r '.nixpkgsRevision')

if [[ -z "$rev" ]]; then
  echo "Failed to extract nixpkgsRevision" >&2
  exit 1
fi

echo "Updating flake to nixpkgs revision: $rev"

nix flake update \
  --override-input nixpkgs "github:NixOS/nixpkgs/${rev}"
