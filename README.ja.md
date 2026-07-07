# VibesDeGoGo! for Claude Code

Claude Code 向けの state ＋ hook ワークフロー。要件定義・調査・実装・検証・コミットを通してエージェントを走らせ続けつつ、手順の飛ばし・検証の省略・スコープ逸脱の手前で止めます。

すべてを貫くのは1つの非対称：

- 進捗確認では止まらない ──「続けていいですか？」を言わず走り続ける。
- 制約違反の手前では止まる ── 依存の追加、auth / 永続化 / 課金 / セキュリティに触る、破壊的操作、手順の飛び越し ── これらの直前で止まって尋ねる。

ルールはプロンプト本文ではなく、hook（`PreToolUse` / `PostToolUse` / `Stop`）＋ state file で強制し、タスクゲートが実際のファイル変更を宣言済み許可リストと突き合わせます。hook はサンドボックスではなくガードレールです ── 「強固なレール＋監査記録」であって、正しさの証明ではありません。

bash と jq のみ。アカウント・鍵・テレメトリなし。MIT。

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

## アンインストール

すべての足跡の一覧です（あなた自身でも、Claude に頼む場合でもこのリストで完遂できます）:

- プラグイン導入の場合: Claude Code 内で `/plugin uninstall vibesdegogo@vibesdegogo` を実行（ターミナルからなら `claude plugin uninstall vibesdegogo@vibesdegogo`）。
- 手動導入の場合: `~/.claude/skills/vibesdegogo/` を削除し、`~/.claude/settings.json` から
  `vdgg-hook-*.sh` を参照するフック4件（`PreToolUse` / `PostToolUse` / `PostToolUseFailure` / `Stop`）を除去。
- 各リポジトリ内のセッション生成物: `.claude/.vdgg-*` と `tasks/vdgg/` は削除して安全です。
  `.gitignore` に自動追記される `.claude/.vdgg-*` のブロックも不要なら消してかまいません。
- `.vdgg-target` は残してください — これはあなたの設定ファイルで、VDGG が入れたものではありません。

## テスト

```bash
bash tests/run-all.sh
```

## オプション：MAGI 連携

**MAGI**（小さなオープンソースの3人格合議スキル）も入れていれば、VibesDeGoGo! は2箇所でそれを使います ── 無ければ黙ってスキップ：**Step 0** で本当に割れた高リスクの判断を合議し（材料を返すだけ／決めるのはあなた）、**Step 7** で主観的成果物（ドキュメント・コピー・デザイン）のレビューゲートにします。MAGIが見るのは「望ましさ」で、コードの正しさではありません。→ https://github.com/tmknzz/MAGI

## ステータス

このリポジトリは Claude Code 向けエディションです。Codex 向けエディションは [VibesDeGoGo-for-Codex](https://github.com/tmknzz/VibesDeGoGo-for-Codex) として別リポジトリにあります。