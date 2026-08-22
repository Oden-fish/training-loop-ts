#!/usr/bin/env bash
# テスト用の gh スタブ。$FIXTURES 配下の JSON を、本物の gh と同じように扱って返す。
#
# 本物に寄せている点（ここを手を抜くと、再現したいバグがテストをすり抜ける）:
#   - issue list は既定で新しい順（番号の降順）に返す
#   - --limit は API 側で先に効く。つまり「降順に並べてから先頭 N 件」を切り、
#     そのあとで --jq の式に渡す
#   - --jq は決め打ちの文字列ではなく、実際に jq を通す（jq 式が壊れれば落ちる）
#
# 読むファイル:
#   $FIXTURES/issues-<label>.json   ラベルは ':' を '-' に置換 (agent:ready -> agent-ready)
#   $FIXTURES/blocked-by-<N>.json   無ければ「依存なし」とみなす
#
# 環境変数（異常系の再現用）:
#   GH_STUB_FAIL_API=1    api サブコマンドを失敗させる（依存 API が無い環境）
#   GH_STUB_FAIL_LIST=4   issue サブコマンドを指定の終了コードで失敗させる
#                         （gh は認証切れやレートリミットで 4 を返すことがある）
#   GH_STUB_CRLF=1        出力の改行を CRLF にする（Windows の環境を再現）
set -uo pipefail

emit() { # 標準出力へ。CRLF モードなら行末に CR を付ける
  if [[ "${GH_STUB_CRLF:-0}" == "1" ]]; then
    sed 's/$/\r/'
  else
    cat
  fi
}

sub="${1:-}"
shift || true

case "$sub" in
  issue)
    if [[ "${GH_STUB_FAIL_LIST:-0}" != "0" ]]; then
      echo "gh: To get started with GitHub CLI, please run: gh auth login" >&2
      exit "$GH_STUB_FAIL_LIST"
    fi
    label=""
    filter="."
    limit=""
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
        --limit)
          limit="$2"
          shift 2
          ;;
        *) shift ;;
      esac
    done
    file="$FIXTURES/issues-${label//:/-}.json"
    [[ -f "$file" ]] || file=""
    data="$([[ -n "$file" ]] && cat "$file" || printf '[]')"
    data="$(jq -c 'sort_by(.number) | reverse' <<<"$data")"
    [[ -n "$limit" ]] && data="$(jq -c --argjson n "$limit" '.[0:$n]' <<<"$data")"
    jq -r "$filter" <<<"$data" | emit
    ;;
  api)
    if [[ "${GH_STUB_FAIL_API:-0}" == "1" ]]; then
      echo "gh: dependencies API is unavailable" >&2
      exit 1
    fi
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
    data="$([[ -f "$file" ]] && cat "$file" || printf '[]')"
    jq -r "$filter" <<<"$data" | emit
    ;;
  *)
    echo "gh-stub: 未対応のサブコマンド: $sub" >&2
    exit 64
    ;;
esac
