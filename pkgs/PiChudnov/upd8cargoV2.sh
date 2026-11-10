#!/usr/bin/env bash
set -euo pipefail

upd8cargomain() {
  cd "$(dirname "$0")"

  NIX_FILE="package.nix"
  FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
  # Flake output whose cargoDeps we want (adjust if not the default package)
  TARGET=".#default.cargoDeps"

  # refresh Cargo.lock
  nix-shell -p cargo --run "cargo generate-lockfile"

  # flakes only see git-tracked files; make sure the new lock is visible
  git add -N Cargo.lock 2>/dev/null || true

  # 1. put in a placeholder hash
  update_hash_attr "cargoHash" "$FAKE_HASH"

  # 2. build ONLY the vendor FOD (no compiling) and capture the real hash
  out=$(nix build "$TARGET" --no-link 2>&1 || true)
  real=$(grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/=]+' <<<"$out" | head -n1)

  if [[ -z "$real" ]]; then
    echo "Could not extract hash. Nix output:" >&2
    echo "$out" >&2
    exit 1
  fi

  # 3. write the real hash
  update_hash_attr "cargoHash" "$real"
  echo "done."
}

update_hash_attr() {
  local attr="$1" hash="$2"
  sed -i "s|\(^[[:space:]]*${attr}[[:space:]]*=[[:space:]]*\"\)[^\"]*\([[:space:]]*\"[[:space:]]*;\)|\1${hash}\2|" "$NIX_FILE"
  echo "updated ${attr} = ${hash}"
}

upd8cargomain

# cd "$(dirname "$0")"
# 
# NIX_FILE="package.nix"
# 
# prefetch_cargo_vendor() {
#     local vendor_path
#     vendor_path="$(pwd)/vendor"
#     nix-shell -p cargo nix --run "
#       cargo vendor > /dev/null 2>&1
#       if [ -d 'vendor' ]; then
#         printf '%s' \$(nix hash path --sri vendor)
#       else
#         echo 'No vendor directory created (no dependencies found).' >&2
#       fi
#     "
# }
# 
# # https://github.com/Mic92/nix-update
#     # nix-shell -p nix-update
#   # nix-shell -p nix-update --run "nix-update attribute [--version version]"
# 
# upd8cargomain(){
#   # refresh cargo.lock
#   nix-shell -p cargo --run "cargo generate-lockfile"
# 
#   # Call the function and print the result directly
#   hash_result=$(prefetch_cargo_vendor)
#   echo "The generated hash is: $hash_result"
#   # The generated hash is: 0wkrz7jfbzkaljxsrv6g4k6l1nar9216qnls0djly8g04vx9q8x6
# 
#   #updates `./package.nix` hash attr for the lock
#   update_hash_attr "cargoHash" "$hash_result"
# 
#   echo "done."
# }
# 
# # Updates a specific attribute in the local Nix package file in-place.
# # Modifies ./package.nix directly and prints a confirmation message to stdout.
# update_hash_attr() {
#   local attr="$1" hash="$2"
#   # $1 - The attribute name to update (e.g., "cargoHash")
#   # $2 - The new value for the attribute
#   sed -i "s|\(^[[:space:]]*${attr}[[:space:]]*=[[:space:]]*\"\)[^\"]*\([[:space:]]*\"[[:space:]]*;\)|\1${hash}\2|" "$NIX_FILE"
#   echo "updated ${attr} = ${hash}"
# }
# 
# upd8cargomain
# 
# exit
