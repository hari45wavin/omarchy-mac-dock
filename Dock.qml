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

  // Feature detection for optional plugins
  property bool isOmaplugAvailable: false
  property bool isActivityMonitorAvailable: false

  // Parabolic Wave Tracking
  property real mouseShelfX: -9999
  property bool isShelfHovered: false
  readonly property var shelfItem: shelf
  readonly property var layoutItem: dockLayout

  property bool ignoreDiskChanges: false

  function updateHover(shelfX) {
    exitTimer.stop()
    triggerDismissTimer.stop()
    hideTimer.stop()
    mouseShelfX = shelfX
    isShelfHovered = true
    isDockHovered = true
  }

  function notifyHoverExit() {
    exitTimer.restart()
    hideTimer.restart()
  }

  Timer {
    id: exitTimer
    interval: 80
    onTriggered: {
      dockWindow.isShelfHovered = false
      dockWindow.mouseShelfX = -9999
    }
  }

  Timer {
    id: triggerDismissTimer
    interval: 1200
    onTriggered: {
      if (!dockWindow.isShelfHovered && !shelfHoverArea.containsMouse && !shelfContainerHover.containsMouse) {
        dockWindow.isDockHovered = false
      }
    }
  }

  Timer {
    id: saveCooldown
    interval: 1500
    onTriggered: dockWindow.ignoreDiskChanges = false
  }

  // Auto-hide & Hover State Tracking
  property bool isDockHovered: false
  readonly property string hideMode: dockConfig.autoHideMode ? dockConfig.autoHideMode : (dockConfig.autoHide ? "always" : "intellihide")
  readonly property bool isSettingsOpen: (settingsPanel !== null && settingsPanel.visible) || (menuPanel !== null && menuPanel.visible)

  // Focused Workspace window detection for Intellihide
  readonly property bool hasOpenAppsOnWorkspace: {
    try {
      if (Hyprland.focusedWorkspace) {
        return (Hyprland.focusedWorkspace.windows > 0)
      }
    } catch (e1) {}

    try {
      var list = dockWindow.toplevelsList || []
      for (var i = 0; i < list.length; i++) {
        var top = list[i]
        if (top && !top.minimized) {
          var appId = String(top.appId || "").toLowerCase()
          if (appId !== "hyprlock" && appId !== "wlogout" && appId !== "quickshell" && appId !== "omarchy-mac-dock") {
            return true
          }
        }
      }
    } catch (e2) {}

    return false
  }

  readonly property bool shouldHide: {
    if (isSettingsOpen || isDockHovered) return false
    if (hideMode === "always") return true
    if (hideMode === "intellihide") return hasOpenAppsOnWorkspace
    return false // "disabled" / "never"
  }

  // Trash Full State Tracking
  property bool isTrashFull: false

  visible: true
  color: "transparent"

  anchors {
    bottom: true
    left: true
    right: true
  }

  // Generous headroom (+110px) so magnified icons and floating tooltips NEVER get cut off
  implicitHeight: shelf.height + (dockConfig.bottomMargin || 10) + 110

  WlrLayershell.namespace: "omarchy-mac-dock"
  WlrLayershell.layer: WlrLayer.Top
  exclusionMode: (dockConfig.reserveSpace && hideMode === "disabled") ? ExclusionMode.Auto : ExclusionMode.Ignore

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
    width: shelf.width + 80
    height: shelf.height + (dockConfig.bottomMargin || 10) + 100

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
        dockWindow.notifyHoverExit()
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

  // Detect availability of optional plugins to avoid showing ghost icons
  Timer {
    id: pluginDetectTimer
    interval: 10000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      pluginCheckProcess.running = true
    }
  }

  Process {
    id: pluginCheckProcess
    command: ["bash", "-c", "echo \"omaplug:$(test -d $HOME/.config/omarchy/plugins/omaplug && echo 1 || echo 0);activity:$(test -d $HOME/.config/omarchy/plugins/stappmus.activity-monitor && echo 1 || echo 0)\""]
    stdout: StdioCollector {
      onDataChanged: {
        var raw = (text || "").trim()
        dockWindow.isOmaplugAvailable = (raw.indexOf("omaplug:1") !== -1)
        dockWindow.isActivityMonitorAvailable = (raw.indexOf("activity:1") !== -1)
      }
    }
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

  // Native Config Load and Save using Quickshell FileView
  function loadConfig() {
    if (dockWindow.ignoreDiskChanges) {
      return
    }
    if (configFileView.loaded) {
      try {
        var txt = configFileView.text()
        if (txt && txt.trim().length > 0) {
          var parsed = JSON.parse(txt)
          if (parsed && typeof parsed === "object" && parsed.pinnedApps && parsed.pinnedApps.length > 0) {
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
    if (!dockConfig || !dockConfig.pinnedApps || dockConfig.pinnedApps.length === 0) {
      dockConfig = DockModel.defaultConfig()
      updateToplevels()
    }
  }

  function saveConfig(newConfig) {
    dockConfig = newConfig
    dockWindow.ignoreDiskChanges = true
    saveCooldown.restart()
    updateToplevels()
    try {
      configFileView.setText(JSON.stringify(newConfig, null, 2) + "\n")
    } catch (e) {
      console.warn("mac-dock: failed to persist config via FileView:", e)
    }
  }

  function applyLiveConfig(newConfig) {
    dockConfig = newConfig
    updateToplevels()
  }

  FileView {
    id: configFileView
    path: dockWindow.configPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: dockWindow.loadConfig()
    onFileChanged: {
      if (!dockWindow.ignoreDiskChanges) {
        reload()
      }
    }
    onLoadFailed: function(error) {
      // Keep in-memory config intact
    }
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
        menuPanel.actionTriggered.connect(function(actionId, targetApp) {
          if (actionId === "quit") {
            var tops = DockModel.findAllMatchingToplevels(dockWindow.toplevelsList, targetApp)
            for (var t = 0; t < tops.length; t++) {
              var top = tops[t]
              if (top) {
                top.close()
              }
            }
          } else if (actionId === "minimize") {
            var mTop = DockModel.findMatchingToplevel(dockWindow.toplevelsList, targetApp)
            if (mTop) {
              mTop.activate()
              Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.move({ workspace = 'special:minimized', follow = false })"])
            }
          } else if (actionId === "togglePin") {
            var updated = DockModel.togglePinApp(dockWindow.dockConfig, targetApp)
            dockWindow.saveConfig(updated)
          } else if (actionId === "settings") {
            dockWindow.openSettings()
          } else if (actionId === "openTrash") {
            Quickshell.execDetached(["xdg-open", "trash:///"])
          } else if (actionId === "emptyTrash") {
            dockWindow.emptyTrash()
          }
        })
      }
    }
    if (menuPanel) {
      var running = DockModel.isAppRunning(dockWindow.toplevelsList, app)
      var pinned = DockModel.isAppPinned(dockWindow.dockConfig, app)
      menuPanel.openMenu(app, screenCenterX, running, pinned)
    }
  }

  Component {
    id: menuComponent
    DockMenu { }
  }

  // Multi-window cycling and launch activation
  function launchOrActivate(app, iconItem) {
    var matching = DockModel.findAllMatchingToplevels(toplevelsList, app)
    if (matching.length > 0) {
      var activeTop = ToplevelManager.activeToplevel
      var isCurrentActive = activeTop && DockModel.matchesToplevel(activeTop, app)

      if (isCurrentActive && dockConfig.clickToMinimize !== false) {
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.move({ workspace = 'special:minimized', follow = false })"])
        return
      }

      var targetTop = matching[0]
      if (matching.length > 1) {
        var currentIndex = -1
        for (var i = 0; i < matching.length; i++) {
          if (matching[i] === activeTop) {
            currentIndex = i
            break
          }
        }
        var nextIndex = (currentIndex + 1) % matching.length
        targetTop = matching[nextIndex]
      }

      // 1. Activate via Wayland toplevel protocol
      targetTop.activate()

      // 2. Dispatch Hyprland focus via Lua API across ANY workspace!
      var targetId = String(targetTop.appId || app.id || "").trim()
      var targetTitle = String(targetTop.title || app.name || "").trim()
      if (targetId.length > 0) {
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ window = \"class:" + targetId + "\" })"])
      } else if (targetTitle.length > 0) {
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ window = \"title:" + targetTitle + "\" })"])
      }

      // Also ensure brought to top
      Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.bring_to_top()"])
      return
    }

    // Trigger authentic macOS bounce animation
    if (dockConfig.bounceOnLaunch !== false && iconItem && typeof iconItem.startBounce === "function") {
      iconItem.startBounce()
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
    interval: 550
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
    anchors.horizontalCenter: parent.horizontalCenter
    width: Math.max(shelf.width + 120, 500)
    height: 8
    z: 9999

    MouseArea {
      id: triggerHoverArea
      anchors.fill: parent
      hoverEnabled: true
      onEntered: {
        dockWindow.isDockHovered = true
        triggerDismissTimer.restart()
      }
      onExited: {
        triggerDismissTimer.restart()
      }
    }
  }

  // Floating Frosted Glass Shelf (macOS Style)
  Rectangle {
    id: shelf
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom

    // Auto-hide smooth slide down animation
    anchors.bottomMargin: dockWindow.shouldHide ? (-height - 24) : (dockConfig.bottomMargin || 10)

    Behavior on anchors.bottomMargin {
      NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
    }

    readonly property int baseItemSize: dockConfig.dockSize || 44

    height: baseItemSize + 16
    width: dockLayout.width + 28
    radius: height / 2

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
        dockWindow.updateHover(shelfHoverArea.mouseX)
      }
      onPositionChanged: function(mouse) {
        dockWindow.updateHover(mouse.x)
      }
      onExited: {
        dockWindow.notifyHoverExit()
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
      anchors.centerIn: parent
      spacing: 6

      // 1. Launchpad / App Grid Launcher
      DockIcon {
        id: launchpadIcon
        visible: !dockConfig.preTasks || dockConfig.preTasks.showLauncher !== false
        baseSize: shelf.baseItemSize
        magnificationEnabled: dockConfig.magnification !== false
        maxMagnification: dockConfig.maxScale || 1.35
        app: ({
          id: "omarchy.menu",
          name: "Launchpad",
          icon: dockWindow.iconsDir + "/launchpad.png",
          gradientStart: "#3b82f6",
          gradientEnd: "#1d4ed8"
        })
        onClicked: Quickshell.execDetached(["omarchy-shell", "shell", "summon", "omarchy.menu"])
        onRightClicked: function(mx, my, screenX) { dockWindow.openContextMenu(app, screenX) }
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
        onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"+1\" })"])
        onRightClicked: function(mx, my, screenX) { dockWindow.openContextMenu(app, screenX) }
      }

      // 7. Activity Monitor (Only shown if installed or enabled)
      DockIcon {
        id: activityIcon
        visible: dockConfig.preTasks && dockConfig.preTasks.showActivityMonitor === true && dockWindow.isActivityMonitorAvailable
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
      }

      // 8. Plugin Store (Omaplug - Only shown if omaplug is installed)
      DockIcon {
        id: pluginStoreIcon
        visible: dockConfig.preTasks && dockConfig.preTasks.showPluginManager === true && dockWindow.isOmaplugAvailable
        baseSize: shelf.baseItemSize
        magnificationEnabled: dockConfig.magnification !== false
        maxMagnification: dockConfig.maxScale || 1.35
        app: ({
          id: "omaplug",
          name: "Plugin Store",
          icon: dockWindow.iconsDir + "/omaplug.svg",
          gradientStart: "#8b5cf6",
          gradientEnd: "#6d28d9"
        })
        onClicked: Quickshell.execDetached(["omarchy-shell", "shell", "summon", "omaplug"])
        onRightClicked: function(mx, my, screenX) { dockWindow.openContextMenu(app, screenX) }
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
          name: "Dock Settings",
          icon: dockWindow.iconsDir + "/settings.png",
          gradientStart: "#64748b",
          gradientEnd: "#334155"
        })
        onClicked: dockWindow.openSettings()
        onRightClicked: function(mx, my, screenX) { dockWindow.openContextMenu(app, screenX) }
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
          icon: dockWindow.isTrashFull ? (dockWindow.iconsDir + "/trash-full.png") : (dockWindow.iconsDir + "/trash-empty.png"),
          gradientStart: "#94a3b8",
          gradientEnd: "#475569"
        })
        onClicked: Quickshell.execDetached(["xdg-open", "trash:///"])
        onRightClicked: function(mx, my, screenX) { dockWindow.openContextMenu(app, screenX) }
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
