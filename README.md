# claude-tools

Claude Code の tmux セッション管理ツール集

## インストール

```bash
curl -fsSL https://raw.githubusercontent.com/oreoriorosu/claude-tools/main/install.sh | bash
source ~/.bashrc
```

## 機能

| コマンド | 説明 |
|----------|------|
| `claude-dev` | プロジェクトを選択して Claude を起動 |
| `claude-switch` | 実行中のセッション間を切り替え |
| `claude-list` | プロジェクトとセッションの一覧表示 |
| `claude-kill` | 特定のセッションを終了 |
| `claude-kill-all` | 全 Claude セッションを終了 |
| `claude-clean` | 古い会話履歴を削除 |
| `claude-help` | ヘルプ表示 |

## 使い方

### プロジェクトで Claude を起動

```bash
# カレントディレクトリで起動
claude-dev

# プロジェクト名を指定して起動
claude-dev my-project

# プロジェクト一覧から選択
claude-dev -l
```

### セッション管理

```bash
# 実行中セッションの切り替え
claude-switch

# セッション一覧表示
claude-list

# 特定セッション終了
claude-kill my-project

# 全セッション終了
claude-kill-all
```

### 履歴クリーンアップ

```bash
# 30日より古い履歴を削除
claude-clean 30d

# 12時間より古い履歴を削除
claude-clean 12h
```

## 設定

### 環境変数

| 変数 | 説明 | デフォルト |
|------|------|-----------|
| `CLAUDE_TOOLS_BASE_DIR` | プロジェクトのベースディレクトリ | `/mnt/c/git` |

```bash
# 例: .bashrc で設定
export CLAUDE_TOOLS_BASE_DIR="/path/to/your/projects"
source ~/bin/claude-tools/claude-tools.sh
```

## プロジェクトの検出

以下のいずれかが存在するディレクトリを Claude プロジェクトとして認識します:

- `.claude` ファイルまたはディレクトリ
- `.claude.toml` ファイル
- `claude.toml` ファイル
- `~/.claude/projects/` にセッション履歴がある

## 依存関係

- bash
- tmux
- [Claude Code](https://github.com/anthropics/claude-code)

## ライセンス

MIT
