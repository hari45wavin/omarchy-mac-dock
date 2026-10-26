function defaultConfig() {
  var home = Quickshell.env("HOME");
  var iconDir = home + "/.config/omarchy/plugins/omarchy-mac-dock/assets/icons";
  return {
    version: 1,
    dockSize: 44,
    magnification: true,
    maxScale: 1.35,
    glassOpacity: 0.45,
    reserveSpace: true,
    bottomMargin: 10,
    clickToMinimize: true,
    bounceOnLaunch: true,
    showRecentApps: true,
    autoHide: false,
    autoHideMode: "intellihide", // "intellihide", "always", "disabled"
    hideOnAppOpen: true,
    preTasks: {
      showLauncher: true,
      showWorkspaces: true,
      showActivityMonitor: false,
      showPluginManager: false,
      showTrash: true,
      showSettings: true
    },
    pinnedApps: [
      {
        id: "org.gnome.Nautilus",
        name: "Finder",
        desktopFile: "org.gnome.Nautilus.desktop",
        icon: iconDir + "/Finder.png",
        exec: "nautilus",
        gradientStart: "#38bdf8",
        gradientEnd: "#0284c7"
      },
      {
        id: "brave-browser",
        name: "Brave Browser",
        desktopFile: "brave-browser.desktop",
        icon: iconDir + "/Brave.png",
        exec: "brave",
        gradientStart: "#fb923c",
        gradientEnd: "#ea580c"
      },
      {
        id: "antigravity",
        name: "Antigravity IDE",
        desktopFile: "antigravity.desktop",
        icon: "antigravity",
        exec: "antigravity",
        gradientStart: "#818cf8",
        gradientEnd: "#4f46e5"
      },
      {
        id: "foot",
        name: "Terminal",
        desktopFile: "foot.desktop",
        icon: iconDir + "/Terminal.png",
        exec: "foot",
        gradientStart: "#334155",
        gradientEnd: "#0f172a"
      },
      {
        id: "notion",
        name: "Notion",
        desktopFile: "notion.desktop",
        icon: iconDir + "/notion.png",
        exec: "notion-app",
        gradientStart: "#475569",
        gradientEnd: "#1e293b"
      },
      {
        id: "md.obsidian.Obsidian",
        name: "Obsidian",
        desktopFile: "obsidian.desktop",
        icon: iconDir + "/obsidian.png",
        exec: "obsidian",
        gradientStart: "#a855f7",
        gradientEnd: "#6b21a8"
      },
      {
        id: "spotify",
        name: "Spotify",
        desktopFile: "spotify.desktop",
        icon: iconDir + "/Spotify.png",
        exec: "spotify",
        gradientStart: "#22c55e",
        gradientEnd: "#15803d"
      },
      {
        id: "WhatsApp",
        name: "WhatsApp",
        desktopFile: "WhatsApp.desktop",
        icon: iconDir + "/whatsapp.png",
        exec: "omarchy-launch-webapp https://web.whatsapp.com/",
        gradientStart: "#10b981",
        gradientEnd: "#059669"
      },
      {
        id: "Discord",
        name: "Discord",
        desktopFile: "Discord.desktop",
        icon: iconDir + "/discord.png",
        exec: "discord",
        gradientStart: "#818cf8",
        gradientEnd: "#4f46e5"
      },
      {
        id: "omasettings",
        name: "System Settings",
        desktopFile: "omasettings.desktop",
        icon: iconDir + "/settings.png",
        exec: "omarchy-shell omasettings toggle",
        gradientStart: "#94a3b8",
        gradientEnd: "#475569"
      }
    ]
  };
}

