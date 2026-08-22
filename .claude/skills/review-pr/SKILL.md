---
name: review-pr
description: 指定した Pull Request を、実装した文脈から切り離した独立エージェントでレビューし、結果を PR にコメントする。実装直後に必ず実行する。
argument-hint: "<PR番号>"
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Agent
disallowed-tools:
  - AskUserQuestion
---

PR **$ARGUMENTS** をレビューします。

1. レビュー対象の HEAD SHA を記録する: `gh pr view $ARGUMENTS --json headRefOid`
2. `pr-reviewer` サブエージェントを起動し、PR 番号だけを渡す。
   **あなた（メインセッション）の実装意図や「ここは意図的にこうした」といった説明を渡さないこと。**
   独立性がこのステップの価値そのものです。
3. 返ってきた結果を `.claude/tmp/review-$ARGUMENTS.md` に保存する。1行目に対象 SHA を書く。
4. PR にコメントとして投稿する:

```bash
mkdir -p .claude/tmp
gh pr comment $ARGUMENTS --body-file .claude/tmp/review-$ARGUMENTS.md
```

5. 呼び出し元には `VERDICT` の値と Blocking 指摘の件数だけを1行で返す。

## 注意

- レビューは**差分が変わるたびにやり直す**。修正を push したら、このスキルをもう一度実行すること。
  `.claude/tmp/review-<N>.md` の SHA が現在の HEAD と違う場合、そのレビュー結果は無効です。
- レビュー結果を自分で書かない。必ずサブエージェントの出力をそのまま使う。
