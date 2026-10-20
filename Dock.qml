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
  property string configPath: home + "/.config/omarchy/mac-dock.json"
  property var dockConfig: DockModel.defaultConfig()
  property var toplevelsList: []
  property var settingsPanel: null

  visible: true
  color: "transparent"

  anchors {
    bottom: true
    left: true
    right: true
  }

  implicitHeight: shelf.height + (dockConfig.bottomMargin || 10) + 16

  WlrLayershell.namespace: "omarchy-mac-dock"
  WlrLayershell.layer: WlrLayer.Top
  exclusionMode: dockConfig.reserveSpace ? ExclusionMode.Auto : ExclusionMode.Ignore

  // Input mask ensures mouse clicks outside the rounded shelf pass straight to background windows
  mask: Region {
    item: shelf
  }

  // Hyprland / Wayland Toplevels Tracking for Running Dots
  function updateToplevels() {
    try {
      toplevelsList = ToplevelManager.toplevels.values || []
    } catch (e) {
      toplevelsList = []
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

  Component.onCompleted: {
    loadConfig()
    updateToplevels()
  }

  // Load config from ~/.config/omarchy/mac-dock.json
  function loadConfig() {
    if (configFileView.loaded) {
      try {
        var parsed = JSON.parse(configFileView.text())
        if (parsed && typeof parsed === "object") {
          dockConfig = parsed
          return
        }
      } catch (e) {
        console.warn("mac-dock: failed to parse config JSON, using defaults")
      }
    }
    dockConfig = DockModel.defaultConfig()
  }

  function saveConfig(newConfig) {
    dockConfig = newConfig
    Quickshell.execDetached([
      "python3",
      "-c",
      "import sys; open(sys.argv[2], 'w').write(sys.argv[1])",
      JSON.stringify(newConfig, null, 2),
      dockWindow.configPath
    ])
  }

  function applyLiveConfig(newConfig) {
    dockConfig = newConfig
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

  // App Launcher & Minimize/Restore Handler
  function launchOrActivate(app) {
    var match = DockModel.findMatchingToplevel(toplevelsList, app)
    var active = ToplevelManager.activeToplevel

    if (match) {
      // Click-to-minimize: if already focused and minimize is enabled in config
      if (active && DockModel.matchesToplevel(active, app)) {
        if (dockConfig.clickToMinimize !== false) {
          // Send active window to special:minimized
          Quickshell.execDetached(["hyprctl", "eval", "hl.dsp.window.move({ workspace = 'special:minimized', follow = false })"])
          return
        }
      }

      // App is running: restore and activate
      Quickshell.execDetached(["hyprctl", "eval", "hl.dsp.workspace.toggle_special('minimized')"])
      match.activate()
      Quickshell.execDetached(["hyprctl", "eval", "hl.dsp.window.bring_to_top()"])
      return
    }

    // App is not running: launch it
    if (app.exec && app.exec.length > 0) {
      Quickshell.execDetached(["bash", "-c", app.exec])
    } else if (app.desktopFile && app.desktopFile.length > 0) {
      Quickshell.execDetached(["uwsm-app", "--", "gtk-launch", app.desktopFile])
    }
  }

  // Floating Frosted Glass Shelf (macOS Style)
  Rectangle {
    id: shelf
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: dockConfig.bottomMargin || 10

    readonly property int baseItemSize: dockConfig.dockSize || 52

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

    // Dock Items Layout: using Row for rock-solid horizontal layout
    Row {
      id: dockLayout
      anchors.centerIn: parent
      spacing: 8

      // 1. App Launcher / Launchpad (Pre-task)
      DockIcon {
        visible: !dockConfig.preTasks || dockConfig.preTasks.showLauncher !== false
        baseSize: shelf.baseItemSize
        magnificationEnabled: dockConfig.magnification !== false
        maxMagnification: dockConfig.maxScale || 1.25
        app: ({
          id: "omarchy.menu",
          name: "Launchpad / Apps",
          icon: "view-app-grid-symbolic",
          gradientStart: "#3b82f6",
          gradientEnd: "#1d4ed8"
        })
        onClicked: Quickshell.execDetached(["omarchy-shell", "shell", "summon", "omarchy.menu"])
        onRightClicked: dockWindow.openSettings()
      }

      // 2. Pinned Apps Row
      Repeater {
        model: dockConfig.pinnedApps || []

        DockIcon {
          required property var modelData
          required property int index

          baseSize: shelf.baseItemSize
          magnificationEnabled: dockConfig.magnification !== false
          maxMagnification: dockConfig.maxScale || 1.25
          app: modelData

          isRunning: DockModel.isAppRunning(dockWindow.toplevelsList, modelData)
          isFocused: DockModel.isAppFocused(dockWindow.toplevelsList, ToplevelManager.activeToplevel, modelData)

          onClicked: dockWindow.launchOrActivate(modelData)
          onRightClicked: dockWindow.openSettings()
        }
      }

      // 3. Divider Separator
      Rectangle {
        width: 1
        height: Math.round(shelf.baseItemSize * 0.65)
        anchors.verticalCenter: parent.verticalCenter
        color: Qt.rgba(255, 255, 255, 0.22)
      }

      // 4. Workspaces Indicator (Pre-task)
      DockIcon {
        visible: !dockConfig.preTasks || dockConfig.preTasks.showWorkspaces !== false
        baseSize: shelf.baseItemSize
        magnificationEnabled: dockConfig.magnification !== false
        maxMagnification: dockConfig.maxScale || 1.25
        isRunning: true
        app: ({
          id: "workspaces",
          name: "Mission Control / Workspaces (" + (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : "1") + ")",
          icon: "preferences-desktop-multitasking-symbolic",
          gradientStart: "#ec4899",
          gradientEnd: "#be185d"
        })
        onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "workspace", "+1"])
        onRightClicked: dockWindow.openSettings()
      }

      // 5. Activity Monitor (Pre-task)
      DockIcon {
        visible: !dockConfig.preTasks || dockConfig.preTasks.showActivityMonitor !== false
        baseSize: shelf.baseItemSize
        magnificationEnabled: dockConfig.magnification !== false
        maxMagnification: dockConfig.maxScale || 1.25
        app: ({
          id: "stappmus.activity-monitor",
          name: "Activity Monitor",
          icon: "utilities-system-monitor",
          gradientStart: "#10b981",
          gradientEnd: "#047857"
        })
        onClicked: Quickshell.execDetached(["omarchy-shell", "shell", "summon", "stappmus.activity-monitor"])
        onRightClicked: dockWindow.openSettings()
      }

      // 6. Plugin Manager (omaplug)
      DockIcon {
        visible: !dockConfig.preTasks || dockConfig.preTasks.showPluginManager !== false
        baseSize: shelf.baseItemSize
        magnificationEnabled: dockConfig.magnification !== false
        maxMagnification: dockConfig.maxScale || 1.25
        app: ({
          id: "omaplug",
          name: "Plugin Store (Omaplug)",
          icon: "package-x-generic",
          gradientStart: "#8b5cf6",
          gradientEnd: "#6d28d9"
        })
        onClicked: Quickshell.execDetached(["omarchy-shell", "shell", "summon", "omaplug"])
        onRightClicked: dockWindow.openSettings()
      }

      // 7. Dock Settings (Edit Mode)
      DockIcon {
        visible: !dockConfig.preTasks || dockConfig.preTasks.showSettings !== false
        baseSize: shelf.baseItemSize
        magnificationEnabled: dockConfig.magnification !== false
        maxMagnification: dockConfig.maxScale || 1.25
        app: ({
          id: "dock-settings",
          name: "Dock Customizer (Edit Apps)",
          icon: "preferences-system",
          gradientStart: "#64748b",
          gradientEnd: "#334155"
        })
        onClicked: dockWindow.openSettings()
        onRightClicked: dockWindow.openSettings()
      }

      // 8. Trash (Pre-task)
      DockIcon {
        visible: !dockConfig.preTasks || dockConfig.preTasks.showTrash !== false
        baseSize: shelf.baseItemSize
        magnificationEnabled: dockConfig.magnification !== false
        maxMagnification: dockConfig.maxScale || 1.25
        app: ({
          id: "trash",
          name: "Trash Bin",
          icon: "user-trash",
          gradientStart: "#94a3b8",
          gradientEnd: "#475569"
        })
        onClicked: Quickshell.execDetached(["nautilus", "trash:///"])
        onRightClicked: dockWindow.openSettings()
      }
    }

    // Right click on shelf background opens settings
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.RightButton
      cursorShape: Qt.ArrowCursor
      z: -1
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) {
          dockWindow.openSettings()
        }
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
