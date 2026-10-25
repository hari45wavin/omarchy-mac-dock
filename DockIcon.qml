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
  property int baseSize: 44
  property real scaleFactor: 1.0
  property bool isRunning: false
  property bool isFocused: false
  property bool magnificationEnabled: true
  property real maxMagnification: 1.35
  property bool isBouncing: false

  signal clicked()
  signal rightClicked(real mouseX, real mouseY, real screenCenterX)

  // Stable fixed slot size: avoids exponential layout thrashing and stutter
  width: baseSize
  height: baseSize + 8
  implicitWidth: width
  implicitHeight: height
  Layout.preferredWidth: width
  Layout.preferredHeight: height

  // Dynamically raise z-index of magnified icon so it renders cleanly above neighbors
  z: Math.round(computedScale * 100)

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

  readonly property bool isFullAppArtwork: {
    var u = String(root.iconUrl).toLowerCase()
    if (u.indexOf(".png") !== -1 || u.indexOf(".jpg") !== -1 || u.indexOf(".webp") !== -1) return true
    if (u.indexOf("assets/icons") !== -1) return true
    if (u.indexOf("-symbolic") === -1 && appImage.status === Image.Ready) return true
    return false
  }

  // Exact live horizontal center relative to shelf floor (pure reactive arithmetic; never goes stale)
  readonly property real centerInShelf: {
    if (!dockWindow || !dockWindow.layoutItem) return 0
    return dockWindow.layoutItem.x + root.x + (root.baseSize / 2)
  }

  readonly property real distToMouse: (dockWindow && dockWindow.isShelfHovered) ? Math.abs(dockWindow.mouseShelfX - centerInShelf) : 9999
  readonly property real hoverRadius: root.baseSize * 2.3
  readonly property real normDist: distToMouse / hoverRadius

  // Smooth cosine parabolic bell-curve with graceful exponential decay
  readonly property real waveInfluence: {
    if (!dockWindow || !dockWindow.isShelfHovered || normDist >= 1.0) return 0.0
    var c = Math.cos(normDist * Math.PI * 0.5)
    return Math.pow(c, 1.6)
  }

  readonly property real targetScale: {
    if (!root.magnificationEnabled || !dockWindow || !dockWindow.isShelfHovered) return 1.0
    return 1.0 + (root.maxMagnification - 1.0) * waveInfluence
  }

  // Instant 120 FPS cursor tracking while hovering (0ms latency), smooth 140ms ease-out on exit
  property real computedScale: targetScale
  Behavior on computedScale {
    enabled: !dockWindow || !dockWindow.isShelfHovered
    NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
  }

  // Authentic macOS App Launch Bounce Animation
  function startBounce() {
    isBouncing = true
    bounceTimer.restart()
    bounceAnim.restart()
  }

  function stopBounce() {
    isBouncing = false
    bounceAnim.stop()
    bounceOffset.y = 0
  }

  // Safety fallback: auto-stop bounce after 4.5 seconds if app doesn't map
  Timer {
    id: bounceTimer
    interval: 4500
    onTriggered: root.stopBounce()
  }

  SequentialAnimation {
    id: bounceAnim
    running: root.isBouncing
    loops: 3
    onFinished: root.isBouncing = false

    NumberAnimation { target: bounceOffset; property: "y"; to: -24; duration: 160; easing.type: Easing.OutQuad }
    NumberAnimation { target: bounceOffset; property: "y"; to: 0; duration: 140; easing.type: Easing.InQuad }
    NumberAnimation { target: bounceOffset; property: "y"; to: -14; duration: 120; easing.type: Easing.OutQuad }
    NumberAnimation { target: bounceOffset; property: "y"; to: 0; duration: 100; easing.type: Easing.InQuad }
    NumberAnimation { target: bounceOffset; property: "y"; to: -6; duration: 80; easing.type: Easing.OutQuad }
    NumberAnimation { target: bounceOffset; property: "y"; to: 0; duration: 70; easing.type: Easing.InQuad }
    PauseAnimation { duration: 120 }
  }

  // Bounce container
  Item {
    id: bounceOffset
    anchors.fill: parent
    y: 0

    // Visual Animated Icon Container
    Item {
      id: iconContainer
      width: root.baseSize
      height: root.baseSize
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Math.round(6 + (root.computedScale - 1.0) * root.baseSize * 0.45)

      scale: root.computedScale
      transformOrigin: Item.Bottom

      // Ambient Drop Shadow
      Rectangle {
        anchors.fill: parent
        anchors.topMargin: 3
        radius: root.baseSize * 0.22
        color: "black"
        opacity: root.isDirectlyHovered ? 0.38 : 0.20
        scale: 0.94
        z: 0
      }

      // Authentic Apple Squircle Container / Fallback Card
      Rectangle {
        id: squircle
        anchors.fill: parent
        radius: Math.round(root.baseSize * 0.22)
        clip: !root.isFullAppArtwork
        z: 1

        color: "transparent"
        gradient: root.isFullAppArtwork ? null : fallbackGradient
        border.width: root.isFullAppArtwork ? 0 : 1
        border.color: Qt.rgba(255, 255, 255, root.isDirectlyHovered ? 0.55 : 0.25)

        Gradient {
          id: fallbackGradient
          orientation: Gradient.Vertical
          GradientStop { position: 0.0; color: root.colorStart }
          GradientStop { position: 1.0; color: root.colorEnd }
        }

        // Glossy Top Reflection only for synthetic cards
        Rectangle {
          visible: !root.isFullAppArtwork
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          height: parent.height * 0.44
          radius: squircle.radius
          gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(255, 255, 255, 0.35) }
            GradientStop { position: 1.0; color: Qt.rgba(255, 255, 255, 0.0) }
          }
        }

        // App Icon Image - Renders authentic 256x256 macOS Big Sur artwork crisp & unboxed
        Image {
          id: appImage
          anchors.centerIn: parent
          width: root.isFullAppArtwork ? parent.width : Math.round(parent.width * 0.72)
          height: root.isFullAppArtwork ? parent.height : Math.round(parent.height * 0.72)
          sourceSize: Qt.size(Math.round(parent.width * 2), Math.round(parent.height * 2))
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
      opacity: root.isFocused ? 1.0 : 0.85
      z: 2

      Behavior on width { NumberAnimation { duration: 150 } }
      Behavior on color { ColorAnimation { duration: 150 } }
    }
  }

  readonly property bool isDirectlyHovered: clickArea.containsMouse || (dockWindow && dockWindow.isShelfHovered && normDist < 0.32)

  // Direct click and coordinate forwarding (does NOT steal or kill shelf hover)
  MouseArea {
    id: clickArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor

    onPositionChanged: function(mouse) {
      if (dockWindow && typeof dockWindow.updateHover === "function") {
        var sX = dockWindow.layoutItem.x + root.x + mouse.x
        dockWindow.updateHover(sX)
      }
    }

    onEntered: {
      if (dockWindow && typeof dockWindow.updateHover === "function") {
        var sX = dockWindow.layoutItem.x + root.x + (root.baseSize / 2)
        dockWindow.updateHover(sX)
      }
    }

    onExited: {
      if (dockWindow && typeof dockWindow.notifyHoverExit === "function") {
        dockWindow.notifyHoverExit()
      }
    }

    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) {
        var screenPt = root.mapToItem(null, root.width / 2, 0)
        root.rightClicked(mouse.x, mouse.y, screenPt.x)
      } else {
        root.clicked()
      }
    }
  }

  // Floating High-Contrast macOS Tooltip Pill
  Rectangle {
    id: tooltip
    visible: root.isDirectlyHovered && (!dockWindow.menuPanel || !dockWindow.menuPanel.visible)
    z: 9999
    anchors.bottom: root.top
    anchors.bottomMargin: Math.round(16 + (root.computedScale - 1.0) * root.baseSize * 1.1)
    anchors.horizontalCenter: parent.horizontalCenter

    implicitWidth: tooltipLabel.implicitWidth + 20
    implicitHeight: tooltipLabel.implicitHeight + 10
    radius: 7

    // Deep high-contrast obsidian background with crisp border
    color: "#18181b"
    border.width: 1
    border.color: Qt.rgba(255, 255, 255, 0.32)

    // Shadow beneath tooltip
    Rectangle {
      anchors.fill: parent
      anchors.topMargin: 2
      radius: parent.radius
      color: "black"
      opacity: 0.65
      z: -1
    }

    Text {
      id: tooltipLabel
      anchors.centerIn: parent
      text: root.appName
      color: "#ffffff"
      font.pixelSize: Style.font.caption
      font.bold: true
      font.family: Style.font.family
    }
  }
}
