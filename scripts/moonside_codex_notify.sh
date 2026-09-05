#!/usr/bin/env bash
# Moonside notify entry point for completed Codex turns.
# Always exits 0 so a lamp integration can never block Codex.

MOONSIDE_CODEX_NOTIFY_VERSION=5

PAYLOAD="$*"
if [ -z "$PAYLOAD" ] && [ ! -t 0 ]; then
  IFS= read -r -d '' PAYLOAD 2>/dev/null || true
fi

printf '%s' "$PAYLOAD" \
  | /bin/bash "$HOME/.claude/moonside_hooks/moonside_codex_state.sh" notify \
      >/dev/null 2>&1 \
  || true

exit 0
