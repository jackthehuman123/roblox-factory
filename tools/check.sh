#!/usr/bin/env bash
# Quiet project check. Prints exactly "OK" on success.
# On failure prints only "file:line: message" lines (max 30) and exits 1.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
export PATH="$HOME/.rokit/bin:$PATH"

DIRS=()
for d in kit games templates tools tests; do
	[ -d "$d" ] && DIRS+=("$d")
done

OUT="$(mktemp)"
trap 'rm -f "$OUT"' EXIT

if [ ${#DIRS[@]} -gt 0 ]; then
	# StyLua: summary format lists one unformatted file per line.
	stylua --check --output-format=summary "${DIRS[@]}" 2>&1 \
		| grep -E '\.luau?$' \
		| sed -E 's/$/:1: not formatted (run stylua)/' >>"$OUT"

	# selene: quiet style is already "file:line:col: severity[code]: message".
	selene --display-style quiet "${DIRS[@]}" 2>&1 \
		| grep -E '^[^ ]+:[0-9]+:[0-9]+: ' \
		| sed -E 's/^([^:]+):([0-9]+):[0-9]+: /\1:\2: /' >>"$OUT"
fi

# Lune runner prints "<file>: <test>: <abs path>:<line>: <msg>"; move the line number up front.
if [ -f tests/run.luau ]; then
	lune run tests/run 2>&1 \
		| sed -E \
			-e 's#^([^ :]+): (.*): [^ ]*/[^/: ]+:([0-9]+): (.*)$#\1:\3: \2: \4#' \
			-e '/^[^ :]+:[0-9]+: /!s#^([^ :]+): #\1:1: #' >>"$OUT"
	status=${PIPESTATUS[0]}
	if [ "$status" -ne 0 ] && [ ! -s "$OUT" ]; then
		echo "tests/run.luau:1: lune exited $status" >>"$OUT"
	fi
fi

# Graybox worlds: kit Graybox.validate on every games/*/src/server/graybox.luau and the template's.
if ! err="$(lune run tools/graybox_check 2>&1)"; then
	printf '%s\n' "$err" | grep -E '^[^ :]+:[0-9]+: ' >>"$OUT" \
		|| echo "tools/graybox_check.luau:1: lune exited with an error" >>"$OUT"
fi

# Art: kit Art validation on every games/*/art and the template's.
if ! err="$(lune run tools/art_check 2>&1)"; then
	printf '%s\n' "$err" | grep -E '^[^ :]+:[0-9]+: ' >>"$OUT" \
		|| echo "tools/art_check.luau:1: lune exited with an error" >>"$OUT"
fi

# Assets: catalogue and library validation.
if ! err="$(lune run tools/asset_check 2>&1)"; then
	printf '%s\n' "$err" | grep -E '^[^ :]+:[0-9]+: ' >>"$OUT" \
		|| echo "tools/asset_check.luau:1: lune exited with an error" >>"$OUT"
fi

# Games: sourcemap + luau-lsp analyze + rojo build per games/*/default.project.json.
# Every failure line names the game ("[games/<slug>]"), so a kit change that breaks a game is attributed.
DEFS="tools/types/globalTypes.d.luau"
DEFS_URL="https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau"
GAMES=(games/*/default.project.json)
if [ -e "${GAMES[0]}" ] && [ ! -s "$DEFS" ]; then
	mkdir -p tools/types
	curl -fsSL -o "$DEFS" "$DEFS_URL" 2>/dev/null || {
		rm -f "$DEFS"
		echo "$DEFS:1: cannot download Roblox definitions from $DEFS_URL" >>"$OUT"
	}
fi
BUILD_DIR="$(mktemp -d)"
trap 'rm -f "$OUT"; rm -rf "$BUILD_DIR"' EXIT
for project in "${GAMES[@]}"; do
	[ -e "$project" ] && [ -s "$DEFS" ] || continue
	dir="$(dirname "$project")"
	tag="[$dir]"
	if ! err="$(rojo sourcemap "$project" -o "$dir/sourcemap.json" 2>&1)"; then
		echo "$project:1: $tag rojo sourcemap failed: $(printf '%s' "$err" | grep -v '^$' | tail -1)" >>"$OUT"
		continue
	fi
	# Plain format: "<abs file> [<dm path>]:<line>:<col>: (<code>) <message>"; continuation lines dropped.
	(cd "$dir" && luau-lsp analyze --formatter=plain --platform=roblox --defs="$ROOT/$DEFS" \
		--sourcemap=sourcemap.json src "$ROOT/kit/src" 2>/dev/null) \
		| grep -E '^/[^ ]+ \[[^]]*\]:[0-9]+:' \
		| sed -E "s#^$ROOT/([^ ]+) \[[^]]*\]:([0-9]+):[0-9-]+: \([A-Z0-9]+\) #\1:\2: $tag #" \
		| awk '!seen[$0]++' >>"$OUT"
	if ! err="$(rojo build "$project" -o "$BUILD_DIR/$(basename "$dir").rbxl" 2>&1)"; then
		echo "$project:1: $tag rojo build failed: $(printf '%s' "$err" | grep -v '^$' | tail -1)" >>"$OUT"
	fi
done

# Shell tests print "<file>: <message>" lines on failure.
for t in tests/hook.test.sh tests/new_game.test.sh tests/graybox_check.test.sh tests/art_check.test.sh tests/asset_check.test.sh tests/asset_db.test.sh tests/asset_find.test.sh tests/art_import.test.sh tests/budget_add.test.sh tests/asset_worktree.test.sh tests/setup.test.sh; do
	[ -f "$t" ] || continue
	if ! err="$(bash "$t" 2>&1)"; then
		printf '%s\n' "$err" | sed -E 's#^([^ :]+): #\1:1: #' >>"$OUT"
		grep -qE "^$t:" <<<"$err" || echo "$t:1: failed" >>"$OUT"
	fi
done

if [ -s "$OUT" ]; then
	grep -E "^[^[:space:]:]+:[0-9]+: " "$OUT" | head -30
	exit 1
fi
echo OK
