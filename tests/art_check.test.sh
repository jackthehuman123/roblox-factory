#!/usr/bin/env bash
# Tests for tools/art_check.luau against temp game dirs. Prints nothing on success.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
export PATH="$HOME/.rokit/bin:$PATH"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fails=0

fail() {
	echo "tests/art_check.test.sh: $1"
	fails=$((fails + 1))
}

# run <dir>: sets $out and $status from checking one game dir
run() {
	out="$(lune run tools/art_check "$1" 2>&1)"
	status=$?
}

# game <name>: creates $TMP/<name> with a graybox tagging two "Light" boxes and an empty art folder
game() {
	mkdir -p "$TMP/$1/art/models" "$TMP/$1/src/server"
	printf 'return {\n\t{ size = { 1, 1, 1 }, at = { 0, 0, 0 }, tags = { "Light" } },\n\t{ size = { 1, 1, 1 }, at = { 0, 2, 0 }, tags = { "Light" } },\n}\n' >"$TMP/$1/src/server/graybox.luau"
	printf 'return { parts = { { size = { 1, 1, 1 }, at = { 0, 0, 0 } } } }\n' >"$TMP/$1/art/models/Lamp.luau"
}

game good
printf 'return {\n\t{ size = { 10, 1, 10 }, at = { 0, -0.5, 0 }, tags = { "Floor" } },\n\t{ size = { 1, 1, 1 }, at = { 0, 3, 0 }, tags = { "Light" } },\n}\n' >"$TMP/good/src/server/graybox.luau"
printf 'return { { model = "Lamp", at = { 3, 5, 3 }, sit = "floor" }, { model = "Lamp", onTag = "Light", sit = "under" } }\n' >"$TMP/good/art/placements.luau"
run "$TMP/good"
[ "$status" -eq 0 ] || fail "valid art: expected exit 0, got $status ($out)"
[ -z "$out" ] || fail "valid art: expected no output, got: $out"

game doubled
printf 'return { { model = "Lamp", onTag = "Light" } }\n' >"$TMP/doubled/art/placements.luau"
run "$TMP/doubled"
[ "$status" -eq 1 ] || fail "doubled: expected exit 1, got $status ($out)"
printf '%s\n' "$out" | grep -qF "placements.luau:1: placement 1 (Lamp): doubled:" \
	|| fail "doubled: missing doubled line, got: $out"

game ghost
printf 'return { { model = "Ghost", at = { 0, 0, 0 } } }\n' >"$TMP/ghost/art/placements.luau"
run "$TMP/ghost"
[ "$status" -eq 1 ] || fail "unknown model: expected exit 1, got $status"
printf '%s\n' "$out" | grep -qF "$TMP/ghost/art/placements.luau:1: placement 1: unknown model Ghost" \
	|| fail "unknown model: missing placement line, got: $out"

game broken
printf 'return {}\n' >"$TMP/broken/art/placements.luau"
printf 'return { parts = \n' >"$TMP/broken/art/models/Bad.luau"
run "$TMP/broken"
[ "$status" -eq 1 ] || fail "syntax error: expected exit 1, got $status"
printf '%s\n' "$out" | grep -q "^$TMP/broken/art/models/Bad.luau:1: " || fail "syntax error: no line naming the file: $out"

game lower
printf 'return {}\n' >"$TMP/lower/art/placements.luau"
rm "$TMP/lower/art/models/Lamp.luau" # macOS file names ignore case
printf 'return { parts = { { size = { 1, 1, 1 }, at = { 0, 0, 0 } } } }\n' >"$TMP/lower/art/models/lamp.luau"
run "$TMP/lower"
[ "$status" -eq 1 ] || fail "bad model file name: expected exit 1, got $status"
printf '%s\n' "$out" | grep -q "^$TMP/lower/art/models/lamp.luau:1: " || fail "bad model file name: no line naming the file: $out"

game noplace
run "$TMP/noplace"
[ "$status" -eq 1 ] || fail "missing placements: expected exit 1, got $status"

mkdir -p "$TMP/noart"
run "$TMP/noart"
[ "$status" -eq 0 ] || fail "no art dir: expected exit 0, got $status ($out)"
[ -z "$out" ] || fail "no art dir: expected no output, got: $out"

[ "$fails" -eq 0 ] || exit 1
