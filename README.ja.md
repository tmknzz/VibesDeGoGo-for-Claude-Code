# VibesDeGoGo! for Claude Code

**Claude Code に、手を抜かせず最後までやり切らせる。**

Claude Code は賢い。でも、いつも最後まで走り切るとは限らない ── 本当に終わる前に息切れし、踏むべき手順を飛び越え、後から手痛いどんでん返しになる手抜きをする。終わったと思った瞬間に、全部がほどける。

VibesDeGoGo! for Claude Code の答えは1つ：**強制**。地味だが屋台骨の部分 ── 要件定義・調査・1タスクずつの実装・検証 ── をエージェントに飛ばさせず、ほどけの原因になる動きを物理的にブロックする state-and-hook workflow です。

すべてを貫くのは1つの非対称：

- **進捗確認では止まらない** ──「続けていいですか？」を言わず、走り続ける。
- **制約違反の手前では止まる** ── 依存の追加、auth / 永続化 / 課金 / セキュリティに触る、破壊的操作、手順の飛び越し ── これらの直前で止まって尋ねる。

これはプロンプト内のお願いではありません。hook（`PreToolUse` / `PostToolUse` / `Stop`）＋ state file で強制し、タスクゲートが実際のファイル変更を宣言済み許可リストと突き合わせます。手順を飛ばそうとしたりワークフローを歪めようとすると、フックが tool 呼び出しをその場で止めます。（正直な但し書き：これは「強固なレール＋監査記録」であって、サンドボックスでも正しさの証明でもありません。）

bash と jq だけ。SaaSなし・アカウントなし・APIキーなし・テレメトリなし。MIT、無料。

> これの出どころ：私はコードを書きません ── 一文字も書いたことがないし、一行も読みません。それでもこのリポジトリのツールは本物で、テスト付きで、オープンソースです。読めない分をレールが肩代わりするから ── 各ステップは検証され、テストは通らねばならず、レビュー無しでは何も出荷されません。それが核心：VibesDeGoGo! は、コードを書けない人間が、エージェントを誠実に走らせるための仕組みです。

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

## オプション：MAGI 連携

**MAGI**（小さなオープンソースの3人格合議スキル）も入れていれば、VibesDeGoGo! は2箇所でそれを使います ── 無ければ黙ってスキップ：**Step 0** で本当に割れた高リスクの判断を合議し（材料を返すだけ／決めるのはあなた）、**Step 7** で主観的成果物（ドキュメント・コピー・デザイン）のレビューゲートにします。MAGIが見るのは「望ましさ」で、コードの正しさではありません。→ https://github.com/tmknzz/MAGI

## ステータス

このリポジトリは Claude Code 向けエディションです。Codex 向けエディションは [VibesDeGoGo-for-Codex](https://github.com/tmknzz/VibesDeGoGo-for-Codex) として別リポジトリにあります。

## 支援（Support）

無料、ずっと無料。もし週末を1回救えたなら、コーヒー1杯は歓迎 ── 強制はしません。
