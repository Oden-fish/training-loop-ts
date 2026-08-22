#!/usr/bin/env bash
# SessionStart: 「いまループのどこにいるか」をセッション冒頭で毎回注入する。
# これがないと、再開したセッションが状況を再調査するところから始まってしまう。
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PHASE="$(loop_phase)"
BRANCH="$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
DIRTY="$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"

READY=""; WIP=""; REVIEW=""; PRS=""
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  READY="$(gh issue list --label 'agent:ready'  --state open --limit 20 --json number,title \
            --jq '[.[] | "#\(.number) \(.title)"] | join("\n")' 2>/dev/null)"
  WIP="$(gh issue list --label 'agent:wip'    --state open --limit 20 --json number,title \
            --jq '[.[] | "#\(.number) \(.title)"] | join("\n")' 2>/dev/null)"
  REVIEW="$(gh issue list --label 'agent:review' --state open --limit 20 --json number,title \
            --jq '[.[] | "#\(.number) \(.title)"] | join("\n")' 2>/dev/null)"
  PRS="$(gh pr list --state open --limit 20 --json number,title,isDraft \
            --jq '[.[] | "#\(.number) \(.title)\(if .isDraft then " (draft)" else "" end)"] | join("\n")' 2>/dev/null)"
fi

CTX="$(cat <<EOF
## ループの現在地 (SessionStart フックが自動生成)

- 自律フェーズ: Phase ${PHASE}  (1=PR作成まで / 2=マージまで / 3=無人でキュー消化)
- 現在のブランチ: ${BRANCH}
- 未コミットの変更: ${DIRTY} 件

### 着手待ち (agent:ready)
${READY:-なし}

### 作業中 (agent:wip)  ※ここに残っていたら、まずこの Issue を片付ける
${WIP:-なし}

### レビュー/マージ待ち (agent:review)
${REVIEW:-なし}

### オープンな PR
${PRS:-なし}

作業を始める前に、agent:wip が残っていないかを必ず確認すること。
EOF
)"

jq -n --arg ctx "$CTX" '{
  hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: $ctx }
}'
echo "[loop] Phase ${PHASE} / branch ${BRANCH} / dirty ${DIRTY}" >&2
exit 0
