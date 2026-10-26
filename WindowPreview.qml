import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Authentic macOS App Exposé Window Preview Card
Item {
  id: root

  required property var windowData
  property string iconSource: ""
  property bool active: false
  property var captureToplevel: null

  signal activated(var windowData)
  signal closeRequested(var windowData)

  width: 180
  height: 148

  function resolveToplevel() {
    var wanted = String(root.windowData && root.windowData.address ? root.windowData.address : "")
    if (!wanted) return null
    try {
      if (typeof Hyprland !== "undefined" && Hyprland.toplevels && Hyprland.toplevels.values) {
        var values = Hyprland.toplevels.values
        for (var i = 0; i < values.length; i++) {
          var candidate = values[i]
          if (candidate && String(candidate.address || "") === wanted) {
            return candidate
          }
        }
      }
    } catch (e) {}
    return null
  }

  Component.onCompleted: root.captureToplevel = root.resolveToplevel()

  Connections {
    target: (typeof Hyprland !== "undefined" && Hyprland.toplevels) ? Hyprland.toplevels : null
    function onValuesChanged() {
      root.captureToplevel = root.resolveToplevel()
    }
  }

  Rectangle {
    id: card
    anchors {
      top: parent.top
      left: parent.left
      right: parent.right
    }
    height: 120
    radius: 12

    // Dark Frosted Glass Surface
    color: "#18181b"
    border.color: root.active ? Commons.Color.accent : Qt.rgba(255, 255, 255, 0.20)
    border.width: root.active ? 2 : 1
    clip: true

    Behavior on border.color { ColorAnimation { duration: 150 } }
    Behavior on scale {
      NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }

    // Drop shadow
    Rectangle {
      anchors.fill: parent
      anchors.topMargin: 4
      radius: parent.radius
      color: "black"
      opacity: 0.50
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
      z: 2
    }

    // Live Screencopy compositor capture
    ScreencopyView {
      id: livePreview
      anchors.fill: parent
      anchors.margins: 6
      captureSource: root.captureToplevel ? root.captureToplevel.wayland : null
      live: true
      paintCursor: false
      visible: root.captureToplevel !== null && root.captureToplevel.wayland !== null
      clip: true
    }

    // Fallback: App Icon when screencopy is unavailable or window is unmapped
    Item {
      anchors.fill: parent
      anchors.margins: 6
      visible: !livePreview.visible

      Rectangle {
        anchors.fill: parent
        radius: 8
        color: Qt.rgba(255, 255, 255, 0.05)
      }

      Image {
        id: iconImage
        anchors.centerIn: parent
        width: 56
        height: 56
        source: root.iconSource
        sourceSize: Qt.size(112, 112)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true

        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          visible: parent.status !== Image.Ready
          text: "◆"
          color: Commons.Color.foreground
          font.pixelSize: 24
        }
      }
    }

    // Subtle inner border line
    Rectangle {
      anchors.fill: parent
      anchors.margins: 6
      radius: 8
      color: "transparent"
      border.width: 1
      border.color: Qt.rgba(255, 255, 255, 0.08)
    }

    // Card Hover Area
    MouseArea {
      id: cardHover
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor

      onEntered: {
        card.scale = 1.04
        card.z = 10
      }
      onExited: {
        card.scale = 1.0
        card.z = 0
      }
      onClicked: root.activated(root.windowData)
    }

    // Close Button (macOS style red badge on hover)
    Rectangle {
      id: closeBtn
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: 6
      anchors.rightMargin: 6
      width: 20
      height: 20
      radius: 10
      z: 20
      visible: cardHover.containsMouse || closeMouse.containsMouse

      color: closeMouse.containsMouse ? "#ef4444" : Qt.rgba(0, 0, 0, 0.65)
      border.width: 1
      border.color: Qt.rgba(255, 255, 255, 0.30)

      Text {
        textFormat: Text.PlainText
        anchors.centerIn: parent
        text: "✕"
        color: "#ffffff"
        font.pixelSize: 10
        font.bold: true
      }

      MouseArea {
        id: closeMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.closeRequested(root.windowData)
      }
    }
  }

  // Window Title Text
  Text {
    textFormat: Text.PlainText
    id: titleText
    anchors {
      top: card.bottom
      left: parent.left
      right: parent.right
    }
    height: 24
    topPadding: 4
    elide: Text.ElideRight
    horizontalAlignment: Text.AlignHCenter
    text: root.windowData && root.windowData.title ? root.windowData.title : ""
    color: "#ffffff"
    font.family: Style.font.family
    font.pixelSize: 11
    font.bold: true
  }
}
