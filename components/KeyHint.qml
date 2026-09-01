import QtQuick
import qs.Commons

Row {
  id: root

  property string chord: ""
  property string action: ""
  property color foreground: Color.menu.text
  property color accent: Color.accent
  property bool compact: false
  property bool highlighted: false

  spacing: compact ? Style.spacing.sm : Style.spacing.md

  Rectangle {
    id: keycap
    anchors.verticalCenter: parent.verticalCenter
    width: keyLabel.implicitWidth + (root.compact ? Style.spacing.md : Style.spacing.lg) * 2
    height: Math.max(root.compact ? Style.space(22) : Style.space(26),
      keyLabel.implicitHeight + Style.spacing.sm * 2)
    radius: Math.max(Style.space(4), Style.cornerRadius / 2)
    color: root.highlighted
      ? Style.hoverFillFor(root.foreground, root.accent)
      : Style.normalFillFor(root.foreground, root.accent)
    border.color: root.highlighted ? root.accent : Style.normalBorderFor(root.foreground, root.accent)
    border.width: Math.max(1, Style.space(1))

    Text {
      id: keyLabel
      anchors.centerIn: parent
      text: root.chord
      textFormat: Text.PlainText
      color: root.highlighted ? root.accent : root.foreground
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.caption
      font.weight: Font.DemiBold
    }
  }

  Text {
    id: actionLabel
    anchors.verticalCenter: parent.verticalCenter
    text: root.action
    textFormat: Text.PlainText
    color: root.highlighted ? root.accent : root.foreground
    opacity: root.highlighted ? 1 : 0.68
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.caption
  }
}
