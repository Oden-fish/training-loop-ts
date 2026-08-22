---
name: land-pr
description: Phase 2 以降で PR をマージし、対応する Issue をクローズしてブランチを片付ける。マージ前に merge-gatekeeper で機械的なゲートを通す。
argument-hint: "<PR番号>"
allowed-tools:
  - Read
  - Bash
  - Agent
disallowed-tools:
  - AskUserQuestion
---

PR **$ARGUMENTS** を着地させます。

## 0. フェーズ確認

`.claude/loop-phase` が `2` 以上であること。`1` なら**何もせず**、
「Phase 1 のためマージは人間が行う」と報告して終了。

## 1. ゲート

`merge-gatekeeper` サブエージェントを起動し、`DECISION` を得る。

- `NO_GO` → 未達項目を PR にコメントし、`/issue-loop` の「詰まったとき」の手順で
  Issue を `agent:blocked` にして終了。**自分でゲートを甘くしない。**
- `GO` → 次へ

## 2. マージ

```bash
gh pr merge $ARGUMENTS --squash --delete-branch
```

`--admin` は使わない（保護ルールの迂回は禁止。フックが止めます）。

## 3. 後片付け

```bash
git switch <既定ブランチ> && git pull --ff-only
gh issue edit <Issue番号> --remove-label "agent:review" --add-label "agent:done"
gh issue view <Issue番号> --json state --jq .state   # closed になっているか確認
```

`Closes #<N>` があれば自動でクローズされます。されていなければ `gh issue close <N> --comment "PR #$ARGUMENTS でマージ済み"`。

## 4. 報告

1行で: `#<Issue番号> 完了 / PR #$ARGUMENTS マージ済み / 残りの agent:ready は N 件`
