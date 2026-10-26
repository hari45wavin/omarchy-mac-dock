import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

PanelWindow {
  id: menuWindow

  property var targetApp: null
  property real targetCenterX: 0
  property bool isRunning: false
  property bool isPinned: false

  signal actionTriggered(string actionId, var targetApp)

  visible: false
  color: "transparent"

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  WlrLayershell.namespace: "omarchy-mac-dock-menu"
  WlrLayershell.layer: WlrLayer.Overlay
  exclusionMode: ExclusionMode.Ignore

  function openMenu(app, centerX, running, pinned) {
    targetApp = app
    targetCenterX = centerX
    isRunning = running
    isPinned = pinned
    visible = true
    appearAnim.restart()
  }

  function closeMenu() {
    visible = false
    targetApp = null
  }

  // Dismiss on outside click
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.ArrowCursor
    onClicked: menuWindow.closeMenu()
  }

  // Floating Context Menu Card (placed cleanly right above the dock icon)
  Rectangle {
    id: menuCard

    readonly property string appTitle: targetApp ? String(targetApp.name || targetApp.id || "App") : ""
    readonly property bool isTrash: targetApp && (targetApp.id === "trash" || targetApp.name === "Trash")

    width: 220
    height: menuLayout.implicitHeight + 18
    radius: 12

    // Position horizontally centered above the clicked icon, clamped within screen margins
    x: Math.max(14, Math.min(menuWindow.width - width - 14, targetCenterX - width / 2))
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 80

    // macOS Frosted Dark Glass
    color: "#1c1c1e"
    border.width: 1
    border.color: Qt.rgba(255, 255, 255, 0.18)
    clip: true

    // Ambient drop shadow
    Rectangle {
      anchors.fill: parent
      anchors.topMargin: 6
      radius: parent.radius
      color: "black"
      opacity: 0.65
      scale: 0.98
      z: -1
    }

    // Top Glossy Specular Rim
    Rectangle {
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: 8
      anchors.rightMargin: 8
      height: 1
      color: Qt.rgba(255, 255, 255, 0.35)
    }

    // Smooth macOS Popover Entrance Animation
    ParallelAnimation {
      id: appearAnim
      NumberAnimation { target: menuCard; property: "opacity"; from: 0; to: 1; duration: 120; easing.type: Easing.OutCubic }
      NumberAnimation { target: menuCard; property: "scale"; from: 0.94; to: 1.0; duration: 120; easing.type: Easing.OutCubic }
    }

    Column {
      id: menuLayout
      anchors.fill: parent
      anchors.margins: 8
      spacing: 3

      // 1. Header (App Info)
      Item {
        width: parent.width
        height: 28

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 8
          anchors.rightMargin: 8
          spacing: 8

          Text {
            Layout.fillWidth: true
            text: menuCard.appTitle
            color: "#ffffff"
            font.bold: true
            font.pixelSize: 13
            font.family: Style.font.family
            elide: Text.ElideRight
          }

          Rectangle {
            visible: menuWindow.isRunning
            width: 7
            height: 7
            radius: 3.5
            color: "#22c55e"
          }
        }
      }

      // Divider
      Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(255, 255, 255, 0.10)
      }

      // TRASH OPTIONS
      Item {
        visible: menuCard.isTrash
        width: parent.width
        height: menuCard.isTrash ? trashCol.implicitHeight : 0

        Column {
          id: trashCol
          width: parent.width
          spacing: 2

          MenuItemRow {
            title: "Open Trash"
            glyph: "📂"
            onTriggered: {
              menuWindow.closeMenu()
              menuWindow.actionTriggered("openTrash", null)
            }
          }

          MenuItemRow {
            title: "Empty Trash"
            glyph: "🗑️"
            isDestructive: true
            onTriggered: {
              menuWindow.closeMenu()
              menuWindow.actionTriggered("emptyTrash", null)
            }
          }
        }
      }

      // NORMAL APP OPTIONS
      Item {
        visible: !menuCard.isTrash
        width: parent.width
        height: !menuCard.isTrash ? appCol.implicitHeight : 0

        Column {
          id: appCol
          width: parent.width
          spacing: 2

          MenuItemRow {
            title: menuWindow.isRunning ? "Bring to Front" : "Open Application"
            glyph: "↗"
            onTriggered: {
              menuWindow.closeMenu()
              menuWindow.actionTriggered("activate", menuWindow.targetApp)
            }
          }

          MenuItemRow {
            visible: menuWindow.isRunning
            title: "Minimize Window"
            glyph: "−"
            onTriggered: {
              menuWindow.closeMenu()
              menuWindow.actionTriggered("minimize", menuWindow.targetApp)
            }
          }

          MenuItemRow {
            visible: menuWindow.isRunning
            title: "Maximize / Zoom Window"
            glyph: "⤢"
            onTriggered: {
              menuWindow.closeMenu()
              menuWindow.actionTriggered("maximize", menuWindow.targetApp)
            }
          }

          MenuItemRow {
            visible: menuWindow.isRunning
            title: "Quit Application"
            glyph: "✕"
            isDestructive: true
            onTriggered: {
              menuWindow.closeMenu()
              menuWindow.actionTriggered("quit", menuWindow.targetApp)
            }
          }

          // Inner Divider
          Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(255, 255, 255, 0.10)
          }

          MenuItemRow {
            title: menuWindow.isPinned ? "Keep in Dock" : "Keep in Dock"
            glyph: menuWindow.isPinned ? "✓" : "+"
            highlightGlyph: menuWindow.isPinned
            onTriggered: {
              menuWindow.closeMenu()
              menuWindow.actionTriggered("togglePin", menuWindow.targetApp)
            }
          }
        }
      }

      // Divider
      Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(255, 255, 255, 0.10)
      }

      // Settings Option
      MenuItemRow {
        title: "Dock Preferences..."
        glyph: "⚙"
        onTriggered: {
          menuWindow.closeMenu()
          menuWindow.actionTriggered("settings", null)
        }
      }
    }
  }

  // Reusable Menu Item Component with macOS hover styling
  component MenuItemRow: Rectangle {
    id: rowItem

    property string title: ""
    property string glyph: ""
    property bool isDestructive: false
    property bool highlightGlyph: false
    signal triggered()

    width: parent ? parent.width : 204
    height: 28
    radius: 6
    color: itemMouse.containsMouse 
      ? (isDestructive ? "#dc2626" : "#0a84ff")
      : "transparent"

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 8
      anchors.rightMargin: 8
      spacing: 8

      Text {
        text: rowItem.glyph
        color: itemMouse.containsMouse ? "#ffffff" : (rowItem.highlightGlyph ? "#38bdf8" : Qt.rgba(255, 255, 255, 0.75))
        font.pixelSize: 12
        font.bold: true
      }

      Text {
        Layout.fillWidth: true
        text: rowItem.title
        color: itemMouse.containsMouse ? "#ffffff" : Qt.rgba(255, 255, 255, 0.90)
        font.pixelSize: 12
        font.family: Style.font.family
        elide: Text.ElideRight
      }
    }

    MouseArea {
      id: itemMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: rowItem.triggered()
    }
  }
}
