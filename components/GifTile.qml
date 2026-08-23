import QtQuick
import qs.Commons

Rectangle {
  id: tile

  required property int index
  required property string title
  required property string previewUrl
  required property bool selected
  property bool favourite: false
  property bool pooled: false
  property bool previewFailed: false
  property color foreground: Color.menu.text
  property color selectedForeground: Color.menu.selectedText
  property color selectedBackground: Color.menu.selectedBackground

  signal activated(int index)
  signal hovered(int index)
  signal imageFailed(int index)

  readonly property var view: GridView.view
  readonly property bool inViewport: view
    && y + height >= view.contentY
    && y <= view.contentY + view.height

  radius: Style.cornerRadius
  scale: selected ? 0.97 : 1
  z: selected ? 1 : 0
  color: selected ? selectedBackground : Style.normalFillFor(foreground, Color.accent)
  border.color: selected ? Color.accent : "transparent"
  border.width: selected ? Math.max(Style.space(3), 3) : 0
  clip: true

  Behavior on color { ColorAnimation { duration: 100 } }
  Behavior on border.color { ColorAnimation { duration: 100 } }
  Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

  AnimatedImage {
    id: preview
    anchors.fill: parent
    anchors.margins: tile.selected ? Style.space(4) : 0
    source: tile.previewUrl
    sourceSize.width: Math.min(Math.ceil(tile.width), 420)
    sourceSize.height: Math.min(Math.ceil(tile.height), 260)
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    cache: true
    playing: !tile.pooled && tile.inViewport && status === AnimatedImage.Ready

    onSourceChanged: tile.previewFailed = false
    onStatusChanged: {
      if (status === AnimatedImage.Error && !tile.previewFailed) {
        tile.previewFailed = true
        tile.imageFailed(tile.index)
      }
    }
  }

  Rectangle {
    anchors.fill: preview
    color: Style.normalFillFor(tile.foreground, Color.accent)
    visible: preview.status !== AnimatedImage.Ready

    Column {
      anchors.centerIn: parent
      width: parent.width - Style.spacing.xl * 2
      spacing: Style.spacing.md

      Text {
        width: parent.width
        text: preview.status === AnimatedImage.Error ? "󰋩" : "󰔟"
        color: preview.status === AnimatedImage.Error ? Color.urgent : tile.foreground
        opacity: preview.status === AnimatedImage.Error ? 0.9 : 0.55
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.display
        horizontalAlignment: Text.AlignHCenter
      }

      Text {
        width: parent.width
        text: preview.status === AnimatedImage.Error ? "Preview unavailable" : "Loading preview"
        color: tile.foreground
        opacity: 0.68
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
      }
    }
  }

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: Math.max(Style.space(32), label.implicitHeight + Style.spacing.md * 2)
    color: Util.alpha(Color.background, 0.82)

    Text {
      id: label
      anchors.left: parent.left
      anchors.leftMargin: Style.spacing.lg
      anchors.right: favouriteMark.left
      anchors.rightMargin: Style.spacing.sm
      anchors.verticalCenter: parent.verticalCenter
      text: tile.title || "Untitled GIF"
      color: tile.selected ? tile.selectedForeground : tile.foreground
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.caption
      font.weight: tile.selected ? Font.DemiBold : Font.Normal
      elide: Text.ElideRight
    }

    Text {
      id: favouriteMark
      anchors.right: parent.right
      anchors.rightMargin: Style.spacing.lg
      anchors.verticalCenter: parent.verticalCenter
      text: ""
      visible: tile.favourite
      color: tile.selected ? tile.selectedForeground : Color.accent
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.caption
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onContainsMouseChanged: if (containsMouse) tile.hovered(tile.index)
    onClicked: tile.activated(tile.index)
  }

  GridView.onPooled: pooled = true
  GridView.onReused: pooled = false
}
