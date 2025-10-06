#!/bin/bash
# Quest Vim Syntax Installation Script

set -e

# Detect if using Vim or Neovim
if [ -d "$HOME/.config/nvim" ]; then
    VIM_DIR="$HOME/.config/nvim"
    echo "Installing for Neovim..."
elif [ -d "$HOME/.vim" ]; then
    VIM_DIR="$HOME/.vim"
    echo "Installing for Vim..."
else
    echo "Neither Vim nor Neovim configuration directory found."
    echo "Creating Vim directory at ~/.vim"
    VIM_DIR="$HOME/.vim"
fi

# Create directories
mkdir -p "$VIM_DIR/syntax"
mkdir -p "$VIM_DIR/ftdetect"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Copy files
echo "Copying syntax files..."
cp "$SCRIPT_DIR/syntax/quest.vim" "$VIM_DIR/syntax/"
cp "$SCRIPT_DIR/ftdetect/quest.vim" "$VIM_DIR/ftdetect/"

echo ""
echo "✓ Quest syntax highlighting installed successfully!"
echo ""
echo "Files installed to:"
echo "  - $VIM_DIR/syntax/quest.vim"
echo "  - $VIM_DIR/ftdetect/quest.vim"
echo ""
echo "Open any .q file in Vim/Neovim to see syntax highlighting."
echo ""
