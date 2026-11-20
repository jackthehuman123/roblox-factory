#!/usr/bin/env bash
# Usage: tools/new-game.sh <slug>
# Creates games/<slug> from templates/game when ideas/<slug>/brief.md says "Decision: go".
# Prints "created games/<slug>" (exit 0) or one error message and writes nothing (exit 1).
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

die() {
	echo "new-game: $1" >&2
	exit 1
}

[ $# -eq 1 ] || die "usage: tools/new-game.sh <slug>"
slug="$1"
[[ "$slug" =~ ^[a-z][a-z0-9-]*$ ]] || die "bad slug '$slug' (must match ^[a-z][a-z0-9-]*\$)"
brief="ideas/$slug/brief.md"
[ -f "$brief" ] || die "no brief at $brief"
grep -q '^Decision: go$' "$brief" || die "$brief is not marked 'Decision: go'"
[ ! -e "games/$slug" ] || die "games/$slug already exists"
[ -d templates/game ] || die "templates/game is missing"

mkdir -p games 2>/dev/null || die "cannot create games/"
STAGE="$(mktemp -d "games/.new-$slug.XXXXXX" 2>/dev/null)" || die "cannot create staging dir"
trap 'rm -rf "$STAGE"' EXIT
chmod 755 "$STAGE" 2>/dev/null || die "cannot set permissions on staging dir"

cp -R templates/game/. "$STAGE/" 2>/dev/null || die "copy failed"
while IFS= read -r -d '' f; do
	sed "s/{{slug}}/$slug/g" "$f" >"$f.tmp" 2>/dev/null && mv "$f.tmp" "$f" || die "placeholder replace failed in $f"
done < <(grep -rl --null '{{slug}}' "$STAGE" 2>/dev/null)
mv "$STAGE" "games/$slug" 2>/dev/null || die "could not move into games/$slug"
trap - EXIT

echo "created games/$slug"
