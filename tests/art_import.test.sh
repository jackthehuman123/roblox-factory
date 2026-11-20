#!/usr/bin/env bash
# Tests for tools/art_import.luau library and game modes. Prints nothing on success.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
export PATH="$HOME/.rokit/bin:$PATH"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fails=0

fail() {
	echo "tests/art_import.test.sh: $1"
	fails=$((fails + 1))
}

imp() {
	out="$(lune run tools/art_import "$@" 2>&1)"
	status=$?
}

P='{"class":"Part","size":[1,1,1],"at":[0,0.5,0],"rot":[0,0,0],"color":[200,200,200],"material":"Plastic","transparency":0}'
echo "{\"parts\":[$P],\"unsupported\":[]}" >"$TMP/ok.json"
echo "{\"parts\":[$P],\"unsupported\":[\"ParticleEmitter Workspace.X.P\"]}" >"$TMP/bad.json"

mkdir -p "$TMP/r/assets/library"
imp --library Thing "$TMP/ok.json" generated --root "$TMP/r"
[ "$status" = 0 ] || fail "library exit $status: $out"
[ -f "$TMP/r/assets/library/Thing.luau" ] || fail "library file missing"

imp --library Blocked "$TMP/bad.json" generated --root "$TMP/r"
[ "$status" = 1 ] || fail "blocking exit $status"
[ ! -e "$TMP/r/assets/library/Blocked.luau" ] || fail "blocking wrote a file"

# existing name is refused and left untouched; --replace overwrites
printf -- '-- keep\n' >"$TMP/r/assets/library/Thing.luau"
imp --library Thing "$TMP/ok.json" generated --root "$TMP/r"
[ "$status" = 1 ] || fail "existing name exit $status"
printf '%s\n' "$out" | grep -q '^art_import: Thing already exists' || fail "existing name message: $out"
[ "$(cat "$TMP/r/assets/library/Thing.luau")" = "-- keep" ] || fail "existing name was overwritten"
imp --library Thing "$TMP/ok.json" generated --root "$TMP/r" --replace
[ "$status" = 0 ] || fail "--replace exit $status: $out"
grep -q parts "$TMP/r/assets/library/Thing.luau" || fail "--replace did not write"

mkdir -p "$TMP/n"
imp --library Thing "$TMP/ok.json" generated --root "$TMP/n"
[ "$status" = 1 ] || fail "missing library dir exit $status"

mkdir -p "$TMP/g/games/x/art/models"
cp "$ROOT/rokit.toml" "$TMP/g/rokit.toml"
out="$(cd "$TMP/g" && lune run "$ROOT/tools/art_import" x Chair "$TMP/ok.json" generated 2>&1)"
status=$?
[ "$status" = 0 ] || fail "game mode exit $status: $out"
[ -f "$TMP/g/games/x/art/models/Chair.luau" ] || fail "game file missing"

[ "$fails" = 0 ]
