import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Floating Window Preview Overlay Panel (macOS App Exposé Peek)
PanelWindow {
  id: root

  property bool previewVisible: false
  property var windowList: []
  property real centerX: 0
  property real bottomY: 0
  property var iconSourceFor: function(item) { return "" }

  signal activated(var windowData)
  signal closeRequested(var windowData)
  signal previewHoverEntered()
  signal previewHoverExited()

  readonly property bool panelActive: root.previewVisible && root.windowList && root.windowList.length > 0

  visible: root.panelActive
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "omarchy-mac-dock-preview"
  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  mask: Region { item: previewContainer }

  Item {
    id: previewContainer

    // Center above the hovered dock item, clamped to screen edges
    x: Math.max(12, Math.min(root.centerX - width / 2, root.width - width - 12))
    y: Math.max(12, (root.bottomY > 0 ? root.bottomY : (root.height - 100)) - height - 12)

    width: previewRow.implicitWidth + 24
    height: previewRow.implicitHeight + 20

    opacity: root.panelActive ? 1.0 : 0.0
    scale: root.panelActive ? 1.0 : 0.94

    Behavior on opacity {
      NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
      NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }

    // Background glass shelf for the preview strip
    Rectangle {
      anchors.fill: parent
      radius: 16
      color: Util.alpha(Commons.Color.background, 0.70)
      border.width: 1
      border.color: Qt.rgba(255, 255, 255, 0.20)

      // Ambient drop shadow
      Rectangle {
        anchors.fill: parent
        anchors.topMargin: 6
        radius: parent.radius
        color: "black"
        opacity: 0.45
        scale: 0.98
        z: -1
      }
    }

    Row {
      id: previewRow
      anchors.centerIn: parent
      spacing: 12

      Repeater {
        model: root.windowList || []

        WindowPreview {
          required property var modelData
          required property int index

          windowData: modelData
          iconSource: root.iconSourceFor(modelData)
          active: !!modelData.active

          onActivated: function(data) {
            root.activated(data)
          }
          onCloseRequested: function(data) {
            root.closeRequested(data)
          }
        }
      }
    }

    // Hover area covering the preview strip: keeps preview alive while user glides into it
    MouseArea {
      id: previewHoverArea
      anchors.fill: parent
      anchors.margins: -14
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
      cursorShape: Qt.ArrowCursor

      onEntered: root.previewHoverEntered()
      onExited: root.previewHoverExited()
    }
  }
}
