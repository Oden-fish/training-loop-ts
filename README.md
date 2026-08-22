# Loop Engineering の練習リポジトリ (ver Typescript)

Claude Code を用いた Loop Engineering の練習を行うためのリポジトリ（自分用）

## CLI

- 標準入力の各行を slug にして標準出力に返す: `cat titles.txt | npm run --silent slugify`

## 使い方メモ

- `.github/workflows/ci.yml` をリポジトリに入れておくと、自動で GH Actions が走る
- `.claude` 配下に skills, hooks, subagents の設定が入っている
- ループ処理の枠組みは `issue-loop` skill に書いてある
- `/issue-loop` が loop のエントリーポイント
