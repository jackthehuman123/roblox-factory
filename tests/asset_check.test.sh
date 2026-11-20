#!/usr/bin/env bash
# Tests for tools/asset_check.luau against temp roots. Prints nothing on success.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
export PATH="$HOME/.rokit/bin:$PATH"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fails=0

fail() {
	echo "tests/asset_check.test.sh: $1"
	fails=$((fails + 1))
}

# run <root>: sets $out and $status
run() {
	out="$(lune run tools/asset_check --root "$1" 2>&1)"
	status=$?
}

# scaffold <name>: empty library under $TMP/<name>/assets
scaffold() {
	local a="$TMP/$1/assets"
	mkdir -p "$a/library" "$a/thumbs" "$a/images" "$a/skipped"
	cp assets/tags.luau "$a/tags.luau"
	printf 'return {}\n' >"$a/index.luau"
	printf 'return {}\n' >"$a/images.luau"
}

# asset <name> <tag> <size>: one full library entry with its files
asset() {
	local a="$TMP/$1/assets"
	printf 'return {\n\t{ name = "Lamp", tags = { "%s" }, size = { 1, 1, 1 }, sources = { "lamp.png" }, built = "code", review = "unreviewed" },\n}\n' "$2" >"$a/index.luau"
	printf 'return { parts = { { size = { %s }, at = { 0, 0.5, 0 } } } }\n' "$3" >"$a/library/Lamp.luau"
	: >"$a/thumbs/Lamp.png"
	: >"$a/images/lamp.png"
	printf 'return {\n\t{ file = "lamp.png", hash = "%s", status = "done", built = { "Lamp" }, skipped = {} },\n}\n' "$(printf 'a%.0s' {1..64})" >"$a/images.luau"
}

scaffold empty
run "$TMP/empty"
[ "$status" -eq 0 ] || fail "empty library: expected exit 0, got $status ($out)"
[ -z "$out" ] || fail "empty library: expected no output, got: $out"

scaffold good
asset good light "1, 1, 1"
printf 'print("build")\n' >"$TMP/good/assets/library/Lamp.build.luau"
run "$TMP/good"
[ "$status" -eq 0 ] || fail "valid asset: expected exit 0, got $status ($out)"
[ -z "$out" ] || fail "valid asset: expected no output, got: $out"

scaffold badmodel
asset badmodel light "0, 1, 1"
run "$TMP/badmodel"
[ "$status" -eq 1 ] || fail "bad model: expected exit 1, got $status ($out)"
printf '%s\n' "$out" | grep -q "^$TMP/badmodel/assets/library/Lamp.luau:1: " || fail "bad model: no line naming the file: $out"

scaffold badindex
asset badindex nonsense "1, 1, 1"
run "$TMP/badindex"
[ "$status" -eq 1 ] || fail "bad index: expected exit 1, got $status ($out)"
printf '%s\n' "$out" | grep -q "^$TMP/badindex/assets/index.luau:1: " || fail "bad index: no line naming index: $out"

mkdir -p "$TMP/none"
run "$TMP/none"
[ "$status" -eq 0 ] || fail "no assets dir: expected exit 0, got $status ($out)"
[ -z "$out" ] || fail "no assets dir: expected no output, got: $out"

[ "$fails" -eq 0 ] || exit 1
