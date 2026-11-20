#!/usr/bin/env bash
# Tests for tools/hooks/post-edit.sh. Prints "OK" on success, failures otherwise.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$ROOT/tools/hooks/post-edit.sh"
export PATH="$HOME/.rokit/bin:$PATH"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fails=0

fail() {
	echo "tests/hook.test.sh: $1"
	fails=$((fails + 1))
}

# run_hook <case> <file_path>: feeds hook JSON, asserts exit 0 and no output.
run_hook() {
	local name="$1" path="$2" out status
	out="$(jq -n --arg p "$path" '{tool_name: "Edit", tool_input: {file_path: $p}}' | bash "$HOOK" 2>&1)"
	status=$?
	[ "$status" -eq 0 ] || fail "$name: exit $status"
	[ -z "$out" ] || fail "$name: unexpected output: $out"
}

# Case 1: badly formatted .luau gets formatted.
LUAU="$TMP/bad.luau"
printf -- '--!strict\nlocal   x=1\nreturn    x\n' >"$LUAU"
run_hook "luau" "$LUAU"
stylua --check "$LUAU" >/dev/null 2>&1 || fail "luau: file still not formatted"

# Case 2: .md file is untouched.
MD="$TMP/notes.md"
printf 'local   x=1\n' >"$MD"
before="$(cat "$MD")"
run_hook "md" "$MD"
[ "$(cat "$MD")" = "$before" ] || fail "md: file was modified"

# Case 3: nonexistent path raises no error.
run_hook "missing" "$TMP/does-not-exist.luau"

if [ "$fails" -ne 0 ]; then
	exit 1
fi
echo OK
