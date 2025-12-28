#!/bin/bash
# claude-tools.sh - Claude Code tmux session management tools
# https://github.com/danndizumu/claude-tools

CLAUDE_TOOLS_BASE_DIR="${CLAUDE_TOOLS_BASE_DIR:-/mnt/c/git}"

# Check if project has Claude configuration or session history
_has_claude_config() {
    local project_path="$1"

    # Check for config files
    if [ -f "$project_path/.claude" ] || [ -f "$project_path/.claude.toml" ] || \
       [ -f "$project_path/claude.toml" ] || [ -d "$project_path/.claude" ]; then
        return 0
    fi

    # Check for session in ~/.claude/projects/
    local encoded_path=$(echo "$project_path" | sed 's|/|-|g')
    if [ -d "$HOME/.claude/projects/$encoded_path" ]; then
        return 0
    fi

    return 1
}

# Start or attach to Claude tmux session
_start_claude_session() {
    local project_name="$1"
    local project_path="$2"
    local session_name="claude-$project_name"

    if tmux has-session -t "$session_name" 2>/dev/null; then
        echo "既存のセッション '$session_name' に接続します..."
        tmux attach-session -t "$session_name"
    else
        echo "新しいセッション '$session_name' を作成中..."
        echo "作業ディレクトリ: $project_path"
        tmux new-session -d -s "$session_name" -c "$project_path"
        tmux send-keys -t "$session_name" 'claude --continue' C-m
        tmux attach-session -t "$session_name"
    fi
}

