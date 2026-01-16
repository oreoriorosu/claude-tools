# claude-tools

Claude Code の tmux セッション管理ツール集

## インストール

```bash
curl -fsSL https://raw.githubusercontent.com/oreoriorosu/claude-tools/main/install.sh | bash
source ~/.bashrc
```

## アンインストール

```bash
~/bin/claude-tools/uninstall.sh
source ~/.bashrc
```

## 機能

| コマンド | 説明 |
|----------|------|
| `claude-dev` | プロジェクトを選択して Claude を起動 |
| `shell-dev` | プロジェクトを選択してシェルを起動 |
| `claude-switch` | 実行中のセッション間を切り替え |
| `claude-list` | プロジェクトとセッションの一覧表示 |
| `claude-kill` | 特定のセッションを終了 |
| `claude-kill-all` | 全 Claude セッションを終了 |
| `claude-archive` | 古い履歴をアーカイブ |
| `claude-restore` | アーカイブを復元 |
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

### シェルセッション

sudo や手動コマンドの実行履歴を残すためのシェルセッション。

```bash
# カレントディレクトリでシェル起動
shell-dev

# プロジェクト名を指定して起動
shell-dev my-project

# プロジェクト一覧から選択
shell-dev -l
```

### セッション管理

```bash
# 実行中セッションの切り替え (Claude + Shell)
claude-switch

# セッション一覧表示
claude-list

# 特定セッション終了
claude-kill my-project

# 全セッション終了
claude-kill-all
```

### 履歴アーカイブ

古い履歴を削除せずにアーカイブし、必要に応じて復元できます。

```bash
# 対話式でプロジェクト選択してアーカイブ
claude-archive 30d

# 特定プロジェクトをアーカイブ
claude-archive 30d -p sumo

# 全プロジェクトを一括アーカイブ
claude-archive 30d --all

# アーカイブ一覧表示
claude-restore --list

# 対話式で復元
claude-restore

# 特定アーカイブを指定して復元
claude-restore 2025-01-05_093000
```

アーカイブは `~/.claude/archive/` に保存されます。

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
- jq（アーカイブ機能で使用）
- [Claude Code](https://github.com/anthropics/claude-code)

## ライセンス

MIT
