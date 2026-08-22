---
name: loop-status
description: ループの現在地（フェーズ、キューの各ラベル件数、オープンPR、直近の監査ログ）を1画面にまとめて表示する。
allowed-tools:
  - Read
  - Bash(gh *)
  - Bash(git *)
  - Bash(tail *)
  - Bash(cat *)
---

以下を実行して、表形式で簡潔に報告してください。推測で埋めず、コマンドの出力だけを使うこと。

```bash
echo "phase=$(cat .claude/loop-phase 2>/dev/null || echo 1)"
for L in agent:ready agent:wip agent:review agent:blocked; do
  printf '%-16s %s\n' "$L" "$(gh issue list --label "$L" --state open --json number --jq 'length')"
done
gh pr list --state open --json number,title,statusCheckRollup \
  --jq '.[] | "#\(.number) \(.title)"'
tail -n 10 .claude/loop.log 2>/dev/null
```

最後に「次にやるべきこと」を1行で示す:
- `agent:wip` が残っている → その Issue の再開
- `agent:blocked` がある → 人間の判断待ち。Issue 番号と論点を列挙
- `agent:review` がある（Phase 1）→ 人間のマージ待ち
- それ以外で `agent:ready` がある → `/issue-loop` を実行
- すべて空 → 完了
