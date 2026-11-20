#!/usr/bin/env bash
# Tests for tools/budget_add.luau against temp files. Prints nothing on success.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
export PATH="$HOME/.rokit/bin:$PATH"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fails=0

fail() {
	echo "tests/budget_add.test.sh: $1"
	fails=$((fails + 1))
}

# add <args...>: sets $out and $status
add() {
	out="$(lune run tools/budget_add "$@" 2>&1)"
	status=$?
}

f="$TMP/a/budget.md"
mkdir -p "$TMP/a"
add "$f" pitch council-hook haiku 10000
[ "$status" -eq 0 ] || fail "first add exited $status: $out"
[ "$out" = "pitch: 10000/60000 (17%)" ] || fail "first add printed: $out"
head -1 "$f" | grep -qx "# Token use" || fail "heading missing"
grep -qF "| Stage | Agent | Model | Tokens |" "$f" || fail "table header missing"
grep -qxF "| pitch | council-hook | haiku | 10000 |" "$f" || fail "row missing"

add "$f" pitch council-feasibility sonnet 30000
[ "$out" = "pitch: 40000/60000 (67%)" ] || fail "sum printed: $out"

add "$f" pitch council-loop haiku 10000
[ "$status" -eq 0 ] || fail "warn add exited $status"
grep -qx "pitch: 50000/60000 (83%)" <<<"$out" || fail "83% line missing: $out"
grep -qx "WARN pitch at 83% of budget" <<<"$out" || fail "WARN line missing: $out"

g="$TMP/a/stock.md"
add "$g" stock asset-builder sonnet 99999 --assets 1
[ "$status" -eq 0 ] || fail "stock log-only exited $status"
[ "$out" = "stock: 99999 tokens (no budget)" ] || fail "stock log-only printed: $out"
grep -q WARN <<<"$out" && fail "stock warned though it has no budget: $out"
grep -qxF "| stock | asset-builder×1 | sonnet | 99999 |" "$g" || fail "stock row missing asset count"
add "$g" stock asset-builder sonnet 16000
grep -qxF "| stock | asset-builder | sonnet | 16000 |" "$g" || fail "stock row without --assets changed"

before="$(cat "$f")"
add "$f" nonsense builder sonnet 100
[ "$status" -eq 1 ] || fail "unknown stage exited $status"
grep -q "^budget_add: " <<<"$out" || fail "unknown stage message: $out"
[ "$(cat "$f")" = "$before" ] || fail "unknown stage changed the file"

add "$f" pitch builder sonnet 12k
[ "$status" -eq 1 ] || fail "non-integer exited $status"
grep -q "^budget_add: " <<<"$out" || fail "non-integer message: $out"
[ "$(cat "$f")" = "$before" ] || fail "non-integer changed the file"

add "$TMP/missing/budget.md" pitch builder sonnet 100
[ "$status" -eq 1 ] || fail "missing parent exited $status"
grep -q "^budget_add: " <<<"$out" || fail "missing parent message: $out"
[ ! -e "$TMP/missing" ] || fail "missing parent was created"

[ "$fails" -eq 0 ]
