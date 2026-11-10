# snake — PIthon snake segments from PiChudnov digits

Goal: every snake segment in `pkgs/PIthon/PIthon.c` shows a character
of π instead of `#`. The head is `3`, the next segment is `.`, then
`1`, `4`, `1`, `5`, … so the snake reads `3.14159…` from head to tail.

The digits come from `pichudnov_bs()` in the `PiChudnov` package
(`libpichudnov.so` + `PiChudnov.h`), computed once at startup.

---

## 1. The numbers

- Board is `width * height = 40 * 40 = 1600` cells, so the snake can
  never be longer than **1600** segments.
- PIthon holds one `uint8_t` per segment, as ASCII chars:
  `uint8_t snake_chars[1600]`.
- One of those 1600 chars is the `.`, so we only ask PiChudnov for
  **1599** digits (the `3` plus 1598 digits after the point).
- The call returns `314159…` with no point. To get `3.14159…` we
  write the 1599 digits to the **end** of the array (`[1..1599]`),
  leaving `[0]` free, then move the `3` down and drop the `.` in its
  place:

```
after decode:   [0]=?   [1]='3' [2]='1' [3]='4' ... [1599]
fix up head:    [0]='3' [1]='.' [2]='1' [3]='4' ... [1599]
```

- Packed size: base 10 is 4 bits per digit, 16 digits per `uint64_t`,
  so 1599 digits need `ceil(1599 / 16) = 100` words (800 bytes). Small
  enough for a local array; no `malloc`.

## 2. Code in `PIthon.c`

Include, next to `<CALLDeck.h>`:

```c
#include <PiChudnov.h>
```

Constants and the array, next to the other game constants. `width` and
`height` are `const uint8_t`, which C99 does not accept as an array
size at file scope, hence the `#define`:

```c
#define SNAKE_MAX 1600                    // must equal width * height
#define PI_DIGITS (SNAKE_MAX - 1)         // 1599: one slot is the '.'
#define PI_WORDS  ((PI_DIGITS + 15) / 16) // 100 words, 16 digits each

uint8_t snake_chars[SNAKE_MAX];
```

Fill function:

```c
int fill_snake_chars(void) {
    uint64_t packed[PI_WORDS];
    int rc = pichudnov_bs(10, PI_DIGITS, packed, PI_WORDS);
    if (rc != PICHUDNOV_OK) return rc;

    // digit i goes to slot i + 1, leaving slot 0 free
    for (size_t i = 0; i < PI_DIGITS; i++)
        snake_chars[i + 1] = '0' + ((packed[i / 16] >> (60 - 4 * (i % 16))) & 0xF);

    snake_chars[0] = snake_chars[1]; // the '3'
    snake_chars[1] = '.';
    return PICHUDNOV_OK;
}
```

The shift is the README's general decode formula
`64 - bits * (i % dpw + 1)` with `bits = 4`, `dpw = 16` filled in.

Call it in `main()` **before** `initscr()`, so a failure can print a
normal error message and exit without touching ncurses:

```c
assert(width * height == SNAKE_MAX);
if (fill_snake_chars() != PICHUDNOV_OK) {
    fprintf(stderr, "PiChudnov failed\n");
    return 1;
}
```

Drawing — one line changes in `update_world()`. The draw loop already
walks the snake from the head with index `i`:

```c
// before
gs->snake_world[snake_seg.y * width + snake_seg.x] = snakechar;
// after
gs->snake_world[snake_seg.y * width + snake_seg.x] = snake_chars[i];
```

Nothing else needs to change:

- `snake_world` cells are compared only against `emptychar` (`' '`)
  and `applechar` (`'@'`). Digits and `.` collide with neither, so the
  empty-space scan and the red-apple rendering keep working.
- `i < snake_length <= 1600`, so `snake_chars[i]` stays in bounds.
- `DEFINE_CALLDECK(coord, 255)` is a linked list of 255-element
  chunks, not a 255 cap, so the deck already handles 1600 segments.
- `snakechar` becomes unused and can be removed.

## 3. `pkgs/PIthon/package.nix`

```nix
{ lib, stdenv, makeheaders, minimus, ncurses, PiChudnov }:

  buildInputs = [ minimus ncurses PiChudnov ];
```

PIthon compile line — add the include path and the library:

```
$CC -m64 -O2 -std=gnu99 -Wno-error=return-mismatch \
    -I${minimus}/include -I${ncurses}/include -I${PiChudnov}/include \
    -include annexb.h -include NuClear.h PIthon.c \
    -L${minimus}/lib -lNuClear -lncurses \
    -L${PiChudnov}/lib -lpichudnov -o PIthon
```

`preFixup` — add the lib dir to the rpath so `libpichudnov.so` is
found at runtime:

```
patchelf --set-rpath "${minimus}/lib:${ncurses}/lib:${PiChudnov}/lib" $out/bin/PIthon
```

`PiChudnov` resolves as a `callPackage` argument because the overlay
in `flake.nix` puts every local package at the top level of `final`.
No `flake.nix` change is needed for that.

## 4. Checked so far

A scratch program (`/tmp/opencode/snake/t.c`, outside the repo) with
exactly the `fill_snake_chars()` above, built against the current
`./result` (`PiChudnov` rev `03bebd4`):

- `pichudnov_bs(10, 1599, …)` returns `PICHUDNOV_OK`;
  `pichudnov_words_needed(10, 1599)` is 100, matching `PI_WORDS`.
- The array starts `3.141592653589793238` and ends `…097777279380`.
- The whole run takes about 2 ms, so computing at startup is fine.

Not done yet: no change has been made to `PIthon.c` or its
`package.nix`, and nothing has been through `nix build`.

## 5. Things to watch

- **`stage_nix_build.sh` and the PIthon `rev=`.** The script strips
  `./` from the path before its `sed`, so it searches for
  `git+file:pkgs/PIthon?…` while `flake.nix` contains
  `git+file:./pkgs/PIthon?…`. From reading the script, the `rev=`
  will not be rewritten, and `nix build` would keep building the old
  PIthon commit. If the build output does not show the new digits,
  check the `rev=` in `flake.nix` against
  `git -C pkgs/PIthon rev-parse HEAD` first.
- **Reading direction.** The head is `3`, so the text follows the
  snake's body: moving left it reads `3.1415` left to right, moving
  right it appears as `5141.3`.
- **Start length is 1**, so the game opens with a lone `3`; the `.`,
  `1` and `4` appear after the first three apples.

## 6. Steps (in order)

1. [ ] `PIthon.c`: add the include, `SNAKE_MAX` / `PI_DIGITS` /
       `PI_WORDS`, `snake_chars`, `fill_snake_chars()` (§2).
2. [ ] `PIthon.c`: call it before `initscr()`; draw `snake_chars[i]`;
       remove `snakechar`.
3. [ ] `package.nix`: `PiChudnov` argument, `buildInputs`, `-I`,
       `-L … -lpichudnov`, rpath (§3).
4. [ ] `./stage_nix_build.sh && nix build` (see §5 about `rev=`).
5. [ ] Run `./result/bin/PIthon`, eat a few apples, confirm
       `3.14…` from the head.
6. [ ] Ask: "Do you wish to run `./unstage_nix_build.sh` and prepare
       an actual commit?"

## Open questions

- Start with a 4-segment snake so `3.14` is visible immediately, or
  keep the start length at 1 and grow into it?
- Fixed `#define SNAKE_MAX 1600` (as above), or `malloc(width *
  height)` in `GameState` beside `snake_world` so the size follows
  the board constants automatically?
