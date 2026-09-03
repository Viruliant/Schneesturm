#!/usr/bin/env bash
utcupdate() { utc=$(date -u "+%Y.%m.%dT%H.%M.%SZ"); } #UTC Time (filename safe)
utcupdate
owd="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" #Path to THIS script.

set -euo pipefail

$owd/unstage_nix_build.sh

# # 1. Make edits to source files
# # 2. Commit in the submodules
commit_msg="stash_everything"

cd $owd/pkgs/minimus && git add -A && git commit -m "$commit_msg"
cd $owd/pkgs/PIthon && git add -A && git commit -m "$commit_msg"

# 3. Update parent repo
cd $owd

# get new commit hashes
minimus_rev=$(git -C "$owd/pkgs/minimus" rev-parse HEAD)
python_rev=$(git -C "$owd/pkgs/PIthon" rev-parse HEAD)

# update flake.nix rev fields
# Update minimus rev
sed -i \
  -e "s|\(git+file:./pkgs/minimus?submodules=1&rev=\)[^\"]*|\1$minimus_rev|" \
  "$owd/flake.nix"

# Update PIthon rev
sed -i \
  -e "s|\(git+file:./pkgs/PIthon?submodules=1&rev=\)[^\"]*|\1$python_rev|" \
  "$owd/flake.nix"

git add pkgs/minimus pkgs/PIthon && git add -A && \
git commit -m "$commit_msg"



#set nixpkgs to current local system nixpkgs
rev=$(nixos-version --json | jq -r '.nixpkgsRevision')

if [[ -z "$rev" ]]; then
  echo "Failed to extract nixpkgsRevision" >&2
  exit 1
fi

echo "Updating flake to nixpkgs revision: $rev"

nix flake update \
  --override-input nixpkgs "github:NixOS/nixpkgs/${rev}"
