#!/usr/bin/env bash
set -euo pipefail

# 1. Replace every literal "default.nix" with "package.nix" in all flake.nix / lib.nix files in the tree
while IFS= read -r f; do
  [ -n "$f" ] && sed -i 's/default\.nix/package\.nix/g' "$f"
done < <(find . -type f \( -name flake.nix -o -name lib.nix \))

# 2. Move every file exactly named default.nix to package.nix in its own directory
while IFS= read -r f; do
  dir=$(dirname "$f")
  mv -- "$f" "$dir/package.nix"
done < <(find . -type f -name default.nix)
