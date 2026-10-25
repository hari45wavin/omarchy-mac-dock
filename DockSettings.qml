import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "DockModel.js" as DockModel

PanelWindow {
  id: settingsWindow

  property var dockConfig: ({})
  property var originalConfig: ({})
  property var allApps: []
  property string searchQuery: ""

  signal configSaved(var newConfig)
  signal configLivePreview(var previewConfig)

  visible: false
  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }

  WlrLayershell.namespace: "omarchy-mac-dock-settings"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  exclusionMode: ExclusionMode.Ignore

  // Background Scrim (Dim desktop)
  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.55)

    MouseArea {
      anchors.fill: parent
      onClicked: settingsWindow.cancelAndClose()
    }
  }

  // Settings Card (macOS styled dialog)
  Rectangle {
    id: card
    width: Math.min(parent.width - 40, 840)
    height: Math.min(parent.height - 60, 680)
    anchors.centerIn: parent
    radius: 16
    color: Util.alpha(Commons.Color.background, 0.96)
    border.width: 1
    border.color: Qt.rgba(255, 255, 255, 0.18)
    clip: true

    MouseArea {
      anchors.fill: parent
      // Block clicks from passing to scrim
    }

    // Header
    Rectangle {
      id: header
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: 56
      color: Qt.rgba(255, 255, 255, 0.04)
      border.width: 0

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 16

        Text {
          text: "macOS Dock Customizer"
          color: Commons.Color.foreground
          font.pixelSize: Style.font.title
          font.bold: true
          font.family: Style.font.family
          Layout.fillWidth: true
        }

        // Close button (macOS red circle)
        Rectangle {
          width: 28
          height: 28
          radius: 14
          color: closeHover.containsMouse ? "#ef4444" : Qt.rgba(239, 68, 68, 0.8)

          Text {
            anchors.centerIn: parent
            text: "✕"
            color: "white"
            font.pixelSize: 12
            font.bold: true
          }

          MouseArea {
            id: closeHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: settingsWindow.cancelAndClose()
          }
        }
      }
    }

    // Tabs: [Pinned Apps] | [Pre-Tasks & Launchers] | [Appearance & Behavior]
    Rectangle {
      id: tabBar
      anchors.top: header.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      height: 44
      color: Qt.rgba(0, 0, 0, 0.20)

      property int activeTab: 0 // 0: Pinned Apps, 1: Pre-tasks, 2: Appearance

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        spacing: 12

        Repeater {
          model: [
            { label: "Pinned Apps", icon: "view-app-grid-symbolic" },
            { label: "Pre-Tasks & Launchers", icon: "preferences-desktop-multitasking-symbolic" },
            { label: "Appearance & Behavior", icon: "preferences-system" }
          ]

          Rectangle {
            width: tabLabel.implicitWidth + 24
            height: 32
            radius: 8
            color: tabBar.activeTab === index ? Commons.Color.accent : "transparent"

            Text {
              id: tabLabel
              anchors.centerIn: parent
              text: modelData.label
              color: tabBar.activeTab === index ? "white" : Qt.rgba(255, 255, 255, 0.7)
              font.pixelSize: Style.font.body
              font.bold: tabBar.activeTab === index
              font.family: Style.font.family
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: tabBar.activeTab = index
            }
          }
        }
      }
    }

    // Content Area
    Item {
      anchors.top: tabBar.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: footer.top
      anchors.margins: 16

      // ==========================================
      // TAB 0: PINNED APPS MANAGER
      // ==========================================
      Item {
        visible: tabBar.activeTab === 0
        anchors.fill: parent

        // Search Bar
        Rectangle {
          id: searchBox
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          height: 38
          radius: 8
          color: Qt.rgba(255, 255, 255, 0.08)
          border.width: 1
          border.color: Qt.rgba(255, 255, 255, 0.15)

          TextInput {
            id: searchInput
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            color: "white"
            font.pixelSize: Style.font.body
            font.family: Style.font.family
            onTextChanged: settingsWindow.searchQuery = text

            Text {
              visible: !searchInput.text
              text: "🔍 Search all installed applications to add to your dock..."
              color: Qt.rgba(255, 255, 255, 0.4)
              font.pixelSize: Style.font.body
              anchors.verticalCenter: parent.verticalCenter
              font.family: Style.font.family
            }
          }
        }

        // Split View: Pinned on Left | Available on Right
        RowLayout {
          anchors.top: searchBox.bottom
          anchors.topMargin: 14
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          spacing: 16

          // Pinned Apps List (Left Column)
          ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: parent.width * 0.48
            spacing: 8

            Text {
              text: "Currently Pinned in Dock (" + ((settingsWindow.dockConfig.pinnedApps || []).length) + ")"
              color: Commons.Color.foreground
              font.pixelSize: Style.font.caption
              font.bold: true
              font.family: Style.font.family
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.fillHeight: true
              radius: 10
              color: Qt.rgba(0, 0, 0, 0.25)
              border.width: 1
              border.color: Qt.rgba(255, 255, 255, 0.08)
              clip: true

              ListView {
                id: pinnedList
                anchors.fill: parent
                anchors.margins: 6
                spacing: 4
                model: settingsWindow.dockConfig.pinnedApps || []

                delegate: Rectangle {
                  required property var modelData
                  required property int index

                  width: pinnedList.width
                  height: 42
                  radius: 6
                  color: rowHover.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : "transparent"

                  MouseArea {
                    id: rowHover
                    anchors.fill: parent
                    hoverEnabled: true
                  }

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    Text {
                      text: modelData.name || modelData.id
                      color: "white"
                      font.pixelSize: Style.font.body
                      Layout.fillWidth: true
                      elide: Text.ElideRight
                      font.family: Style.font.family
                    }

                    // Move Up button
                    Rectangle {
                      width: 26
                      height: 26
                      radius: 4
                      color: upHover.containsMouse ? Qt.rgba(255, 255, 255, 0.2) : Qt.rgba(255, 255, 255, 0.08)
                      Text { anchors.centerIn: parent; text: "▲"; color: "white"; font.pixelSize: 10 }
                      MouseArea {
                        id: upHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: settingsWindow.movePinnedApp(index, -1)
                      }
                    }

                    // Move Down button
                    Rectangle {
                      width: 26
                      height: 26
                      radius: 4
                      color: downHover.containsMouse ? Qt.rgba(255, 255, 255, 0.2) : Qt.rgba(255, 255, 255, 0.08)
                      Text { anchors.centerIn: parent; text: "▼"; color: "white"; font.pixelSize: 10 }
                      MouseArea {
                        id: downHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: settingsWindow.movePinnedApp(index, 1)
                      }
                    }

                    // Remove / Unpin button
                    Rectangle {
                      width: 26
                      height: 26
                      radius: 4
                      color: removeHover.containsMouse ? "#ef4444" : Qt.rgba(239, 68, 68, 0.3)
                      Text { anchors.centerIn: parent; text: "✕"; color: "white"; font.pixelSize: 12; font.bold: true }
                      MouseArea {
                        id: removeHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: settingsWindow.removePinnedApp(index)
                      }
                    }
                  }
                }
              }
            }
          }

          // Available Applications List (Right Column)
          ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            spacing: 8

            Text {
              text: "Available System Apps (Click to Pin)"
              color: Commons.Color.foreground
              font.pixelSize: Style.font.caption
              font.bold: true
              font.family: Style.font.family
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.fillHeight: true
              radius: 10
              color: Qt.rgba(0, 0, 0, 0.25)
              border.width: 1
              border.color: Qt.rgba(255, 255, 255, 0.08)
              clip: true

              ListView {
                id: availableList
                anchors.fill: parent
                anchors.margins: 6
                spacing: 4
                model: settingsWindow.filteredApps(settingsWindow.searchQuery)

                delegate: Rectangle {
                  required property var modelData
                  width: availableList.width
                  height: 44
                  radius: 6
                  color: availHover.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : "transparent"

                  MouseArea {
                    id: availHover
                    anchors.fill: parent
                    hoverEnabled: true
                  }

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    Text {
                      Layout.fillWidth: true
                      text: modelData.name || modelData.id
                      color: "white"
                      font.pixelSize: Style.font.body
                      elide: Text.ElideRight
                      font.family: Style.font.family
                    }

                    Rectangle {
                      Layout.preferredWidth: 72
                      Layout.preferredHeight: 28
                      radius: 6
                      color: modelData.isPinned ? Qt.rgba(239, 68, 68, 0.25) : Commons.Color.accent

                      Text {
                        anchors.centerIn: parent
                        text: modelData.isPinned ? "Unpin" : "+ Pin"
                        color: "white"
                        font.pixelSize: 12
                        font.bold: true
                      }

                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          if (modelData.isPinned) {
                            settingsWindow.unpinAppById(modelData.id)
                          } else {
                            settingsWindow.pinApp(modelData)
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      // ==========================================
      // TAB 1: PRE-TASKS & LAUNCHERS
      // ==========================================
      Item {
        visible: tabBar.activeTab === 1
        anchors.fill: parent

        ColumnLayout {
          anchors.fill: parent
          spacing: 12

          Text {
            text: "Pre-Task Systems & Dock Widgets"
            color: Commons.Color.foreground
            font.pixelSize: Style.font.title
            font.bold: true
            font.family: Style.font.family
          }

          Text {
            text: "Toggle quick launchers and system status indicators shown in your macOS Dock shelf:"
            color: Qt.rgba(255, 255, 255, 0.7)
            font.pixelSize: Style.font.body
            font.family: Style.font.family
          }

          // Options Grid
          GridLayout {
            columns: 2
            rowSpacing: 12
            columnSpacing: 20
            Layout.fillWidth: true
            Layout.topMargin: 12

            Repeater {
              model: [
                { key: "showLauncher", label: "Launchpad / App Menu", desc: "macOS modern rocket launcher for applications" },
                { key: "showWorkspaces", label: "Mission Control / Workspaces", desc: "Displays current Hyprland workspace indicator" },
                { key: "showSettings", label: "Dock Settings Gear", desc: "Direct gear shortcut to edit dock layout anytime" },
                { key: "showTrash", label: "Trash Bin", desc: "macOS Trash shortcut with empty/full states" }
              ]

              Rectangle {
                Layout.fillWidth: true
                height: 58
                radius: 10
                color: Qt.rgba(255, 255, 255, 0.06)

                RowLayout {
                  anchors.fill: parent
                  anchors.margins: 12

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: modelData.label; color: "white"; font.bold: true; font.pixelSize: Style.font.body }
                    Text { text: modelData.desc; color: Qt.rgba(255, 255, 255, 0.6); font.pixelSize: Style.font.caption }
                  }

                  Rectangle {
                    width: 44
                    height: 24
                    radius: 12
                    color: settingsWindow.dockConfig.preTasks && settingsWindow.dockConfig.preTasks[modelData.key] !== false ? Commons.Color.accent : Qt.rgba(255, 255, 255, 0.2)

                    Rectangle {
                      width: 20
                      height: 20
                      radius: 10
                      color: "white"
                      anchors.verticalCenter: parent.verticalCenter
                      x: settingsWindow.dockConfig.preTasks && settingsWindow.dockConfig.preTasks[modelData.key] !== false ? 22 : 2
                      Behavior on x { NumberAnimation { duration: 150 } }
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: settingsWindow.togglePreTask(modelData.key)
                    }
                  }
                }
              }
            }
          }

          Item { Layout.fillHeight: true }
        }
      }

      // ==========================================
      // TAB 2: APPEARANCE & BEHAVIOR
      // ==========================================
      ScrollView {
        visible: tabBar.activeTab === 2
        anchors.fill: parent
        clip: true

        ColumnLayout {
          width: parent.width - 24
          spacing: 16

          // 1. Dock Icon Size Selector
          Rectangle {
            Layout.fillWidth: true
            height: 82
            radius: 10
            color: Qt.rgba(255, 255, 255, 0.06)

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: 14
              spacing: 8

              Text {
                text: "Dock Icon Size: " + (settingsWindow.dockConfig.dockSize || 44) + "px"
                color: "white"
                font.bold: true
                font.pixelSize: Style.font.body
                font.family: Style.font.family
              }

              RowLayout {
                spacing: 8
                Repeater {
                  model: [
                    { label: "Compact (36px)", size: 36 },
                    { label: "Small (42px)", size: 42 },
                    { label: "Medium (50px)", size: 50 },
                    { label: "Large (60px)", size: 60 },
                    { label: "XL (72px)", size: 72 }
                  ]

                  Rectangle {
                    width: 95
                    height: 34
                    radius: 6
                    color: settingsWindow.dockConfig.dockSize === modelData.size ? Commons.Color.accent : Qt.rgba(255, 255, 255, 0.12)
                    Text { anchors.centerIn: parent; text: modelData.label; color: "white"; font.pixelSize: 11; font.bold: true }
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: settingsWindow.updateDockSize(modelData.size)
                    }
                  }
                }
              }
            }
          }

          // 2. Auto-Hide & Visibility Mode (Intellihide / Always / Disabled)
          Rectangle {
            Layout.fillWidth: true
            height: 94
            radius: 10
            color: Qt.rgba(255, 255, 255, 0.06)

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: 14
              spacing: 8

              Text {
                text: "Dock Visibility & Auto-Hide Mode"
                color: "white"
                font.bold: true
                font.pixelSize: Style.font.body
              }

              RowLayout {
                spacing: 8
                Repeater {
                  model: [
                    { key: "intellihide", label: "Intellihide (Hide When Apps Open)" },
                    { key: "always", label: "Always Auto-Hide" },
                    { key: "disabled", label: "Always Visible (Reserve Space)" }
                  ]

                  Rectangle {
                    width: labelItem.implicitWidth + 24
                    height: 34
                    radius: 6
                    color: (settingsWindow.dockConfig.autoHideMode === modelData.key || (!settingsWindow.dockConfig.autoHideMode && modelData.key === "intellihide")) ? Commons.Color.accent : Qt.rgba(255, 255, 255, 0.12)

                    Text {
                      id: labelItem
                      anchors.centerIn: parent
                      text: modelData.label
                      color: "white"
                      font.pixelSize: 11
                      font.bold: true
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: settingsWindow.updateHideMode(modelData.key)
                    }
                  }
                }
              }
            }
          }

          // 3. Click to Minimize Active App
          Rectangle {
            Layout.fillWidth: true
            height: 60
            radius: 10
            color: Qt.rgba(255, 255, 255, 0.06)

            RowLayout {
              anchors.fill: parent
              anchors.margins: 14

              ColumnLayout {
                Layout.fillWidth: true
                Text { text: "Click Active App to Minimize"; color: "white"; font.bold: true; font.pixelSize: Style.font.body }
                Text { text: "Clicking a currently focused app icon automatically minimizes it; clicking again restores it"; color: Qt.rgba(255, 255, 255, 0.6); font.pixelSize: Style.font.caption }
              }

              Rectangle {
                width: 44
                height: 24
                radius: 12
                color: settingsWindow.dockConfig.clickToMinimize !== false ? Commons.Color.accent : Qt.rgba(255, 255, 255, 0.2)

                Rectangle {
                  width: 20
                  height: 20
                  radius: 10
                  color: "white"
                  anchors.verticalCenter: parent.verticalCenter
                  x: settingsWindow.dockConfig.clickToMinimize !== false ? 22 : 2
                  Behavior on x { NumberAnimation { duration: 150 } }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    var c = Util.cloneJson(settingsWindow.dockConfig)
                    c.clickToMinimize = !(c.clickToMinimize !== false)
                    settingsWindow.dockConfig = c
                    settingsWindow.configLivePreview(c)
                  }
                }
              }
            }
          }

          // 4. Hover Magnification Toggle
          Rectangle {
            Layout.fillWidth: true
            height: 60
            radius: 10
            color: Qt.rgba(255, 255, 255, 0.06)

            RowLayout {
              anchors.fill: parent
              anchors.margins: 14

              ColumnLayout {
                Layout.fillWidth: true
                Text { text: "macOS Hover Magnification Effect"; color: "white"; font.bold: true; font.pixelSize: Style.font.body }
                Text { text: "Smoothly magnifies icons when you hover your cursor over the dock shelf"; color: Qt.rgba(255, 255, 255, 0.6); font.pixelSize: Style.font.caption }
              }

              Rectangle {
                width: 44
                height: 24
                radius: 12
                color: settingsWindow.dockConfig.magnification !== false ? Commons.Color.accent : Qt.rgba(255, 255, 255, 0.2)

                Rectangle {
                  width: 20
                  height: 20
                  radius: 10
                  color: "white"
                  anchors.verticalCenter: parent.verticalCenter
                  x: settingsWindow.dockConfig.magnification !== false ? 22 : 2
                  Behavior on x { NumberAnimation { duration: 150 } }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    var c = Util.cloneJson(settingsWindow.dockConfig)
                    c.magnification = !(c.magnification !== false)
                    settingsWindow.dockConfig = c
                    settingsWindow.configLivePreview(c)
                  }
                }
              }
            }
          }

          // 5. App Launch Bounce Animation
          Rectangle {
            Layout.fillWidth: true
            height: 60
            radius: 10
            color: Qt.rgba(255, 255, 255, 0.06)

            RowLayout {
              anchors.fill: parent
              anchors.margins: 14

              ColumnLayout {
                Layout.fillWidth: true
                Text { text: "App Launch Bounce Animation"; color: "white"; font.bold: true; font.pixelSize: Style.font.body }
                Text { text: "Authentic macOS spring bounce animation when an app is launched until its window appears"; color: Qt.rgba(255, 255, 255, 0.6); font.pixelSize: Style.font.caption }
              }

              Rectangle {
                width: 44
                height: 24
                radius: 12
                color: settingsWindow.dockConfig.bounceOnLaunch !== false ? Commons.Color.accent : Qt.rgba(255, 255, 255, 0.2)

                Rectangle {
                  width: 20
                  height: 20
                  radius: 10
                  color: "white"
                  anchors.verticalCenter: parent.verticalCenter
                  x: settingsWindow.dockConfig.bounceOnLaunch !== false ? 22 : 2
                  Behavior on x { NumberAnimation { duration: 150 } }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    var c = Util.cloneJson(settingsWindow.dockConfig)
                    c.bounceOnLaunch = !(c.bounceOnLaunch !== false)
                    settingsWindow.dockConfig = c
                    settingsWindow.configLivePreview(c)
                  }
                }
              }
            }
          }

          // 6. Show Running Unpinned Apps in Dock
          Rectangle {
            Layout.fillWidth: true
            height: 60
            radius: 10
            color: Qt.rgba(255, 255, 255, 0.06)

            RowLayout {
              anchors.fill: parent
              anchors.margins: 14

              ColumnLayout {
                Layout.fillWidth: true
                Text { text: "Show Running Unpinned Apps"; color: "white"; font.bold: true; font.pixelSize: Style.font.body }
                Text { text: "Dynamically shows active applications in a recent partition; right-click any to keep it in dock"; color: Qt.rgba(255, 255, 255, 0.6); font.pixelSize: Style.font.caption }
              }

              Rectangle {
                width: 44
                height: 24
                radius: 12
                color: settingsWindow.dockConfig.showRecentApps !== false ? Commons.Color.accent : Qt.rgba(255, 255, 255, 0.2)

                Rectangle {
                  width: 20
                  height: 20
                  radius: 10
                  color: "white"
                  anchors.verticalCenter: parent.verticalCenter
                  x: settingsWindow.dockConfig.showRecentApps !== false ? 22 : 2
                  Behavior on x { NumberAnimation { duration: 150 } }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    var c = Util.cloneJson(settingsWindow.dockConfig)
                    c.showRecentApps = !(c.showRecentApps !== false)
                    settingsWindow.dockConfig = c
                    settingsWindow.configLivePreview(c)
                  }
                }
              }
            }
          }

          Item { Layout.fillHeight: true }
        }
      }
    }

    // Footer with Save / Close buttons
    Rectangle {
      id: footer
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      height: 56
      color: Qt.rgba(0, 0, 0, 0.3)

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20

        Text {
          text: "Changes take effect immediately and are saved to ~/.config/omarchy/mac-dock.json"
          color: Qt.rgba(255, 255, 255, 0.5)
          font.pixelSize: Style.font.caption
          font.family: Style.font.family
          Layout.fillWidth: true
        }

        Rectangle {
          width: 100
          height: 34
          radius: 8
          color: Qt.rgba(255, 255, 255, 0.15)
          Text { anchors.centerIn: parent; text: "Cancel"; color: "white"; font.bold: true }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: settingsWindow.cancelAndClose()
          }
        }

        Rectangle {
          width: 130
          height: 34
          radius: 8
          color: Commons.Color.accent
          Text { anchors.centerIn: parent; text: "Save Changes"; color: "white"; font.bold: true }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: settingsWindow.saveAndApply()
          }
        }
      }
    }
  }

  // --- Logic Helpers ---
  function openSettings(currentConfig) {
    originalConfig = Util.cloneJson(currentConfig || DockModel.defaultConfig())
    dockConfig = Util.cloneJson(originalConfig)
    loadSystemApps()
    visible = true
  }

  function cancelAndClose() {
    configLivePreview(originalConfig)
    visible = false
  }

  function updateDockSize(newSize) {
    var c = Util.cloneJson(dockConfig)
    c.dockSize = newSize
    dockConfig = c
    configLivePreview(c)
  }

  function updateHideMode(mode) {
    var c = Util.cloneJson(dockConfig)
    c.autoHideMode = mode
    c.autoHide = (mode === "always" || mode === "intellihide")
    c.reserveSpace = (mode === "disabled")
    dockConfig = c
    configLivePreview(c)
  }

  function loadSystemApps() {
    var rawValues = DesktopEntries.applications.values || []
    var list = []
    var pinnedMap = {}
    var pinned = dockConfig.pinnedApps || []
    for (var p = 0; p < pinned.length; p++) {
      pinnedMap[String(pinned[p].id).toLowerCase()] = true
      pinnedMap[String(pinned[p].desktopFile).toLowerCase()] = true
    }

    for (var i = 0; i < rawValues.length; i++) {
      var entry = rawValues[i]
      if (!entry || !entry.name || !entry.id) continue
      var appId = String(entry.id)
      var dFile = appId.indexOf(".desktop") !== -1 ? appId : appId + ".desktop"
      var isPinned = pinnedMap[appId.toLowerCase()] === true || pinnedMap[dFile.toLowerCase()] === true
      list.push({
        id: appId,
        name: String(entry.name),
        desktopFile: dFile,
        icon: String(entry.icon || "application-x-executable"),
        comment: String(entry.comment || ""),
        isPinned: isPinned
      })
    }
    list.sort(function(a, b) { return a.name.localeCompare(b.name) })
    allApps = list
  }

  function filteredApps(query) {
    if (!query || query.trim() === "") return allApps
    var q = query.toLowerCase().trim()
    return allApps.filter(function(app) {
      return app.name.toLowerCase().indexOf(q) !== -1 || app.id.toLowerCase().indexOf(q) !== -1
    })
  }

  function movePinnedApp(index, delta) {
    var target = index + delta
    var pinned = (dockConfig.pinnedApps || []).slice()
    if (target < 0 || target >= pinned.length) return
    var item = pinned.splice(index, 1)[0]
    pinned.splice(target, 0, item)
    var c = Util.cloneJson(dockConfig)
    c.pinnedApps = pinned
    dockConfig = c
    configLivePreview(c)
  }

  function removePinnedApp(index) {
    var pinned = (dockConfig.pinnedApps || []).slice()
    pinned.splice(index, 1)
    var c = Util.cloneJson(dockConfig)
    c.pinnedApps = pinned
    dockConfig = c
    configLivePreview(c)
    loadSystemApps()
  }

  function unpinAppById(id) {
    var pinned = (dockConfig.pinnedApps || []).slice()
    for (var i = 0; i < pinned.length; i++) {
      if (pinned[i].id === id || pinned[i].desktopFile === id) {
        pinned.splice(i, 1)
        break
      }
    }
    var c = Util.cloneJson(dockConfig)
    c.pinnedApps = pinned
    dockConfig = c
    configLivePreview(c)
    loadSystemApps()
  }

  function pinApp(app) {
    var pinned = (dockConfig.pinnedApps || []).slice()
    var gradient = DockModel.defaultGradients(pinned.length)
    var macIcon = DockModel.resolveMacIcon(app.id, app.icon)
    pinned.push({
      id: app.id,
      name: app.name,
      desktopFile: app.desktopFile,
      icon: macIcon,
      gradientStart: gradient.start,
      gradientEnd: gradient.end
    })
    var c = Util.cloneJson(dockConfig)
    c.pinnedApps = pinned
    dockConfig = c
    configLivePreview(c)
    loadSystemApps()
  }

  function togglePreTask(key) {
    var c = Util.cloneJson(dockConfig)
    if (!c.preTasks) c.preTasks = {}
    c.preTasks[key] = !c.preTasks[key]
    dockConfig = c
    configLivePreview(c)
  }

  function saveAndApply() {
    configSaved(dockConfig)
    visible = false
  }
}
