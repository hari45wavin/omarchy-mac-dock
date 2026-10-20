function defaultConfig() {
  return {
    version: 1,
    dockSize: 52,
    magnification: true,
    maxScale: 1.25,
    glassOpacity: 0.45,
    reserveSpace: true,
    bottomMargin: 10,
    clickToMinimize: true,
    preTasks: {
      showLauncher: true,
      showWorkspaces: true,
      showActivityMonitor: true,
      showPluginManager: true,
      showTrash: true,
      showSettings: true
    },
    pinnedApps: [
      {
        id: "org.gnome.Nautilus",
        name: "Finder",
        desktopFile: "org.gnome.Nautilus.desktop",
        icon: "org.gnome.Nautilus",
        exec: "nautilus",
        gradientStart: "#38bdf8",
        gradientEnd: "#0284c7"
      },
      {
        id: "brave-browser",
        name: "Brave Browser",
        desktopFile: "brave-browser.desktop",
        icon: "brave-desktop",
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
        icon: "foot",
        exec: "foot",
        gradientStart: "#334155",
        gradientEnd: "#0f172a"
      },
      {
        id: "notion",
        name: "Notion",
        desktopFile: "notion.desktop",
        icon: "notion",
        exec: "notion-app",
        gradientStart: "#475569",
        gradientEnd: "#1e293b"
      },
      {
        id: "md.obsidian.Obsidian",
        name: "Obsidian",
        desktopFile: "obsidian.desktop",
        icon: "obsidian",
        exec: "obsidian",
        gradientStart: "#a855f7",
        gradientEnd: "#6b21a8"
      },
      {
        id: "spotify",
        name: "Spotify",
        desktopFile: "spotify.desktop",
        icon: "spotify-client",
        exec: "spotify",
        gradientStart: "#22c55e",
        gradientEnd: "#15803d"
      },
      {
        id: "WhatsApp",
        name: "WhatsApp",
        desktopFile: "WhatsApp.desktop",
        icon: "whatsapp",
        exec: "omarchy-launch-webapp https://web.whatsapp.com/",
        gradientStart: "#10b981",
        gradientEnd: "#059669"
      },
      {
        id: "omasettings",
        name: "System Settings",
        desktopFile: "omasettings.desktop",
        icon: "/home/hariom_joshi/.config/omarchy/plugins/io.github.twiking.omasettings/icon.png",
        exec: "omarchy-shell omasettings toggle",
        gradientStart: "#94a3b8",
        gradientEnd: "#475569"
      }
    ]
  };
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
  if (!toplevels || !Array.isArray(toplevels)) return null;
  for (var i = 0; i < toplevels.length; i++) {
    if (matchesToplevel(toplevels[i], app)) {
      return toplevels[i];
    }
  }
  return null;
}

function isAppRunning(toplevels, app) {
  return findMatchingToplevel(toplevels, app) !== null;
}

function isAppFocused(toplevels, activeToplevel, app) {
  if (!activeToplevel) return false;
  return matchesToplevel(activeToplevel, app);
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
