#!/usr/bin/env bash
# Tests for tools/new-game.sh against a temp copy of the repo. Prints "OK" on success.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fails=0

fail() {
	echo "tests/new_game.test.sh: $1"
	fails=$((fails + 1))
}

mkdir -p "$TMP/repo/tools" "$TMP/repo/ideas" "$TMP/repo/games"
[ -f "$ROOT/tools/new-game.sh" ] && cp "$ROOT/tools/new-game.sh" "$TMP/repo/tools/"
[ -d "$ROOT/templates" ] && cp -R "$ROOT/templates" "$TMP/repo/"
REPO="$TMP/repo"

# brief <slug> <decision>: writes ideas/<slug>/brief.md
brief() {
	mkdir -p "$REPO/ideas/$1"
	printf '# Test\n\nSlug: %s\nDecision: %s\n\n## Pitch\nx\n' "$1" "$2" >"$REPO/ideas/$1/brief.md"
}

# refuses <case> <slug>: asserts exit 1, one line of output, and nothing new under games/
refuses() {
	local name="$1" slug="$2" out status before after
	before="$(cd "$REPO" && find games | sort)"
	out="$(cd "$REPO" && bash tools/new-game.sh "$slug" 2>&1)"
	status=$?
	after="$(cd "$REPO" && find games | sort)"
	[ "$status" -eq 1 ] || fail "$name: expected exit 1, got $status"
	[ "$(printf '%s\n' "$out" | grep -c .)" -eq 1 ] || fail "$name: expected one message, got: $out"
	[ "$before" = "$after" ] || fail "$name: games/ changed"
}

refuses "bad slug" "Bad_Slug"
brief "Bad_Slug" go
refuses "bad slug with brief" "Bad_Slug"
refuses "no brief" "nobrief"
brief "pending" pending
refuses "pending brief" "pending"
brief "maybe" "go-ish"
refuses "decision not exactly go" "maybe"
brief "taken" go
mkdir -p "$REPO/games/taken"
refuses "existing game" "taken"

brief "good-1" go
out="$(cd "$REPO" && bash tools/new-game.sh good-1 2>&1)"
status=$?
[ "$status" -eq 0 ] || fail "go brief: expected exit 0, got $status ($out)"
[ "$out" = "created games/good-1" ] || fail "go brief: unexpected output: $out"
grep -q '"name": "good-1"' "$REPO/games/good-1/default.project.json" 2>/dev/null \
	|| fail "go brief: default.project.json missing \"name\": \"good-1\""
if grep -rq '{{slug}}' "$REPO/games/good-1" 2>/dev/null; then
	fail "go brief: {{slug}} left in games/good-1"
fi

if [ "$fails" -ne 0 ]; then
	exit 1
fi
echo OK
