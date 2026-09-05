#!/usr/bin/env bash
# Serialized state coordinator for persisted, user-facing Codex sessions.
# Payloads arrive on stdin. No payload or identifier is logged.

MOONSIDE_CODEX_STATE_VERSION=5

MODE="${1:-}"
LOCKED="${2:-}"
LOCK_FILE="/tmp/moonside_cx.lock"
BUCKET_DIR="/tmp/moonside_cx.d"
TURN_DIR="/tmp/moonside_cx.turns"
STATE_FILE="/tmp/moonside_cx"
DB_PATH="${CODEX_HOME:-$HOME/.codex}/state_5.sqlite"

case "$MODE" in hook|notify) ;; *) exit 0 ;; esac
IFS= read -r -d '' PAYLOAD 2>/dev/null || true

# lockf owns the kernel lock for the whole parse, validate, prune, mutate and
# aggregate transaction. A pre-start timeout leaves state untouched, and the
# kernel releases the lock whenever the coordinator exits or crashes.
if [ "$LOCKED" != "--locked" ]; then
  printf '%s' "$PAYLOAD" \
    | /usr/bin/lockf -k -t 2 "$LOCK_FILE" /bin/bash "$0" "$MODE" --locked \
        >/dev/null 2>&1 \
    || true
  exit 0
fi

json_string() {
  printf '%s' "$PAYLOAD" \
    | /usr/bin/plutil -extract "$1" raw -expect string -n -o - - 2>/dev/null
}

has_key() {
  printf '%s' "$PAYLOAD" | /usr/bin/plutil -type "$1" - >/dev/null 2>&1
}

is_safe_id() {
  case "$1" in
    ""|*[!A-Za-z0-9_-]*) return 1 ;;
    *) return 0 ;;
  esac
}

read_hook_sid() {
  if has_key session_id; then
    SID="$(json_string session_id)"
  elif has_key thread_id; then
    SID="$(json_string thread_id)"
  elif has_key thread-id; then
    SID="$(json_string thread-id)"
  elif has_key conversation_id; then
    SID="$(json_string conversation_id)"
  fi
}

read_notify_sid() {
  if has_key thread-id; then
    SID="$(json_string thread-id)"
  elif has_key thread_id; then
    SID="$(json_string thread_id)"
  elif has_key session_id; then
    SID="$(json_string session_id)"
  elif has_key conversation_id; then
    SID="$(json_string conversation_id)"
  fi
}

read_turn_id() {
  TURN_PRESENT=0
  if has_key turn_id; then
    TURN_PRESENT=1
    TURN_ID="$(json_string turn_id)"
  elif has_key turn-id; then
    TURN_PRESENT=1
    TURN_ID="$(json_string turn-id)"
  fi
}

load_user_ids() {
  DB_READ_OK=0
  ROOT_IDS=""
  ACTIVE_USER_IDS=""
  [ -f "$DB_PATH" ] || return 1
  local rows id active
  rows="$(/usr/bin/sqlite3 -batch -noheader -readonly "$DB_PATH" \
      "SELECT id, CASE WHEN COALESCE(archived, 0) = 0 THEN 1 ELSE 0 END
         FROM threads
        WHERE thread_source = 'user'
           OR (thread_source IS NULL AND source = 'vscode');" 2>/dev/null)" \
    || return 1

  while IFS='|' read -r id active; do
    is_safe_id "$id" || continue
    ROOT_IDS="${ROOT_IDS}${ROOT_IDS:+$'\n'}${id}"
    if [ "$active" = 1 ]; then
      ACTIVE_USER_IDS="${ACTIVE_USER_IDS}${ACTIVE_USER_IDS:+$'\n'}${id}"
    fi
  done <<< "$rows"
  DB_READ_OK=1
  return 0
}

id_in_list() {
  local wanted="$1" ids="$2" candidate
  while IFS= read -r candidate; do
    [ "$candidate" = "$wanted" ] && return 0
  done <<< "$ids"
  return 1
}

is_persisted_root() { id_in_list "$1" "$ROOT_IDS"; }
is_active_root() { id_in_list "$1" "$ACTIVE_USER_IDS"; }

atomic_write() {
  local destination="$1" value="$2" temporary="${1}.tmp.$$"
  if printf '%s' "$value" > "$temporary" 2>/dev/null \
      && /bin/mv -f "$temporary" "$destination" 2>/dev/null; then
    return 0
  fi
  /bin/rm -f "$temporary" 2>/dev/null
  return 1
}

