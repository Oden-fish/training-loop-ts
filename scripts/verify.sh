#!/usr/bin/env bash
# ローカルと CI で共有する唯一の検証コマンド。
#   ./scripts/verify.sh          整形チェック + 型 + テスト + カバレッジ下限
#   ./scripts/verify.sh --fast   テストだけ（実装ループ中の高速確認用）
#   ./scripts/verify.sh --fix    prettier を当ててから全部走らせる
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-}"

if [[ "$MODE" == "--fix" ]]; then
  echo "==> fix" && npx prettier --write "src/**/*.ts" "tests/**/*.ts"
  MODE=""
fi

if [[ "$MODE" == "--fast" ]]; then
  npx vitest run
  echo "OK"
  exit 0
fi

echo "==> format"    && npx prettier --check "src/**/*.ts" "tests/**/*.ts"
echo "==> typecheck" && npx tsc --noEmit
# カバレッジ下限は vitest.config.ts の thresholds が判定する
echo "==> test"      && npx vitest run --coverage
echo "OK"
