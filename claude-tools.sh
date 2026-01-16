#!/bin/bash
# claude-tools.sh - Claude Code tmux session management tools
# https://github.com/oreoriorosu/claude-tools

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

# Start or attach to shell tmux session
_start_shell_session() {
    local project_name="$1"
    local project_path="$2"
    local session_name="shell-$project_name"

    if tmux has-session -t "$session_name" 2>/dev/null; then
        echo "既存のセッション '$session_name' に接続します..."
        tmux attach-session -t "$session_name"
    else
        echo "新しいセッション '$session_name' を作成中..."
        echo "作業ディレクトリ: $project_path"
        tmux new-session -d -s "$session_name" -c "$project_path"
        tmux attach-session -t "$session_name"
    fi
}

# Show existing Claude sessions
_show_existing_sessions() {
    local claude_sessions=$(tmux list-sessions 2>/dev/null | grep "^claude-" | cut -d: -f1)
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

# Show existing shell sessions
_show_shell_sessions() {
    local shell_sessions=$(tmux list-sessions 2>/dev/null | grep "^shell-" | cut -d: -f1)
    if [ -z "$shell_sessions" ]; then
        echo "  (実行中のセッションはありません)"
        return
    fi
    while IFS= read -r session; do
        if [ -n "$session" ]; then
            local project_name=${session#shell-}
            local session_info=$(tmux list-sessions | grep "^$session:" | cut -d: -f2-)
            echo "  実行中: $project_name $session_info"
        fi
    done <<< "$shell_sessions"
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

# Main command: Start shell for a project
shell-dev() {
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
            _start_shell_session "$project_name" "$project_path"
        else
            echo "プロジェクト '$project_name' が見つかりません: $project_path"
            return 1
        fi
        return
    fi

    # Check if current directory is a project
    local current_dir=$(pwd)
    local current_project=""
    if [[ "$current_dir" == "$base_dir"/* ]]; then
        local relative_path="${current_dir#$base_dir/}"
        current_project="${relative_path%%/*}"
        if [ -d "$base_dir/$current_project" ]; then
            if [ "$show_list" = false ]; then
                _start_shell_session "$current_project" "$base_dir/$current_project"
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
    echo "プロジェクトを検索中..."

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
            if [ "$project_name" != "$current_project" ]; then
                projects+=("$project_name")
                display_list+="  $counter) $project_name\n"
                ((counter++))
            fi
        fi
    done

    if [ ${#projects[@]} -eq 0 ]; then
        echo "プロジェクトが見つかりません"
        return 1
    fi

    echo ""
    echo "既存のshellセッション:"
    _show_shell_sessions
    echo ""
    echo "起動するプロジェクトを選択してください:"
    echo -e "$display_list"
    echo "  0) キャンセル"
    echo ""
    read -p "番号を入力 [1-${#projects[@]}]: " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#projects[@]} ]; then
        local selected_project="${projects[$((choice-1))]}"
        local project_path="$base_dir/$selected_project"
        _start_shell_session "$selected_project" "$project_path"
    elif [ "$choice" = "0" ]; then
        echo "キャンセルしました"
    else
        echo "無効な選択です"
    fi
}

# Switch between Claude and shell sessions
claude-switch() {
    echo "セッション一覧:"
    echo ""
    echo "Claude:"
    _show_existing_sessions
    echo ""
    echo "Shell:"
    _show_shell_sessions

    local all_sessions=()
    local claude_sessions=($(tmux list-sessions 2>/dev/null | grep "^claude-" | cut -d: -f1))
    local shell_sessions=($(tmux list-sessions 2>/dev/null | grep "^shell-" | cut -d: -f1))

    if [ ${#claude_sessions[@]} -eq 0 ] && [ ${#shell_sessions[@]} -eq 0 ]; then
        echo ""
        echo "実行中のセッションがありません"
        return 1
    fi

    echo ""
    local counter=1
    for session in "${claude_sessions[@]}"; do
        local project_name=${session#claude-}
        echo "  $counter) [claude] $project_name"
        all_sessions+=("$session")
        ((counter++))
    done
    for session in "${shell_sessions[@]}"; do
        local project_name=${session#shell-}
        echo "  $counter) [shell] $project_name"
        all_sessions+=("$session")
        ((counter++))
    done
    echo "  0) キャンセル"
    echo ""
    read -p "切り替えるセッション番号 [1-${#all_sessions[@]}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#all_sessions[@]} ]; then
        local selected_session="${all_sessions[$((choice-1))]}"
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
    echo "プロジェクト管理状況:"
    echo ""
    echo "実行中のClaudeセッション:"
    _show_existing_sessions
    echo ""
    echo "実行中のShellセッション:"
    _show_shell_sessions
    echo ""
    echo "利用可能なプロジェクト:"
    local base_dir="$CLAUDE_TOOLS_BASE_DIR"
    local found_projects=false
    for dir in "$base_dir"/*; do
        if [ -d "$dir" ]; then
            local project_name=$(basename "$dir")
            if _has_claude_config "$dir"; then
                local claude_session="claude-$project_name"
                local shell_session="shell-$project_name"
                local status=""
                if tmux has-session -t "$claude_session" 2>/dev/null; then
                    status="claude"
                fi
                if tmux has-session -t "$shell_session" 2>/dev/null; then
                    [ -n "$status" ] && status="$status+" || status=""
                    status="${status}shell"
                fi
                if [ -n "$status" ]; then
                    echo "  $project_name ($status)"
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
    echo "プロジェクト管理コマンド:"
    echo ""
    echo "Claudeセッション:"
    echo "  claude-dev [project]  - プロジェクト選択してClaude起動"
    echo "  claude-kill [project] - 特定Claudeセッションの終了"
    echo "  claude-kill-all       - 全Claudeセッション終了"
    echo ""
    echo "Shellセッション:"
    echo "  shell-dev [project]   - プロジェクト選択してシェル起動"
    echo ""
    echo "共通:"
    echo "  claude-switch         - 実行中セッション間の切り替え"
    echo "  claude-list           - プロジェクトとセッション一覧表示"
    echo "  claude-archive        - 古い履歴をアーカイブ"
    echo "  claude-restore        - アーカイブを復元"
    echo "  claude-help           - このヘルプを表示"
    echo ""
    echo "例:"
    echo "  claude-dev                    # プロジェクト選択メニューを表示"
    echo "  claude-dev my_project         # 直接プロジェクトを指定"
    echo "  shell-dev my_project          # シェルセッションを開始"
    echo "  claude-switch                 # セッション切り替えメニュー"
    echo "  claude-kill my_project        # 特定セッションを終了"
    echo "  claude-archive 30d            # 30日より古い履歴をアーカイブ"
    echo "  claude-archive 30d --all      # 全プロジェクト対象"
    echo "  claude-restore --list         # アーカイブ一覧表示"
    echo "  claude-restore                # 対話式で復元"
    echo ""
    echo "環境変数:"
    echo "  CLAUDE_TOOLS_BASE_DIR         # プロジェクトのベースディレクトリ (default: /mnt/c/git)"
}

# Archive old Claude history files
claude-archive() {
    local ARCHIVE_BASE="$HOME/.claude/archive"
    local PROJECTS_DIR="$HOME/.claude/projects"
    local WARNING_HOURS=6
    local period=""
    local target_project=""
    local all_projects=false

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            -p|--project)
                target_project="$2"
                shift 2
                ;;
            --all)
                all_projects=true
                shift
                ;;
            *)
                if [ -z "$period" ]; then
                    period="$1"
                fi
                shift
                ;;
        esac
    done

    if [ -z "$period" ]; then
        echo "使用法: claude-archive <期間> [-p プロジェクト名] [--all]"
        echo ""
        echo "例:"
        echo "  claude-archive 30d              # 対話式でプロジェクト選択"
        echo "  claude-archive 30d -p sumo      # 特定プロジェクト"
        echo "  claude-archive 30d --all        # 全プロジェクト"
        return 1
    fi

    # Parse period
    local age_min
    if [[ "$period" =~ ^([0-9]+)([dhm])$ ]]; then
        local value="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[2]}"
        case $unit in
            d) age_min=$((value * 1440)) ;;
            h) age_min=$((value * 60)) ;;
            m) age_min=$value ;;
        esac
    else
        echo "エラー: 期間の形式が不正です (例: 30d, 12h, 90m)"
        return 1
    fi

    # Warning for short period
    if ((age_min < WARNING_HOURS * 60)); then
        echo "警告: ${period} は短い期間です。続行しますか？"
        read -p "[y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "キャンセルしました"
            return 1
        fi
    fi

    # Get project list
    local projects=()
    if [ "$all_projects" = true ]; then
        for dir in "$PROJECTS_DIR"/*; do
            [ -d "$dir" ] && projects+=("$(basename "$dir")")
        done
    elif [ -n "$target_project" ]; then
        local encoded_path=$(echo "/mnt/c/git/$target_project" | sed 's|/|-|g')
        if [ -d "$PROJECTS_DIR/$encoded_path" ]; then
            projects+=("$encoded_path")
        else
            echo "エラー: プロジェクト '$target_project' が見つかりません"
            return 1
        fi
    else
        # Interactive selection
        echo "アーカイブするプロジェクトを選択:"
        local counter=1
        local available=()
        for dir in "$PROJECTS_DIR"/*; do
            if [ -d "$dir" ]; then
                local name=$(basename "$dir")
                available+=("$name")
                local file_count=$(find "$dir" -maxdepth 1 -name "*.jsonl" -type f 2>/dev/null | wc -l)
                echo "  $counter) $name ($file_count ファイル)"
                ((counter++))
            fi
        done
        echo "  0) キャンセル"
        echo ""
        read -p "番号を入力: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#available[@]} ]; then
            projects+=("${available[$((choice-1))]}")
        elif [ "$choice" = "0" ]; then
            echo "キャンセルしました"
            return 1
        else
            echo "無効な選択です"
            return 1
        fi
    fi

    if [ ${#projects[@]} -eq 0 ]; then
        echo "対象プロジェクトがありません"
        return 1
    fi

    # Create archive directory
    local timestamp=$(date +%Y-%m-%d_%H%M%S)
    local archive_dir="$ARCHIVE_BASE/$timestamp"
    mkdir -p "$archive_dir"

    local total_files=0
    local total_size=0
    local archived_projects=()

    for project in "${projects[@]}"; do
        local project_dir="$PROJECTS_DIR/$project"
        [ -d "$project_dir" ] || continue

        # Get files sorted by modification time (oldest first)
        mapfile -t files < <(find "$project_dir" -maxdepth 1 -name "*.jsonl" -type f -printf "%T@ %p\n" 2>/dev/null | sort -n | awk '{print $2}')

        if [ ${#files[@]} -le 1 ]; then
            echo "  $project: スキップ (1ファイル以下)"
            continue
        fi

        # Exclude latest file
        local files_to_check=("${files[@]:0:${#files[@]}-1}")
        local archived_count=0

        for file in "${files_to_check[@]}"; do
            local file_time=$(stat -c %Y "$file")
            local now=$(date +%s)
            local age_minutes=$(((now - file_time) / 60))

            if ((age_minutes > age_min)); then
                # Create project archive directory
                local project_archive="$archive_dir/$project"
                mkdir -p "$project_archive"

                local file_size=$(stat -c %s "$file")
                mv "$file" "$project_archive/"
                ((archived_count++))
                ((total_files++))
                total_size=$((total_size + file_size))
            fi
        done

        if [ $archived_count -gt 0 ]; then
            echo "  $project: $archived_count ファイルをアーカイブ"
            archived_projects+=("$project")
        fi
    done

    if [ $total_files -eq 0 ]; then
        rmdir "$archive_dir" 2>/dev/null
        echo "アーカイブ対象のファイルがありませんでした"
        return 0
    fi

    # Create manifest
    local size_human
    if [ $total_size -ge 1048576 ]; then
        size_human="$((total_size / 1048576))MB"
    elif [ $total_size -ge 1024 ]; then
        size_human="$((total_size / 1024))KB"
    else
        size_human="${total_size}B"
    fi

    cat > "$archive_dir/manifest.json" << EOF
{
  "created": "$(date -Iseconds)",
  "period": "$period",
  "projects": $(printf '%s\n' "${archived_projects[@]}" | jq -R . | jq -s .),
  "files_count": $total_files,
  "total_size": "$size_human"
}
EOF

    echo ""
    echo "アーカイブ完了: $archive_dir"
    echo "  ファイル数: $total_files"
    echo "  サイズ: $size_human"
}

# Restore archived Claude history files
claude-restore() {
    local ARCHIVE_BASE="$HOME/.claude/archive"
    local PROJECTS_DIR="$HOME/.claude/projects"
    local show_list=false
    local target_archive=""

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            -l|--list)
                show_list=true
                shift
                ;;
            *)
                target_archive="$1"
                shift
                ;;
        esac
    done

    # Check if archive directory exists
    if [ ! -d "$ARCHIVE_BASE" ]; then
        echo "アーカイブがありません"
        return 1
    fi

    # Get archive list
    local archives=()
    for dir in "$ARCHIVE_BASE"/*; do
        [ -d "$dir" ] && [ -f "$dir/manifest.json" ] && archives+=("$(basename "$dir")")
    done

    if [ ${#archives[@]} -eq 0 ]; then
        echo "アーカイブがありません"
        return 1
    fi

    # List mode
    if [ "$show_list" = true ]; then
        echo "アーカイブ一覧:"
        echo ""
        for archive in "${archives[@]}"; do
            local manifest="$ARCHIVE_BASE/$archive/manifest.json"
            local period=$(jq -r '.period' "$manifest" 2>/dev/null)
            local files_count=$(jq -r '.files_count' "$manifest" 2>/dev/null)
            local total_size=$(jq -r '.total_size' "$manifest" 2>/dev/null)
            local projects=$(jq -r '.projects | join(", ")' "$manifest" 2>/dev/null)
            echo "  $archive"
            echo "    期間: $period, ファイル数: $files_count, サイズ: $total_size"
            echo "    プロジェクト: $projects"
            echo ""
        done
        return 0
    fi

    # Select archive
    local selected_archive=""
    if [ -n "$target_archive" ]; then
        if [ -d "$ARCHIVE_BASE/$target_archive" ]; then
            selected_archive="$target_archive"
        else
            echo "エラー: アーカイブ '$target_archive' が見つかりません"
            return 1
        fi
    else
        # Interactive selection
        echo "復元するアーカイブを選択:"
        echo ""
        local counter=1
        for archive in "${archives[@]}"; do
            local manifest="$ARCHIVE_BASE/$archive/manifest.json"
            local files_count=$(jq -r '.files_count' "$manifest" 2>/dev/null)
            local total_size=$(jq -r '.total_size' "$manifest" 2>/dev/null)
            echo "  $counter) $archive ($files_count ファイル, $total_size)"
            ((counter++))
        done
        echo "  0) キャンセル"
        echo ""
        read -p "番号を入力: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#archives[@]} ]; then
            selected_archive="${archives[$((choice-1))]}"
        elif [ "$choice" = "0" ]; then
            echo "キャンセルしました"
            return 1
        else
            echo "無効な選択です"
            return 1
        fi
    fi

    local archive_dir="$ARCHIVE_BASE/$selected_archive"
    local restored_files=0

    echo "復元中: $selected_archive"

    # Restore each project
    for project_dir in "$archive_dir"/*; do
        [ -d "$project_dir" ] || continue
        local project=$(basename "$project_dir")
        [ "$project" = "manifest.json" ] && continue

        local target_dir="$PROJECTS_DIR/$project"
        mkdir -p "$target_dir"

        local count=0
        for file in "$project_dir"/*.jsonl; do
            [ -f "$file" ] || continue
            local filename=$(basename "$file")

            # Check for collision
            if [ -f "$target_dir/$filename" ]; then
                echo "  警告: $filename は既に存在します（スキップ）"
                continue
            fi

            mv "$file" "$target_dir/"
            ((count++))
            ((restored_files++))
        done

        if [ $count -gt 0 ]; then
            echo "  $project: $count ファイルを復元"
        fi
    done

    # Remove empty archive directory
    if [ $restored_files -gt 0 ]; then
        # Remove empty project directories
        for project_dir in "$archive_dir"/*; do
            [ -d "$project_dir" ] && rmdir "$project_dir" 2>/dev/null
        done
        # Remove manifest and archive directory
        rm -f "$archive_dir/manifest.json"
        rmdir "$archive_dir" 2>/dev/null

        echo ""
        echo "復元完了: $restored_files ファイル"
    else
        echo "復元するファイルがありませんでした"
    fi
}