prune_orphans() {
  local file sid
  [ "$DB_READ_OK" = 1 ] || return 0

  for file in "$BUCKET_DIR"/*; do
    [ -f "$file" ] || continue
    sid="${file##*/}"
    if ! is_active_root "$sid"; then
      /bin/rm -f "$file" "$TURN_DIR/$sid" 2>/dev/null
    fi
  done

  for file in "$TURN_DIR"/*; do
    [ -f "$file" ] || continue
    sid="${file##*/}"
    if ! is_active_root "$sid" || [ ! -f "$BUCKET_DIR/$sid" ]; then
      /bin/rm -f "$file" 2>/dev/null
    fi
  done
}

aggregate() {
  local file state had_input=0 had_working=0 had_idle=0 token
  for file in "$BUCKET_DIR"/*; do
    [ -f "$file" ] || continue
    state="$(<"$file")"
    case "$state" in
      input) had_input=1 ;;
      working) had_working=1 ;;
      idle) had_idle=1 ;;
    esac
  done

  if [ "$had_input" = 1 ]; then
    token=input_cx
  elif [ "$had_working" = 1 ]; then
    token=working_cx
  elif [ "$had_idle" = 1 ]; then
    token=idle
  else
    token=off
  fi
  printf '%s' "$token" > "$STATE_FILE" 2>/dev/null
}

ACTION=""
SID=""
TURN_ID=""
TURN_PRESENT=0
DB_READ_OK=0
ROOT_IDS=""
ACTIVE_USER_IDS=""

if [ "$MODE" = hook ]; then
  EVENT="$(json_string hook_event_name)"
  case "$EVENT" in
    UserPromptSubmit) ACTION=start ;;
    Stop|Interrupt) ACTION=complete ;;
    SessionEnd) ACTION=end ;;
    SessionStart|PreToolUse|PostToolUse) exit 0 ;;
    *) exit 0 ;;
  esac
  read_hook_sid
else
  TYPE="$(json_string type)"
  [ "$TYPE" = agent-turn-complete ] || exit 0
  ACTION=complete
  read_notify_sid
fi

is_safe_id "$SID" || exit 0
if [ "$ACTION" != end ]; then
  read_turn_id
  if [ "$TURN_PRESENT" = 1 ]; then
    is_safe_id "$TURN_ID" || exit 0
  fi
fi

BUCKET="$BUCKET_DIR/$SID"
TURN_FILE="$TURN_DIR/$SID"

if [ "$ACTION" = start ]; then
  # A start is accepted only for a persisted root conversation. Ephemeral
  # internals and subagents have no matching user row and remain invisible.
  load_user_ids || exit 0
  is_active_root "$SID" || exit 0
  /bin/mkdir -p "$BUCKET_DIR" "$TURN_DIR" 2>/dev/null || exit 0
  prune_orphans

  if [ "$TURN_PRESENT" = 1 ]; then
    atomic_write "$TURN_FILE" "$TURN_ID" || exit 0
  else
    # Legacy starts without a turn id can only be completed by a matching
    # legacy completion. They cannot safely protect against delayed events.
    /bin/rm -f "$TURN_FILE" 2>/dev/null
  fi
  atomic_write "$BUCKET" working || exit 0
  aggregate
  exit 0
fi

if [ "$ACTION" = end ]; then
  if [ ! -f "$BUCKET" ]; then
    load_user_ids || exit 0
    is_persisted_root "$SID" || exit 0
  fi
  /bin/rm -f "$BUCKET" "$TURN_FILE" 2>/dev/null
  if [ "$DB_READ_OK" != 1 ]; then
    load_user_ids || true
  fi
  prune_orphans
  aggregate
  exit 0
fi

# Turn completions never create a bucket. A bucket proves an earlier start
# was accepted; database failure therefore does not prevent safe completion.
if [ ! -f "$BUCKET" ]; then
  load_user_ids || exit 0
  is_persisted_root "$SID" || exit 0
  prune_orphans
  aggregate
  exit 0
fi
if [ -f "$TURN_FILE" ]; then
  [ "$TURN_PRESENT" = 1 ] || exit 0
  CURRENT_TURN="$(<"$TURN_FILE")"
  [ "$CURRENT_TURN" = "$TURN_ID" ] || exit 0
fi

# Buckets migrated from v3 have no turn sidecar. Their completion is accepted
# with or without a turn id, but legacy events have no ordering guarantee.
if load_user_ids; then
  prune_orphans
  if [ ! -f "$BUCKET" ]; then
    aggregate
    exit 0
  fi
fi

atomic_write "$BUCKET" idle || exit 0
aggregate
exit 0
