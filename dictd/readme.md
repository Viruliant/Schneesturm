# dictd (mk-configure multi-subproject example)

This directory builds **dict**, **dictd**, **dictfmt** and **dictzip** from
[`examples/dictd`](https://github.com/Viruliant/mk-configure/tree/master/examples/dictd)
of the mk-configure repo, as a standalone Nix package.

## What it is

`examples/dictd` is the *multi-subproject build* sample that mk-configure's
presentation calls "Example 5". Its top-level `Makefile` wires together three
internal libraries and four programs with `mkc.subprj.mk`:

```make
LIBDEPS  = libcommon:dict   libcommon:dictd   libcommon:dictfmt   libcommon:dictzip
LIBDEPS += libmaa:dict      libmaa:dictd      libmaa:dictfmt      libmaa:dictzip
LIBDEPS += libdz:dictzip
INTERNALLIBS += libcommon
SUBPRJ_DFLT = dict dictd dictzip dictfmt
```

- `libcommon` – static internal library (`str.c`, `iswalnum.c`)
- `libmaa` – small library (`log.c`, `prime.c`, `set.c`, …) built static + shared
- `libdz` – DICT .dz compression library, requires **zlib** (`zlib.h`, `deflate:z`)
- `doc` – a subproject that is *not* built by default

## The point

The **programs are intentionally fake** – `dict.c` just prints `fake1..fake6`
from the shared libs, and the man pages say "is just a fake application". Their
whole job is to demonstrate how a real multi-component C project is declared and
built with mk-configure (dependency graph, internal libs, subproject targets like
`all-dict`, `install-dict`, `nodeps-cleandir-dictfmt`). The regression harness in
`test.mk` exercises all of it.

For a *real* DICT (RFC 2229) client/server implementation, see
[cheusov/dictd](https://github.com/cheusov/dictd).

## Building

```bash
nix build .#dictd --no-link
```

`dictd/default.nix` fetches the mk-configure repo, roots the build tree at
`examples/dictd` via `sourceRoot`, then drives the build with our own
`mk-configure` package:

```bash
mkcmake configure PREFIX=$out
mkcmake all
mkcmake install PREFIX=$out
```

Result: `bin/dict`, `bin/dictd`, `bin/dictfmt`, `bin/dictzip` (+ man pages).

## Using it

The binaries are self-contained examples:

```bash
./result/bin/dict
./result/bin/dictd
./result/bin/dictfmt
./result/bin/dictzip
```

## Status

**Working.** `nix build .#dictd` builds all four programs plus man pages, and
`nix flake check -L` passes.

- `dictd` is wired into `flake.nix` (overlay + `packages.dictd`).
- The install-side `mkc_install` bug was fixed with an `INSTALL` shim in
  `default.nix`: mkc's install rules emit `-o -g ...` with an empty owner, and
  `mkc_install`'s `getopts` mis-parses that ("Last argument ... is not a
  directory"). The shim drops empty `-o` / `-g` options before delegating to
  the real `mkc_install`. (Same wrapper used by `calc2`.)
- RPATH is correct: the shared `libmaa` / `libdz` resolve to the package's own
  `lib/`.
