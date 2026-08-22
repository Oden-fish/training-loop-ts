#!/usr/bin/env bash
# 次に着手すべき Issue 番号を1つだけ標準出力に返す。
#
# 選び方:
#   1. agent:wip が残っていれば、その中で最も番号が小さいものを返す。
#      着手済みのものを依存で止める理由はないので、依存は見ない。
#   2. なければ agent:ready のうち、未クローズの前提 Issue (blocked by) を持たない、
#      最も番号が小さいものを返す。
#
# 「番号の昇順」はタイブレークで、着手可否のゲートは依存関係が持つ。
# 依存は GitHub ネイティブの Issue dependencies を使う。人間が Issue の UI から張れて、
# PR のマージで前提 Issue が閉じれば自動的に解けるため。
#
# 終了コード:
#   0  候補を1件出力した
#   3  候補が1件も無い（キューが空）
#   4  候補はあるが、すべて前提 Issue の完了待ち
set -euo pipefail

# テストからスタブに差し替えられるようにしておく
GH="${GH:-gh}"
LIMIT="${ISSUE_LIST_LIMIT:-200}"

# ラベルの付いた open Issue の番号を、昇順で1行ずつ返す。
# --limit は API 側で先に効くので、絞ってから sort しても古い順にはならない。
# 必ず十分な件数を取ってから jq で並べ替えること。
# tr は CR の除去。Windows 環境では改行に CR が混ざり、番号の比較や空判定が壊れる。
numbers_by_label() {
  "$GH" issue list --label "$1" --state open --limit "$LIMIT" \
    --json number --jq 'sort_by(.number) | .[].number' | tr -d '\r'
}

# 未クローズの前提 Issue の番号を空白区切りで返す。
# 依存 API が無い環境では空を返し、依存なしとして扱う（機能ごと落とさないため）。
open_blockers() {
  "$GH" api "repos/:owner/:repo/issues/$1/dependencies/blocked_by" \
    --jq '[.[] | select(.state != "closed") | .number] | join(" ")' 2>/dev/null |
    tr -d '\r' || true
}

wip="$(numbers_by_label 'agent:wip')"
if [[ -n "$wip" ]]; then
  printf '%s\n' "${wip%%$'\n'*}"
  exit 0
fi

ready="$(numbers_by_label 'agent:ready')"
[[ -z "$ready" ]] && exit 3

while IFS= read -r n; do
  [[ -z "$n" ]] && continue
  blockers="$(open_blockers "$n")"
  if [[ -z "$blockers" ]]; then
    printf '%s\n' "$n"
    exit 0
  fi
  echo "Issue #$n: 前提 Issue が未完了のためスキップ (blocked by: #${blockers// /, #})" >&2
done <<<"$ready"

exit 4
