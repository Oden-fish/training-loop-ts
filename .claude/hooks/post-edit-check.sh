#!/usr/bin/env bash
# PostToolUse(Edit|Write): 変更されたファイルだけを整形し、明らかな構文/lint エラーを
# その場で Claude に差し戻す。ここで潰しておくと PR レビューが本質的な指摘に集中する。
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

INPUT="$(cat)"
FILE="$(jq -r '.tool_input.file_path // ""' <<<"$INPUT")"
[[ -z "$FILE" || ! -f "$FILE" ]] && exit 0

OUT=""; RC=0
case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs)
    BIN="$PROJECT_DIR/node_modules/.bin"
    [[ -x "$BIN/prettier" ]] && "$BIN/prettier" --write "$FILE" >/dev/null 2>&1
    if [[ -x "$BIN/eslint" ]]; then
      if OUT="$(cd "$PROJECT_DIR" && "$BIN/eslint" --max-warnings=0 "$FILE" 2>&1)"; then :; else RC=1; fi
    elif [[ -x "$BIN/tsc" && "$FILE" == *.ts ]]; then
      if OUT="$(cd "$PROJECT_DIR" && "$BIN/tsc" --noEmit 2>&1)"; then :; else RC=1; fi
    fi
    ;;
  *.py)
    command -v ruff >/dev/null && ruff format "$FILE" >/dev/null 2>&1
    if command -v ruff >/dev/null; then
      if OUT="$(ruff check "$FILE" 2>&1)"; then :; else RC=1; fi
    fi
    ;;
  *.json)
    if OUT="$(python3 -m json.tool "$FILE" 2>&1 >/dev/null)"; then :; else RC=1; fi
    ;;
  *.sh)
    if OUT="$(bash -n "$FILE" 2>&1)"; then :; else RC=1; fi
    ;;
  *.go)
    # gofmt は構文エラーでも落ちるので、整形と構文チェックを兼ねる
    if OUT="$(gofmt -l -w "$FILE" 2>&1)"; then :; else RC=1; fi
    ;;
  *.dart)
    if command -v dart >/dev/null; then
      dart format "$FILE" >/dev/null 2>&1
      if OUT="$(cd "$PROJECT_DIR" && dart analyze "$FILE" 2>&1)"; then :; else RC=1; fi
    fi
    ;;
  *.java|*.kts)
    # Java/Kotlin DSL は1ファイル単位の高速チェックが無いので、ここでは何もしない。
    # 整形と静的解析は ./scripts/verify.sh (Spotless + Checkstyle) がまとめて行う。
    :
    ;;
  *.yaml|*.yml)
    # PyYAML が無い環境では黙って飛ばす（検査は CI 側に任せる）
    if command -v python3 >/dev/null && python3 -c "import yaml" 2>/dev/null; then
      if OUT="$(python3 "$PROJECT_DIR/.claude/hooks/check_yaml.py" "$FILE" 2>&1)"; then :; else RC=1; fi
    fi
    ;;
esac

if [[ $RC -ne 0 ]]; then
  # PostToolUse の exit 2 はツール呼び出しを止めないが、stderr が Claude に渡る。
  echo "自動チェックが $FILE で失敗しました。次の指摘を直してから先に進んでください:" >&2
  echo "$OUT" | head -40 >&2
  exit 2
fi
exit 0
