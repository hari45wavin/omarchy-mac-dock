# Contributing to Omarchy macOS Dock

First off, thank you for considering contributing to **Omarchy macOS Dock**! 🎉

Whether you're reporting a bug, suggesting a feature, improving documentation, or submitting a pull request, your help is warmly welcomed.

---

## 🛠️ Development Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/hari45wavin/omarchy-mac-dock.git
   cd omarchy-mac-dock
   ```

2. **Symlink to your local plugins directory:**
   ```bash
   mkdir -p ~/.config/omarchy/plugins
   ln -s "$(pwd)" ~/.config/omarchy/plugins/omarchy-mac-dock
   ```

3. **Reload Omarchy Shell:**
   ```bash
   omarchy-restart-shell
   ```

4. **Testing Changes:**
   Any edits to `Dock.qml`, `DockIcon.qml`, `DockSettings.qml`, or `DockModel.js` can be verified by running `omarchy-restart-shell`.

---

## 💡 Good First Issues

Looking to make your first contribution? Check out issues tagged with [`good first issue`](https://github.com/hari45wavin/omarchy-mac-dock/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22)!

## 📋 Pull Request Guidelines

1. Create a descriptive branch: `git checkout -b feature/awesome-dock-effect`
2. Test your changes live on Omarchy with Hyprland and Wayland.
3. Ensure no QML binding loops or syntax warnings in `journalctl --user -u omarchy-shell` / Quickshell stdout.
4. Submit your pull request with a concise description and before/after screenshots.
