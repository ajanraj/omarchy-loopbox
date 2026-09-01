import QtQuick
import qs.Commons

Item {
  id: root

  property string message: ""
  property bool error: false
  property bool busy: false
  property color foreground: Color.menu.text

  implicitHeight: Math.max(Style.space(34), statusText.implicitHeight + Style.spacing.md * 2)

  Row {
    id: statusRow
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: Math.max(0, parent.width - shortcutText.implicitWidth - Style.spacing.xl)
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

  Text {
    id: shortcutText
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    text: "Enter  copy GIF    Shift+Enter  copy link    Ctrl+Shift+F  favourite"
    color: root.foreground
    opacity: 0.62
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.caption
  }
}
