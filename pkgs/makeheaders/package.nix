#################################################################
# `pkgs.callPackage` convention for `package.nix` files

# a Nix expression that exports a `pure` = reproducible function, 
# used to create a derivation.
# (unless there are non-relative paths)

# That function’s parameters are the package’s dependencies  
# `pkgs.callPackage` fills dependencies in automatically
#################################################################
# official mkDerivation attrs:
  # https://nix.dev/tutorials/callpackage.html
  # https://nixos.org/manual/nixpkgs/stable/#sec-stdenv-phases
  # https://nixos.org/manual/nixpkgs/stable/#var-stdenv-phases
# Default Phase order: 1 unpack, 2 patch, 3 configure, 4 build,
# 5 check, 6 install, 7 fixup, 8 installCheck, 9 dist
# where {$var} is the phase name there is a 
# `pre{$var}`, `{$var}Phase`, and `post{$var}` for each phase
#################################################################

{ lib, stdenv, mawk }:

stdenv.mkDerivation (rec {
  pname = "makeheaders";
  version = "325f0576c453cfdf7d35cfc03a8aceb249f76cc9";

  src = builtins.fetchurl {
    url = "https://raw.githubusercontent.com/Viruliant/fossil-mirror/${version}/tools/makeheaders.c";
    sha256 = "1mr09x1pwqv7g0ifhz4nfi4mc9z6pygf0p4jhmihv6xs1w0p81py";
  };

  unpackPhase = ''
    cp $src makeheaders.c
  '';

  nativeBuildInputs = [ stdenv.cc mawk ];

  buildPhase = ''
    $CC -O2 -std=gnu99 makeheaders.c -o makeheaders
  '';

  # `filter-makeheaders` — a makeheaders wrapper that can see through
  # macros (e.g. DEFINE_LLDECK) invoked inside `#if INTERFACE` blocks.
  #
  # Pipeline (per input .c):
  #   1. annotate_interface.awk — wrap #if INTERFACE/#endif with
  #      /*@MH_IF@*/ /*@MH_ENDIF@*/ sentinel comments in a throwaway copy
  #      (cpp eats the directives themselves; comments survive `gcc -E -C`)
  #   2. gcc -E -C -D INTERFACE=1 — expand macros (INTERFACE true for cpp
  #      only; INTERFACE is 0/undefined for every real compilation)
  #   3. linemarker filter — keep only lines originating from the target .c
  #   4. restore literal #if/#endif from the sentinel comments
  #   5. strip_bodies.awk — replace macro-expanded function bodies with ';'
  #      so makeheaders parses pure declarations (it emits prototypes)
  #   6. makeheaders -local -h — write <base>.h
  #
  # usage: filter-makeheaders [-I<dir>]... ./pkgs/PIthon/FileIO.c
  installPhase = ''
    mkdir -p $out/bin $out/share/makeheaders
    install -Dm755 makeheaders $out/bin/makeheaders

    cat > $out/share/makeheaders/annotate_interface.awk <<'AWK_EOF'
# annotate_interface.awk
# Wraps #if INTERFACE / LOCAL_INTERFACE / EXPORT_INTERFACE blocks with
# sentinel comments that survive `gcc -E -C`, so the literal #if/#endif
# (which cpp always eats) can be restored afterward for makeheaders.
function strip_comment(s) {
    sub(/\/\/.*/, "", s); sub(/\/\*.*\*\//, "", s)
    gsub(/^[ \t]+/, "", s); gsub(/[ \t]+$/, "", s)
    return s
}
function directive_word(s,    w) {
    if (match(s, /^#[ \t]*[A-Za-z_]+/)) {
        w = substr(s, RSTART, RLENGTH); sub(/^#[ \t]*/, "", w); return w
    }
    return ""
}
{
    line = $0; trimmed = line; sub(/^[ \t]*/, "", trimmed)
    kw = directive_word(trimmed)

    if (kw == "if" || kw == "ifdef" || kw == "ifndef") {
        depth++
        cond = trimmed
        sub(/^#[ \t]*/, "", cond); sub(/^[A-Za-z_]+[ \t]*/, "", cond)
        cond = strip_comment(cond)
        if (cond == "INTERFACE" || cond == "LOCAL_INTERFACE" || cond == "EXPORT_INTERFACE") {
            tag[depth] = cond
            print line; print "/*@MH_IF:" cond "@*/"; next
        }
        print line; next
    }
    if (kw == "endif") {
        if (depth in tag) { print "/*@MH_ENDIF:" tag[depth] "@*/"; delete tag[depth] }
        depth--
        print line; next
    }
    print line
}
AWK_EOF

    cat > $out/share/makeheaders/strip_bodies.awk <<'AWK_EOF'
# strip_bodies.awk - inside #if INTERFACE..#endif regions, replace function
# bodies with ';' so makeheaders sees only declarations (makeheaders emits
# prototypes, never bodies). Struct/union/enum bodies are kept.
/^#define/ { print; next }
/^#if[ \t]+INTERFACE([ \t].*)?$/ { iface++; print; next }
/^#endif/ { if (iface > 0) iface--; print; next }
{
    line = $0
    if (iface == 0) { print; next }
    out = ""
    n = length(line)
    i = 1
    while (i <= n) {
        c = substr(line, i, 1)
        if (drop > 0) {                      # inside a dropped function body
            if (c == "{") drop++
            else if (c == "}") {
                drop--
                if (drop == 0) { out = out ";"; lasttok = ";" }
            }
            i++
            continue
        }
        if (c == "{") {
            if (lasttok == ")") { drop = 1 } # function body -> drop it
            else {
                out = out c                  # struct/union/enum body -> keep
                brdepth++
                lasttok = "{"
            }
            i++
            continue
        }
        if (c == "}") {
            out = out c
            if (brdepth > 0) brdepth--
            lasttok = "}"
            i++
            continue
        }
        if (c != " " && c != "\t") lasttok = c
        out = out c
        i++
    }
    print out
}
AWK_EOF

    cat > $out/bin/filter-makeheaders <<'SH_EOF'
#!/usr/bin/env bash
set -eu

# filter-makeheaders — preprocess .c through gcc -E -C -D INTERFACE=1,
# filter linemarkers, restore #if INTERFACE/#endif from sentinel comments,
# strip function bodies inside INTERFACE blocks, then run makeheaders.
#
# Usage: filter-makeheaders [-I<dir>]... [-D<name>=<val>]... <file.c>
#
# Generates <file>.h alongside the source.

MH="''${MAKEHEADERS:-makeheaders}"
MAWK="''${MAWK:-mawk}"
CC="''${CC:-gcc}"

# ---- parse args ----
cppflags=()
infile=
while [ "$#" -gt 0 ]; do
    case "$1" in
        -I*|-D*|-U*) cppflags+=("$1"); shift ;;
        --) shift; break ;;
        *)
            if [ -z "$infile" ]; then
                infile="$1"
            fi
            shift
            ;;
    esac
done

if [ -z "$infile" ]; then
    echo "Usage: $0 [-I<dir>]... [-D<name>=<val>]... <file.c>"
    exit 1
fi

base="''${infile%.c}"
header="''${base}.h"
full="''${base}.full.c"
filtered="''${base}.filtered.c"
annotated="''${base}.mh.c"

# ---- annotate_interface.awk (inline) ----
annotate_interface() {
    "$MAWK" '
function strip_comment(s) {
    sub(/\/\/.*/, "", s); sub(/\/\*.*\*\//, "", s)
    gsub(/^[ \t]+/, "", s); gsub(/[ \t]+$/, "", s)
    return s
}
function directive_word(s,    w) {
    if (match(s, /^#[ \t]*[A-Za-z_]+/)) {
        w = substr(s, RSTART, RLENGTH); sub(/^#[ \t]*/, "", w); return w
    }
    return ""
}
{
    line = $0; trimmed = line; sub(/^[ \t]*/, "", trimmed)
    kw = directive_word(trimmed)

    if (kw == "if" || kw == "ifdef" || kw == "ifndef") {
        depth++
        cond = trimmed
        sub(/^#[ \t]*/, "", cond); sub(/^[A-Za-z_]+[ \t]*/, "", cond)
        cond = strip_comment(cond)
        if (cond == "INTERFACE" || cond == "LOCAL_INTERFACE" || cond == "EXPORT_INTERFACE") {
            tag[depth] = cond
            print "#undef INTERFACE"; print "#define INTERFACE 1"
            print line; print "/*@MH_IF:" cond "@*/"; next
        }
        print line; next
    }
    if (kw == "endif") {
        if (depth in tag) { print "/*@MH_ENDIF:" tag[depth] "@*/"; delete tag[depth] }
        depth--
        print line; next
    }
    print line
}
'
}

# ---- strip_bodies.awk (inline) ----
strip_bodies() {
    "$MAWK" '
/^#define/ { print; next }
/^#if[ \t]+INTERFACE([ \t].*)?$/ { iface++; print; next }
/^#endif/ { if (iface > 0) iface--; print; next }
{
    line = $0
    if (iface == 0) { print; next }
    out = ""
    n = length(line)
    i = 1
    while (i <= n) {
        c = substr(line, i, 1)
        if (drop > 0) {
            if (c == "{") drop++
            else if (c == "}") {
                drop--
                if (drop == 0) { out = out ";"; lasttok = ";" }
            }
            i++
            continue
        }
        if (c == "{") {
            if (lasttok == ")") { drop = 1 }
            else {
                out = out c
                brdepth++
                lasttok = "{"
            }
            i++
            continue
        }
        if (c == "}") {
            out = out c
            if (brdepth > 0) brdepth--
            lasttok = "}"
            i++
            continue
        }
        if (c != " " && c != "\t") lasttok = c
        out = out c
        i++
    }
    print out
}
'
}

# ---- step 1: annotate interface blocks ----
rm -f "$full" "$filtered" "$annotated"
# Touch the header so preprocessor can find it (the .c includes its own header)
touch "$header"
annotate_interface < "$infile" > "$annotated"

# ---- step 2: preprocess with INTERFACE=1 for cpp ----
# -dD keeps #define directives in the output (otherwise cpp consumes them as
# it applies the macro and they vanish from the preprocessed form, losing the
# DEFINE_* / inline-macro source that makeheaders must re-emit into the .h).
"$CC" -E -C -dD -D INTERFACE=1 "''${cppflags[@]}" "$annotated" -o "$full"
rm -f "$annotated"

# ---- step 3: fix linemarkers to original filename ----
sed -i "s|$(basename "''${base}.mh.c")|$(basename "$infile")|g" "$full"

# ---- step 4: filter to original file lines only ----
awk -v target="$(basename "$infile")" '
    function base(path, n, arr) { n = split(path, arr, "/"); return arr[n] }
    /^# [0-9]+ / {
        n = split($0, parts, "\"")
        keep = (base(parts[2]) == target)
        next
    }
    keep { print }
' "$full" > "$filtered"

# ---- step 5: restore #if/#endif from sentinel comments ----
sed -E \
    -e 's|/\*[[:space:]]*@MH_IF:([A-Za-z0-9_]+)@[[:space:]]*\*/|#if \1|g' \
    -e 's|/\*[[:space:]]*@MH_IF@[[:space:]]*\*/|#if INTERFACE|g' \
    -e 's|/\*[[:space:]]*@MH_ENDIF(:[A-Za-z0-9_]+)?@[[:space:]]*\*/|#endif|g' \
    "$filtered" > "$filtered.tmp" && mv "$filtered.tmp" "$filtered"

# ---- step 6: strip function bodies inside INTERFACE ----
strip_bodies < "$filtered" > "$filtered.tmp" && mv "$filtered.tmp" "$filtered"

# ---- step 7: generate header via makeheaders (all declarations) and deduplicate ----
"$MH" -local -h "$filtered" 2>/dev/null | "$MAWK" '!seen[$0]++' > "$header"

# ---- step 8: strip makeheaders internal defines + wrap structs in PRIV guard ----
# makeheaders injects #define INTERFACE 0 etc. — these conflict with
# our own #undef/#define pattern, so remove them.
# Struct/union/enum definitions get wrapped in #if !PARGS_PRIV_INTERFACE
# so the owning .c (which includes the header with PARGS_PRIV_INTERFACE=1
# via set_priv.h) can supply its own copies via DEFINE_LLDECK without
# redefinition errors. Function prototypes stay unguarded.
"$MAWK" '
function braces(s,    c) {
    c = s
    return (gsub(/{/, "{", c) - gsub(/}/, "}", c))
}
BEGIN { in_struct = 0; depth = 0 }
/^#define[ \t]+(INTERFACE|EXPORT_INTERFACE|LOCAL_INTERFACE|EXPORT|LOCAL|PUBLIC|PRIVATE|PROTECTED)([ \t]|$)/ { next }
/^(typedef[ \t]+)?(struct|union|enum)[ \t]/ {
    in_struct = 1
    structs = structs $0 "\n"
    depth += braces($0)
    if (depth == 0 && $0 ~ /;[ \t]*$/) in_struct = 0
    next
}
in_struct {
    structs = structs $0 "\n"
    depth += braces($0)
    if (depth == 0 && $0 ~ /;[ \t]*$/) in_struct = 0
    next
}
{ pub = pub $0 "\n" }
END {
    if (structs != "") {
        print "#if !PARGS_PRIV_INTERFACE"
        printf "%s", structs
        print "#endif"
        print ""
    }
    printf "%s", pub
}
' "$header" > "$header.tmp"
mv "$header.tmp" "$header"

# ---- step 9: wrap static declarations in #if PARGS_PRIV_INTERFACE ----
# Extract static function names from the original source, then move
# matching declaration lines from the header into a guarded section.
static_names=$("$MAWK" '
    # Match lines like: static <type> <name>(...)
    # Handles: static type *name(..., static type name(..., static const type name(...
    /^[ \t]*static[ \t]/ {
        # Join continuation lines (multiline function signatures)
        line = $0
        while (line !~ /\([^)]*\)[ \t]*\{?[ \t]*(,\/\/.*)?$/) {
            getline nextline
            line = line " " nextline
        }
        # Extract function name: word just before "(" after the return type
        match(line, /[ \t]+([a-zA-Z_][a-zA-Z0-9_]*)[ \t]*\(/, arr)
        if (arr[1] != "") print arr[1]
    }
' "$infile" 2>/dev/null || true)

if [ -n "$static_names" ]; then
    # Build grep patterns for those names (word boundaries)
    patterns=""
    for name in $static_names; do
        patterns="''${patterns:+''${patterns}|}$name"
    done
    # Split header: lines matching static function names go to priv block
    priv_header="''${header}.priv"
    "$MAWK" -v pat="$patterns" '
        $0 ~ "^(" pat ")[ \t]*\\(" { priv = priv $0 "\n"; next }
        { pub = pub $0 "\n" }
        END { printf "%s", pub; if (priv != "") {
            print "";
            print "#if PARGS_PRIV_INTERFACE";
            printf "%s", priv;
            print "#endif"
        } }
    ' "$header" > "$priv_header" && mv "$priv_header" "$header"
fi

# ---- cleanup temp files ----
rm -f "$full" "$filtered"
SH_EOF

    # The script resolves makeheaders/mawk/gcc from env vars at runtime, with
    # the names of the tools as defaults (so it works standalone from a dev
    # shell). Inside the derivation, pin those defaults to the store paths.
    substituteInPlace $out/bin/filter-makeheaders \
      --replace 'MAKEHEADERS:-makeheaders' "MAKEHEADERS:-$out/bin/makeheaders" \
      --replace 'MAWK:-mawk' "MAWK:-${mawk}/bin/mawk" \
      --replace 'CC:-gcc' "CC:-${stdenv.cc}/bin/cc"
    patchShebangs $out/bin/filter-makeheaders
    chmod +x $out/bin/filter-makeheaders
  '';

  meta = {
    description = "Up-to-date version of makeheaders from fossil-scm.org";
    homepage = "https://fossil-scm.org/";
    license = lib.licenses.bsd2;
    platforms = lib.platforms.unix;
    maintainers = [ lib.maintainers.GlassGhost ];
  };

  passthru.tests = {
    interface-preprocess = stdenv.mkDerivation {
      name = "test-interface-preprocess";
      src = ./test_interface.c;
      dontUnpack = true;
      makeheadersVersion = "325f0576c453cfdf7d35cfc03a8aceb249f76cc9";
      makeheaders_src = builtins.fetchurl {
        url = "https://raw.githubusercontent.com/Viruliant/fossil-mirror/325f0576c453cfdf7d35cfc03a8aceb249f76cc9/tools/makeheaders.c";
        sha256 = "1mr09x1pwqv7g0ifhz4nfi4mc9z6pygf0p4jhmihv6xs1w0p81py";
      };
      filter_mh_src = ./filter-makeheaders;
      nativeBuildInputs = [ mawk stdenv.cc ];
      buildPhase = ''
        cp "$src" test_interface.c
        cp "$makeheaders_src" makeheaders.c
        cp "$filter_mh_src" filter-makeheaders
        chmod +x filter-makeheaders

        CC="${stdenv.cc}/bin/cc"
        MAWK="${mawk}/bin/mawk"

        export MAKEHEADERS="$PWD/makeheaders"
        export MAWK
        export CC

        # Build makeheaders binary locally for the test
        $CC -O2 -std=gnu99 makeheaders.c -o makeheaders 2>&1

        # Test 1: INTERFACE=1 expands #if INTERFACE blocks
        echo "--- Test 1: gcc -E -D INTERFACE=1 ---"
        $CC -E -D INTERFACE=1 -C test_interface.c 2>&1 \
          | grep -q TestPoint \
          || { echo "FAIL: INTERFACE=1 should expand struct in #if INTERFACE"; exit 1; }
        echo "PASS: INTERFACE=1 expands structs"

        # Test 2: without -D, #if INTERFACE is skipped
        echo "--- Test 2: gcc -E (no -D INTERFACE) ---"
        $CC -E -C test_interface.c 2>&1 \
          | grep -q TestPoint \
          && { echo "FAIL: INTERFACE=0 should skip #if INTERFACE block"; exit 1; }
        echo "PASS: without -D, INTERFACE block is skipped"

        # Test 3: preprocessor expands DECLARE_PAIR macro inside INTERFACE
        echo "--- Test 3: macro expansion inside INTERFACE ---"
        $CC -E -D INTERFACE=1 -C test_interface.c 2>&1 \
          | grep -q Pair_int \
          || { echo "FAIL: DECLARE_PAIR should expand under INTERFACE=1"; exit 1; }
        echo "PASS: macro expansion works inside INTERFACE"

        # Test 4: run filter-makeheaders pipeline
        echo "--- Test 4: filter-makeheaders on test_interface.c ---"
        bash ./filter-makeheaders test_interface.c 2>&1

        # Test 5: generated .h contains structs from INTERFACE block
        echo "--- Test 5: .h contains structs from INTERFACE ---"
        grep -q TestPoint test_interface.h \
          || { echo "FAIL: .h should contain TestPoint"; exit 1; }
        grep -q Pair_int test_interface.h \
          || { echo "FAIL: .h should contain Pair_int from macro"; exit 1; }
        echo "PASS: structs in .h"

        # Test 6: generated .h contains regular function declarations
        echo "--- Test 6: .h contains regular function declarations ---"
        grep -q 'add(' test_interface.h \
          || { echo "FAIL: .h should contain add() declaration"; exit 1; }
        grep -q 'greet(' test_interface.h \
          || { echo "FAIL: .h should contain greet() declaration"; exit 1; }
        echo "PASS: regular function declarations in .h"

        # Test 7: static functions are guarded by PARGS_PRIV_INTERFACE
        echo "--- Test 7: static functions in PARGS_PRIV_INTERFACE ---"
        grep -q 'PARGS_PRIV_INTERFACE' test_interface.h \
          || { echo "FAIL: .h should have #if PARGS_PRIV_INTERFACE"; exit 1; }
        grep -q 'multiply(' test_interface.h \
          || { echo "FAIL: .h should contain multiply()"; exit 1; }
        grep -q 'divide(' test_interface.h \
          || { echo "FAIL: .h should contain divide()"; exit 1; }
        echo "PASS: static functions guarded"

        # Test 8: no makeheaders internal defines
        echo "--- Test 8: no makeheaders internal defines ---"
        grep -q '^#define INTERFACE 0' test_interface.h \
          && { echo "FAIL: .h should not contain #define INTERFACE 0"; exit 1; }
        echo "PASS: no internal defines"

        # Test 9: no duplicate lines
        echo "--- Test 9: no duplicate lines ---"
        dupes=$("$MAWK" '{ count[$0]++ } END { for (l in count) if (count[l] > 1) print l }' test_interface.h)
        if [ -n "$dupes" ]; then
          echo "FAIL: duplicate lines found:"; echo "$dupes"; exit 1
        fi
        echo "PASS: no duplicates"

        touch $out
      '';
      installPhase = ''
        mkdir -p $out
        cp test_interface.h $out/
        touch $out
      '';
    };
  };
})
