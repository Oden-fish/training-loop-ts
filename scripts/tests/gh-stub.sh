#!/usr/bin/env bash
# テスト用の gh スタブ。$FIXTURES 配下の JSON を、本物の gh と同じように
# --jq の式に通して返す。--jq 式そのものもテスト対象にしたいので、
# 決め打ちの文字列を返すのではなく実際に jq を通している。
#
# 読むファイル:
#   $FIXTURES/issues-<label>.json   ラベルは ':' を '-' に置換 (agent:ready -> agent-ready)
#   $FIXTURES/blocked-by-<N>.json   無ければ「依存なし」とみなす
#
# $GH_STUB_FAIL_API=1 のとき、api サブコマンドを失敗させる（依存 API が無い環境の再現）。
set -uo pipefail

sub="${1:-}"
shift || true

case "$sub" in
  issue)
    label=""
    filter="."
    while (($#)); do
      case "$1" in
        --label)
          label="$2"
          shift 2
          ;;
        --jq)
          filter="$2"
          shift 2
          ;;
        *) shift ;;
      esac
    done
    file="$FIXTURES/issues-${label//:/-}.json"
    [[ -f "$file" ]] || printf '[]\n' >"$file"
    jq -r "$filter" "$file"
    ;;
  api)
    [[ "${GH_STUB_FAIL_API:-0}" == "1" ]] && {
      echo "gh: dependencies API is unavailable" >&2
      exit 1
    }
    path="${1:-}"
    shift || true
    filter="."
    while (($#)); do
      case "$1" in
        --jq)
          filter="$2"
          shift 2
          ;;
        *) shift ;;
      esac
    done
    num="${path#*/issues/}"
    num="${num%%/*}"
    file="$FIXTURES/blocked-by-${num}.json"
    [[ -f "$file" ]] || file="/dev/null"
    if [[ "$file" == "/dev/null" ]]; then
      printf '[]\n' | jq -r "$filter"
    else
      jq -r "$filter" "$file"
    fi
    ;;
  *)
    echo "gh-stub: 未対応のサブコマンド: $sub" >&2
    exit 64
    ;;
esac
