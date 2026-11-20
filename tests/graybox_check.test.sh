#!/usr/bin/env bash
# Tests for tools/graybox_check.luau against temp graybox files. Prints "OK" on success.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
export PATH="$HOME/.rokit/bin:$PATH"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fails=0

fail() {
	echo "tests/graybox_check.test.sh: $1"
	fails=$((fails + 1))
}

# run <file>: sets $out and $status from checking one file
run() {
	out="$(lune run tools/graybox_check "$1" 2>&1)"
	status=$?
}

printf 'return {\n\t{ size = { 4, 1, 4 }, at = { 0, -0.5, 0 }, material = "Grass" },\n}\n' >"$TMP/good.luau"
run "$TMP/good.luau"
[ "$status" -eq 0 ] || fail "valid world: expected exit 0, got $status ($out)"
[ -z "$out" ] || fail "valid world: expected no output, got: $out"

printf 'return {\n\t{ size = { 1, 1, 1 }, at = { 0, 0, 0 } },\n\t{ size = { 0, 1, 1 }, at = { 0, 0, 0 }, material = "Plastic" },\n}\n' >"$TMP/bad.luau"
run "$TMP/bad.luau"
[ "$status" -eq 1 ] || fail "bad world: expected exit 1, got $status"
[ "$(printf '%s\n' "$out" | grep -c "^$TMP/bad.luau:1: box 2: ")" -eq 2 ] \
	|| fail "bad world: expected two 'box 2' lines, got: $out"

printf 'return { size = \n' >"$TMP/broken.luau"
run "$TMP/broken.luau"
[ "$status" -eq 1 ] || fail "syntax error: expected exit 1, got $status"
printf '%s\n' "$out" | grep -q "^$TMP/broken.luau:1: " || fail "syntax error: no line naming the file: $out"

printf 'return 5\n' >"$TMP/notlist.luau"
run "$TMP/notlist.luau"
[ "$status" -eq 1 ] || fail "not a list: expected exit 1, got $status"
printf '%s\n' "$out" | grep -q "^$TMP/notlist.luau:1: " || fail "not a list: no line naming the file: $out"

# a plain file in games/ (e.g. .gitkeep in an empty factory) is not a game
mkdir -p "$TMP/empty/games"
: >"$TMP/empty/games/.gitkeep"
cp "$ROOT/rokit.toml" "$TMP/empty/"
out="$(cd "$TMP/empty" && lune run "$ROOT/tools/graybox_check" 2>&1)"
status=$?
[ "$status" -eq 0 ] && [ -z "$out" ] || fail "games/.gitkeep: expected clean exit, got $status ($out)"

if [ "$fails" -ne 0 ]; then
	exit 1
fi
echo OK
