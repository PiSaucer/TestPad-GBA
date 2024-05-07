#!/bin/bash
# install.sh
# Copyright (c) 2024 PiSaucer
# Licensed under the MIT License

# Color codes
# https://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux
NC='\033[0m' # No Color
RED='\033[0;31m'
GREEN='\033[0;32m'

# Check if running on macOS
if [[ "$(uname -s)" != "Darwin" ]]; then
    printf "${RED}Error: This script only supports macOS.${NC}\n"
    exit 1
fi

# Install Xcode Command Line Tools
if ! xcode-select -p >/dev/null 2>&1; then
    xcode-select --install
    echo "Complete the Xcode installation, then rerun this script."
    exit 0
fi

# Check if devkitPro installer is already downloaded
PKG="devkitpro-pacman-installer.pkg"

if [[ -f "$PKG" ]]; then
    printf "${GREEN}devkitPro installer already downloaded. Skipping download.${NC}\n"
else
    echo "Downloading devkitPro installer..."
    curl -fL -o "$PKG" \
    "https://github.com/devkitPro/pacman/releases/download/v6.0.2/devkitpro-pacman-installer.pkg"
fi

# Install devkitPro pacman
sudo installer -pkg "$PKG" -target /

# Install Game Boy Advance development tools
sudo /opt/devkitpro/pacman/bin/pacman -S --needed gba-dev

# Configure environment variables
echo "Configuring environment..."
PROFILE="$HOME/.zshrc"

touch "$PROFILE"

# Check DEVKITPRO
if grep -q '^export DEVKITPRO=' "$PROFILE"; then
    printf "${GREEN}DEVKITPRO already configured.${NC}\n"
else
    echo 'export DEVKITPRO=/opt/devkitpro' >> "$PROFILE"
    printf "${GREEN}DEVKITPRO added to .zshrc.${NC}\n"
fi

# Check DEVKITARM
if grep -q '^export DEVKITARM=' "$PROFILE"; then
    printf "${GREEN}DEVKITARM already configured.${NC}\n"
else
    echo 'export DEVKITARM=$DEVKITPRO/devkitARM' >> "$PROFILE"
    printf "${GREEN}DEVKITARM added to .zshrc.${NC}\n"
fi

# Set environment variables for this script
export DEVKITPRO=/opt/devkitpro
export DEVKITARM="$DEVKITPRO/devkitARM"

# Verify installation
if [[ -d "$DEVKITARM" ]]; then
    printf "${GREEN}devkitARM installation verified.${NC}\n"
else
    printf "${RED}Error: devkitARM directory not found.${NC}\n"
    exit 1
fi

# Configure VS Code settings
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SCRIPT_DIR/.vscode/settings-mac.json"
DEST="$SCRIPT_DIR/.vscode/settings.json"
cp "$SOURCE" "$DEST"&& \
printf "${GREEN}VS Code settings configured.${NC}\n"

printf "${GREEN}devkitPro GBA installation complete!${NC}\n"
echo "Run 'source ~/.zshrc' to apply environment variables."
