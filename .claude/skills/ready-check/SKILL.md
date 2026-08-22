---
name: ready-check
description: 無人ループを回す前の前提チェック。gh 認証、ラベル、検証コマンド、CI、ブランチ保護、フックの実行権限を確認し、足りないものを直す。最初に1回、環境を変えたら都度実行する。
allowed-tools:
  - Read
  - Bash
  - Edit
  - Write
---

無人ループを開始できる状態かを確認し、直せるものはその場で直してください。

## チェック項目

1. **gh 認証**: `gh auth status`。`repo` スコープがあること。
2. **リポジトリ**: `gh repo view --json nameWithOwner,defaultBranchRef`
3. **ラベル**: 次の5つが存在するか。無ければ作る。
   ```bash
   gh label create "agent:ready"   --color 0E8A16 --description "エージェント着手可" --force
   gh label create "agent:wip"     --color FBCA04 --description "エージェント作業中（ロック）" --force
   gh label create "agent:review"  --color 1D76DB --description "PR作成済み・レビュー/マージ待ち" --force
   gh label create "agent:blocked" --color D93F0B --description "人間の判断待ち" --force
   gh label create "agent:done"    --color 5319E7 --description "完了" --force
   ```
4. **検証コマンド**: `./scripts/verify.sh` が存在し、実行可能で、**現在の main で緑**であること。
   緑でないなら、ループを回してはいけない（何が自分の変更で壊れたか区別できなくなる）。
   初回だけフォーマッタ由来で赤い場合は `./scripts/verify.sh --fix` を1回実行してよい。
5. **言語ツールチェーン**: リポジトリのファイルから言語を判定し、対応する項目だけを確認する。

   | 判定材料 | 確認するコマンド | 不足時の対処 |
   | --- | --- | --- |
   | `package.json` | `node -v`, `npm -v`, `ls node_modules` | `npm install` |
   | `pyproject.toml` | `pytest --version`, `ruff --version`, `mypy --version`, `coverage --version` | `pip install "coverage>=7.6" "mypy>=1.11" "pytest>=8" "ruff>=0.6"` |
   | `go.mod` | `go version`, `gofmt -l .`, `golangci-lint --version` | `go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest` |
   | `build.gradle.kts` | `java -version`（17以上）, `./gradlew --version`, `gradlew` に実行権限 | `chmod +x gradlew` / JDK 21 を入れる |
   | `pubspec.yaml` | `flutter --version`, `dart --version`, `ls .dart_tool` | `flutter pub get` |

   Gradle と Flutter は**初回だけ**依存の取得に数分かかる。ループを始める前に1回流しておくこと
   （ループの1周目がタイムアウトで潰れるのを防ぐ）。
6. **CI**: `.github/workflows/` に PR で走るワークフローがあること。`gh run list --limit 3` で直近が緑か確認。
7. **ブランチ保護**: 既定ブランチが直接 push を拒否する設定になっているか
   （`gh api repos/{owner}/{repo}/branches/<既定>/protection` が 404 なら未設定）。
   Phase 2 以降は必須。未設定なら、設定コマンドを提示する（勝手に変更はしない）。
8. **フック**: `.claude/hooks/*.sh` に実行権限があるか。無ければ `chmod +x` する。
9. **フェーズ**: `.claude/loop-phase` が存在するか。無ければ `1` で作る。
10. **jq**: `command -v jq`（フックが依存）。

## 出力

各項目を `OK` / `修正した` / `要対応（理由）` の3値で列挙し、最後に
**「無人ループを開始してよいか: はい/いいえ」**を1行で述べてください。
「要対応」が1つでもあれば「いいえ」です。
