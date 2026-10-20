import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy-mac-dock"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\udb81\udfa7"
    tooltipText: "macOS Dock"

    onPressed: function(b) {
      if (b === Qt.RightButton) {
        Quickshell.execDetached(["omarchy-shell", "shell", "summon", "omarchy-mac-dock", "settings"])
      } else {
        Quickshell.execDetached(["omarchy-shell", "shell", "summon", "omarchy-mac-dock", "toggle"])
      }
    }
  }
}
