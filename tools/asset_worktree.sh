#!/usr/bin/env bash
# Creates the asset-library worktree at ../<repo folder name>-assets if missing; prints its absolute path.
# Branch asset-library is created from HEAD when it does not exist yet. Idempotent. Never deletes anything.
# After the parent folder (repo + worktree) was moved, it relinks them with `git worktree repair`.
# If the repo folder was renamed or moved alone, it stops and says where to move the library folder.
set -uo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
name="$(basename "$root")"
path="$(cd "$root/.." && pwd -P)/$name-assets"

# Where git thinks the asset-library worktree is (empty if none).
registered=""
current=""
while IFS= read -r line; do
	case "$line" in
	"worktree "*) current="${line#worktree }" ;;
	"branch refs/heads/asset-library") registered="$current" ;;
	esac
done < <(git -C "$root" worktree list --porcelain)

if [ -n "$registered" ] && [ "$registered" = "$path" ] && [ -d "$path" ]; then
	echo "$path"
	exit 0
fi
if [ -e "$path/.git" ]; then
	# The library folder is where it should be but the link is stale (both folders moved together).
	git -C "$root" worktree repair "$path" >&2 || exit 1
	echo "$path"
	exit 0
fi
if [ "$registered" = "$path" ]; then
	echo "library folder $path is missing; put it back, or run \`git worktree prune\` and run this again" >&2
	exit 1
fi
if [ -n "$registered" ]; then
	echo "library worktree not found at $path (git has it at $registered); move it to $path and run this again" >&2
	exit 1
fi
if git -C "$root" show-ref --verify --quiet refs/heads/asset-library; then
	git -C "$root" worktree add "$path" asset-library >&2 || exit 1
else
	git -C "$root" worktree add -b asset-library "$path" HEAD >&2 || exit 1
fi
echo "$path"
