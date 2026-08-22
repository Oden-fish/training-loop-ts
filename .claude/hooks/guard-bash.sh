#!/usr/bin/env bash
# PreToolUse(Bash): ループが踏んではいけない操作を決定論的に止める。
# 権限ルール(settings.json の deny)と二重化しているのは意図的。
# deny ルールは「コマンド文字列」に効き、こちらは「文脈(ブランチ・フェーズ)」に効く。
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

INPUT="$(cat)"
CMD="$(jq -r '.tool_input.command // ""' <<<"$INPUT")"
[[ -z "$CMD" ]] && exit 0

PHASE="$(loop_phase)"
BRANCH="$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
DEFAULT="$(default_branch)"; DEFAULT="${DEFAULT:-main}"

# 1. 履歴破壊は常に禁止
if grep -Eq '(^|[;&|]\s*)git\s+push\b.*(--force|-f\b)' <<<"$CMD"; then
  deny "force push はこのリポジトリでは禁止です。履歴を書き換えず、追加コミットで修正してください。"
fi
if grep -Eq '(^|[;&|]\s*)git\s+(reset\s+--hard|filter-branch|clean\s+-[a-z]*f)' <<<"$CMD"; then
  deny "作業ツリーを破壊するコマンドは禁止です。git stash か新しいコミットで対応してください。"
fi

# 2. 既定ブランチへの直接コミット/直接 push を禁止（必ず PR 経由）
if [[ "$BRANCH" == "$DEFAULT" ]] && grep -Eq '(^|[;&|]\s*)git\s+commit\b' <<<"$CMD"; then
  deny "既定ブランチ ($DEFAULT) への直接コミットは禁止です。まず 'git switch -c feat/issue-<番号>-<slug>' で作業ブランチを作ってください。"
fi
if grep -Eq "(^|[;&|]\s*)git\s+push\b.*\b(origin\s+)?(HEAD:)?($DEFAULT|master|main)\b" <<<"$CMD"; then
  deny "既定ブランチへの直接 push は禁止です。作業ブランチを push して PR を作成してください。"
fi

# 3. フェーズによる着地操作のゲート
if [[ "$PHASE" -lt 2 ]]; then
  if grep -Eq '(^|[;&|]\s*)gh\s+pr\s+merge\b' <<<"$CMD"; then
    deny "現在は Phase $PHASE です。マージは人間が行います。PR の URL を報告して、この Issue の作業を終了してください。"
  fi
  if grep -Eq '(^|[;&|]\s*)gh\s+issue\s+close\b' <<<"$CMD"; then
    deny "現在は Phase $PHASE です。Issue のクローズは人間が行います。ラベルを agent:review に更新するだけにしてください。"
  fi
fi
if [[ "$PHASE" -lt 3 ]] && grep -Eq '(^|[;&|]\s*)gh\s+pr\s+merge\b.*--admin' <<<"$CMD"; then
  deny "--admin による保護ルールの迂回は禁止です。CI とレビューを通してからマージしてください。"
fi

# 4. 秘密情報の露出を止める
if grep -Eq '(cat|less|head|tail|strings|base64)\s+[^|;&]*\.env' <<<"$CMD"; then
  deny ".env の内容を読み出すことは禁止です。必要なキー名だけを .env.example から確認してください。"
fi

exit 0
