import QtQuick
import qs.Commons

Item {
  id: root

  property string message: ""
  property bool error: false
  property bool busy: false
  property color foreground: Color.menu.text
  property string shortcut: ""

  signal shortcutRequested()

  implicitHeight: Math.max(Style.space(34), statusText.implicitHeight + Style.spacing.md * 2)

  Row {
    id: statusRow
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: Math.max(0, parent.width - actionsRow.implicitWidth - Style.spacing.xl)
    spacing: Style.spacing.md

    Text {
      visible: root.busy || root.error
      text: root.error ? "" : "󰔟"
      color: root.error ? Color.urgent : root.foreground
      opacity: 0.9
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.caption
    }

    Text {
      id: statusText
      width: Math.max(0, statusRow.width - (root.busy || root.error ? parent.spacing + Style.space(16) : 0))
      text: root.message
      textFormat: Text.PlainText
      color: root.error ? Color.urgent : root.foreground
      opacity: root.message ? 0.9 : 0
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }

  Row {
    id: actionsRow
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.spacing.lg

    KeyHint {
      chord: "Space"
      action: "Preview"
      foreground: root.foreground
    }

    KeyHint {
      chord: "Enter"
      action: "Copy GIF"
      foreground: root.foreground
    }

    KeyHint {
      chord: "Shift+Enter"
      action: "Copy link"
      foreground: root.foreground
    }

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: Math.max(1, Style.space(1))
      height: Style.space(24)
      color: Style.normalBorderFor(root.foreground, Color.accent)
      opacity: 0.72
    }

    Item {
      width: shortcutHint.implicitWidth
      height: shortcutHint.implicitHeight

      KeyHint {
        id: shortcutHint
        chord: root.shortcut
          ? String(root.shortcut).replace(/ \+ /g, " ")
          : "Unassigned"
        action: root.shortcut ? "Launch shortcut" : "Set shortcut"
        foreground: root.foreground
        highlighted: shortcutMouse.containsMouse
      }

      MouseArea {
        id: shortcutMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.shortcutRequested()
      }
    }
  }
}
