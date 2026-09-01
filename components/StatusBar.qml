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

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "Enter  copy GIF    Shift+Enter  copy link"
      color: root.foreground
      opacity: 0.62
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.caption
    }

    Rectangle {
      width: shortcutLabel.implicitWidth + Style.spacing.xl * 2
      height: Math.max(Style.space(28), shortcutLabel.implicitHeight + Style.spacing.sm * 2)
      radius: Style.cornerRadius
      color: shortcutMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
      border.color: shortcutMouse.containsMouse ? Color.accent : Style.normalBorderFor(root.foreground, Color.accent)
      border.width: Math.max(1, Style.space(1))

      Text {
        id: shortcutLabel
        anchors.centerIn: parent
        text: root.shortcut
          ? "⌨  " + String(root.shortcut).replace(/ \+ /g, " ")
          : "⌨  Set shortcut"
        color: shortcutMouse.containsMouse ? Color.accent : root.foreground
        opacity: shortcutMouse.containsMouse ? 1 : 0.82
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.caption
        font.weight: Font.DemiBold
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
