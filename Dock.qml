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
import "IconResolver.js" as IconResolver

PanelWindow {
  id: dockWindow

  property string home: Quickshell.env("HOME")
  property string pluginDir: home + "/.config/omarchy/plugins/omarchy-mac-dock"
  property string iconsDir: pluginDir + "/assets/icons"
  property string configPath: home + "/.config/omarchy/mac-dock.json"
  property string iconMapPath: home + "/.config/omarchy/dock-icons.json"
  property string helperPath: pluginDir + "/scripts/omarchy-dock-icon"
  property var dockConfig: DockModel.defaultConfig()
  property var toplevelsList: []
  property var unpinnedRunningApps: []
  property var settingsPanel: null
  property var menuPanel: null
  property var iconPickerPanel: null
  property var altTabPanel: null
  property var previewPanel: previewPanelInstance
  property bool isWritingConfig: false
  property var minimizedApps: ({})

  // Custom Icons State
  property var customIcons: ({})
  property int customIconRevision: 0

  // Live Window Preview State (macOS Exposé)
  property string previewAppId: ""
  property var previewPendingApp: null
  property real previewCenterX: 0
  property var previewWindows: []
  property bool previewVisible: false

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
  readonly property bool isSettingsOpen: (settingsPanel !== null && settingsPanel.visible) || (menuPanel !== null && menuPanel.visible) || (iconPickerPanel !== null && iconPickerPanel.open)

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
            var wins = dockWindow.gatherWindowsForApp(targetApp)
            for (var t = 0; t < wins.length; t++) {
              dockWindow.closeWindowAddress(wins[t].address)
            }
          } else if (actionId === "minimize") {
            dockWindow.minimizeApp(targetApp)
          } else if (actionId === "maximize") {
            dockWindow.toggleMaximizeApp(targetApp)
          } else if (actionId === "activate") {
            dockWindow.launchOrActivate(targetApp, null)
          } else if (actionId === "togglePin") {
            var updated = DockModel.togglePinApp(dockWindow.dockConfig, targetApp)
            dockWindow.saveConfig(updated)
          } else if (actionId === "changeIcon") {
            dockWindow.openIconPicker(targetApp.id, targetApp.name)
          } else if (actionId === "manageIcons") {
            dockWindow.openManageIcons()
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

  // Live Desktop Windows Discovery for Previews, Exposé and Precise Focus
  function gatherWindowsForApp(app) {
    var output = []
    if (!app) return output
    var targetId = String(app.id || "").toLowerCase()
    var desktopFile = String(app.desktopFile || "").toLowerCase().replace(/\.desktop$/, "")
    var name = String(app.name || "").toLowerCase()
    var exec = String(app.exec || "").toLowerCase()
    var baseExec = exec ? exec.split(" ")[0].split("/").pop().toLowerCase() : ""

    try {
      var values = Hyprland.toplevels.values || []
      for (var i = 0; i < values.length; i++) {
        var candidate = values[i]
        if (!candidate) continue
        var ids = []
        if (candidate.wayland && candidate.wayland.appId) ids.push(String(candidate.wayland.appId).toLowerCase())
        var ipc = candidate.lastIpcObject || {}
        if (ipc.appId) ids.push(String(ipc.appId).toLowerCase())
        if (ipc["class"]) ids.push(String(ipc["class"]).toLowerCase())
        if (ipc.initialClass) ids.push(String(ipc.initialClass).toLowerCase())

        var match = false
        for (var j = 0; j < ids.length; j++) {
          var cid = ids[j]
          if (cid === targetId || cid === desktopFile || (baseExec && cid === baseExec)) {
            match = true; break
          }
          if (targetId.length > 2 && (cid.indexOf(targetId) !== -1 || targetId.indexOf(cid) !== -1)) {
            match = true; break
          }
          if (desktopFile.length > 2 && (cid.indexOf(desktopFile) !== -1 || desktopFile.indexOf(cid) !== -1)) {
            match = true; break
          }
        }
        if (!match && name.length > 2) {
          var cTitle = String(candidate.title || "").toLowerCase()
          if (cTitle.indexOf(name) !== -1) match = true
        }

        if (!match) continue

        output.push({
          address: String(candidate.address || ""),
          title: String(candidate.title || name || "Window"),
          active: !!(ipc.focused || candidate.focused),
          mapped: !!ipc.mapped,
          minimized: !!ipc.minimized,
          workspaceId: (ipc.workspace && ipc.workspace.id !== undefined) ? ipc.workspace.id : -1,
          appId: targetId
        })
      }
    } catch (e) {
      console.warn("gatherWindowsForApp error:", e)
    }
    return output
  }

  // Hover Window Previews Management (macOS Peek)
  function requestPreviewForApp(app, centerX) {
    if (!app || isSettingsOpen || (menuPanel && menuPanel.visible)) return
    previewGraceTimer.stop()
    previewPendingApp = app
    previewCenterX = centerX
    previewDelayTimer.restart()
  }

  function notifyIconHoverExit(app) {
    previewDelayTimer.stop()
    previewGraceTimer.restart()
  }

  function hidePreview() {
    previewDelayTimer.stop()
    previewGraceTimer.stop()
    previewVisible = false
    previewAppId = ""
    previewPendingApp = null
    previewWindows = []
  }

  Timer {
    id: previewDelayTimer
    interval: 220
    onTriggered: {
      if (!dockWindow.previewPendingApp || dockWindow.isSettingsOpen || (dockWindow.menuPanel && dockWindow.menuPanel.visible)) return
      var wins = dockWindow.gatherWindowsForApp(dockWindow.previewPendingApp)
      if (wins.length === 0) return
      dockWindow.previewAppId = String(dockWindow.previewPendingApp.id || "")
      dockWindow.previewWindows = wins
      dockWindow.previewVisible = true
    }
  }

  Timer {
    id: previewGraceTimer
    interval: 320
    onTriggered: {
      dockWindow.hidePreview()
    }
  }

  // Address-based Smooth Window Focus with Cursor Warps Protection
  function focusWindowAddress(address) {
    if (!address) return false
    var normalized = String(address)
    if (normalized.indexOf("0x") !== 0) normalized = "0x" + normalized
    dockWindow.hidePreview()
    Quickshell.execDetached(["bash", "-c", "hyprctl eval 'hl.config({ cursor = { no_warps = true } })'; hyprctl dispatch 'hl.dsp.focus({ window = \"address:" + normalized + "\" })'; hyprctl dispatch 'hl.dsp.window.bring_to_top()'; sleep 0.25; hyprctl eval 'hl.config({ cursor = { no_warps = false } })'"])
    return true
  }

  // Address-based Window Close
  function closeWindowAddress(address) {
    if (!address) return false
    var normalized = String(address)
    if (normalized.indexOf("0x") !== 0) normalized = "0x" + normalized
    Quickshell.execDetached(["hyprctl", "dispatch", "closewindow", "address:" + normalized])
    if (dockWindow.previewPendingApp) {
      Qt.callLater(function() {
        var wins = dockWindow.gatherWindowsForApp(dockWindow.previewPendingApp)
        if (wins.length === 0) {
          dockWindow.hidePreview()
        } else {
          dockWindow.previewWindows = wins
        }
      })
    }
    return true
  }

  // Smooth Minimize to Special Workspace
  function minimizeApp(app) {
    var wins = gatherWindowsForApp(app)
    if (wins.length === 0) return
    var targetWin = wins[0]
    var addr = targetWin.address
    var appId = String(app.id || "").toLowerCase()
    var curWs = Hyprland.focusedWorkspace ? String(Hyprland.focusedWorkspace.id) : "1"

    var newMap = Object.assign({}, dockWindow.minimizedApps)
    newMap[appId] = {
      address: addr,
      workspace: curWs,
      title: String(targetWin.title || app.name || ""),
      time: Date.now()
    }
    dockWindow.minimizedApps = newMap

    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.move({ workspace = 'special:minimized', window = 'address:" + addr + "' })"])
  }

  // Smooth Restore from Special Workspace onto active workspace
  function restoreApp(app) {
    var appId = String(app.id || "").toLowerCase()
    var minData = dockWindow.minimizedApps ? dockWindow.minimizedApps[appId] : null
    var curWs = Hyprland.focusedWorkspace ? String(Hyprland.focusedWorkspace.id) : "1"
    var origWs = (minData && minData.workspace) ? minData.workspace : curWs
    var addr = minData ? minData.address : ""

    var newMap = Object.assign({}, dockWindow.minimizedApps)
    delete newMap[appId]
    dockWindow.minimizedApps = newMap

    var windowTarget = addr ? ("address:" + addr) : ("class:" + (app.id || ""))
    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.move({ workspace = '" + origWs + "', window = '" + windowTarget + "' })"])
    dockWindow.focusWindowAddress(addr || windowTarget)
  }

  // Toggle Maximize / Zoom
  function toggleMaximizeApp(app) {
    var wins = gatherWindowsForApp(app)
    if (wins.length > 0) {
      Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.fullscreen({ mode = 1, window = 'address:" + wins[0].address + "' })"])
    }
  }

  // Multi-window cycling, minimize, restore, and launch activation
  function launchOrActivate(app, iconItem) {
    var appId = String(app.id || "").toLowerCase()

    // 1. If currently minimized, restore it immediately
    if (dockWindow.minimizedApps && dockWindow.minimizedApps[appId]) {
      dockWindow.restoreApp(app)
      return
    }

    var wins = gatherWindowsForApp(app)
    if (wins.length > 0) {
      var activeIndex = -1
      for (var i = 0; i < wins.length; i++) {
        if (wins[i].active) {
          activeIndex = i
          break
        }
      }

      // 2. Click active focused app to minimize
      if (activeIndex !== -1 && dockConfig.clickToMinimize !== false && wins.length === 1) {
        dockWindow.minimizeApp(app)
        return
      }

      var targetWin = wins[0]
      if (wins.length > 1 && activeIndex !== -1) {
        targetWin = wins[(activeIndex + 1) % wins.length]
      }

      dockWindow.focusWindowAddress(targetWin.address)
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

  // Live Window Preview Overlay Panel
  WindowPreviewPanel {
    id: previewPanelInstance
    screen: dockWindow.screen
    previewVisible: dockWindow.previewVisible && !dockWindow.isSettingsOpen && (!dockWindow.menuPanel || !dockWindow.menuPanel.visible)
    windowList: dockWindow.previewWindows
    centerX: dockWindow.previewCenterX
    bottomY: dockWindow.height - (shelf.height + (dockConfig.bottomMargin || 10))
    iconSourceFor: function(winData) {
      return IconResolver.resolveAppIcon({ id: winData.appId }, dockWindow.customIcons, dockWindow.iconsDir, dockWindow.customIconRevision)
    }
    onActivated: function(winData) {
      dockWindow.focusWindowAddress(winData.address)
    }
    onCloseRequested: function(winData) {
      dockWindow.closeWindowAddress(winData.address)
    }
    onPreviewHoverEntered: {
      dockWindow.previewGraceTimer.stop()
      dockWindow.isDockHovered = true
    }
    onPreviewHoverExited: {
      dockWindow.previewGraceTimer.restart()
    }
  }

  // Custom Icon Management & Picker Integration
  FileView {
    id: customIconsFileView
    path: dockWindow.iconMapPath
    watchChanges: true
    printErrors: false
    onLoaded: dockWindow.loadCustomIcons(text())
    onFileChanged: reload()
  }

  function loadCustomIcons(content) {
    try {
      var parsed = JSON.parse(String(content || "{}"))
      if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
        dockWindow.customIcons = parsed
        dockWindow.customIconRevision++
      }
    } catch (e) {}
  }

  function openIconPicker(appId, appName) {
    if (!iconPickerPanel) {
      iconPickerPanel = iconPickerComponent.createObject(dockWindow, {
        screen: dockWindow.screen,
        helperPath: dockWindow.helperPath,
        customIcons: dockWindow.customIcons,
        iconSourceFor: function(id) {
          return IconResolver.resolveAppIcon({ id: id }, dockWindow.customIcons, dockWindow.iconsDir, dockWindow.customIconRevision)
        }
      })
    }
    if (iconPickerPanel) {
      iconPickerPanel.customIcons = dockWindow.customIcons
      iconPickerPanel.openForApp(appId, appName, false, true)
    }
  }

  function openManageIcons() {
    if (!iconPickerPanel) {
      iconPickerPanel = iconPickerComponent.createObject(dockWindow, {
        screen: dockWindow.screen,
        helperPath: dockWindow.helperPath,
        customIcons: dockWindow.customIcons,
        iconSourceFor: function(id) {
          return IconResolver.resolveAppIcon({ id: id }, dockWindow.customIcons, dockWindow.iconsDir, dockWindow.customIconRevision)
        }
      })
    }
    if (iconPickerPanel) {
      iconPickerPanel.customIcons = dockWindow.customIcons
      iconPickerPanel.openManage(true)
    }
  }

  Component {
    id: iconPickerComponent
    IconPickerPanel { }
  }

  // Alt-Tab / App Switcher HUD Integration
  function openAltTab() {
    if (!altTabPanel) {
      altTabPanel = altTabComponent.createObject(dockWindow, {
        screen: dockWindow.screen,
        iconSourceFor: function(app) {
          return IconResolver.resolveAppIcon(app, dockWindow.customIcons, dockWindow.iconsDir, dockWindow.customIconRevision)
        }
      })
      if (altTabPanel) {
        altTabPanel.activated.connect(function(appId, appName) {
          dockWindow.launchOrActivate({ id: appId, name: appName }, null)
        })
      }
    }
    return altTabPanel
  }

  Component {
    id: altTabComponent
    AltTabPanel { }
  }

  function altTabNext() {
    var p = openAltTab()
    if (!p) return
    if (p.active) {
      p.next()
    } else {
      var running = dockWindow.getRunningAppsList()
      p.open(running, 1)
    }
  }

  function altTabPrev() {
    var p = openAltTab()
    if (!p) return
    if (p.active) {
      p.prev()
    } else {
      var running = dockWindow.getRunningAppsList()
      p.open(running, running.length > 1 ? running.length - 1 : 0)
    }
  }

  function altTabCancel() {
    if (altTabPanel && altTabPanel.active) {
      altTabPanel.cancel()
    }
  }

  function getRunningAppsList() {
    var list = []
    var seen = {}
    var pinned = dockConfig.pinnedApps || []
    for (var i = 0; i < pinned.length; i++) {
      if (DockModel.isAppRunning(dockWindow.toplevelsList, pinned[i])) {
        list.push(pinned[i])
        seen[pinned[i].id] = true
      }
    }
    var unpinned = dockWindow.unpinnedRunningApps || []
    for (var j = 0; j < unpinned.length; j++) {
      if (!seen[unpinned[j].id]) {
        list.push(unpinned[j])
        seen[unpinned[j].id] = true
      }
    }
    return list
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
    function manageIcons(): void {
      dockWindow.openManageIcons()
    }
    function altTabNext(): void {
      dockWindow.altTabNext()
    }
    function altTabPrev(): void {
      dockWindow.altTabPrev()
    }
    function altTabCancel(): void {
      dockWindow.altTabCancel()
    }
  }
}
