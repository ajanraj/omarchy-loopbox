import QtQuick
import Quickshell.Io
import qs.Commons

Rectangle {
  id: tile

  required property int index
  required property string title
  required property string previewUrl
  required property string previewScript
  required property string provider
  required property string resultId
  required property bool selected
  property bool favourite: false
  property bool busy: false
  property bool pooled: false
  property bool previewFailed: false
  property bool componentReady: false
  property bool stoppingPreview: false
  property int previewSerial: 0
  property string localPreviewPath: ""
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
  readonly property bool previewError: previewFailed || preview.status === AnimatedImage.Error

  function queuePreview() {
    previewSerial += 1
    localPreviewPath = ""
    previewFailed = false
    if (!componentReady) return
    if (previewProc.running || stoppingPreview) {
      stoppingPreview = true
      previewProc.running = false
      return
    }
    Qt.callLater(startPreview)
  }

  function startPreview() {
    if (!componentReady || pooled || previewProc.running || stoppingPreview || localPreviewPath
        || !previewScript || !previewUrl || provider !== "klipy" || !resultId) return
    previewProc.requestSerial = previewSerial
    previewProc.expectedUrl = previewUrl
    previewProc.expectedProvider = provider
    previewProc.expectedResultId = resultId
    previewProc.command = [previewScript, previewUrl]
    previewProc.launchPending = true
    previewProc.running = true
  }

  function reportPreviewFailure() {
    if (previewFailed) return
    previewFailed = true
    imageFailed(index)
  }

  onPreviewUrlChanged: queuePreview()
  onPreviewScriptChanged: queuePreview()
  onProviderChanged: queuePreview()
  onResultIdChanged: queuePreview()

  Component.onCompleted: {
    componentReady = true
    queuePreview()
  }

  Process {
    id: previewProc
    property bool launchPending: false
    property int requestSerial: 0
    property string expectedUrl: ""
    property string expectedProvider: ""
    property string expectedResultId: ""

    stdout: StdioCollector { id: previewStdout; waitForEnd: true }

    onStarted: launchPending = false
    onRunningChanged: {
      if (!running && launchPending) {
        Qt.callLater(function() {
          if (!previewProc.running && previewProc.launchPending) {
            previewProc.launchPending = false
            tile.stoppingPreview = false
            var currentRequest = previewProc.requestSerial === tile.previewSerial
              && previewProc.expectedUrl === tile.previewUrl
              && previewProc.expectedProvider === tile.provider
              && previewProc.expectedResultId === tile.resultId
              && !tile.pooled
            if (currentRequest)
              tile.reportPreviewFailure()
            else
              Qt.callLater(tile.startPreview)
          }
        })
      }
    }

    onExited: function(exitCode, exitStatus) {
      launchPending = false
      tile.stoppingPreview = false
      var currentRequest = requestSerial === tile.previewSerial
        && expectedUrl === tile.previewUrl
        && expectedProvider === tile.provider
        && expectedResultId === tile.resultId
        && !tile.pooled
      if (!currentRequest) {
        Qt.callLater(tile.startPreview)
        return
      }
      var path = String(previewStdout.text || "").trim()
      if (exitCode === 0 && exitStatus === 0 && path.charAt(0) === "/")
        tile.localPreviewPath = path
      else
        tile.reportPreviewFailure()
    }
  }

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
    // Provider URLs are inputs to preview-gif only. Qt decodes local cache files.
    source: tile.localPreviewPath
    sourceSize.width: Math.min(Math.ceil(tile.width), 420)
    sourceSize.height: Math.min(Math.ceil(tile.height), 260)
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    cache: true
    playing: !tile.pooled && tile.inViewport && status === AnimatedImage.Ready
    opacity: tile.busy ? 0.55 : 1

    Behavior on opacity { NumberAnimation { duration: 100 } }

    onStatusChanged: {
      if (status === AnimatedImage.Error && !tile.previewFailed) {
        tile.reportPreviewFailure()
      }
    }
  }

  Rectangle {
    anchors.centerIn: parent
    width: Style.space(42)
    height: width
    radius: width / 2
    color: Util.alpha(Color.background, 0.86)
    visible: tile.busy
    z: 3

    Text {
      anchors.centerIn: parent
      text: "󰔟"
      color: tile.selectedForeground
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.heading

      RotationAnimator on rotation {
        from: 0
        to: 360
        duration: 850
        loops: Animation.Infinite
        running: tile.busy
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
        text: tile.previewError ? "󰋩" : "󰔟"
        color: tile.previewError ? Color.urgent : tile.foreground
        opacity: tile.previewError ? 0.9 : 0.55
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.display
        horizontalAlignment: Text.AlignHCenter
      }

      Text {
        width: parent.width
        text: tile.previewError ? "Preview unavailable" : "Loading preview"
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
      textFormat: Text.PlainText
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
    onPositionChanged: tile.hovered(tile.index)
    onClicked: tile.activated(tile.index)
  }

  GridView.onPooled: {
    pooled = true
    queuePreview()
  }
  GridView.onReused: {
    pooled = false
    queuePreview()
  }
}
