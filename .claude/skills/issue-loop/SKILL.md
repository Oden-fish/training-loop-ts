---
name: issue-loop
description: GitHub Issue を1件、着手からPR作成（Phase 2 以降はマージ・クローズまで）まで一気に片付ける。ループの本体。番号を省略すると agent:ready の先頭を自動で拾う。
argument-hint: "[issue番号]"
allowed-tools:
  - Read
  - Grep
  - Glob
  - Edit
  - Write
  - Bash
  - Agent
  - Skill
  - TodoWrite
disallowed-tools:
  - AskUserQuestion
---

Issue **$ARGUMENTS** を片付けます。番号が空なら、対象は自分で選ばず
`./scripts/select-next-issue.sh` に選ばせてください。

```bash
./scripts/select-next-issue.sh   # 番号を1つ出力。終了コード 3 = キューが空 / 4 = 全件が前提待ち
```

無人ループ（`scripts/run-loop.sh`）と同じ規則をこのスクリプトが持っています。手で番号なしの
`/issue-loop` を叩いたときに判定がズレないよう、**自分で `gh issue list` を並べ替えて選ばないこと。**
規則は次のとおりです。

1. `agent:wip` が残っていれば、その中で最も番号が小さいものを再開する（依存は見ない）
2. なければ `agent:ready` のうち、**未クローズの前提 Issue（blocked by）を持たない**、
   最も番号が小さいもの
3. 終了コード 3（キューが空）または 4（候補はあるが全件が前提待ち）なら、着手せずに終了する

番号を明示的に渡された場合も、その Issue に未クローズの前提が無いかだけは確認してください。
残っていれば着手せず、「7. 詰まったとき」の手順で `agent:blocked` にします。

```bash
gh api "repos/:owner/:repo/issues/<N>/dependencies/blocked_by" --jq '[.[] | select(.state != "closed") | .number]'
```

> このスキルは無人で回ることを前提にしています。**人間に質問しないでください。**
> 判断できない状況になったら「7. 詰まったとき」の手順で `agent:blocked` にして終了します。

## 0. 前提の確認

- `git status` が clean であること。未コミットの変更があれば、それが前回の作業の残骸かを確認し、
  残骸なら `git stash` してから進む。
- `gh issue list --label agent:wip --state open` が**空**であること。
  残っていたら、新しい Issue に着手せず**その Issue の続きから再開**する（PR があるか、
  ブランチがあるかを確認して、下の該当ステップに合流する）。

## 1. 着手（ロックを取る）

```bash
gh issue view <N> --comments
gh issue edit <N> --add-label "agent:wip" --remove-label "agent:ready"
```

ラベルの付け替えが**ロック**です。これを最初にやることで、別セッションや再開時の二重着手を防ぎます。

## 2. 計画

`issue-planner` サブエージェントを使って実装計画を作ります。メインの文脈を調査ログで埋めないためです。

- 計画の「リスクと分からないこと」に人間の判断が要る項目があれば、**実装に入らず**「7. 詰まったとき」へ。
- 「1回のループで完了できるか: いいえ」なら、分割案を Issue にコメントして「7」へ。
- 問題なければ、受け入れ条件とテスト方針を Issue にコメントで残す（後から追跡できるように）。

```bash
gh issue comment <N> --body "$(cat .claude/tmp/plan-<N>.md)"
```

## 3. ブランチ

```bash
git switch <既定ブランチ> && git pull --ff-only
git switch -c feat/issue-<N>-<短いslug>
```

## 4. 実装

- **テストを先に書く。** 受け入れ条件ごとに、落ちることを確認してから実装する。
- 既存の書き方に合わせる（計画の「参照する既存実装」に従う）。
- コミットは意味のある単位で小さく。メッセージは `type(scope): 要約` + 本文に「なぜ」。
- **Issue のスコープ外を触らない。** 気づいた別の問題は、直さずに新しい Issue を立てる:
  `gh issue create --title "..." --body "..." --label "agent:ready"`
  立てた Issue が**この Issue の完了を前提にする**なら、依存を張っておく（張らないと、
  ループが前提の揃っていない Issue を拾ってしまう）:

  ```bash
  gh api --method POST "repos/:owner/:repo/issues/<新Issue番号>/dependencies/blocked_by" \
    -F issue_id="$(gh api repos/:owner/:repo/issues/<N> --jq '.id')"
  ```

## 5. ローカル検証

`./scripts/verify.sh`（無ければ `CLAUDE.md` の検証コマンド）を**緑になるまで**回します。
ここを飛ばして push しないこと。CI で落とすとループが1周分無駄になります。

## 6. PR 作成

```bash
git push -u origin HEAD
gh pr create --title "<Issueと対応するタイトル>" --body "$(cat <<'EOF'
## 概要
<何をなぜ変えたか>

## 受け入れ条件
- [x] ...

## 検証
<実行したコマンドと結果>

Closes #<N>
EOF
)"
gh issue edit <N> --add-label "agent:review" --remove-label "agent:wip"
```

`Closes #<N>` は必須です（マージ時の自動クローズと、レビュー時の照合に使います）。

## 7. CI を通す

```bash
gh pr checks <PR番号> --watch
```

赤ければ `ci-doctor` サブエージェントに原因を診断させ、その方針で最小の修正を入れて push。
**同じ失敗で3回直しても緑にならなければ「9. 詰まったとき」へ。**

## 8. 独立レビュー

`/review-pr <PR番号>` を実行します（`pr-reviewer` サブエージェントが別文脈で PR を見ます）。

- `VERDICT: APPROVE` → 「9. 着地」へ
- `VERDICT: REQUEST_CHANGES` → Blocking の指摘を**すべて**直し、5 → 7 → 8 をやり直す。
  ただし**レビューの往復は3回まで**。それでも Blocking が残るなら「10. 詰まったとき」へ。
- `VERDICT: BLOCKED` → 「10. 詰まったとき」へ

指摘に**反論する場合も直さない理由を PR にコメントする**こと。黙って無視しない。

## 9. 着地

`.claude/loop-phase` の値で分岐します。

- **Phase 1** — ここで終了。PR の URL と、レビューの要約を1行で報告する。
  マージと Issue クローズは人間が行う。ラベルは `agent:review` のまま残す。
- **Phase 2 / 3** — `/land-pr <PR番号>` を実行する。

## 10. 詰まったとき（必ずこの形で止まる）

```bash
gh issue edit <N> --add-label "agent:blocked" --remove-label "agent:wip"
gh issue comment <N> --body "エージェントが停止しました。

**何をしようとしたか**: ...
**どこで詰まったか**: ...
**試したこと**: ...
**人間に判断してほしいこと**: ...
**現在の状態**: ブランチ <branch> / PR <url or なし>
"
```

そのうえで、**次の Issue には進まずにターンを終了**します。
黙って諦めたり、スコープを勝手に狭めて「完了」と報告したりしないこと。

## 完了の定義

このスキルが「完了」と言ってよいのは次のいずれかだけです。

- Phase 1: PR が作成され、CI が緑で、`pr-reviewer` が APPROVE を返し、ラベルが `agent:review` になった
- Phase 2/3: PR がマージされ、Issue が closed になった
- どのフェーズでも: `agent:blocked` が付き、理由がコメントされた
