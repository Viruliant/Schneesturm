
```bash
mkdir ~/test_dir
cd ~/test_dir
git clone https://github.com/Viruliant/Bnix.git

# build the regular package:
cd ~/test_dir/Bnix
nix build .#default

# enter environment made by flake
nix develop

# run a example default.nix managed program depending on mk-configure
calc <<< '( 1 + 1 )'

```

view files built with `tree ./result | sed 's/ -> .*//'`

## build all of the tests

We can Executes/Runs all Tests/Checks defined under the 
checks.<system> attribute in your `flake.nix` from

[examples dir in mk-configure](https://github.com/Viruliant/mk-configure/tree/master/examples)

with the following command:

```bash
nix flake check -L
```

It also verifies that a Nix flake is valid and correctly 
formatted, while building and testing all its defined outputs 
with verbose logging. 

---

Here's the markdown version of the Presentation.pdf:

---

# MK‑CONFIGURE (MK‑C)  
### Lightweight, easy‑to‑use alternative to GNU Autotools  
**Aleksey Cheusov — vle@gmx.net**  
*Minsk, Belarus, 2012*

---

## About this presentation
- Part of the official documentation  
- Latest version: **`http://mova.org/~cheusov/pub/mk-c/mk-c.pdf` [(mova.org in Bing)](https://www.bing.com/search?q="http%3A%2F%2Fmova.org%2F~cheusov%2Fpub%2Fmk-c%2Fmk-c.pdf")**
- Part 1: Introduction  
- Part 2: Usage samples  
- Part 3: Features, TODO, more

---

## Concepts behind mk‑configure

### Design principles and goals
- **I detest code generation** as in Autotools and CMake — MK‑C uses a **library approach** instead.
- Written in **bmake** (portable NetBSD make) + UNIX tools.  
  No Python, Ruby, Perl.  
  **bmake + sh is good enough**.
- Principles similar to **bsd.\*.mk** files.
- **Portable** across UNIX‑like systems.
- **KISS** — ~4000 lines of code.

### More goals
- Useful for end‑users, packagers, and **developers**.
- Declarative Makefiles using special variables + bmake includes.
- **Cross‑compilation** support.
- **Extensible** via bmake includes + shell/awk/sed/grep.
- **Easy to use** — one command: `mkcmake`.  
  Only Makefiles required.

### Negative side‑effects
- End‑users must install **bmake** and **mk‑configure**.

---

# Example 1 — Hello World

### Makefile
```make
PROG = hello
.include <mkc.prog.mk>
```

### hello.c
```c
#include <stdio.h>

int main (int, char **)
{
   puts("Hello World!");
   return 0;
}
```

### How it works
```sh
$ export PREFIX=/usr SYSCONFDIR=/etc
$ mkcmake
checking for compiler type... gcc
checking for program cc... /usr/bin/cc
cc -c hello.c
cc -o hello hello.o

$ ./hello
Hello World!

$ DESTDIR=/tmp/fakeroot mkcmake install
install -c -s -o cheusov -g users -m 755 hello /tmp/fakeroot/usr/bin/hello
```

Supported targets: `all`, `clean`, `cleandir`, `install`, `uninstall`, `installdirs`, `depend`, etc.

---

# Example 2 — Using non‑standard `strlcpy(3)`

### Directory contents
```sh
$ ls -l
Makefile
main.c
strlcpy.c
```

### Makefile
```make
PROG = strlcpy_test
SRCS = main.c

MKC_SOURCE_FUNCLIBS = strlcpy
MKC_CHECK_FUNCS3 = strlcpy:string.h

.include <mkc.prog.mk>
```

### main.c
```c
#include <string.h>

#ifndef HAVE_FUNC3_STRLCPY_STRING_H
size_t strlcpy(char *dst, const char *src, size_t siz);
#endif

int main(int argc, char** argv)
{
    /* Use strlcpy(3) here */
    return 0;
}
```

### Linux build
```sh
$ CC=icc mkcmake
checking for compiler type... icc
checking for function strlcpy... no
checking for func strlcpy (string.h)... no
icc -c main.c
icc -c strlcpy.c
icc -o strlcpy_test main.o strlcpy.o
```

### NetBSD build
```sh
$ mkcmake
checking for function strlcpy... yes
checking for func strlcpy (string.h)... yes
cc -DHAVE_FUNC3_STRLCPY_STRING_H=1 -c main.c
cc -o strlcpy_test main.o
```

---

# Example 3 — Plugins via `dlopen`

### Makefile
```make
PROG = myapp
MKC_CHECK_FUNCLIBS = dlopen:dl

.include <mkc.configure.mk>

.if ${HAVE_FUNCLIB.dlopen:U0} || ${HAVE_FUNCLIB.dlopen.dl:U0}
CFLAGS += -DPLUGINS_ENABLED=1
.endif

.include <mkc.prog.mk>
```

### QNX
```sh
checking for function dlopen (-ldl)... yes
checking for function dlopen... no
gcc -DPLUGINS_ENABLED=1 -c myapp.c
gcc -o myapp myapp.o -ldl
```

### OpenBSD
```sh
checking for function dlopen (-ldl)... no
checking for function dlopen... yes
gcc -DPLUGINS_ENABLED=1 -c myapp.c
gcc -o myapp myapp.o
```

---

# Example 4 — Shared libraries & C++

### Makefile
```make
LIB = foobar
SRCS = foo.cc bar.cc baz.cc

MKPICLIB ?= no
MKSTATICLIB ?= no

SHLIB_MAJOR = 1
SHLIB_MINOR = 0

.include <mkc.lib.mk>
```

### Solaris (SunStudio)
```sh
CC -c -KPIC foo.cc
CC -c -KPIC bar.cc
CC -c -KPIC baz.cc
CC -G -h libfoobar.so.1 -o libfoobar.so.1.0 foo.os bar.os baz.os
```

### Darwin (macOS)
```sh
c++ -c -fPIC -DPIC foo.cc
c++ -dynamiclib -install_name /usr/local/lib/libfoobar.1.0.dylib \
    -current_version 2.0 -compatibility_version 2 \
    -o libfoobar.1.0.dylib foo.os bar.os baz.os
```

---

# Example 5 — Multi‑subproject build

### Directory layout
```
dict/
dictd/
dictfmt/
dictzip/
doc/
libcommon/
libdz/
libmaa/
Makefile
```

### Top‑level Makefile
```make
SUBPRJ = libcommon:dict
SUBPRJ += libcommon:dictd
SUBPRJ += libcommon:dictzip
SUBPRJ += libcommon:dictfmt
SUBPRJ += libmaa:dict
SUBPRJ += libmaa:dictd
SUBPRJ += libmaa:dictfmt
SUBPRJ += libmaa:dictzip
SUBPRJ += libdz:dictzip
SUBPRJ += doc

.include <mkc.subprj.mk>
```

### Failure example (missing zlib)
```sh
ERROR: cannot find header zlib.h
ERROR: cannot find function deflate:z
```

### Successful build
```sh
cc -I../libcommon -I../libdz -I../libmaa -c dictzip.c
cc -L... -o dictzip dictzip.o -lcommon -lmaa -ldz
```

---

# Example 6 — Lua support

### Makefile
```make
SCRIPTS = foobar
LUA_LMODULES = foo bar
LUA_CMODULE = baz

.include <mkc.lib.mk>
```

### Build
```sh
checking for pkg-config lua... yes
checking for header lua.h... yes
cc -DHAVE_HEADER_LUA_H=1 -I/usr/pkg/include -c -fPIC baz.c
cc -shared -o baz.so baz.os -llua -lm
```

### Install
```
/usr/pkg/bin/foobar
/usr/pkg/lib/lua/5.1/baz.so
/usr/pkg/share/lua/5.1/foo.lua
/usr/pkg/share/lua/5.1/bar.lua
```

---

# Example 7 — Custom tests & sizeof

### Makefile
```make
MKC_CUSTOM_DIR = ${.CURDIR}/checks
M4 ?= m4
MKC_REQUIRE_CUSTOM += m4P
MKC_CUSTOM_FN.m4P = m4P.sh
.export: M4

MKC_REQUIRE_CUSTOM += constructor destructor
MKC_CHECK_SIZEOF = char short int long void* long-long

LIB = mylib
CFLAGS += -DM4_CMD='"${M4}"'
.include <mkc.lib.mk>
```

### Custom test script
```sh
m4_define(fruit, apple)
fruit
```

### FreeBSD result
```
checking for custom test m4P... 0 (no)
ERROR: custom test m4P failed
```

### With GNU m4
```
checking for custom test m4P... 1 (yes)
```

---

# Example 8 — Portable AWK

Includes checks for:
- `__fpurge`
- `fpurge`
- `isblank`
- `strlcat`

Builds portable AWK with fallback implementations.

---

# Example 9 — Cross‑compilation

```sh
export SYSROOT=/tmp/destdir.sparc64
export TOOLCHAIN_PREFIX=sparc64--netbsd-
export TOOLCHAIN_DIR=/tmp/tooldir.sparc64/bin

$ mkcmake
sparc64--netbsd-gcc --sysroot=/tmp/destdir.sparc64 -c hello.c
sparc64--netbsd-gcc --sysroot=/tmp/destdir.sparc64 -o hello hello.o
```

Result:
```
hello: ELF 64-bit MSB executable, SPARC V9, NetBSD 5.99.56
```

---

# Features

### Automatic OS feature detection
- Headers  
- Function declarations  
- Types  
- Struct members  
- Variables  
- Defines  
- Type sizes  
- Library functions  
- Programs  
- Custom checks  
- Built‑in checks (endianness, flex, bison, gawk, gm4)

### Build system features
- Programs, static/shared/dynamic libraries  
- C, C++, Objective‑C  
- Many OSes: NetBSD, FreeBSD, OpenBSD, DragonFlyBSD, Linux, Solaris, Darwin, Interix, Tru64, QNX, HP‑UX, Cygwin  
- Many compilers: GCC, Intel, pcc, DEC, HP, SunStudio, etc.

### Additional features
- Man/info/POD handling  
- Script installation  
- `.in` file substitution  
- Cross‑compilation  
- pkg‑config  
- Lua  
- yacc/lex  
- Multi‑subproject builds  
- Archive/package creation (`tar`, `zip`, `deb`)  
- Standalone tools: `mkc_install`, `mkc_check_header`, etc.

---

# MK‑CONFIGURE in the real world

### Packaged in:
- FreeBSD, pkgsrc  
- Gentoo, Fedora, AltLinux  
- Debian/Ubuntu

### Used by:
- lmdbg  
- nbawk  
- runawk  
- paexec  
- distbb  
- pkg_online  
- Any project using traditional BSD mk files

---

# MK‑C needs your help
- Packagers welcome  
- Needs shell accounts on exotic UNIX systems  
- Documentation review  
- Mailing lists: `mk-configure-help`, `mk-configure-discuss`  
- TODO file full of tasks
