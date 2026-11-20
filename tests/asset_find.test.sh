#!/usr/bin/env bash
# Tests for tools/asset_find.luau against temp roots. Prints nothing on success.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
export PATH="$HOME/.rokit/bin:$PATH"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fails=0

fail() {
	echo "tests/asset_find.test.sh: $1"
	fails=$((fails + 1))
}

find_() {
	local r="$1"
	shift
	out="$(lune run tools/asset_find --root "$r" "$@" 2>&1)"
	status=$?
}

mkdir -p "$TMP/a/assets"
cp assets/tags.luau "$TMP/a/assets/tags.luau"
cat >"$TMP/a/assets/index.luau" <<'LUA'
return {
	{ name = "Lamp", tags = { "light", "wood" }, size = { 1, 2.5, 1.005 }, sources = {}, built = "code", review = "approved" },
	{ name = "Torch", tags = { "light" }, size = { 1, 1, 1 }, sources = {}, built = "code", review = "unreviewed" },
	{ name = "Bad", tags = { "light" }, size = { 1, 1, 1 }, sources = {}, built = "code", review = "rejected", reason = "x" },
}
LUA
mkdir -p "$TMP/e/assets"
cp assets/tags.luau "$TMP/e/assets/tags.luau"
printf 'return {}\n' >"$TMP/e/assets/index.luau"

find_ "$TMP/a" light
[ "$status" = 0 ] || fail "default exit $status"
[ "$out" = "Lamp  1×2.5×1  light, wood" ] || fail "default output: $out"
find_ "$TMP/a" --all light
echo "$out" | grep -q "^Torch .*(unreviewed)$" || fail "--all lacks unreviewed: $out"
echo "$out" | grep -q "Bad" && fail "rejected shown"
find_ "$TMP/a" light wood
[ "$(echo "$out" | wc -l | tr -d ' ')" = 1 ] || fail "AND: $out"
find_ "$TMP/a" nonsense
[ "$status" = 1 ] || fail "unknown tag exit $status"
[ "$out" = "asset_find: unknown tag nonsense" ] || fail "unknown tag msg: $out"
find_ "$TMP/e" light
[ "$status" = 0 ] && [ -z "$out" ] || fail "empty library: $status $out"
find_ "$TMP/a"
[ "$status" = 1 ] && echo "$out" | grep -q "^usage: lune run tools/asset_find" || fail "no tags: $status $out"

[ "$fails" = 0 ]