function resolveMacIcon(appId, fallbackIcon) {
  var home = Quickshell.env("HOME");
  var iconDir = home + "/.config/omarchy/plugins/omarchy-mac-dock/assets/icons";
  var id = String(appId || "").toLowerCase();
  var fallback = String(fallbackIcon || "").toLowerCase();

  if (id.indexOf("nautilus") !== -1 || id.indexOf("finder") !== -1 || id.indexOf("files") !== -1 || fallback.indexOf("finder") !== -1) {
    return iconDir + "/Finder.png";
  }
  if (id.indexOf("brave") !== -1 || fallback.indexOf("brave") !== -1) {
    return iconDir + "/Brave.png";
  }
  if (id.indexOf("vscode") !== -1 || id.indexOf("code") !== -1 || fallback.indexOf("vscode") !== -1 || fallback.indexOf("code") !== -1) {
    return iconDir + "/vscode.png";
  }
  if (id.indexOf("foot") !== -1 || id.indexOf("terminal") !== -1 || id.indexOf("alacritty") !== -1 || id.indexOf("kitty") !== -1 || fallback.indexOf("terminal") !== -1) {
    return iconDir + "/Terminal.png";
  }
  if (id.indexOf("spotify") !== -1 || fallback.indexOf("spotify") !== -1) {
    return iconDir + "/Spotify.png";
  }
  if (id.indexOf("discord") !== -1 || fallback.indexOf("discord") !== -1) {
    return iconDir + "/discord.png";
  }
  if (id.indexOf("obsidian") !== -1 || fallback.indexOf("obsidian") !== -1) {
    return iconDir + "/obsidian.png";
  }
  if (id.indexOf("notion") !== -1 || fallback.indexOf("notion") !== -1) {
    return iconDir + "/notion.png";
  }
  if (id.indexOf("telegram") !== -1 || fallback.indexOf("telegram") !== -1) {
    return iconDir + "/Telegram.png";
  }
  if (id.indexOf("whatsapp") !== -1 || fallback.indexOf("whatsapp") !== -1) {
    return iconDir + "/whatsapp.png";
  }
  if (id.indexOf("setting") !== -1 || id.indexOf("control") !== -1 || fallback.indexOf("settings") !== -1) {
    return iconDir + "/settings.png";
  }
  if (id.indexOf("trash") !== -1) {
    return iconDir + "/trash-empty.png";
  }
  if (id.indexOf("launchpad") !== -1 || id.indexOf("menu") !== -1) {
    return iconDir + "/launchpad.png";
  }

  return fallbackIcon || appId || "";
}

function cleanId(str) {
  return String(str || "").toLowerCase().replace(/[^a-z0-9]/g, "");
}

function matchesToplevel(toplevel, app) {
  if (!toplevel || !app) return false;
  var appId = String(toplevel.appId || "").toLowerCase();
  var title = String(toplevel.title || "").toLowerCase();
  
  var targetId = String(app.id || "").toLowerCase();
  var desktopFile = String(app.desktopFile || "").toLowerCase().replace(/\.desktop$/, "");
  var name = String(app.name || "").toLowerCase();
  var exec = String(app.exec || "").toLowerCase();

  if (appId.length > 0) {
    if (appId === targetId || appId === desktopFile) return true;
    if (targetId.length > 0 && (appId.indexOf(targetId) !== -1 || targetId.indexOf(appId) !== -1)) return true;
    if (desktopFile.length > 0 && (appId.indexOf(desktopFile) !== -1 || desktopFile.indexOf(appId) !== -1)) return true;
    if (exec.length > 0) {
      var baseExec = exec.split(" ")[0].split("/").pop();
      if (baseExec.length > 1 && appId.indexOf(baseExec) !== -1) return true;
    }
  }

  // Fallback to title keywords for webapps / electron apps
  if (name.length > 2 && title.indexOf(name) !== -1) return true;
  if (targetId.length > 2 && title.indexOf(targetId) !== -1) return true;
  
  return false;
}

function findMatchingToplevel(toplevels, app) {
  if (!toplevels || typeof toplevels.length !== "number") return null;
  for (var i = 0; i < toplevels.length; i++) {
    if (matchesToplevel(toplevels[i], app)) {
      return toplevels[i];
    }
  }
  return null;
}

function findAllMatchingToplevels(toplevels, app) {
  if (!toplevels || typeof toplevels.length !== "number") return [];
  var matches = [];
  for (var i = 0; i < toplevels.length; i++) {
    if (matchesToplevel(toplevels[i], app)) {
      matches.push(toplevels[i]);
    }
  }
  return matches;
}

function isAppRunning(toplevels, app) {
  return findMatchingToplevel(toplevels, app) !== null;
}

function isAppFocused(toplevels, activeToplevel, app) {
  if (!activeToplevel) return false;
  return matchesToplevel(activeToplevel, app);
}