# Show existing Claude sessions
_show_existing_sessions() {
    local claude_sessions=$(tmux list-sessions 2>/dev/null | grep "claude-" | cut -d: -f1)
    if [ -z "$claude_sessions" ]; then
        echo "  (実行中のセッションはありません)"
        return
    fi
    while IFS= read -r session; do
        if [ -n "$session" ]; then
            local project_name=${session#claude-}
            local session_info=$(tmux list-sessions | grep "^$session:" | cut -d: -f2-)
            echo "  実行中: $project_name $session_info"
        fi
    done <<< "$claude_sessions"
}

# Main command: Start Claude for a project
claude-dev() {
    local base_dir="$CLAUDE_TOOLS_BASE_DIR"
    local show_list=false

    # Parse options
    if [ "$1" = "-l" ] || [ "$1" = "--list" ]; then
        show_list=true
        shift
    fi

    # Direct project name specified
    if [ -n "$1" ]; then
        local project_name="$1"
        local project_path="$base_dir/$project_name"
        if [ -d "$project_path" ]; then
            _start_claude_session "$project_name" "$project_path"
        else
            echo "プロジェクト '$project_name' が見つかりません: $project_path"
            return 1
        fi
        return
    fi

    # Check if current directory is a Claude project
    local current_dir=$(pwd)
    local current_project=""
    if [[ "$current_dir" == "$base_dir"/* ]]; then
        local relative_path="${current_dir#$base_dir/}"
        current_project="${relative_path%%/*}"
        if [ -d "$base_dir/$current_project" ] && _has_claude_config "$base_dir/$current_project"; then
            if [ "$show_list" = false ]; then
                _start_claude_session "$current_project" "$base_dir/$current_project"
                return
            fi
        else
            current_project=""
        fi
    fi

    # Show project list
    local projects=()
    local display_list=""
    local counter=1
    echo "Claude対応プロジェクトを検索中..."

    # Current directory project first
    if [ -n "$current_project" ]; then
        projects+=("$current_project")
        display_list+="  $counter) $current_project (現在のディレクトリ)\n"
        ((counter++))
    fi

    # Add other projects
    for dir in "$base_dir"/*; do
        if [ -d "$dir" ]; then
            local project_name=$(basename "$dir")
            if [ "$project_name" != "$current_project" ] && _has_claude_config "$dir"; then
                projects+=("$project_name")
                display_list+="  $counter) $project_name\n"
                ((counter++))
            fi
        fi
    done

    if [ ${#projects[@]} -eq 0 ]; then
        echo "Claude設定があるプロジェクトが見つかりません"
        echo "プロジェクトディレクトリで 'claude init' を実行してください"
        return 1
    fi

    echo ""
    echo "既存のClaudeセッション:"
    _show_existing_sessions
    echo ""
    echo "起動するプロジェクトを選択してください:"
    echo -e "$display_list"
    echo "  0) キャンセル"
    echo ""
    read -p "番号を入力 [1-${#projects[@]}]: " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#projects[@]} ]; then
        local selected_project="${projects[$((choice-1))]}"
        local project_path="$base_dir/$selected_project"
        _start_claude_session "$selected_project" "$project_path"
    elif [ "$choice" = "0" ]; then
        echo "キャンセルしました"
    else
        echo "無効な選択です"
    fi
}

# Switch between Claude sessions
claude-switch() {
    echo "Claudeセッション一覧:"
    _show_existing_sessions
    local claude_sessions=($(tmux list-sessions 2>/dev/null | grep "claude-" | cut -d: -f1))
    if [ ${#claude_sessions[@]} -eq 0 ]; then
        echo ""
        echo "実行中のClaudeセッションがありません"
        echo "'claude-dev' でセッションを開始してください"
        return 1
    fi
    echo ""
    local counter=1
    for session in "${claude_sessions[@]}"; do
        local project_name=${session#claude-}
        echo "  $counter) $project_name"
        ((counter++))
    done
    echo "  0) キャンセル"
    echo ""
    read -p "切り替えるセッション番号 [1-${#claude_sessions[@]}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#claude_sessions[@]} ]; then
        local selected_session="${claude_sessions[$((choice-1))]}"
        echo "セッション '$selected_session' に切り替えます..."
        tmux attach-session -t "$selected_session"
    elif [ "$choice" = "0" ]; then
        echo "キャンセルしました"
    else
        echo "無効な選択です"
    fi
}

# List all Claude projects and sessions
claude-list() {
    echo "Claude プロジェクト管理状況:"
    echo ""
    echo "実行中のセッション:"
    _show_existing_sessions
    echo ""
    echo "利用可能なプロジェクト:"
    local base_dir="$CLAUDE_TOOLS_BASE_DIR"
    local found_projects=false
    for dir in "$base_dir"/*; do
        if [ -d "$dir" ]; then
            local project_name=$(basename "$dir")
            if _has_claude_config "$dir"; then
                local session_name="claude-$project_name"
                if tmux has-session -t "$session_name" 2>/dev/null; then
                    echo "  $project_name (実行中)"
                else
                    echo "  $project_name"
                fi
                found_projects=true
            fi
        fi
    done
    if [ "$found_projects" = false ]; then
        echo "  (Claude設定があるプロジェクトが見つかりません)"
    fi
}

# Kill a specific Claude session
claude-kill() {
    if [ -n "$1" ]; then
        local session_name="claude-$1"
        if tmux has-session -t "$session_name" 2>/dev/null; then
            tmux kill-session -t "$session_name"
            echo "セッション '$session_name' を終了しました"
        else
            echo "セッション '$session_name' が見つかりません"
        fi
    else
        echo "終了するセッションを選択してください:"
        claude-switch-kill
    fi
}

# Interactive session kill
claude-switch-kill() {
    echo "終了するClaudeセッション:"
    _show_existing_sessions
    local claude_sessions=($(tmux list-sessions 2>/dev/null | grep "claude-" | cut -d: -f1))
    if [ ${#claude_sessions[@]} -eq 0 ]; then
        echo ""
        echo "終了できるセッションがありません"
        return 1
    fi
    echo ""
    local counter=1
    for session in "${claude_sessions[@]}"; do
        local project_name=${session#claude-}
        echo "  $counter) $project_name"
        ((counter++))
    done
    echo "  0) キャンセル"
    echo ""
    read -p "終了するセッション番号 [1-${#claude_sessions[@]}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#claude_sessions[@]} ]; then
        local selected_session="${claude_sessions[$((choice-1))]}"
        tmux kill-session -t "$selected_session"
        echo "セッション '$selected_session' を終了しました"
    elif [ "$choice" = "0" ]; then
        echo "キャンセルしました"
    else
        echo "無効な選択です"
    fi
}

# Kill all Claude sessions
claude-kill-all() {
    local claude_sessions=($(tmux list-sessions 2>/dev/null | grep "claude-" | cut -d: -f1))
    if [ ${#claude_sessions[@]} -eq 0 ]; then
        echo "終了できるClaudeセッションがありません"
        return 1
    fi
    echo "全てのClaudeセッション (${#claude_sessions[@]}個) を終了しますか？"
    read -p "実行しますか？ [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        for session in "${claude_sessions[@]}"; do
            tmux kill-session -t "$session"
            echo "$session を終了しました"
        done
        echo "全てのClaudeセッションを終了しました"
    else
        echo "キャンセルしました"
    fi
}

# Show help
claude-help() {
    echo "Claude プロジェクト管理コマンド:"
    echo ""
    echo "  claude-dev [project]  - プロジェクト選択してClaude起動"
    echo "  claude-switch         - 実行中セッション間の切り替え"
    echo "  claude-list           - プロジェクトとセッション一覧表示"
    echo "  claude-kill [project] - 特定セッションの終了"
    echo "  claude-kill-all       - 全Claudeセッション終了"
    echo "  claude-help           - このヘルプを表示"
    echo "  claude-clean          - Claude履歴の古いものを削除"
    echo ""
    echo "例:"
    echo "  claude-dev                    # プロジェクト選択メニューを表示"
    echo "  claude-dev my_project         # 直接プロジェクトを指定"
    echo "  claude-switch                 # セッション切り替えメニュー"
    echo "  claude-kill my_project        # 特定セッションを終了"
    echo "  claude-clean 30d              # 30日より前の履歴を削除"
    echo ""
    echo "環境変数:"
    echo "  CLAUDE_TOOLS_BASE_DIR         # プロジェクトのベースディレクトリ (default: /mnt/c/git)"
}

# Alias for cleanup script
alias claude-clean='~/bin/claude-tools/cleanup_claude_logs.sh'
