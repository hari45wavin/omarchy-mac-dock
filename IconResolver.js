.pragma library

var FALLBACK_MAP = {
  "org.kde.dolphin": "system-file-manager",
  "dolphin": "system-file-manager",
  "org.gnome.nautilus": "system-file-manager",
  "nautilus": "system-file-manager",
  "code": "vscode",
  "com.visualstudio.code": "vscode",
  "google-chrome": "google-chrome",
  "com.google.chrome": "google-chrome",
  "chromium": "chromium",
  "brave-browser": "brave",
  "whatsapp": "whatsapp",
  "discord": "discord",
  "omarchy-discord": "discord",
  "tui.tile": "terminal",
  "kitty": "terminal",
  "foot": "terminal",
  "alacritty": "terminal",
  "org.mozilla.firefox": "firefox",
  "firefox": "firefox",
  "spotify": "spotify",
  "md.obsidian.obsidian": "obsidian",
  "obsidian": "obsidian",
  "notion": "notion"
};

function sanitizeName(value) {
  return String(value || "").replace(/\.desktop$/i, "").replace(/[-_]+/g, " ").trim();
}

function normalizeId(value) {
  var id = String(value || "").trim();
  return id.endsWith(".desktop") ? id.slice(0, -8) : id;
}

function customIconFile(customIcons, id) {
  if (!customIcons || typeof customIcons !== "object") return "";
  var key = normalizeId(id);
  var value = customIcons[key];
  if (!value) {
    var lowerKey = key.toLowerCase();
    for (var candidate in customIcons) {
      var normalizedCandidate = normalizeId(candidate);
      if (normalizedCandidate.toLowerCase() === lowerKey) {
        value = customIcons[candidate];
        break;
      }
    }
    if (!value && lowerKey.length >= 4) {
      for (var alias in customIcons) {
        var normalizedAlias = normalizeId(alias).toLowerCase();
        if (lowerKey.indexOf(normalizedAlias) !== -1) {
          value = customIcons[alias];
          break;
        }
      }
    }
  }
  if (!value) return "";
  var file = typeof value === "string" ? value : (value.file || "");
  file = String(file || "").trim();
  return /^[A-Za-z0-9._-]+$/.test(file) ? file : "";
}

function resolveAppIcon(app, customIcons, iconsDir, appliedRevision) {
  if (!app) return "";
  var id = normalizeId(app.id || app.desktopId || "");
  var lowerId = id.toLowerCase();

  // 1. Check custom user-assigned icons (~/.config/omarchy/icons)
  var customFile = customIconFile(customIcons, id);
  if (customFile) {
    var home = (typeof Quickshell !== "undefined" && Quickshell.env) ? Quickshell.env("HOME") : "/home/hariom_joshi";
    var customPath = "file://" + home + "/.config/omarchy/icons/" + customFile;
    return appliedRevision ? (customPath + "?v=" + appliedRevision) : customPath;
  }

  // 2. Check explicit icon property on app
  var rawIcon = String(app.icon || app.iconName || "").trim();
  if (rawIcon.indexOf("/") === 0 || rawIcon.indexOf("file://") === 0) {
    return rawIcon.indexOf("file://") === 0 ? rawIcon : "file://" + rawIcon;
  }

  // 3. Check bundled high-res macOS Big Sur / Sonoma icons
  var baseIconsDir = iconsDir || "";
  if (baseIconsDir) {
    if (lowerId.indexOf("nautilus") !== -1 || lowerId.indexOf("finder") !== -1 || lowerId.indexOf("files") !== -1 || rawIcon.indexOf("finder") !== -1) {
      return "file://" + baseIconsDir + "/Finder.png";
    }
    if (lowerId.indexOf("brave") !== -1 || rawIcon.indexOf("brave") !== -1) {
      return "file://" + baseIconsDir + "/Brave.png";
    }
    if (lowerId.indexOf("vscode") !== -1 || lowerId.indexOf("code") !== -1 || rawIcon.indexOf("vscode") !== -1 || rawIcon.indexOf("code") !== -1) {
      return "file://" + baseIconsDir + "/vscode.png";
    }
    if (lowerId.indexOf("foot") !== -1 || lowerId.indexOf("terminal") !== -1 || lowerId.indexOf("alacritty") !== -1 || lowerId.indexOf("kitty") !== -1 || rawIcon.indexOf("terminal") !== -1) {
      return "file://" + baseIconsDir + "/Terminal.png";
    }
    if (lowerId.indexOf("spotify") !== -1 || rawIcon.indexOf("spotify") !== -1) {
      return "file://" + baseIconsDir + "/Spotify.png";
    }
    if (lowerId.indexOf("discord") !== -1 || rawIcon.indexOf("discord") !== -1) {
      return "file://" + baseIconsDir + "/discord.png";
    }
    if (lowerId.indexOf("obsidian") !== -1 || rawIcon.indexOf("obsidian") !== -1) {
      return "file://" + baseIconsDir + "/obsidian.png";
    }
    if (lowerId.indexOf("notion") !== -1 || rawIcon.indexOf("notion") !== -1) {
      return "file://" + baseIconsDir + "/notion.png";
    }
    if (lowerId.indexOf("telegram") !== -1 || rawIcon.indexOf("telegram") !== -1) {
      return "file://" + baseIconsDir + "/Telegram.png";
    }
    if (lowerId.indexOf("whatsapp") !== -1 || rawIcon.indexOf("whatsapp") !== -1) {
      return "file://" + baseIconsDir + "/whatsapp.png";
    }
    if (lowerId.indexOf("setting") !== -1 || lowerId.indexOf("control") !== -1 || rawIcon.indexOf("settings") !== -1) {
      return "file://" + baseIconsDir + "/settings.png";
    }
    if (lowerId.indexOf("trash") !== -1) {
      return "file://" + baseIconsDir + "/trash-empty.png";
    }
    if (lowerId.indexOf("launchpad") !== -1 || lowerId.indexOf("menu") !== -1) {
      return "file://" + baseIconsDir + "/launchpad.png";
    }
  }

  // 4. Try Quickshell icon path
  if (typeof Quickshell !== "undefined" && typeof Quickshell.iconPath === "function") {
    if (rawIcon && rawIcon.length > 0 && rawIcon !== "application-x-executable") {
      var resolved = Quickshell.iconPath(rawIcon, true);
      if (resolved && resolved.length > 0) return resolved;
    }

    // Try fallback map
    var mappedName = FALLBACK_MAP[lowerId] || FALLBACK_MAP[normalizeId(rawIcon).toLowerCase()];
    if (mappedName) {
      var mappedPath = Quickshell.iconPath(mappedName, true);
      if (mappedPath && mappedPath.length > 0) return mappedPath;
    }

    // Try id as icon name
    var idPath = Quickshell.iconPath(lowerId, true);
    if (idPath && idPath.length > 0) return idPath;

    // Generic fallback
    var generic = Quickshell.iconPath("application-x-executable", true);
    if (generic && generic.length > 0) return generic;
  }

  if (rawIcon && (rawIcon.indexOf("/") === 0 || rawIcon.indexOf("file://") === 0)) {
    return rawIcon.indexOf("file://") === 0 ? rawIcon : ("file://" + rawIcon);
  }
  return "";
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    FALLBACK_MAP: FALLBACK_MAP,
    sanitizeName: sanitizeName,
    normalizeId: normalizeId,
    customIconFile: customIconFile,
    resolveAppIcon: resolveAppIcon
  };
}
