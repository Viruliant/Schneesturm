#!/usr/bin/env bash
utcupdate() { utc=$(date -u "+%Y.%m.%dT%H.%M.%SZ"); } #UTC Time (filename safe)
utcupdate
owd="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" #Path to THIS script.
set -euo pipefail

# ## Result
# 
# - All your temporary “staging temp test commit for nix build” commits disappear.
# - All your files remain exactly as they are now.
# - Your repo history is clean again.
# - No changes are lost.

# commit_msg="stash_everything"
commit_msg="staging temp test commit for nix build"

# commit_msg="staging temp test commit"

# Function: remove commits with the staging message, but keep working tree
undo_commits() {
  local repo="$1"
  cd "$repo"

  # Find the last commit *before* the staging commit
  last_good=$(git log --grep="$commit_msg" --invert-grep --format="%H" -n 1)

  if [[ -z "$last_good" ]]; then
    echo "No staging commits found in $repo"
    return
  fi

  echo "Rewriting $repo to remove staging commits…"

  # Reset to last good commit but keep working tree intact
  git reset --soft "$last_good"

  # Now drop the staging commit(s) from history
  git reset --mixed "$last_good"

  echo "Done with $repo"
}

# Undo commits in submodules
undo_commits "$owd/pkgs/minimus"
undo_commits "$owd/pkgs/PIthon"

# Undo commits in parent repo
undo_commits "$owd"

exit

#####

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

