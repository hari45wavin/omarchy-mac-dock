#!/usr/bin/env bash
# ==============================================================================
# Omarchy macOS Dock - Automated Installer
# ==============================================================================
set -euo pipefail

COLOR_RESET="\033[0m"
COLOR_CYAN="\033[1;36m"
COLOR_GREEN="\033[1;32m"
COLOR_YELLOW="\033[1;33m"
COLOR_RED="\033[1;31m"
COLOR_BOLD="\033[1m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_PLUGIN_DIR="${HOME}/.config/omarchy/plugins/omarchy-mac-dock"
CONFIG_FILE="${HOME}/.config/omarchy/mac-dock.json"
SHELL_CONFIG="${HOME}/.config/omarchy/shell.json"
HYPR_BINDINGS="${HOME}/.config/hypr/bindings.lua"

echo -e "${COLOR_CYAN}${COLOR_BOLD}"
echo "  ██████╗ ███╗   ███╗ █████╗ ██████╗  ██████╗██╗  ██╗██╗   ██╗"
echo " ██╔═══██╗████╗ ████║██╔══██╗██╔══██╗██╔════╝██║  ██║╚██╗ ██╔╝"
echo " ██║   ██║██╔████╔██║███████║██████╔╝██║     ███████║ ╚████╔╝ "
echo " ██║   ██║██║╚██╔╝██║██╔══██║██╔══██╗██║     ██╔══██║  ╚██╔╝  "
echo " ╚██████╔╝██║ ╚═╝ ██║██║  ██║██║  ██║╚██████╗██║  ██║   ██║   "
echo "  ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝   ╚═╝   "
echo "                macOS Dock for Omarchy Linux                  "
echo -e "${COLOR_RESET}"

# 1. Verification
echo -e "${COLOR_BOLD}[1/5] Verifying environment...${COLOR_RESET}"
if ! command -v quickshell >/dev/null 2>&1; then
  echo -e "${COLOR_YELLOW}Warning: 'quickshell' binary not found in PATH. Make sure Omarchy Shell is installed.${COLOR_RESET}"
fi

# 2. Deploy Plugin Files
echo -e "${COLOR_BOLD}[2/5] Installing plugin files to ${TARGET_PLUGIN_DIR}...${COLOR_RESET}"
mkdir -p "${TARGET_PLUGIN_DIR}/assets/icons"
cp -f "${SCRIPT_DIR}/manifest.json" "${TARGET_PLUGIN_DIR}/"
cp -f "${SCRIPT_DIR}/Dock.qml" "${TARGET_PLUGIN_DIR}/"
cp -f "${SCRIPT_DIR}/DockIcon.qml" "${TARGET_PLUGIN_DIR}/"
cp -f "${SCRIPT_DIR}/DockSettings.qml" "${TARGET_PLUGIN_DIR}/"
cp -f "${SCRIPT_DIR}/DockModel.js" "${TARGET_PLUGIN_DIR}/"
cp -f "${SCRIPT_DIR}/SettingsButton.qml" "${TARGET_PLUGIN_DIR}/"
cp -rf "${SCRIPT_DIR}/assets/icons/"* "${TARGET_PLUGIN_DIR}/assets/icons/"
echo -e "${COLOR_GREEN}✓ Plugin files and modern icons copied successfully.${COLOR_RESET}"

# 3. Deploy Default Configuration
echo -e "${COLOR_BOLD}[3/5] Setting up configuration at ${CONFIG_FILE}...${COLOR_RESET}"
if [ ! -f "${CONFIG_FILE}" ]; then
  cp -f "${SCRIPT_DIR}/config.default.json" "${CONFIG_FILE}"
  echo -e "${COLOR_GREEN}✓ Default configuration installed.${COLOR_RESET}"
else
  echo -e "${COLOR_YELLOW}✓ Existing configuration found; keeping your current settings.${COLOR_RESET}"
fi

# 4. Configure Omarchy Shell Top Menu Bar
echo -e "${COLOR_BOLD}[4/5] Aligning Omarchy Bar to top for true macOS experience...${COLOR_RESET}"
if [ -f "${SHELL_CONFIG}" ]; then
  python3 -c "
import json
try:
    with open('${SHELL_CONFIG}', 'r') as f:
        cfg = json.load(f)
    if 'bar' not in cfg: cfg['bar'] = {}
    if cfg['bar'].get('position') != 'top':
        with open('${SHELL_CONFIG}.dock.bak', 'w') as bak:
            json.dump(cfg, bak, indent=2)
        cfg['bar']['position'] = 'top'
        with open('${SHELL_CONFIG}', 'w') as f:
            json.dump(cfg, f, indent=2)
        print('  -> Bar position set to top (backup saved to shell.json.dock.bak)')
    else:
        print('  -> Bar is already set to top')
except Exception as e:
    print('  -> Note: could not update shell.json:', e)
"
fi

# 5. Add Keybinding if bindings.lua exists
if [ -f "${HYPR_BINDINGS}" ]; then
  if ! grep -q "omarchy-mac-dock" "${HYPR_BINDINGS}"; then
    echo -e "${COLOR_BOLD}Adding hotkey (SUPER+CTRL+SHIFT+M) to ${HYPR_BINDINGS}...${COLOR_RESET}"
    cat >> "${HYPR_BINDINGS}" << 'EOF'

-- omaplug-shortcut-start: omarchy-mac-dock
o.bind("SUPER + CTRL + SHIFT + M", "Omaplug: omarchy-mac-dock", "omarchy-shell shell toggle omarchy-mac-dock")
-- omaplug-shortcut-end: omarchy-mac-dock
EOF
    echo -e "${COLOR_GREEN}✓ Hotkey added.${COLOR_RESET}"
  fi
fi

# 6. Restart Omarchy Shell
echo -e "${COLOR_BOLD}[5/5] Reloading Omarchy Shell...${COLOR_RESET}"
if command -v omarchy-restart-shell >/dev/null 2>&1; then
  omarchy-restart-shell || true
  echo -e "${COLOR_GREEN}✓ Omarchy Shell restarted.${COLOR_RESET}"
elif [ -f "/usr/share/omarchy/bin/omarchy-restart-shell" ]; then
  /usr/share/omarchy/bin/omarchy-restart-shell || true
  echo -e "${COLOR_GREEN}✓ Omarchy Shell restarted.${COLOR_RESET}"
else
  echo -e "${COLOR_YELLOW}Please run 'omarchy-restart-shell' or log out/in to apply.${COLOR_RESET}"
fi

echo -e "\n${COLOR_GREEN}${COLOR_BOLD}🎉 Installation Complete! Enjoy your macOS Dock on Omarchy!${COLOR_RESET}"
echo -e "• Right-click any dock icon or shelf to open the ${COLOR_CYAN}macOS Dock Customizer${COLOR_RESET}."
echo -e "• Click any active app to minimize it; click again to restore."
echo -e "• Config file: ${COLOR_CYAN}~/.config/omarchy/mac-dock.json${COLOR_RESET}"
