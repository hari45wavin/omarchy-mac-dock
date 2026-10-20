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
      onClicked: settingsWindow.closeSettings()
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
            onClicked: settingsWindow.closeSettings()
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
          border.color: searchInput.activeFocus ? Commons.Color.accent : Qt.rgba(255, 255, 255, 0.15)

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 8

            TextInput {
              id: searchInput
              Layout.fillWidth: true
              Layout.fillHeight: true
              verticalAlignment: TextInput.AlignVCenter
              color: "white"
              font.pixelSize: Style.font.body
              font.family: Style.font.family
              clip: true

              Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                text: "Search installed applications to pin or unpin..."
                color: Qt.rgba(255, 255, 255, 0.4)
                font.pixelSize: Style.font.body
                font.family: Style.font.family
                visible: !searchInput.text && !searchInput.activeFocus
              }
            }

            Rectangle {
              visible: searchInput.text.length > 0
              width: 20
              height: 20
              radius: 10
              color: Qt.rgba(255, 255, 255, 0.2)
              Text {
                anchors.centerIn: parent
                text: "✕"
                color: "white"
                font.pixelSize: 10
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: searchInput.text = ""
              }
            }
          }
        }

        // Two Column List: Left = Currently Pinned, Right = Available Apps to Add
        RowLayout {
          anchors.top: searchBox.bottom
          anchors.topMargin: 12
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          spacing: 16

          // Left: Currently Pinned Apps
          Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 360
            radius: 10
            color: Qt.rgba(0, 0, 0, 0.25)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.1)

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: 12

              Text {
                text: "Currently Pinned in Dock (" + (settingsWindow.dockConfig.pinnedApps ? settingsWindow.dockConfig.pinnedApps.length : 0) + ")"
                color: Commons.Color.accent
                font.pixelSize: Style.font.caption
                font.bold: true
                font.family: Style.font.family
              }

              ListView {
                id: pinnedList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: settingsWindow.dockConfig.pinnedApps || []

                delegate: Rectangle {
                  width: pinnedList.width
                  height: 48
                  radius: 8
                  color: Qt.rgba(255, 255, 255, 0.06)

                  RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 8

                    // App Squircle with real icon preview
                    Rectangle {
                      Layout.preferredWidth: 32
                      Layout.preferredHeight: 32
                      radius: 8
                      clip: true
                      gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: modelData.gradientStart || "#38bdf8" }
                        GradientStop { position: 1.0; color: modelData.gradientEnd || "#0284c7" }
                      }

                      Image {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        sourceSize: Qt.size(44, 44)
                        source: {
                          var icon = String(modelData.icon || "")
                          if (!icon) return ""
                          if (icon.indexOf("/") === 0 || icon.indexOf("file://") === 0) {
                            return icon.indexOf("file://") === 0 ? icon : "file://" + icon
                          }
                          return Quickshell.iconPath(icon, true)
                        }
                        fillMode: Image.PreserveAspectFit
                        visible: status === Image.Ready
                      }

                      Text {
                        anchors.centerIn: parent
                        visible: parent.children[0].status !== Image.Ready
                        text: (modelData.name || "A").charAt(0)
                        color: "white"
                        font.pixelSize: 13
                        font.bold: true
                      }
                    }

                    Text {
                      Layout.fillWidth: true
                      text: modelData.name || modelData.id
                      color: "white"
                      font.pixelSize: Style.font.body
                      elide: Text.ElideRight
                      font.family: Style.font.family
                    }

                    // Move Left / Up button
                    Rectangle {
                      Layout.preferredWidth: 26
                      Layout.preferredHeight: 26
                      radius: 4
                      color: Qt.rgba(255, 255, 255, 0.12)
                      visible: index > 0
                      Text { anchors.centerIn: parent; text: "↑"; color: "white"; font.bold: true }
                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: settingsWindow.movePinnedApp(index, -1)
                      }
                    }

                    // Move Right / Down button
                    Rectangle {
                      Layout.preferredWidth: 26
                      Layout.preferredHeight: 26
                      radius: 4
                      color: Qt.rgba(255, 255, 255, 0.12)
                      visible: index < (settingsWindow.dockConfig.pinnedApps ? settingsWindow.dockConfig.pinnedApps.length - 1 : 0)
                      Text { anchors.centerIn: parent; text: "↓"; color: "white"; font.bold: true }
                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: settingsWindow.movePinnedApp(index, 1)
                      }
                    }

                    // Remove button
                    Rectangle {
                      Layout.preferredWidth: 26
                      Layout.preferredHeight: 26
                      radius: 4
                      color: Qt.rgba(239, 68, 68, 0.3)
                      Text { anchors.centerIn: parent; text: "✕"; color: "#f87171"; font.bold: true }
                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: settingsWindow.removePinnedApp(index)
                      }
                    }
                  }
                }
              }
            }
          }

          // Right: Available System Apps to Add
          Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 10
            color: Qt.rgba(0, 0, 0, 0.25)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.1)

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: 12

              Text {
                text: "Installed System Applications"
                color: Qt.rgba(255, 255, 255, 0.7)
                font.pixelSize: Style.font.caption
                font.bold: true
                font.family: Style.font.family
              }

              ListView {
                id: availableList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: settingsWindow.filteredApps(searchInput.text)

                delegate: Rectangle {
                  width: availableList.width
                  height: 48
                  radius: 8
                  color: Qt.rgba(255, 255, 255, 0.05)

                  RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 10

                    // Strictly constrained Icon Container (Fixes giant unscaled icon bug)
                    Item {
                      Layout.preferredWidth: 32
                      Layout.preferredHeight: 32
                      Layout.alignment: Qt.AlignVCenter
                      clip: true

                      Image {
                        id: appEntryIcon
                        anchors.fill: parent
                        sourceSize: Qt.size(64, 64)
                        fillMode: Image.PreserveAspectFit
                        source: Quickshell.iconPath(modelData.icon, true)
                        visible: status === Image.Ready
                      }

                      Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: Commons.Color.accent
                        visible: appEntryIcon.status !== Image.Ready
                        Text {
                          anchors.centerIn: parent
                          text: (modelData.name || "A").charAt(0).toUpperCase()
                          color: "white"
                          font.pixelSize: 13
                          font.bold: true
                        }
                      }
                    }

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
                { key: "showActivityMonitor", label: "Activity Monitor", desc: "Quick launcher for CPU & memory monitor" },
                { key: "showPluginManager", label: "Plugin Store (Omaplug)", desc: "Quick launcher for Omarchy plugin manager" },
                { key: "showSettings", label: "Dock Customizer Gear", desc: "Direct gear shortcut to edit dock layout anytime" },
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
                    color: settingsWindow.dockConfig.preTasks && settingsWindow.dockConfig.preTasks[modelData.key] ? Commons.Color.accent : Qt.rgba(255, 255, 255, 0.2)

                    Rectangle {
                      width: 20
                      height: 20
                      radius: 10
                      color: "white"
                      anchors.verticalCenter: parent.verticalCenter
                      x: settingsWindow.dockConfig.preTasks && settingsWindow.dockConfig.preTasks[modelData.key] ? 22 : 2
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
      Item {
        visible: tabBar.activeTab === 2
        anchors.fill: parent

        ColumnLayout {
          anchors.fill: parent
          spacing: 12

          Text {
            text: "Dock Appearance & Window Behavior"
            color: Commons.Color.foreground
            font.pixelSize: Style.font.title
            font.bold: true
            font.family: Style.font.family
          }

          // 1. Icon Size Preset Buttons
          Rectangle {
            Layout.fillWidth: true
            height: 70
            radius: 10
            color: Qt.rgba(255, 255, 255, 0.06)

            RowLayout {
              anchors.fill: parent
              anchors.margins: 14

              ColumnLayout {
                Layout.fillWidth: true
                Text { text: "Base Dock Icon Size"; color: "white"; font.bold: true; font.pixelSize: Style.font.body }
                Text { text: "Current size: " + (settingsWindow.dockConfig.dockSize || 44) + "px (Live Preview)"; color: Qt.rgba(255, 255, 255, 0.6); font.pixelSize: Style.font.caption }
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

          // 2. Auto-Hide Dock (Intellihide)
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
                Text { text: "Auto-Hide Dock When Windows are Open"; color: "white"; font.bold: true; font.pixelSize: Style.font.body }
                Text { text: "Smoothly hides the dock when apps are open; moves back up when cursor hovers bottom edge"; color: Qt.rgba(255, 255, 255, 0.6); font.pixelSize: Style.font.caption }
              }

              Rectangle {
                width: 44
                height: 24
                radius: 12
                color: settingsWindow.dockConfig.autoHide ? Commons.Color.accent : Qt.rgba(255, 255, 255, 0.2)

                Rectangle {
                  width: 20
                  height: 20
                  radius: 10
                  color: "white"
                  anchors.verticalCenter: parent.verticalCenter
                  x: settingsWindow.dockConfig.autoHide ? 22 : 2
                  Behavior on x { NumberAnimation { duration: 150 } }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    var c = Util.cloneJson(settingsWindow.dockConfig)
                    c.autoHide = !c.autoHide
                    settingsWindow.dockConfig = c
                    settingsWindow.configLivePreview(c)
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

          // 5. Reserve Screen Space for Windows
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
                Text { text: "Reserve Space for Windows"; color: "white"; font.bold: true; font.pixelSize: Style.font.body }
                Text { text: "When enabled, Hyprland windows tile neatly above the dock instead of overlapping it"; color: Qt.rgba(255, 255, 255, 0.6); font.pixelSize: Style.font.caption }
              }

              Rectangle {
                width: 44
                height: 24
                radius: 12
                color: settingsWindow.dockConfig.reserveSpace ? Commons.Color.accent : Qt.rgba(255, 255, 255, 0.2)

                Rectangle {
                  width: 20
                  height: 20
                  radius: 10
                  color: "white"
                  anchors.verticalCenter: parent.verticalCenter
                  x: settingsWindow.dockConfig.reserveSpace ? 22 : 2
                  Behavior on x { NumberAnimation { duration: 150 } }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    var c = Util.cloneJson(settingsWindow.dockConfig)
                    c.reserveSpace = !c.reserveSpace
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
            onClicked: settingsWindow.closeSettings()
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
    dockConfig = Util.cloneJson(currentConfig || DockModel.defaultConfig())
    loadSystemApps()
    visible = true
  }

  function closeSettings() {
    visible = false
  }

  function updateDockSize(newSize) {
    var c = Util.cloneJson(dockConfig)
    c.dockSize = newSize
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
    pinned.push({
      id: app.id,
      name: app.name,
      desktopFile: app.desktopFile,
      icon: app.icon,
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
