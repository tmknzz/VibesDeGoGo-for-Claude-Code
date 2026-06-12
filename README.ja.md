# VibesDeGoGo! for Claude Code

VibesDeGoGo! for Claude Code は、コーディング作業が本当に終わるまで Claude Code
を走らせ続け、制約違反の手前でだけ止まる、状態ファイル＋フック駆動のワークフロー
です。

AIコーディングエージェントは、要件定義・調査・検証・引き継ぎといった「地味だが
大事な部分」を飛ばしがちです。VibesDeGoGo! はそこをレールにします。

フックはガードレールであり、サンドボックスではありません。よくある脱線経路
（スコープ外の編集、検証・レビューの省略、黙った停止）を機械的にブロックし、
タスクゲートが実際のファイル変更を宣言済み許可リストと突き合わせます。
「安全柵＋監査記録」として捉えてください。正しさの証明ではありません。

## 基本の流れ

1. ゴール / 制約 / 受け入れ基準に合意する。
2. `tasks/vdgg/{id}/requirements.md` を書く。
3. コードベースを調査して `investigation.md` を書く。
4. `todo.md` と `progress.md` を作る。
5. 区切りのよいタスクを1つずつ実装する。
6. 具体的なチェックで検証する。
7. レビューゲート（simplify または外部レビュー）を通す。
8. 進捗を更新し、必要なら動作確認を依頼する。
9. コミットし、既定の `branch-pr` ワークフローでは PR を作って止まる。
   （PR＝プルリクエストは GitHub の「変更確認ページ」です。あなたが merge を
   承認するまで、本体のコードには何も反映されません。）

## 構成

```text
.claude-plugin/
  plugin.json
  marketplace.json
hooks/
  hooks.json
skills/vibesdegogo/
  SKILL.md
  scripts/
    vdgg-state.sh
    vdgg-hook-pretool.sh
    vdgg-hook-posttool.sh
    vdgg-hook-stop.sh
  references/
    setup.md
    output_formats.md
    target_schema.md
    hook_rules.md
    state_helpers.md
    subagent_prompts.md
```

## インストール

### プラグインとして（推奨）

Claude Code の中で次を実行します:

```text
/plugin marketplace add tmknzz/VibesDeGoGo-for-Claude-Code
/plugin install vibesdegogo@vibesdegogo
```

スキルの登録とフックの有効化が自動で行われます。JSONの手編集は不要です。

### 手動インストール

スキルフォルダを Claude Code のスキルディレクトリにコピーします:

```bash
mkdir -p "$HOME/.claude/skills"
cp -R skills/vibesdegogo "$HOME/.claude/skills/vibesdegogo"
```

その後、次のファイルに記載されたフックを登録してください:

```text
skills/vibesdegogo/references/setup.md
```

フックは Claude Code のフックJSONを `jq` で解析するため、`jq` が必要です:

```bash
brew install jq               # macOS
sudo apt-get install jq       # Debian / Ubuntu / WSL
apk add jq                    # Alpine
sudo dnf install jq           # Fedora / RHEL
```

`jq` がない場合でも、VDGGセッションが動いていないリポジトリでは
フックは何もせず邪魔をしません。

## テスト

```bash
bash tests/run-all.sh
```

## ステータス

このリポジトリは Claude Code 向けエディションです。Codex 向けエディションは
`VibesDeGoGo-for-Codex` として別リポジトリにあります。
