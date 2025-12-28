#!/bin/bash
# claude-tools installer

set -e

REPO_URL="https://github.com/danndizumu/claude-tools.git"
INSTALL_DIR="$HOME/bin/claude-tools"

echo "Installing claude-tools..."

# Clone or update
if [ -d "$INSTALL_DIR" ]; then
    echo "Updating existing installation..."
    cd "$INSTALL_DIR"
    git pull
else
    echo "Cloning repository..."
    mkdir -p "$HOME/bin"
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

# Make executable
chmod +x "$INSTALL_DIR"/*.sh

# Add to .bashrc if not already present
if ! grep -q "claude-tools.sh" "$HOME/.bashrc"; then
    echo "" >> "$HOME/.bashrc"
    echo "# Claude Code Tools" >> "$HOME/.bashrc"
    echo "source ~/bin/claude-tools/claude-tools.sh" >> "$HOME/.bashrc"
    echo "Added to .bashrc"
else
    echo "Already in .bashrc"
fi

echo ""
echo "Installation complete!"
echo "Run: source ~/.bashrc"
echo "Then: claude-help"
