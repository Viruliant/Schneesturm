#!/usr/bin/env bash
utcupdate() { utc=$(date -u "+%Y.%m.%dT%H.%M.%SZ"); } #UTC Time (filename safe)
utcupdate
owd="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" #Path to THIS script.

set -euo pipefail

$owd/unstage_nix_build.sh

# # Make edits to source files
# # Commit in the submodules
commit_msg="staging temp test commit for nix build"

upd8submoduleHashes() {
  cd "$owd"

  # Extract all git+file inputs from flake.nix
  mapfile -t inputs < <(grep -o 'git+file:[^"]*' flake.nix)

  for input in "${inputs[@]}"; do
    # Example input:
    # git+file:./pkgs/some_project?submodules=1&rev=abcdef

    # Strip prefix
    path_with_query="${input#git+file:}"

    # Extract path (before '?')
    submodule_path="${path_with_query%%\?*}"

    # Normalize path
    submodule_path="${submodule_path#./}"

    # Extract project name (last path component)
    project="${submodule_path##*/}"

    echo "Processing submodule: $project at $submodule_path"

    # Commit inside the submodule
    git -C "$owd/$submodule_path" add -A
    git -C "$owd/$submodule_path" commit -m "$commit_msg" || true

    # Get new rev
    new_rev=$(git -C "$owd/$submodule_path" rev-parse HEAD)

    echo "New rev for $project: $new_rev"

    # Update flake.nix
    sed -i \
      -e "s|\(git+file:$submodule_path?submodules=1&rev=\)[^\"]*|\1$new_rev|" \
      flake.nix

    # Stage updated submodule
    git add "$submodule_path"
  done
}

upd8submoduleHashes && git add -A && \
git commit -m "$commit_msg"

SetFlake2LocalSysNixPkgs() {
  # set nixpkgs to current local system nixpkgs
  rev=$(nixos-version --json | jq -r '.nixpkgsRevision')
  if [[ -z "$rev" ]]; then
    echo "Failed to extract nixpkgsRevision" >&2
    exit 1
  fi
  echo "Updating flake to nixpkgs revision: $rev"
  nix flake update \
    --override-input nixpkgs "github:NixOS/nixpkgs/${rev}"
}

SetFlake2LocalSysNixPkgs