function isAppPinned(config, app) {
  if (!config || !config.pinnedApps || !app) return false;
  var targetId = String(app.id || "").toLowerCase();
  for (var i = 0; i < config.pinnedApps.length; i++) {
    var p = config.pinnedApps[i];
    if (String(p.id || "").toLowerCase() === targetId) return true;
    if (matchesToplevel(app, p)) return true;
  }
  return false;
}

function togglePinApp(config, app) {
  if (!config) return config;
  var newConfig = JSON.parse(JSON.stringify(config));
  if (!newConfig.pinnedApps) newConfig.pinnedApps = [];

  var existingIndex = -1;
  var targetId = String(app.id || "").toLowerCase();
  for (var i = 0; i < newConfig.pinnedApps.length; i++) {
    var p = newConfig.pinnedApps[i];
    if (String(p.id || "").toLowerCase() === targetId || matchesToplevel(app, p)) {
      existingIndex = i;
      break;
    }
  }

  if (existingIndex !== -1) {
    // Unpin
    newConfig.pinnedApps.splice(existingIndex, 1);
  } else {
    // Pin to dock
    var grad = defaultGradients(newConfig.pinnedApps.length);
    var resolvedIcon = resolveMacIcon(app.id, app.icon);
    newConfig.pinnedApps.push({
      id: app.id || app.name || "app",
      name: app.name || app.id || "Application",
      desktopFile: app.desktopFile || (app.id ? app.id + ".desktop" : ""),
      icon: resolvedIcon,
      exec: app.exec || "",
      gradientStart: app.gradientStart || grad.start,
      gradientEnd: app.gradientEnd || grad.end
    });
  }

  return newConfig;
}

function getUnpinnedRunningApps(toplevels, pinnedApps) {
  if (!toplevels || typeof toplevels.length !== "number") return [];
  var pinned = pinnedApps || [];
  var unpinned = [];
  var seenIds = {};

  for (var i = 0; i < toplevels.length; i++) {
    var top = toplevels[i];
    if (!top) continue;
    var rawAppId = String(top.appId || "").trim();
    if (!rawAppId) continue;
    var lowerId = rawAppId.toLowerCase();
    
    // Ignore desktop layer-shell/system services
    if (lowerId === "hyprlock" || lowerId === "wlogout" || lowerId === "quickshell" || lowerId === "omarchy-mac-dock" || lowerId === "screensaver") continue;

    // Check if matches any pinned app
    var isPinned = false;
    for (var p = 0; p < pinned.length; p++) {
      if (matchesToplevel(top, pinned[p])) {
        isPinned = true;
        break;
      }
    }

    if (!isPinned && !seenIds[lowerId]) {
      seenIds[lowerId] = true;
      var cleanName = rawAppId;
      if (cleanName === "GTK Application" || cleanName.length < 3) {
        if (top.title && top.title.length > 0) cleanName = top.title;
      } else if (cleanName.indexOf(".") !== -1) {
        var segs = cleanName.split(".");
        cleanName = segs[segs.length - 1];
      }
      cleanName = cleanName.charAt(0).toUpperCase() + cleanName.slice(1);
      var grad = defaultGradients(unpinned.length + 3);
      var macIcon = resolveMacIcon(rawAppId, cleanName.toLowerCase());

      unpinned.push({
        id: rawAppId,
        name: cleanName,
        title: top.title || "",
        icon: macIcon,
        desktopFile: rawAppId + ".desktop",
        isUnpinnedRunning: true,
        gradientStart: grad.start,
        gradientEnd: grad.end
      });
    }
  }

  return unpinned;
}

function defaultGradients(index) {
  var palettes = [
    { start: "#38bdf8", end: "#0284c7" }, // Sky
    { start: "#fb923c", end: "#ea580c" }, // Orange
    { start: "#a855f7", end: "#7e22ce" }, // Purple
    { start: "#10b981", end: "#047857" }, // Emerald
    { start: "#818cf8", end: "#4f46e5" }, // Indigo
    { start: "#f43f5e", end: "#be123c" }, // Rose
    { start: "#eab308", end: "#a16207" }, // Yellow/Gold
    { start: "#06b6d4", end: "#0e7490" }, // Cyan
    { start: "#ec4899", end: "#be185d" }, // Pink
    { start: "#64748b", end: "#334155" }  // Slate
  ];
  return palettes[Math.abs(index) % palettes.length];
}
