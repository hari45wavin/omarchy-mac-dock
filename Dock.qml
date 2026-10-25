import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "DockModel.js" as DockModel

PanelWindow {
  id: dockWindow

  property string home: Quickshell.env("HOME")
  property string pluginDir: home + "/.config/omarchy/plugins/omarchy-mac-dock"
  property string iconsDir: pluginDir + "/assets/icons"
  property string configPath: home + "/.config/omarchy/mac-dock.json"
  property var dockConfig: DockModel.defaultConfig()
  property var toplevelsList: []
  property var unpinnedRunningApps: []
  property var settingsPanel: null
  property var menuPanel: null
  property bool isWritingConfig: false

  // Parabolic Wave Tracking
  property real mouseShelfX: -9999
  property bool isShelfHovered: false
  readonly property var shelfItem: shelf

  // Auto-hide & Hover State Tracking
  property bool isDockHovered: false
  readonly property bool autoHideEnabled: dockConfig.autoHide === true
  readonly property bool isSettingsOpen: (settingsPanel !== null && settingsPanel.visible) || (menuPanel !== null && menuPanel.visible)

  // Accurate open app detection: stays true while apps are open, even if clicking empty desktop
  readonly property bool hasOpenApps: {
    try {
      if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.toplevels) {
        if (Hyprland.focusedWorkspace.toplevels.values.length > 0) return true
      }
    } catch (e1) {}

    try {
      var list = dockWindow.toplevelsList || []
      for (var i = 0; i < list.length; i++) {
        var top = list[i]
        if (top && !top.minimized) {
          var appId = String(top.appId || "").toLowerCase()
          if (appId !== "hyprlock" && appId !== "wlogout" && appId !== "quickshell") return true
        }
      }
    } catch (e2) {}

    return false
  }

  readonly property bool shouldHide: autoHideEnabled && hasOpenApps && !isDockHovered && !isSettingsOpen

  // Trash Full State Tracking
  property bool isTrashFull: false

  visible: true
  color: "transparent"

  anchors {
    bottom: true
    left: true
    right: true
  }

  // Generous headroom (+64px) so magnified icons and floating tooltips NEVER get cut off
  implicitHeight: shelf.height + (dockConfig.bottomMargin || 10) + 64

  WlrLayershell.namespace: "omarchy-mac-dock"
  WlrLayershell.layer: WlrLayer.Top
  exclusionMode: (dockConfig.reserveSpace && !autoHideEnabled) ? ExclusionMode.Auto : ExclusionMode.Ignore

  // Input mask: when hidden, only the bottom trigger hotspot receives hover;
  // when visible, shelfArea receives clicks while outside clicks pass through
  mask: Region {
    item: dockWindow.shouldHide ? triggerHotspot : shelfArea
  }

  // Interactive shelf area for input masking (includes space for floating tooltips)
  Item {
    id: shelfArea
    anchors.horizontalCenter: shelf.horizontalCenter
    anchors.bottom: parent.bottom
    width: shelf.width + 60
    height: shelf.height + (dockConfig.bottomMargin || 10) + 64

    MouseArea {
      id: shelfContainerHover
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
      onEntered: {
        hideTimer.stop()
        dockWindow.isDockHovered = true
      }
      onExited: {
        hideTimer.restart()
      }
    }
  }

  // Hyprland / Wayland Toplevels Tracking for Running Dots, Unpinned Apps & Workspace presence
  function updateToplevels() {
    try {
      toplevelsList = ToplevelManager.toplevels.values || []
    } catch (e) {
      toplevelsList = []
    }

    if (dockConfig.showRecentApps !== false) {
      unpinnedRunningApps = DockModel.getUnpinnedRunningApps(toplevelsList, dockConfig.pinnedApps)
    } else {
      unpinnedRunningApps = []
    }
  }

  Connections {
    target: ToplevelManager.toplevels
    function onValuesChanged() { dockWindow.updateToplevels() }
  }

  Connections {
    target: ToplevelManager
    function onActiveToplevelChanged() { dockWindow.updateToplevels() }
  }

  Connections {
    target: Hyprland.workspaces
    function onValuesChanged() { dockWindow.updateToplevels() }
  }

  Connections {
    target: Hyprland
    function onFocusedWorkspaceChanged() { dockWindow.updateToplevels() }
  }

  // Trash State Monitor
  Timer {
    id: trashTimer
    interval: 3000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      trashCheckProcess.running = true
    }
  }

  Process {
    id: trashCheckProcess
    command: ["bash", "-c", "test -d \"$HOME/.local/share/Trash/files\" && [ $(ls -A \"$HOME/.local/share/Trash/files\" 2>/dev/null | wc -l) -gt 0 ] && echo 1 || echo 0"]
    stdout: StdioCollector {
      onDataChanged: {
        var res = (text || "").trim()
        dockWindow.isTrashFull = (res === "1")
      }
    }
  }

  function emptyTrash() {
    Quickshell.execDetached(["bash", "-c", "rm -rf \"$HOME/.local/share/Trash/files/\"* \"$HOME/.local/share/Trash/info/\"*"])
    trashTimer.restart()
  }

  Component.onCompleted: {
    loadConfig()
    updateToplevels()
  }

  // Load config from ~/.config/omarchy/mac-dock.json with anti-revert protection
  function loadConfig() {
    if (isWritingConfig) {
      isWritingConfig = false
      return
    }
    if (configFileView.loaded) {
      try {
        var txt = configFileView.text()
        if (txt && txt.trim().length > 0) {
          var parsed = JSON.parse(txt)
          if (parsed && typeof parsed === "object" && parsed.pinnedApps) {
            dockConfig = parsed
            updateToplevels()
            return
          }
        }
      } catch (e) {
        console.warn("mac-dock: failed to parse config JSON, keeping current settings")
        return
      }
    }
    if (!dockConfig || !dockConfig.pinnedApps) {
      dockConfig = DockModel.defaultConfig()
      updateToplevels()
    }
  }

  function saveConfig(newConfig) {
    dockConfig = newConfig
    isWritingConfig = true
    updateToplevels()
    Quickshell.execDetached([
      "python3",
      "-c",
      "import sys, os\n" +
      "data = sys.argv[1]\n" +
      "dest = sys.argv[2]\n" +
      "tmp = dest + '.tmp'\n" +
      "with open(tmp, 'w') as f:\n" +
      "  f.write(data)\n" +
      "  f.flush()\n" +
      "  os.fsync(f.fileno())\n" +
      "os.replace(tmp, dest)\n",
      JSON.stringify(newConfig, null, 2),
      dockWindow.configPath
    ])
  }

  function applyLiveConfig(newConfig) {
    dockConfig = newConfig
    updateToplevels()
  }

  FileView {
    id: configFileView
    path: dockWindow.configPath
    watchChanges: true
    printErrors: false
    onLoaded: dockWindow.loadConfig()
    onFileChanged: dockWindow.loadConfig()
    onLoadFailed: dockWindow.loadConfig()
  }

  // Customizer Settings Panel
  function openSettings() {
    if (!settingsPanel) {
      settingsPanel = settingsComponent.createObject(dockWindow, {
        screen: dockWindow.screen
      })
      if (settingsPanel) {
        settingsPanel.configSaved.connect(function(newCfg) {
          dockWindow.saveConfig(newCfg)
        })
        settingsPanel.configLivePreview.connect(function(previewCfg) {
          dockWindow.applyLiveConfig(previewCfg)
        })
      }
    }
    if (settingsPanel) {
      settingsPanel.openSettings(dockConfig)
    }
  }

  Component {
    id: settingsComponent
    DockSettings { }
  }

  // Native macOS Right-Click Context Menu
  function openContextMenu(app, screenCenterX) {
    if (!menuPanel) {
      menuPanel = menuComponent.createObject(dockWindow, {
        screen: dockWindow.screen
      })
      if (menuPanel) {
        menuPanel.actionPinToggle.connect(function(targetApp) {
          var newCfg = DockModel.togglePinApp(dockWindow.dockConfig, targetApp)
          dockWindow.saveConfig(newCfg)
        })
        menuPanel.actionQuit.connect(function(targetApp) {
          var matches = DockModel.findAllMatchingToplevels(dockWindow.toplevelsList, targetApp)
          for (var i = 0; i < matches.length; i++) {
            var top = matches[i]
            if (top) {
              Quickshell.execDetached(["hyprctl", "dispatch", "closewindow", "pid:" + top.pid])
            }
          }
        })
        menuPanel.actionMinimize.connect(function(targetApp) {
          var match = DockModel.findMatchingToplevel(dockWindow.toplevelsList, targetApp)
          if (match) {
            Quickshell.execDetached(["hyprctl", "eval", "hl.dsp.window.move({ workspace = 'special:minimized', follow = false })"])
          }
        })
        menuPanel.actionActivate.connect(function(targetApp) {
          dockWindow.launchOrActivate(targetApp, null)
        })
        menuPanel.actionOpenSettings.connect(function() {
          dockWindow.openSettings()
        })
        menuPanel.actionOpenTrash.connect(function() {
          Quickshell.execDetached(["xdg-open", "trash:///"])
        })
        menuPanel.actionEmptyTrash.connect(function() {
          dockWindow.emptyTrash()
        })
      }
    }
    if (menuPanel) {
      var isRunning = DockModel.isAppRunning(dockWindow.toplevelsList, app)
      var isPinned = DockModel.isAppPinned(dockWindow.dockConfig, app)
      var shelfTopScreenY = dockWindow.height - (shelf.height + (dockConfig.bottomMargin || 10))
      menuPanel.openMenu(app, screenCenterX, shelfTopScreenY, isRunning, isPinned)
    }
  }

  Component {
    id: menuComponent
    DockMenu { }
  }

  // App Launcher & Multi-Window Cycling / Minimize / Bounce Handler
  function launchOrActivate(app, dockIcon) {
    var matches = DockModel.findAllMatchingToplevels(toplevelsList, app)
    var active = ToplevelManager.activeToplevel

    if (matches && matches.length > 0) {
      if (matches.length === 1) {
        var singleMatch = matches[0]
        // Click-to-minimize: if already focused and minimize is enabled in config
        if (active && DockModel.matchesToplevel(active, app)) {
          if (dockConfig.clickToMinimize !== false) {
            Quickshell.execDetached(["hyprctl", "eval", "hl.dsp.window.move({ workspace = 'special:minimized', follow = false })"])
            return
          }
        }
        // App is running: restore and activate
        Quickshell.execDetached(["hyprctl", "eval", "hl.dsp.workspace.toggle_special('minimized')"])
        singleMatch.activate()
        Quickshell.execDetached(["hyprctl", "eval", "hl.dsp.window.bring_to_top()"])
        return
      }

      // Multiple instances open: cycle focus between them!
      var nextIdx = 0
      for (var i = 0; i < matches.length; i++) {
        if (active && matches[i].appId === active.appId && matches[i].title === active.title) {
          nextIdx = (i + 1) % matches.length
          break
        }
      }
      matches[nextIdx].activate()
      Quickshell.execDetached(["hyprctl", "eval", "hl.dsp.window.bring_to_top()"])
      return
    }

    // App is not running: start authentic macOS launch bounce animation!
    if (dockIcon && dockConfig.bounceOnLaunch !== false && dockIcon.startBounce) {
      dockIcon.startBounce()
    }

    // Launch it
    if (app.exec && app.exec.length > 0) {
      Quickshell.execDetached(["bash", "-c", app.exec])
    } else if (app.desktopFile && app.desktopFile.length > 0) {
      Quickshell.execDetached(["uwsm-app", "--", "gtk-launch", app.desktopFile])
    }
  }

  // Auto-Hide Delay Timers
  Timer {
    id: hideTimer
    interval: 400
    onTriggered: {
      var inShelf = shelfContainerHover.containsMouse || shelfHoverArea.containsMouse
      var inTrigger = triggerHoverArea.containsMouse
      if (!inShelf && !inTrigger && !dockWindow.isSettingsOpen) {
        dockWindow.isDockHovered = false
        dockWindow.isShelfHovered = false
        dockWindow.mouseShelfX = -9999
      }
    }
  }

  // Bottom Edge Trigger Hotspot (reveals dock on cursor touch when hidden)
  Item {
    id: triggerHotspot
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 14
    z: 9999

    MouseArea {
      id: triggerHoverArea
      anchors.fill: parent
      hoverEnabled: true
      onEntered: {
        hideTimer.stop()
        dockWindow.isDockHovered = true
      }
      onExited: {
        hideTimer.restart()
      }
    }
  }

  // Floating Frosted Glass Shelf (macOS Style)
  Rectangle {
    id: shelf
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom

    // Auto-hide smooth slide down animation
    anchors.bottomMargin: dockWindow.shouldHide ? (-height - 20) : (dockConfig.bottomMargin || 10)

    Behavior on anchors.bottomMargin {
      NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
    }

    readonly property int baseItemSize: dockConfig.dockSize || 42

    height: baseItemSize + 16
    // Dynamic shelf width that expands smoothly with parabolic icon wave
    width: dockLayout.width + 28
    radius: height / 2

    Behavior on width {
      NumberAnimation { duration: 110; easing.type: Easing.OutQuad }
    }

    // Omarchy theme aware translucent background
    color: Util.alpha(Commons.Color.background, dockConfig.glassOpacity || 0.45)
    border.width: 1
    border.color: Qt.rgba(255, 255, 255, 0.28)

    // Ambient drop shadow
    Rectangle {
      anchors.fill: parent
      anchors.topMargin: 4
      radius: parent.radius
      color: "black"
      opacity: 0.35
      scale: 0.98
      z: -1
    }

    // Top Glossy Specular Rim Reflection
    Rectangle {
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: shelf.radius * 0.4
      anchors.rightMargin: shelf.radius * 0.4
      height: 1
      color: Qt.rgba(255, 255, 255, 0.55)
    }

    // Hover area covering the whole shelf to track continuous parabolic wave coordinates
    MouseArea {
      id: shelfHoverArea
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.RightButton
      onEntered: {
        hideTimer.stop()
        dockWindow.isDockHovered = true
        dockWindow.isShelfHovered = true
      }
      onPositionChanged: function(mouse) {
        dockWindow.mouseShelfX = mouse.x
        dockWindow.isShelfHovered = true
        hideTimer.stop()
        dockWindow.isDockHovered = true
      }
      onExited: {
        dockWindow.isShelfHovered = false
        dockWindow.mouseShelfX = -9999
        hideTimer.restart()
      }
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) {
          dockWindow.openSettings()
        }
      }
    }

    // Dock Items Layout: Row with dynamic spacing
    Row {
      id: dockLayout
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      spacing: 8

      // 1. App Launcher / Launchpad (Modern macOS Rocket Icon)
      DockIcon {
        id: launchpadIcon
        visible: !dockConfig.preTasks || dockConfig.preTasks.showLauncher !== false
        baseSize: shelf.baseItemSize
        magnificationEnabled: dockConfig.magnification !== false
        maxMagnification: dockConfig.maxScale || 1.35
        app: ({
          id: "omarchy.menu",
          name: "Launchpad / Apps",
          icon: dockWindow.iconsDir + "/launchpad.svg",
          gradientStart: "#3b82f6",
          gradientEnd: "#1d4ed8"
        })
        onClicked: Quickshell.execDetached(["omarchy-shell", "shell", "summon", "omarchy.menu"])
        onRightClicked: function(mx, my, screenX) { dockWindow.openContextMenu(app, screenX) }
        onHovered: function() { hideTimer.stop(); dockWindow.isDockHovered = true; }
        onUnhovered: hideTimer.start()
      }

      // 2. Pinned Apps Row
      Repeater {
        id: pinnedRepeater
        model: dockConfig.pinnedApps || []

        DockIcon {
          id: pinnedIcon
          required property var modelData
          required property int index

          baseSize: shelf.baseItemSize
          magnificationEnabled: dockConfig.magnification !== false
          maxMagnification: dockConfig.maxScale || 1.35
          app: modelData

          isRunning: DockModel.isAppRunning(dockWindow.toplevelsList, modelData)
          isFocused: DockModel.isAppFocused(dockWindow.toplevelsList, ToplevelManager.activeToplevel, modelData)

          onClicked: dockWindow.launchOrActivate(modelData, pinnedIcon)
          onRightClicked: function(mx, my, screenX) { dockWindow.openContextMenu(modelData, screenX) }
          onHovered: function() { hideTimer.stop(); dockWindow.isDockHovered = true; }
          onUnhovered: hideTimer.start()
        }
      }

      // 3. Divider Separator for Recent / Unpinned Running Apps (Only shown if unpinned apps are running!)
      Rectangle {
        visible: (dockConfig.showRecentApps !== false) && (unpinnedRepeater.count > 0)
        width: 1
        height: Math.round(shelf.baseItemSize * 0.65)
        anchors.verticalCenter: parent.verticalCenter
        color: Qt.rgba(255, 255, 255, 0.22)
      }

      // 4. Recent / Active Unpinned Apps (macOS Style dynamic running apps partition)
      Repeater {
        id: unpinnedRepeater
        model: (dockConfig.showRecentApps !== false) ? dockWindow.unpinnedRunningApps : []

        DockIcon {
          id: unpinnedIcon
          required property var modelData
          required property int index

          baseSize: shelf.baseItemSize
          magnificationEnabled: dockConfig.magnification !== false
          maxMagnification: dockConfig.maxScale || 1.35
          app: modelData

          isRunning: true
          isFocused: DockModel.isAppFocused(dockWindow.toplevelsList, ToplevelManager.activeToplevel, modelData)

          onClicked: dockWindow.launchOrActivate(modelData, unpinnedIcon)
          onRightClicked: function(mx, my, screenX) { dockWindow.openContextMenu(modelData, screenX) }
          onHovered: function() { hideTimer.stop(); dockWindow.isDockHovered = true; }
          onUnhovered: hideTimer.start()
        }
      }

      // 5. Divider Separator before Pre-Tasks
      Rectangle {
        width: 1
        height: Math.round(shelf.baseItemSize * 0.65)
        anchors.verticalCenter: parent.verticalCenter
        color: Qt.rgba(255, 255, 255, 0.22)
      }

      // 6. Mission Control / Workspaces (Modern Desktop Spaces Icon)
      DockIcon {
        id: workspacesIcon
        visible: !dockConfig.preTasks || dockConfig.preTasks.showWorkspaces !== false
        baseSize: shelf.baseItemSize
        magnificationEnabled: dockConfig.magnification !== false
        maxMagnification: dockConfig.maxScale || 1.35
        isRunning: true
        app: ({
          id: "workspaces",
          name: "Mission Control (" + (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : "1") + ")",
          icon: dockWindow.iconsDir + "/workspaces.svg",
          gradientStart: "#ec4899",
          gradientEnd: "#be185d"
        })
        onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "workspace", "+1"])
        onRightClicked: function(mx, my, screenX) { dockWindow.openContextMenu(app, screenX) }
        onHovered: function() { hideTimer.stop(); dockWindow.isDockHovered = true; }
        onUnhovered: hideTimer.start()
      }

      // 7. Activity Monitor (Modern ECG Pulse Wave Icon)
      DockIcon {
        id: activityIcon
        visible: !dockConfig.preTasks || dockConfig.preTasks.showActivityMonitor !== false
        baseSize: shelf.baseItemSize
        magnificationEnabled: dockConfig.magnification !== false
        maxMagnification: dockConfig.maxScale || 1.35
        app: ({
          id: "stappmus.activity-monitor",
          name: "Activity Monitor",
          icon: dockWindow.iconsDir + "/activity-monitor.svg",
          gradientStart: "#10b981",
          gradientEnd: "#047857"
        })
        onClicked: Quickshell.execDetached(["omarchy-shell", "shell", "summon", "stappmus.activity-monitor"])
        onRightClicked: function(mx, my, screenX) { dockWindow.openContextMenu(app, screenX) }
        onHovered: function() { hideTimer.stop(); dockWindow.isDockHovered = true; }
        onUnhovered: hideTimer.start()
      }

      // 8. Plugin Store (Modern 3D Package Box Icon)
      DockIcon {
        id: pluginStoreIcon
        visible: !dockConfig.preTasks || dockConfig.preTasks.showPluginManager !== false
        baseSize: shelf.baseItemSize
        magnificationEnabled: dockConfig.magnification !== false
        maxMagnification: dockConfig.maxScale || 1.35
        app: ({
          id: "omaplug",
          name: "Plugin Store (Omaplug)",
          icon: dockWindow.iconsDir + "/omaplug.svg",
          gradientStart: "#8b5cf6",
          gradientEnd: "#6d28d9"
        })
        onClicked: Quickshell.execDetached(["omarchy-shell", "shell", "summon", "omaplug"])
        onRightClicked: function(mx, my, screenX) { dockWindow.openContextMenu(app, screenX) }
        onHovered: function() { hideTimer.stop(); dockWindow.isDockHovered = true; }
        onUnhovered: hideTimer.start()
      }

      // 9. Dock Settings (Modern Apple Metallic Gear Icon)
      DockIcon {
        id: settingsIcon
        visible: !dockConfig.preTasks || dockConfig.preTasks.showSettings !== false
        baseSize: shelf.baseItemSize
        magnificationEnabled: dockConfig.magnification !== false
        maxMagnification: dockConfig.maxScale || 1.35
        app: ({
          id: "dock-settings",
          name: "Dock Customizer (Edit Apps)",
          icon: dockWindow.iconsDir + "/settings.svg",
          gradientStart: "#64748b",
          gradientEnd: "#334155"
        })
        onClicked: dockWindow.openSettings()
        onRightClicked: function(mx, my, screenX) { dockWindow.openContextMenu(app, screenX) }
        onHovered: function() { hideTimer.stop(); dockWindow.isDockHovered = true; }
        onUnhovered: hideTimer.start()
      }

      // 10. Trash (Dynamic Empty vs Full Wastebasket Icon)
      DockIcon {
        id: trashIcon
        visible: !dockConfig.preTasks || dockConfig.preTasks.showTrash !== false
        baseSize: shelf.baseItemSize
        magnificationEnabled: dockConfig.magnification !== false
        maxMagnification: dockConfig.maxScale || 1.35
        app: ({
          id: "trash",
          name: dockWindow.isTrashFull ? "Trash (Items inside)" : "Trash (Empty)",
          icon: dockWindow.isTrashFull ? (dockWindow.iconsDir + "/trash-full.svg") : (dockWindow.iconsDir + "/trash-empty.svg"),
          gradientStart: "#94a3b8",
          gradientEnd: "#475569"
        })
        onClicked: Quickshell.execDetached(["xdg-open", "trash:///"])
        onRightClicked: function(mx, my, screenX) { dockWindow.openContextMenu(app, screenX) }
        onHovered: function() { hideTimer.stop(); dockWindow.isDockHovered = true; }
        onUnhovered: hideTimer.start()
      }
    }
  }

  // IPC command handler for toggling and settings
  IpcHandler {
    target: "omarchy-mac-dock"

    function toggle(): void {
      dockWindow.visible = !dockWindow.visible
    }
    function show(): void {
      dockWindow.visible = true
    }
    function hide(): void {
      dockWindow.visible = false
    }
    function settings(): void {
      dockWindow.openSettings()
    }
  }
}
