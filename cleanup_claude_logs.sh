#!/bin/bash
# cleanup_claude_logs.sh - Clean up old Claude session history files
# https://github.com/danndizumu/claude-tools

# Usage: cleanup_claude_logs.sh <period> (e.g., 30d, 12h, 90m)

BASE_DIR="$HOME/.claude/projects"
INPUT="$1"
WARNING_HOURS=6  # Warn if less than 6 hours

if [[ -z "$INPUT" ]]; then
    echo "Usage: $0 <period> (e.g., 30d, 12h, 90m)"
    echo ""
    echo "Examples:"
    echo "  $0 30d    # Delete files older than 30 days"
    echo "  $0 12h    # Delete files older than 12 hours"
    echo "  $0 90m    # Delete files older than 90 minutes"
    exit 1
fi

# Parse unit: d=days, h=hours, m=minutes
if [[ "$INPUT" =~ ^([0-9]+)([dhm])$ ]]; then
    VALUE="${BASH_REMATCH[1]}"
    UNIT="${BASH_REMATCH[2]}"

    case $UNIT in
        d) AGE_MIN=$(( VALUE * 1440 )) ;;  # days -> minutes
        h) AGE_MIN=$(( VALUE * 60 ))   ;;  # hours -> minutes
        m) AGE_MIN=$VALUE              ;;  # minutes
        *) echo "Invalid unit: $UNIT (use d, h, or m)"; exit 1 ;;
    esac
else
    echo "Format error: Use number + unit (d/h/m) (e.g., 2d, 36h)"
    exit 1
fi

# Warning if period is too short
if (( AGE_MIN < WARNING_HOURS * 60 )); then
    echo "Warning: ${VALUE}${UNIT} is quite short. Continue?"
    read -p "Enter y to continue: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 1
    fi
fi

echo "Deleting files older than ${VALUE}${UNIT} (keeping latest)..."

# Process each project folder
find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d | while read -r project_dir; do
    echo "Project: $(basename "$project_dir")"

    # Get files sorted by modification time (oldest first)
    mapfile -t files < <(find "$project_dir" -maxdepth 1 -name '*.jsonl' -type f -printf "%T@ %p\n" | sort -n | awk '{print $2}')

    if (( ${#files[@]} <= 1 )); then
        echo "  -> Skip (1 or fewer files)"
        continue
    fi

    # Exclude the latest file
    files_to_check=("${files[@]:0:${#files[@]}-1}")
    for file in "${files_to_check[@]}"; do
        file_time=$(stat -c %Y "$file")
        now=$(date +%s)
        age_minutes=$(( (now - file_time) / 60 ))

        if (( age_minutes > AGE_MIN )); then
            echo "  Delete: $(basename "$file") ($(( age_minutes / 60 ))h ago)"
            rm -f "$file"
        else
            echo "  Keep: $(basename "$file") (${age_minutes}m ago)"
        fi
    done

done

echo "Done."
