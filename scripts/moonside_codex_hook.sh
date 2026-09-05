#!/usr/bin/env bash
# Moonside LED hook for OpenAI Codex (per-session aware).
# Codex hooks receive JSON on stdin and return JSON on stdout.
# Always exits 0 so it can never block Codex.

MOONSIDE_CODEX_HOOK_VERSION=2

IFS= read -r -d '' INPUT 2>/dev/null || true

EVENT=""
if [[ "$INPUT" =~ \"hook_event_name\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
  EVENT="${BASH_REMATCH[1]}"
fi

# Prefer the current thread identifier so the hook and Codex notify command
# update the same per-session bucket. Keep legacy identifiers for older payloads.
SID=""
if [[ "$INPUT" =~ \"thread_id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
  SID="${BASH_REMATCH[1]}"
elif [[ "$INPUT" =~ \"thread-id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
  SID="${BASH_REMATCH[1]}"
elif [[ "$INPUT" =~ \"session_id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
  SID="${BASH_REMATCH[1]}"
elif [[ "$INPUT" =~ \"conversation_id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
  SID="${BASH_REMATCH[1]}"
fi

case "$EVENT" in
  SessionStart)                          CAT=idle ;;
  UserPromptSubmit|PreToolUse|PostToolUse) CAT=working ;;
  Stop)                                  CAT=idle ;;
  *)                                     exit 0 ;;
esac

# Without an identifier there is no safe per-session bucket to update.
[ -n "$SID" ] || exit 0

source "$HOME/.claude/moonside_hooks/moonside_resolve.sh"
MS_SID="$SID" MS_CAT="$CAT" moonside_resolve cx

echo ""
exit 0
