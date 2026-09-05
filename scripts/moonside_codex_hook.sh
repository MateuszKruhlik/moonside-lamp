#!/usr/bin/env bash
# Moonside hook entry point for persisted, user-facing Codex sessions.
# Always exits 0 so a lamp integration can never block Codex.

MOONSIDE_CODEX_HOOK_VERSION=5

IFS= read -r -d '' PAYLOAD 2>/dev/null || true
printf '%s' "$PAYLOAD" \
  | /bin/bash "$HOME/.claude/moonside_hooks/moonside_codex_state.sh" hook \
      >/dev/null 2>&1 \
  || true

exit 0
