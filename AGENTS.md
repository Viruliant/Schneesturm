# AGENTS.md

Nix flake monorepo that packages `mk-configure` (bmake-based build system) and its dependencies/examples. Each package is a `callPackage`-style derivation in a subdir with its own `default.nix`; there is no `pkgs/` overlay directory, `flake.nix` wires everything through `nixpkgs.legacyPackages.${system}.extend`.

## Commands

```bash
nix build .#default                 # symlinkJoin of mk-configure + bmkdep + calc2
nix build .#mk-configure .#bmkdep .#dictd .#calc2
nix flake check -L                  # runs checks.<system> derivations (examples suite + calc2 test); slow, full rebuild each time
nix develop                         # devShell: calc2, mk-configure, bmake, bmkdep
```

## Layout

- `mk-configure/`, `bmkdep/`, `dictd/`, `calc2/` — each holds a `default.nix`; `mk-configure/` and `calc2/` also hold a `tests.nix` (wired via `passthru.tests = callPackage ./tests.nix { inherit finalAttrs; }`) and `mk-configure/` holds `mk-configure-libdeps.patch`.
- `dictd/` and `calc2/` do **not** build local sources: they fetch the mk-configure repo from GitHub, set `sourceRoot` to `examples/dictd` / `examples/calc2`, and drive the build with the just-built `mk-configure` package (`mkcmake configure/all/install PREFIX=$out`).
- `readme.md` is mostly a markdown transcription of the mk-configure presentation; the real usage is the first ~30 lines. `dictd/readme.md` explains the multi-subproject example in detail.

## Gotchas

- **`Monolithicflake.nix` is stale and unused** — the active flake is `flake.nix` (confirmed by `nix flake metadata`). Do not edit it or port logic from it; its mk-configure lacks the texlive/graphviz/ghostscript build, the libdeps patch, and the test wiring. The commented-out `enable_runTests` toggle in `flake.nix` is also dead.
- **Shared version pin**: `mk-configure`, `dictd`, and `calc2` all fetch `Viruliant/mk-configure` at the same `rev` (`55a5ce31...` currently). Bumping one usually means bumping all three, plus updating each `sha256` (use `nix-prefetch-github Viruliant mk-configure --rev <rev>`, per the comment in `mk-configure/default.nix`). `bmkdep/` fetches a different repo and rev.
- **nixpkgs is pinned** to a specific rev via `nixos-version --json | jq -r '.nixpkgsRevision'`; `flake.nix` has a commented recipe for updating it.
- **No `.gitignore` / no CI** — the `result` symlink is untracked. There is no lint/test framework beyond `nix flake check`.

## Build quirks (mk-configure/default.nix)

- The custom `configurePhase` bootstraps mkc helpers into `.bootstrap-bin`: compiles `mk/mkc_check_*.c` with gcc, writes a hand-rolled `mkc_check_prog` shim, copies `scripts/*`, then runs `bmake configure ... "mkc.environ=CC=gcc CXX=g++ PATH=$BPATH"`. `PATH` must include the bootstrap dir, `bmake`, and `bmkdep` (its `mkdep` alias is expected).
- `installPhase` is fully custom and does several things post-install: `bmake install-examples/helpers`, a manual `install` of `mkc_test_helper3` (upstream `SCRIPTS` bug: it's listed twice so it never ships), a `sed` fix to `mkc_test_helper` for the bmake ≥ 20260313 `.error` format change, and builds+installs `presentation.pdf` (needs texlive `relsize`, graphviz, ghostscript in `nativeBuildInputs`). It ends with `cd presentation`, so **`checkPhase` captures the source root into `MK_ROOT`** and any `installCheckPhase` must not rely on `$PWD`.
- Man-page relocation (`$out/man` → `$out/share/man/man{1,7}`) lives in `postInstall`, which also redundantly reruns `bmake configure`. Don't "clean up" by moving man-page handling into the custom `installPhase` blindly — the custom phase bypasses `postInstall` ordering; verify `nix build .#mk-configure` and `nix flake check -L` still pass.
- `mk-configure-libdeps.patch` exists because in the nix build the source tree is `/build/source`, so `examples/libdeps/test.mk`'s awk filter on the literal substring `mk-configure` strips legitimate cross-dir `-I` headers. The patch keys the filter on `${.CURDIR}` instead. If upstream's `test.mk` changes, this patch likely breaks.

## Test quirks

- `mk-configure/tests.nix` uses `testers.runCommand`, which is a **fixed-output derivation**: `$out` must be an empty file (`touch $out`), and the test log goes to `$TMPDIR/test-output/log` (kept there because `$out` is content-hashed). It unpacks `finalAttrs.src` (the full GitHub fetch, examples/ included), applies the libdeps patch, then runs the entire `mkcmake -f MKCmakefile test` suite from `examples/` against the installed mk-configure, with a `fakePkgConfig` shim on PATH (mkc examples hardcode `/usr/local` lua paths). `testInputs` (texlive, groff, bison, flex, perl, gawk, glib.dev, texinfo, zlib, ...) are intentionally only in the test, not the build.
- `calc2/tests.nix` pipes `examples/calc2/expressions.txt` into the installed `calc` and diffs against the first section of `expect.out` (everything before the `====` banner).
- Run everything with `nix flake check -L`; there is no way to run a single suite faster — it always builds the full package.

## dictd & calc2 shared quirks

- Both embed the same `INSTALL` shim: mkc install rules emit empty `-o`/`-g` owner args and `mkc_install`'s getopts mis-parses them ("Last argument is not a directory"). The shim drops empty owner options before delegating. **If you fix it, update both files**.
- Both set `HOME="$TMPDIR"` and `MKCOMPILERSETTINGS=yes` in `configurePhase`. `calc2` additionally needs `flex` and `bison` in `nativeBuildInputs`.
