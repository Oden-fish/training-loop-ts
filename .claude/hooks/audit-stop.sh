#!/usr/bin/env bash
# Stop: 1ターン終わるごとに監査ログを1行残す。
# 無人運転では「何が起きたか」を後から追える線形のログが唯一の手がかりになる。
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

INPUT="$(cat)"
LOG="$PROJECT_DIR/.claude/loop.log"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
BRANCH="$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '-')"
HEAD_SHA="$(git -C "$PROJECT_DIR" rev-parse --short HEAD 2>/dev/null || echo '-')"
DIRTY="$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
MSG="$(jq -r '.last_assistant_message // "" | gsub("\\s+"; " ") | .[0:180]' <<<"$INPUT")"
SID="$(jq -r '.session_id // "-"' <<<"$INPUT")"

printf '%s\tsession=%s\tbranch=%s\thead=%s\tdirty=%s\t%s\n' \
  "$TS" "$SID" "$BRANCH" "$HEAD_SHA" "$DIRTY" "$MSG" >> "$LOG"
exit 0
