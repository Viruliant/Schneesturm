{
  testers,
  calc2,
  src,
}: {
  # Runs the installed `calc` against the example's expressions.txt and
  # asserts the result matches the first section of expect.out (the 8
  # arithmetic results that appear before the regression-test banners).
  calc2-example-test = testers.runCommand {
    name = "calc2-example-test";
    src = src;
    nativeBuildInputs = [ calc2 ];
    script = ''
      mkdir -p "$TMPDIR"
      ${calc2}/bin/calc < "$src/examples/calc2/expressions.txt" > "$TMPDIR/out"
      awk '/^========/{exit} {print}' "$src/examples/calc2/expect.out" > "$TMPDIR/expected"
      if ! diff -u "$TMPDIR/expected" "$TMPDIR/out"; then
        echo "ERROR: calc output does not match examples/calc2/expect.out" >&2
        exit 1
      fi
      touch $out
    '';
  };
}
