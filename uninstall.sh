#!/bin/bash
# claude-tools uninstaller

INSTALL_DIR="$HOME/bin/claude-tools"

echo "Uninstalling claude-tools..."

# Remove from .bashrc
if grep -q "claude-tools.sh" "$HOME/.bashrc"; then
    sed -i '/# Claude Code Tools/d' "$HOME/.bashrc"
    sed -i '/claude-tools.sh/d' "$HOME/.bashrc"
    echo "Removed from .bashrc"
fi

# Remove directory
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo "Removed $INSTALL_DIR"
fi

echo ""
echo "Uninstall complete!"
echo "Run: source ~/.bashrc"
