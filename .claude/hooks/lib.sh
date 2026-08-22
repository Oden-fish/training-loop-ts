#!/usr/bin/env bash
# 共通ヘルパー。各フックから source される。
set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
PHASE_FILE="$PROJECT_DIR/.claude/loop-phase"

# 現在の自律フェーズ (1=PR止まり / 2=マージまで / 3=完全無人)
loop_phase() {
  if [[ -n "${LOOP_PHASE:-}" ]]; then echo "$LOOP_PHASE"; return; fi
  if [[ -f "$PHASE_FILE" ]]; then tr -dc '0-9' < "$PHASE_FILE" | head -c1; return; fi
  echo 1
}

# PreToolUse を deny して理由を Claude に返す
deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

default_branch() {
  git -C "$PROJECT_DIR" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null \
    | sed 's#^origin/##' || true
}
