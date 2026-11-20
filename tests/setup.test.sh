#!/usr/bin/env bash
# Tests for tools/setup.sh with stub rokit/rojo and a stub check.sh in a temp repo. Prints nothing on success.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
TMP="$(cd "$TMP" && pwd -P)"
fails=0

fail() {
	echo "tests/setup.test.sh: $1"
	fails=$((fails + 1))
}

# repo <dir> <check output>: temp repo with setup.sh, asset_worktree.sh, a stub check.sh and the workshop project
repo() {
	local r="$1"
	mkdir -p "$r/tools" "$r/assets"
	cp "$ROOT/tools/setup.sh" "$ROOT/tools/asset_worktree.sh" "$r/tools/" 2>/dev/null
	printf '#!/usr/bin/env bash\necho "%s"\n' "$2" >"$r/tools/check.sh"
	echo '{}' >"$r/assets/workshop.project.json"
	git -C "$r" init -q -b main
	git -C "$r" -c user.name=t -c user.email=t@t add -A
	git -C "$r" -c user.name=t -c user.email=t@t commit -qm init
}

# stubs <bin> [rokit]: rojo logs its args and writes the -o file; rokit only if asked
stubs() {
	mkdir -p "$1"
	printf '#!/usr/bin/env bash\necho "rojo $*" >>"%s/calls"\nwhile [ $# -gt 0 ]; do [ "$1" = "-o" ] && : >"$2"; shift; done\n' "$1" >"$1/rojo"
	chmod +x "$1/rojo"
	if [ "${2:-}" = rokit ]; then
		printf '#!/usr/bin/env bash\necho "rokit $*" >>"%s/calls"\n' "$1" >"$1/rokit"
		chmod +x "$1/rokit"
	fi
}

run() {
	out="$(HOME="$TMP/home" PATH="$1:/usr/bin:/bin" bash "$2/tools/setup.sh" 2>&1)"
	status=$?
}

# no rokit: stops at step 1 with the install link
A="$TMP/a/factory"
repo "$A" OK
stubs "$TMP/bin-a"
run "$TMP/bin-a" "$A"
[ "$status" -eq 1 ] || fail "no rokit: exit $status"
printf '%s' "$out" | grep -q "Install rokit first" || fail "no rokit: message '$out'"
[ ! -e "$TMP/bin-a/calls" ] || fail "no rokit: something else ran"

# happy path: five steps in order, workshop built, Studio steps printed
B="$TMP/b/factory"
repo "$B" OK
stubs "$TMP/bin-b" rokit
run "$TMP/bin-b" "$B"
[ "$status" -eq 0 ] || fail "happy: exit $status: $out"
steps="$(printf '%s\n' "$out" | grep -o '^Step [0-9]/5' | tr '\n' ' ')"
[ "$steps" = "Step 1/5 Step 2/5 Step 3/5 Step 4/5 Step 5/5 " ] || fail "happy: steps '$steps'"
grep -q "rojo build .*-o $TMP/b/factory-assets/AssetWorkshop.rbxl" "$TMP/bin-b/calls" || fail "happy: rojo build call: $(cat "$TMP/bin-b/calls")"
[ -e "$TMP/b/factory-assets/AssetWorkshop.rbxl" ] || fail "happy: place not built"
printf '%s' "$out" | tail -4 | grep -q "Rojo → Connect" || fail "happy: Studio steps missing"

# again: nothing rebuilt
run "$TMP/bin-b" "$B"
[ "$status" -eq 0 ] || fail "again: exit $status"
printf '%s' "$out" | grep -q "already built" || fail "again: no 'already built'"
[ "$(grep -c 'rojo build' "$TMP/bin-b/calls")" = "1" ] || fail "again: rebuilt"

# check fails: stops after step 2
C="$TMP/c/factory"
repo "$C" "x:1: broken"
stubs "$TMP/bin-c" rokit
run "$TMP/bin-c" "$C"
[ "$status" -eq 1 ] || fail "check fails: exit $status"
printf '%s' "$out" | grep -q "x:1: broken" || fail "check fails: output not shown"
printf '%s' "$out" | grep -q "Step 3/5" && fail "check fails: went on to step 3"

[ "$fails" -eq 0 ] || exit 1
