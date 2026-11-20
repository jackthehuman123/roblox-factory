#!/usr/bin/env bash
# PostToolUse hook (Edit|Write): formats edited .luau files with StyLua.
# Reads Claude Code hook JSON on stdin. Silent; always exits 0. No linting here.
export PATH="$HOME/.rokit/bin:$PATH"

file="$(jq -r '.tool_input.file_path // empty' 2>/dev/null)"

case "$file" in
*.luau)
	if [ -f "$file" ]; then
		stylua "$file" >/dev/null 2>&1
	fi
	;;
esac

exit 0
