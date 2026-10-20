#!/usr/bin/env bash
# ==============================================================================
# Omarchy macOS Dock - Uninstaller
# ==============================================================================
set -euo pipefail

TARGET_PLUGIN_DIR="${HOME}/.config/omarchy/plugins/omarchy-mac-dock"
CONFIG_FILE="${HOME}/.config/omarchy/mac-dock.json"
HYPR_BINDINGS="${HOME}/.config/hypr/bindings.lua"

echo "Uninstalling Omarchy macOS Dock..."

if [ -d "${TARGET_PLUGIN_DIR}" ]; then
  rm -rf "${TARGET_PLUGIN_DIR}"
  echo "✓ Removed ${TARGET_PLUGIN_DIR}"
fi

read -p "Do you also want to remove your dock configuration (~/.config/omarchy/mac-dock.json)? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  rm -f "${CONFIG_FILE}"
  echo "✓ Removed configuration file."
fi

if [ -f "${HYPR_BINDINGS}" ]; then
  sed -i '/omaplug-shortcut-start: omarchy-mac-dock/,/omaplug-shortcut-end: omarchy-mac-dock/d' "${HYPR_BINDINGS}" || true
  echo "✓ Cleaned keybinding from ${HYPR_BINDINGS}"
fi

if command -v omarchy-restart-shell >/dev/null 2>&1; then
  omarchy-restart-shell || true
elif [ -f "/usr/share/omarchy/bin/omarchy-restart-shell" ]; then
  /usr/share/omarchy/bin/omarchy-restart-shell || true
fi

echo "✓ Uninstallation complete."
