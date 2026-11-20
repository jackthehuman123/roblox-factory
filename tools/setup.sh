#!/usr/bin/env bash
# One-command setup: installs the tools, checks the factory, creates your asset library folder, and builds the
# AssetWorkshop place. Safe to run again. Never deletes anything.
# Usage: bash tools/setup.sh
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$root" || exit 1
export PATH="$HOME/.rokit/bin:$PATH"

echo "Step 1/5: installing the tools (rokit)"
if ! command -v rokit >/dev/null 2>&1; then
	echo "Install rokit first: https://github.com/rojo-rbx/rokit — then run this again."
	exit 1
fi
rokit install || exit 1

echo "Step 2/5: checking the factory"
result="$(bash tools/check.sh 2>&1)"
if [ "$result" != "OK" ]; then
	printf '%s\n' "$result"
	echo "The check failed. Fix the lines above, then run this again."
	exit 1
fi

echo "Step 3/5: making your asset library folder"
wt="$(bash tools/asset_worktree.sh)" || exit 1
echo "  $wt"

echo "Step 4/5: building the AssetWorkshop place"
place="$wt/AssetWorkshop.rbxl"
if [ -e "$place" ]; then
	echo "  already built: $place"
else
	rojo build "$wt/assets/workshop.project.json" -o "$place" || exit 1
	echo "  built: $place"
fi

echo "Step 5/5: three things to do yourself"
echo "  1. Open $place in Roblox Studio."
echo "  2. Run: rojo serve \"$wt/assets/workshop.project.json\" --port 34880"
echo "  3. In Studio, click Rojo → Connect."
