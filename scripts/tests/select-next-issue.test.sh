#!/usr/bin/env bash
# scripts/select-next-issue.sh のテスト。
# gh をスタブに差し替え、「どの Issue を選ぶか」だけを検証する。
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$HERE/../select-next-issue.sh"
STUB="$HERE/gh-stub.sh"

FAILURES=0
CURRENT=""

ok() { echo "  ok   - $CURRENT"; }
ng() {
  echo "  FAIL - $CURRENT" >&2
  printf '         %s\n' "$@" >&2
  FAILURES=$((FAILURES + 1))
}

assert_eq() { # 期待値 実際値 ラベル
  if [[ "$1" == "$2" ]]; then return 0; fi
  ng "$3: 期待 '$1' / 実際 '$2'"
  return 1
}

assert_contains() { # 部分文字列 実際値 ラベル
  if [[ "$2" == *"$1"* ]]; then return 0; fi
  ng "$3: '$1' を含むはずが、実際は '$2'"
  return 1
}

# --- fixture 操作 ---------------------------------------------------------

setup() { # テスト名
  CURRENT="$1"
  FIXTURES="$(mktemp -d)"
  export FIXTURES
  printf '[]\n' >"$FIXTURES/issues-agent-wip.json"
  printf '[]\n' >"$FIXTURES/issues-agent-ready.json"
}

teardown() { rm -rf "$FIXTURES"; }

with_label() { # ラベル(wip|ready) 番号...
  local label="$1"
  shift
  jq -n --argjson ns "[$(
    IFS=,
    echo "$*"
  )]" '[$ns[] | {number: .}]' >"$FIXTURES/issues-agent-$label.json"
}

blocked_by() { # 番号 "前提番号:state"...
  local n="$1"
  shift
  local out="[]" spec
  for spec in "$@"; do
    out="$(jq -c --argjson num "${spec%%:*}" --arg st "${spec##*:}" \
      '. + [{number: $num, state: $st}]' <<<"$out")"
  done
  printf '%s\n' "$out" >"$FIXTURES/blocked-by-$n.json"
}

# 標準出力を STDOUT に、標準エラーを STDERR に、終了コードを RC に入れる
run_target() {
  STDOUT="$(GH="$STUB" bash "$TARGET" 2>"$FIXTURES/stderr")"
  RC=$?
  STDERR="$(cat "$FIXTURES/stderr")"
}

# --- テスト ---------------------------------------------------------------

# スタブは本物と同じく新しい順（番号の降順）に返し、--limit も API 側で先に効かせる。
# なので「--limit で絞ってから sort する」実装（元のバグ）だとここで最新の 5 が返り、落ちる。
setup "agent:ready のうち番号が最も小さいものを選ぶ"
with_label ready 5 3 4
run_target
assert_eq "3" "$STDOUT" "選ばれた Issue" && assert_eq "0" "$RC" "終了コード" && ok
teardown

setup "未クローズの前提を持つ Issue はスキップして次の候補を選ぶ"
with_label ready 3 4
blocked_by 3 "2:open"
run_target
assert_eq "4" "$STDOUT" "選ばれた Issue" &&
  assert_contains "#3" "$STDERR" "スキップの通知" &&
  ok
teardown

setup "前提がすべてクローズ済みなら選ばれる"
with_label ready 3 4
blocked_by 3 "1:closed" "2:closed"
run_target
assert_eq "3" "$STDOUT" "選ばれた Issue" && ok
teardown

setup "前提が一部でも未クローズならスキップする"
with_label ready 3 4
blocked_by 3 "1:closed" "2:open"
run_target
assert_eq "4" "$STDOUT" "選ばれた Issue" && ok
teardown

setup "agent:wip が残っていれば agent:ready より優先し、番号が小さいものを選ぶ"
with_label wip 7 6
with_label ready 3
run_target
assert_eq "6" "$STDOUT" "選ばれた Issue" && ok
teardown

setup "agent:wip は前提が未クローズでもスキップしない"
with_label wip 7
with_label ready 3
blocked_by 7 "2:open"
run_target
assert_eq "7" "$STDOUT" "選ばれた Issue" && ok
teardown

setup "候補が1件も無ければ、何も出力せずキューが空を示す終了コードを返す"
run_target
assert_eq "" "$STDOUT" "標準出力" && assert_eq "10" "$RC" "終了コード" && ok
teardown

setup "候補が全部前提待ちなら、キューが空とは別の終了コードを返す"
with_label ready 3 4
blocked_by 3 "2:open"
blocked_by 4 "2:open"
run_target
assert_eq "" "$STDOUT" "標準出力" && assert_eq "11" "$RC" "終了コード" && ok
teardown

setup "依存 API が使えない環境では、依存なしとみなして番号順で選ぶ"
with_label ready 3 4
blocked_by 3 "2:open"
GH_STUB_FAIL_API=1 run_target
unset GH_STUB_FAIL_API
assert_eq "3" "$STDOUT" "選ばれた Issue" &&
  assert_eq "0" "$RC" "終了コード" &&
  assert_contains "依存を確認できませんでした" "$STDERR" "確認できなかった旨の通知" &&
  ok
teardown

# gh は認証切れやレートリミットで 4 を返す。自前の終了コードがそれと衝突していると、
# ループが「全件が前提待ち」と誤読して静かに正常終了してしまう。
setup "gh 自体が失敗したときは、キューが空とも前提待ちとも違う終了コードで落ちる"
with_label ready 3 4
GH_STUB_FAIL_LIST=4 run_target
unset GH_STUB_FAIL_LIST
assert_eq "" "$STDOUT" "標準出力" &&
  { [[ "$RC" != "10" && "$RC" != "11" && "$RC" != "0" ]] || ng "終了コード: 10/11/0 以外のはずが '$RC'"; } &&
  assert_contains "gh issue list に失敗" "$STDERR" "失敗の通知" &&
  ok
teardown

setup "改行に CR が混ざる環境でも、前提の有無を正しく判定する"
with_label ready 3 4
blocked_by 3 "2:open"
GH_STUB_CRLF=1 run_target
unset GH_STUB_CRLF
assert_eq "4" "$STDOUT" "選ばれた Issue" && assert_eq "0" "$RC" "終了コード" && ok
teardown

# --- 結果 -----------------------------------------------------------------

if ((FAILURES > 0)); then
  echo "select-next-issue: $FAILURES 件失敗" >&2
  exit 1
fi
echo "select-next-issue: すべて成功"
