
# Schneesturm

example set of `package.nix` packages interacting inside a flake the same way they would if they were inside of nixpkgs.

## Commands

`nix run github:Viruliant/Schneesturm` will "just work"

but if you run the following commands it will "just work" faster
because `Lock2LocalPkgs.sh` will set the flake.lock to your
system packages, and cause less downloading and building.

```bash
# checkout and run with
git clone https://github.com/Viruliant/Schneesturm.git ~/Schneesturm
cd ~/Schneesturm
# sets flake.lock to match system nixpkgs
./Lock2LocalPkgs.sh
# run with # opens the report in the default browser (via `meta.mainProgram`)
nix build && nix develop

./result/bin/PIthon 

```
