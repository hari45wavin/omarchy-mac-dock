import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "DockModel.js" as DockModel

Item {
  id: root

  property var app: ({})
  property int baseSize: 52
  property real scaleFactor: 1.0
  property bool isRunning: false
  property bool isFocused: false
  property bool magnificationEnabled: true
  property real maxMagnification: 1.25

  signal clicked()
  signal rightClicked()
  signal hovered(real mouseX)
  signal unhovered()

  width: baseSize
  height: baseSize + 8
  implicitWidth: baseSize
  implicitHeight: baseSize + 8
  Layout.preferredWidth: baseSize
  Layout.preferredHeight: baseSize + 8

  readonly property string appName: String(app.name || app.id || "App")
  readonly property string iconName: String(app.icon || "")
  readonly property color colorStart: app.gradientStart ? app.gradientStart : "#38bdf8"
  readonly property color colorEnd: app.gradientEnd ? app.gradientEnd : "#0284c7"

  // Icon Source Resolution with fallback
  readonly property string iconUrl: {
    if (!iconName || iconName === "") return ""
    if (iconName.indexOf("/") === 0 || iconName.indexOf("file://") === 0) {
      return iconName.indexOf("file://") === 0 ? iconName : "file://" + iconName
    }
    var resolved = Quickshell.iconPath(iconName, true)
    if (resolved && resolved.length > 0) return resolved

    // Try symbolic variant
    if (iconName.indexOf("-symbolic") === -1) {
      var sym = Quickshell.iconPath(iconName + "-symbolic", true)
      if (sym && sym.length > 0) return sym
    }

    // Try generic application icon
    var fallback = Quickshell.iconPath("application-x-executable", true)
    return fallback ? fallback : ""
  }

  readonly property bool isHovered: hoverArea.containsMouse

  // Visual Animated Container
  Item {
    id: iconContainer
    width: root.baseSize
    height: root.baseSize
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 6

    scale: root.magnificationEnabled && isHovered ? root.maxMagnification : 1.0
    transformOrigin: Item.Bottom

    Behavior on scale {
      NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    // Ambient Drop Shadow
    Rectangle {
      anchors.fill: parent
      anchors.topMargin: 3
      radius: root.baseSize * 0.22
      color: "black"
      opacity: isHovered ? 0.35 : 0.18
      scale: 0.94
      z: 0
    }

    // Squircle macOS Card
    Rectangle {
      id: squircle
      anchors.fill: parent
      radius: Math.round(root.baseSize * 0.22)
      clip: true
      z: 1

      gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0.0; color: root.colorStart }
        GradientStop { position: 1.0; color: root.colorEnd }
      }

      border.width: 1
      border.color: Qt.rgba(255, 255, 255, isHovered ? 0.50 : 0.25)

      // Glossy Top Reflection
      Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height * 0.44
        radius: squircle.radius
        gradient: Gradient {
          orientation: Gradient.Vertical
          GradientStop { position: 0.0; color: Qt.rgba(255, 255, 255, 0.32) }
          GradientStop { position: 1.0; color: Qt.rgba(255, 255, 255, 0.0) }
        }
      }

      // App Icon Image
      Image {
        id: appImage
        anchors.centerIn: parent
        width: Math.round(parent.width * 0.70)
        height: Math.round(parent.height * 0.70)
        sourceSize: Qt.size(Math.round(parent.width * 1.5), Math.round(parent.height * 1.5))
        source: root.iconUrl
        fillMode: Image.PreserveAspectFit
        mipmap: true
        smooth: true
        visible: status === Image.Ready
      }

      // Fallback Text Glyph when icon image is unavailable
      Text {
        anchors.centerIn: parent
        visible: !appImage.visible
        text: root.appName.charAt(0).toUpperCase()
        color: "white"
        font.pixelSize: Math.round(parent.height * 0.45)
        font.bold: true
        font.family: Style.font.family
      }
    }
  }

  // Active / Running Indicator Dot (macOS Style)
  Rectangle {
    id: runningDot
    visible: root.isRunning
    width: root.isFocused ? 14 : 4
    height: 4
    radius: 2
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 0
    color: root.isFocused ? Commons.Color.accent : "white"
    opacity: root.isFocused ? 1.0 : 0.8
    z: 2

    Behavior on width { NumberAnimation { duration: 150 } }
    Behavior on color { ColorAnimation { duration: 150 } }
  }

  // Mouse Interaction
  MouseArea {
    id: hoverArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor

    onEntered: root.hovered(mouseX)
    onExited: root.unhovered()
    onPositionChanged: root.hovered(mouseX)

    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) {
        root.rightClicked()
      } else {
        root.clicked()
      }
    }
  }

  // Floating Tooltip Pill (macOS style tooltip above icon)
  Rectangle {
    id: tooltip
    visible: isHovered
    z: 100
    anchors.bottom: iconContainer.top
    anchors.bottomMargin: 10
    anchors.horizontalCenter: parent.horizontalCenter

    implicitWidth: tooltipLabel.implicitWidth + 16
    implicitHeight: tooltipLabel.implicitHeight + 8
    radius: 7

    color: Qt.rgba(0.08, 0.12, 0.18, 0.90)
    border.width: 1
    border.color: Qt.rgba(255, 255, 255, 0.22)

    Text {
      id: tooltipLabel
      anchors.centerIn: parent
      text: root.appName
      color: "white"
      font.pixelSize: Style.font.caption
      font.bold: true
      font.family: Style.font.family
    }
  }
}
