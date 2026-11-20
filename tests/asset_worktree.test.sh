#!/usr/bin/env bash
# Tests for tools/asset_worktree.sh in temp repos. Prints nothing on success.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
TMP="$(cd "$TMP" && pwd -P)"
fails=0

fail() {
	echo "tests/asset_worktree.test.sh: $1"
	fails=$((fails + 1))
}

# repo <parent> <name>: a one-commit git repo with the script in tools/
repo() {
	local r="$1/$2"
	mkdir -p "$r/tools"
	cp "$ROOT/tools/asset_worktree.sh" "$r/tools/"
	git -C "$r" init -q -b main
	git -C "$r" -c user.name=t -c user.email=t@t add -A
	git -C "$r" -c user.name=t -c user.email=t@t commit -qm init
}

run() {
	out="$(bash "$1/tools/asset_worktree.sh" 2>/dev/null)"
	status=$?
}

# fresh: creates ../<name>-assets on branch asset-library
P="$TMP/p"
repo "$P" myfactory
run "$P/myfactory"
[ "$status" -eq 0 ] && [ "$out" = "$P/myfactory-assets" ] || fail "fresh: $status '$out'"
[ "$(git -C "$P/myfactory-assets" branch --show-current 2>/dev/null)" = "asset-library" ] || fail "fresh: branch"

# idempotent
run "$P/myfactory"
[ "$status" -eq 0 ] && [ "$out" = "$P/myfactory-assets" ] || fail "again: $status '$out'"
[ "$(git -C "$P/myfactory" worktree list | wc -l | tr -d ' ')" = "2" ] || fail "again: extra worktree"

# moved together: the parent folder holding both moves
mv "$P" "$TMP/q"
Q="$TMP/q"
run "$Q/myfactory"
[ "$status" -eq 0 ] && [ "$out" = "$Q/myfactory-assets" ] || fail "moved: $status '$out'"
git -C "$Q/myfactory-assets" status >/dev/null 2>&1 || fail "moved: worktree git broken"
git -C "$Q/myfactory" worktree list | grep -q "$Q/myfactory-assets" || fail "moved: main repo not relinked"

# renamed alone: old worktree stays, script stops with the fix
R="$TMP/r"
repo "$R" myfactory
run "$R/myfactory"
mv "$R/myfactory" "$R/other"
out="$(bash "$R/other/tools/asset_worktree.sh" 2>&1)"
status=$?
[ "$status" -eq 1 ] || fail "renamed: exit $status"
[ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" = "1" ] && printf '%s' "$out" | grep -q "move it to" || fail "renamed: message '$out'"
[ -d "$R/myfactory-assets" ] || fail "renamed: old worktree deleted"

# library folder deleted: one line naming the way out, nothing created or deleted
D="$TMP/d"
repo "$D" myfactory
run "$D/myfactory"
rm -rf "$D/myfactory-assets"
out="$(bash "$D/myfactory/tools/asset_worktree.sh" 2>&1)"
status=$?
[ "$status" -eq 1 ] || fail "deleted: exit $status"
[ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" = "1" ] && printf '%s' "$out" | grep -q "git worktree prune" || fail "deleted: message '$out'"
[ ! -e "$D/myfactory-assets" ] || fail "deleted: folder recreated"

[ "$fails" -eq 0 ] || exit 1
