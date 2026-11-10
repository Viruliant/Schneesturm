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
- PIthon holds one `uint8_t` per segment, as ASCII chars, in a
  `malloc(width * height)` array `snake_chars`.
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
  so 1599 digits need `ceil(1599 / 16) = 100` words (800 bytes),
  allocated for the call and freed straight after.

## 2. Code in `PIthon.c`

Include, next to `<CALLDeck.h>`:

```c
#include <PiChudnov.h>
```

The array lives in `GameState` beside `snake_world` and is sized from
the board constants, so it follows `width` / `height` automatically:

```c
uint8_t *snake_chars; // "3.14159..." one char per segment, head first
```

Fill function. `len` is the array length (1600); it asks for
`len - 1` digits and sizes the packed buffer with
`pichudnov_words_needed()`:

```c
int fill_snake_chars(uint8_t *chars, size_t len) {
    size_t digits = len - 1;
    size_t words = pichudnov_words_needed(10, digits);
    uint64_t *packed = malloc(words * sizeof *packed);
    if (!packed) return PICHUDNOV_ERR_INTERNAL;

    int rc = pichudnov_bs(10, digits, packed, words);
    if (rc == PICHUDNOV_OK) {
        // digit i goes to slot i + 1, leaving slot 0 free for the '3'
        for (size_t i = 0; i < digits; i++)
            chars[i + 1] = '0' + ((packed[i / 16] >> (60 - 4 * (i % 16))) & 0xF);
        chars[0] = chars[1];
        chars[1] = '.';
    }
    free(packed);
    return rc;
}
```

The shift is the README's general decode formula
`64 - bits * (i % dpw + 1)` with `bits = 4`, `dpw = 16` filled in.

It is called in `main()` **before** `initscr()`, so a failure prints a
normal error message and exits without touching ncurses:

```c
uint8_t *snake_chars = malloc(width * height);
if (!snake_chars || fill_snake_chars(snake_chars, width * height) != PICHUDNOV_OK) {
    fprintf(stderr, "PIthon: could not compute the digits of pi\n");
    return 1;
}
```

Start state — a 4-segment snake `3.14`. The head is at the centre and
the body extends to the right, with the start direction changed from
right to **left**, so the snake reads `3.14` left to right on screen:

```c
.snake_length = 4,
.direction_x = -1,
...
for (uint8_t i = 0; i < gs.snake_length; i++) {
    coord snake_seg = { width / 2 + i, height / 2 };
    pushEnd_CALLDECK_coord_255(&snake_seg, &gs.snake);
}
```

Drawing — one line changes in `update_world()`. The draw loop already
walks the snake from the head with index `i`:

```c
// before
gs->snake_world[snake_seg.y * width + snake_seg.x] = snakechar;
// after
gs->snake_world[snake_seg.y * width + snake_seg.x] = gs->snake_chars[i];
```

Nothing else needed to change:

- `snake_world` cells are compared only against `emptychar` (`' '`)
  and `applechar` (`'@'`). Digits and `.` collide with neither, so the
  empty-space scan and the red-apple rendering keep working.
- `i < snake_length <= 1600`, so `snake_chars[i]` stays in bounds.
- `DEFINE_CALLDECK(coord, 255)` is a linked list of 255-element
  chunks, not a 255 cap, so the deck already handles 1600 segments.
- `snakechar` was unused afterwards and is removed.

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

- Scratch program (`/tmp/opencode/snake/t.c`, outside the repo) using
  the same decode, built against `PiChudnov` rev `03bebd4`:
  `pichudnov_bs(10, 1599, …)` returns `PICHUDNOV_OK`, needs 100 words,
  the array starts `3.141592653589793238` and ends `…097777279380`,
  and the run takes about 2 ms.
- `./stage_nix_build.sh && nix build` succeeds with the PIthon changes.
- `ldd result/bin/PIthon` resolves `libpichudnov.so` from the
  PiChudnov store path.
- Running `result/bin/PIthon` in a 100x50 pseudo-terminal for about a
  second: the status line shows `Snake: 4  Dir:(-1,0)` and the first
  drawn frame has `3.14` on row 20.

Not checked: actual play — eating apples and seeing `1`, `5`, `9`, …
appear on the tail.

## 5. Things to watch

- **`stage_nix_build.sh` `rev=` fix.** The script stripped `./` from
  the path before its `sed`, so it searched for
  `git+file:pkgs/PIthon?…` while `flake.nix` contains
  `git+file:./pkgs/PIthon?…`; the `rev=` was not rewritten and
  `nix build` kept the old PIthon commit. The `sed` pattern now
  accepts an optional `./`.
- **`unstage_nix_build.sh` skips the submodules.** It tests
  `[[ -d "$full_path/.git" ]]`, but in a submodule `.git` is a file,
  so the temp commit inside `pkgs/PIthon` is not undone. Not changed.
- **Reading direction.** The head is `3`, so the text follows the
  snake's body: moving left it reads `3.1415` left to right, moving
  right it appears as `5141.3`.

## 6. Steps

1. [x] `PIthon.c`: include, `snake_chars` in `GameState`,
       `fill_snake_chars()` (§2).
2. [x] `PIthon.c`: fill before `initscr()`; 4-segment start heading
       left; draw `gs->snake_chars[i]`; remove `snakechar`.
3. [x] `package.nix`: `PiChudnov` argument, `buildInputs`, `-I`,
       `-L … -lpichudnov`, rpath (§3).
4. [x] `./stage_nix_build.sh && nix build`.
5. [ ] Play `./result/bin/PIthon`, eat a few apples, confirm the
       digits keep following from the head.
6. [ ] Ask: "Do you wish to run `./unstage_nix_build.sh` and prepare
       an actual commit?"

## Decisions

- Start with a 4-segment snake `3.14`.
- `malloc(width * height)` for `snake_chars`, in `GameState` beside
  `snake_world`.
