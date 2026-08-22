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

# scripts/*.sh のテスト。gh をスタブに差し替えて動くので、ネットワークも認証も要らない。
# 1件も見つからないのは「テストを消した / 移動した」ときなので、黙って飛ばさず失敗させる。
run_shell_tests() {
  local t count=0
  shopt -s nullglob
  for t in scripts/tests/*.test.sh; do
    bash "$t"
    count=$((count + 1))
  done
  shopt -u nullglob
  if ((count == 0)); then
    echo "scripts/tests/*.test.sh が1件も見つかりません" >&2
    return 1
  fi
}

if [[ "$MODE" == "--fast" ]]; then
  npx vitest run
  echo "==> shell tests" && run_shell_tests
  echo "OK"
  exit 0
fi

echo "==> format"    && npx prettier --check "src/**/*.ts" "tests/**/*.ts"
echo "==> typecheck" && npx tsc --noEmit
# カバレッジ下限は vitest.config.ts の thresholds が判定する
echo "==> test"      && npx vitest run --coverage
echo "==> shell tests" && run_shell_tests
echo "OK"
