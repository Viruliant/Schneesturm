#!/usr/bin/env bash
utcupdate() { utc=$(date -u "+%Y.%m.%dT%H.%M.%SZ"); }
utcupdate
owd="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
set -euo pipefail

commit_msg="${1:-staging temp test commit for nix build}"

undo_commits() {
  local repo="$1"
  local msg="$2"

  cd "$repo"

  last_good=$(git log --grep="$msg" --invert-grep --format="%H" -n 1)

  if [[ -z "$last_good" ]]; then
    echo "No commits matching '$msg' found in $repo"
    return
  fi

  echo "Rewriting $repo to remove commits matching '$msg'…"

  git reset --soft "$last_good"
  git reset --mixed "$last_good"

  echo "Done with $repo"
}

# --- Auto-discover submodules from flake.nix ---
cd "$owd"

mapfile -t inputs < <(grep -o 'git+file:[^"]*' flake.nix)

for input in "${inputs[@]}"; do
  # Remove prefix
  path_with_query="${input#git+file:}"

  # Extract path before '?'
  submodule_path="${path_with_query%%\?*}"

  # Normalize path
  submodule_path="${submodule_path#./}"

  full_path="$owd/$submodule_path"

  if [[ -d "$full_path/.git" ]]; then
    echo "Undoing commits in submodule: $submodule_path"
    undo_commits "$full_path" "$commit_msg"
  else
    echo "Skipping non-git directory: $full_path"
  fi
done

# Undo commits in parent repo last
undo_commits "$owd" "$commit_msg"

exit

#####

./unstage_nix_build.sh "stash_everything"
./unstage_nix_build.sh "staging temp test commit for nix build"
./unstage_nix_build.sh "staging temp test commit"

## What this script does

it removes only the *commits* with the message `"staging temp test commit for nix build"` and leaves all files exactly as they are now.**

The safest way to do that is to **rewrite history** inside each submodule and the parent repo, but **without touching the working tree**.  
That means: *files stay exactly as they are*, only the commit objects are removed.


### **1. Finds the last commit *before* your staging commits**
It searches for commits *not* matching your staging message:

```
git log --grep="$commit_msg" --invert-grep
```

### **2. Soft-resets to that commit**
This removes the staging commits from history but keeps all file changes staged.

### **3. Mixed-reset to the same commit**
This unstages everything but **keeps the working tree exactly as-is**.

### **4. Repeats for:**
- `pkgs/minimus`
- `pkgs/PIthon`
- the parent repo

---

