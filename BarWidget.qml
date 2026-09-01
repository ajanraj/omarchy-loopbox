import QtQuick
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.ajanraj.loopbox"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf03e"
    tooltipText: "Loopbox · left: GIF search · right: shortcut settings"

    onPressed: function(mouseButton) {
      if (!root.bar) return
      if (mouseButton === Qt.RightButton)
        root.bar.run("omarchy-shell shell toggle io.github.ajanraj.loopbox '{\"setupShortcut\":true}'")
      else if (mouseButton === Qt.LeftButton)
        root.bar.run("omarchy-shell shell toggle io.github.ajanraj.loopbox '{}'")
    }
  }
}
