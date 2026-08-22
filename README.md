# Loop Engineering の練習リポジトリ (ver Typescript)

Claude Code を用いた Loop Engineering の練習を行うためのリポジトリ（自分用）

## 使い方メモ

- `.github/workflows/ci.yml` をリポジトリに入れておくと、自動で GH Actions が走る
- `.claude` 配下に skills, hooks, subagents の設定が入っている
- ループ処理の枠組みは `issue-loop` skill に書いてある
- `/issue-loop` が loop のエントリーポイント
