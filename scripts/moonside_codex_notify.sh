#!/usr/bin/env bash
# Codex notify handler — agent-turn-complete means the agent is idle.
# Always exits 0.

PAYLOAD="$*"
if [ -z "$PAYLOAD" ] && [ ! -t 0 ]; then
  IFS= read -r -d '' PAYLOAD 2>/dev/null || true
fi

TYPE=""
if [[ "$PAYLOAD" =~ \"type\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
  TYPE="${BASH_REMATCH[1]}"
fi

# Unknown notification types must not change lamp state.
[ "$TYPE" = "agent-turn-complete" ] || exit 0

# `thread-id` is the current Codex notify field. The underscore and legacy
# names keep compatibility with older notification payloads.
SID=""
if [[ "$PAYLOAD" =~ \"thread-id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
  SID="${BASH_REMATCH[1]}"
elif [[ "$PAYLOAD" =~ \"thread_id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
  SID="${BASH_REMATCH[1]}"
elif [[ "$PAYLOAD" =~ \"session_id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
  SID="${BASH_REMATCH[1]}"
elif [[ "$PAYLOAD" =~ \"conversation_id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
  SID="${BASH_REMATCH[1]}"
fi

# A notification without an identifier cannot safely select a session bucket.
[ -n "$SID" ] || exit 0

source "$HOME/.claude/moonside_hooks/moonside_resolve.sh"
MS_SID="$SID" MS_CAT=idle moonside_resolve cx

exit 0
