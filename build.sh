#!/bin/bash
# Build Claude Desktop Flatpak from the official .deb and export a bundle
set -e

APP_ID="com.anthropic.Claude"
cd "$(dirname "$0")"

if ! command -v flatpak-builder &> /dev/null; then
    echo "❌ Error: flatpak-builder is not installed"
    exit 1
fi

flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

flatpak-builder --user --install-deps-from=flathub --force-clean \
    --repo=repo build-dir ${APP_ID}.yml

flatpak build-bundle repo claude-desktop.flatpak ${APP_ID}

echo "✅ Created claude-desktop.flatpak ($(du -h claude-desktop.flatpak | cut -f1))"
echo "Install with: flatpak install --user claude-desktop.flatpak"
