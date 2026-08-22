#!/usr/bin/env bash
# 無人ループを headless(claude -p) で回す。リポジトリのルートで実行する。
#
#   ./scripts/run-loop.sh              # agent:ready が尽きるまで、1件ずつ
#   MAX_ISSUES=3 ./scripts/run-loop.sh # 最大3件で止める
#
# 1 Issue = 1 プロセス にしているのは意図的:
#   - 文脈が Issue ごとにリセットされ、前の Issue の思い込みを持ち越さない
#   - 1件が暴走してもプロセス終了で確実に止まる
#   - ログが Issue 単位で分かれる
set -euo pipefail

MAX_ISSUES="${MAX_ISSUES:-20}"
MAX_TURNS="${MAX_TURNS:-120}"
LOG_DIR="${LOG_DIR:-.claude/logs}"
mkdir -p "$LOG_DIR"

command -v gh >/dev/null || { echo "gh が必要です" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gh auth login を実行してください" >&2; exit 1; }

# 前提: 作業ツリーが clean で、既定ブランチが緑であること
[[ -z "$(git status --porcelain)" ]] || { echo "作業ツリーに未コミットの変更があります" >&2; exit 1; }

SELECT="$(dirname "$0")/select-next-issue.sh"

count=0
while (( count < MAX_ISSUES )); do
  # どの Issue に着手するかの規則は select-next-issue.sh が持つ（そちらにテストがある）
  set +e
  N="$(bash "$SELECT")"
  pick_rc=$?
  set -e
  case $pick_rc in
    0) ;;
    3) echo "キューは空です。終了します。"; break ;;
    4) echo "着手できる Issue がありません（候補はすべて前提 Issue の完了待ちです）。終了します。"; break ;;
    *) echo "Issue の選択に失敗しました (exit $pick_rc)。" >&2; exit $pick_rc ;;
  esac

  count=$((count+1))
  TS="$(date -u +%Y%m%dT%H%M%SZ)"
  LOG="$LOG_DIR/issue-${N}-${TS}.jsonl"
  echo "=== [$count/$MAX_ISSUES] Issue #$N を開始 (log: $LOG)"

  set +e
  claude -p "/issue-loop $N" \
    --permission-mode auto \
    --max-turns "$MAX_TURNS" \
    --output-format stream-json --verbose --include-partial-messages \
    > "$LOG" 2>"$LOG.err"
  rc=$?
  set -e

  # 結果と実コストを取り出す
  jq -r 'select(.type=="result") | "  結果: \(.subtype)  ターン数: \(.num_turns // "-")  費用: $\(.total_cost_usd // 0)"' \
    "$LOG" 2>/dev/null || true

  if [[ $rc -ne 0 ]]; then
    echo "  claude が異常終了しました (exit $rc)。ループを止めます。$LOG.err を確認してください。" >&2
    exit $rc
  fi

  # blocked になったら、そこで人間の判断を待つ
  if gh issue view "$N" --json labels --jq '.labels[].name' | grep -q '^agent:blocked$'; then
    echo "  Issue #$N が agent:blocked になりました。人間の判断待ちのため停止します。"
    break
  fi

  # 前進していない場合の保険: wip のまま残っていたら無限ループを避けて止める
  if gh issue view "$N" --json labels --jq '.labels[].name' | grep -q '^agent:wip$'; then
    echo "  Issue #$N が agent:wip のままです。前進していないため停止します。" >&2
    break
  fi
done

echo "=== ループ終了。$count 件を処理しました。"
