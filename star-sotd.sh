#!/usr/bin/env bash
# Star unstarred SOTD messages in a WhatsApp group via wacli.
# FTS5 search is case-insensitive, so "sotd" matches SOTD, SotD, Sotd, etc.
# Run periodically (e.g. cron) to keep the star list current.
#
# Optional env vars:
#   WACLI          path to the wacli binary (used if wacli is not in PATH)
#   WA_GROUP_NAME  group name to look up (default: "sotd discussion forum")
#   SOTD_KEYWORD   FTS5 search term (default: sotd)
#   SEARCH_DAYS    look-back window in days (default: 7)
#   SOTD_LIMIT     max messages to retrieve per search (default: 500)
set -euo pipefail

if command -v wacli &>/dev/null; then
    WACLI=wacli
elif [ -n "${WACLI:-}" ]; then
    : # use as-is
else
    echo "Error: wacli not found in PATH and WACLI env var is not set" >&2
    exit 1
fi
WA_GROUP_NAME="${WA_GROUP_NAME:-sotd discussion forum}"
KEYWORD="${SOTD_KEYWORD:-sotd}"
SEARCH_DAYS="${SEARCH_DAYS:-7}"
LIMIT="${SOTD_LIMIT:-500}"

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
AFTER=$(date -d "${SEARCH_DAYS} days ago" +%Y-%m-%d)

echo "[$(ts)] Syncing messages from WhatsApp..."
"$WACLI" sync --once

echo "[$(ts)] Looking up JID for '$WA_GROUP_NAME'..."
WA_GROUP=$("$WACLI" groups list --json \
    | jq -r --arg name "$WA_GROUP_NAME" '.data[] | select(.Name == $name) | .JID' \
    | head -1)
if [ -z "$WA_GROUP" ]; then
    echo "Error: no group found with name '$WA_GROUP_NAME'" >&2
    exit 1
fi
echo "[$(ts)] Group JID: $WA_GROUP"

echo "[$(ts)] Searching '$KEYWORD' in '$WA_GROUP_NAME' since $AFTER (limit $LIMIT)..."
RESULTS=$("$WACLI" messages search "$KEYWORD" \
    --chat "$WA_GROUP" \
    --after "$AFTER" \
    --limit "$LIMIT" \
    --json)

mapfile -t PAIRS < <(printf '%s' "$RESULTS" \
    | jq -r '.data.messages[] | select(.Starred == false) | "\(.ChatJID)\t\(.MsgID)"')

if [ "${#PAIRS[@]}" -eq 0 ]; then
    echo "[$(ts)] No unstarred SOTD messages found."
    exit 0
fi

COUNT=0
for pair in "${PAIRS[@]}"; do
    chat_jid="${pair%%$'\t'*}"
    msg_id="${pair##*$'\t'}"
    echo "[$(ts)] Starring $msg_id in $chat_jid"
    "$WACLI" messages star --chat "$chat_jid" --id "$msg_id"
    COUNT=$((COUNT + 1))
done

echo "[$(ts)] Done. Starred $COUNT message(s)."
