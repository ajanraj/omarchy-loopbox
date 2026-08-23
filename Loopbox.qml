import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "components"
import "LoopboxModel.js" as LoopboxModel
import "providers/Klipy.js" as Klipy

Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false
  property string query: ""
  property string viewMode: "trending"
  property int selectedIndex: 0
  property bool loading: false
  property bool copying: false
  property string statusMessage: ""
  property bool statusError: false
  property int requestSerial: 0
  property var state: LoopboxModel.defaultState()
  property bool stateDirectoryReady: false
  property bool stateSavePending: false

  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")
  readonly property string stateDirectory: stateHome + "/loopbox"
  readonly property string statePath: stateDirectory + "/state.json"
  readonly property string pluginDirectory: manifest && manifest.__sourceDir ? String(manifest.__sourceDir) : ""
  readonly property string copyScript: pluginDirectory + "/scripts/copy-gif"

  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int contentSpacing: Style.spacing.lg
  property int cardWidth: Math.min(Style.space(1000), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(Style.space(660), panel.height - Style.gapsOut * 2)

  function open(payloadJson) {
    root.opened = true
    root.query = ""
    root.viewMode = "trending"
    root.selectedIndex = 0
    root.statusMessage = "Trending GIFs"
    root.statusError = false
    resultModel.clear()
    root.requestSerial += 1
    root.startSearch(root.requestSerial, "")
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  // Called by the shell host before this unload-on-close plugin is destroyed.
  function close() {
    dismissTimer.stop()
    searchDebounce.stop()
    root.requestSerial += 1
    searchProc.queuedSerial = 0
    searchProc.expectedStop = true
    if (searchProc.running) searchProc.running = false
    if (copyProc.running) copyProc.running = false
    if (linkProc.running) linkProc.running = false
    root.loading = false
    root.copying = false
    root.opened = false
  }

  function dismiss() {
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "io.github.ajanraj.loopbox")
    else
      root.close()
  }

  function resultFromRow(row) {
    return {
      provider: String(row.provider || ""),
      id: String(row.resultId || ""),
      title: String(row.title || ""),
      pageUrl: String(row.pageUrl || ""),
      shareUrl: String(row.shareUrl || ""),
      originalUrl: String(row.originalUrl || ""),
      previewUrl: String(row.previewUrl || ""),
      width: Number(row.mediaWidth || 0),
      height: Number(row.mediaHeight || 0),
      bytes: Number(row.bytes || 0)
    }
  }

  function resultAt(index) {
    if (index < 0 || index >= resultModel.count) return null
    return root.resultFromRow(resultModel.get(index))
  }

  function replaceResults(rows) {
    resultModel.clear()
    var count = Math.min(8, Array.isArray(rows) ? rows.length : 0)
    for (var i = 0; i < count; i++) {
      var row = rows[i]
      resultModel.append({
        provider: String(row.provider || ""),
        resultId: String(row.id || ""),
        title: String(row.title || "Untitled GIF"),
        pageUrl: String(row.pageUrl || ""),
        shareUrl: String(row.shareUrl || row.originalUrl || ""),
        originalUrl: String(row.originalUrl || ""),
        previewUrl: String(row.previewUrl || ""),
        mediaWidth: Number(row.width || 0),
        mediaHeight: Number(row.height || 0),
        bytes: Number(row.bytes || 0)
      })
    }
    root.selectedIndex = resultModel.count > 0 ? 0 : -1
    Qt.callLater(function() {
      if (resultModel.count > 0) resultGrid.positionViewAtIndex(0, GridView.Contain)
    })
  }

  function loadFavorites() {
    root.replaceResults(root.state.favorites || [])
    root.loading = false
    root.statusError = false
    root.statusMessage = resultModel.count > 0
      ? resultModel.count + (resultModel.count === 1 ? " favourite" : " favourites")
      : "No favourites yet. Select a GIF and press Ctrl+Shift+F."
  }

  function saveState() {
    if (!root.stateDirectoryReady) {
      root.stateSavePending = true
      return
    }
    stateFile.setText(LoopboxModel.serializeState(root.state) + "\n")
    root.stateSavePending = false
  }

  function selectedIsFavorite() {
    var result = root.resultAt(root.selectedIndex)
    return result ? LoopboxModel.isFavorite(root.state, result) : false
  }

  function toggleSelectedFavorite() {
    var result = root.resultAt(root.selectedIndex)
    if (!result || root.copying) return
    var wasFavorite = LoopboxModel.isFavorite(root.state, result)
    root.state = LoopboxModel.toggleFavorite(root.state, result)
    root.saveState()
    root.statusError = false
    root.statusMessage = wasFavorite ? "Removed from favourites" : "Added to favourites"
    if (root.viewMode === "favorites") root.loadFavorites()
  }

  function scheduleSearch() {
    root.requestSerial += 1
    searchDebounce.restart()
  }

  function setQuery(nextQuery) {
    root.query = String(nextQuery || "")
    root.viewMode = root.query ? "search" : "trending"
    root.selectedIndex = resultModel.count > 0 ? 0 : -1
    root.statusError = false
    root.statusMessage = root.query ? "Searching for " + root.query : "Loading trending GIFs"
    root.scheduleSearch()
  }

  function showTrending() {
    root.query = ""
    root.viewMode = "trending"
    root.statusError = false
    root.statusMessage = "Loading trending GIFs"
    root.requestSerial += 1
    searchDebounce.stop()
    root.startSearch(root.requestSerial, "")
  }

  function showFavorites() {
    root.query = ""
    root.viewMode = "favorites"
    root.requestSerial += 1
    searchDebounce.stop()
    searchProc.queuedSerial = 0
    searchProc.expectedStop = true
    if (searchProc.running) searchProc.running = false
    root.loadFavorites()
  }

  function retrySearch() {
    if (root.viewMode === "favorites") return
    root.statusError = false
    root.statusMessage = root.query ? "Retrying search" : "Retrying trending GIFs"
    root.requestSerial += 1
    searchDebounce.stop()
    root.startSearch(root.requestSerial, root.query)
  }

  function startSearch(serial, searchQuery) {
    if (!root.opened || root.viewMode === "favorites") return
    if (searchProc.running) {
      searchProc.queuedSerial = serial
      searchProc.queuedQuery = searchQuery
      searchProc.expectedStop = true
      searchProc.running = false
      root.loading = true
      return
    }

    searchProc.activeSerial = serial
    searchProc.queuedSerial = 0
    searchProc.queuedQuery = ""
    searchProc.expectedStop = false
    searchProc.command = Klipy.searchCommand(searchQuery, 8)
    searchProc.running = true
    root.loading = true
  }

  function providerFailure(message) {
    var detail = String(message || "").trim()
    if (detail.indexOf("429") !== -1)
      return "GIF search is rate limited. Wait a minute and press Ctrl+R."
    if (detail.indexOf("401") !== -1 || detail.indexOf("403") !== -1)
      return "GIF search access was rejected. Press Ctrl+R to retry."
    if (detail.toLowerCase().indexOf("timed out") !== -1 || detail.indexOf("28") !== -1)
      return "GIF search timed out. Press Ctrl+R to retry."
    return "Could not reach the GIF provider. Check your connection and press Ctrl+R."
  }

  function navigate(direction) {
    if (resultModel.count === 0) return
    root.selectedIndex = LoopboxModel.navigate(root.selectedIndex, direction, resultModel.count, 4)
    if (root.selectedIndex >= 0)
      resultGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
  }

  function copyGif(index) {
    var result = root.resultAt(index)
    if (!result || root.copying || !result.originalUrl) return
    if (!root.pluginDirectory) {
      root.statusError = true
      root.statusMessage = "Loopbox could not locate its GIF copy helper."
      return
    }
    copyProc.pendingResult = result
    copyProc.command = [root.copyScript, result.originalUrl, result.provider, result.id]
    root.copying = true
    root.statusError = false
    root.statusMessage = "Downloading and copying GIF"
    copyProc.running = true
  }

  function copyLink(index) {
    var result = root.resultAt(index)
    if (!result || root.copying) return
    var url = result.shareUrl || result.originalUrl
    if (!url) {
      root.statusError = true
      root.statusMessage = "This GIF has no copyable link."
      return
    }
    linkProc.command = ["wl-copy", "--type", "text/plain;charset=utf-8", url]
    root.copying = true
    root.statusError = false
    root.statusMessage = "Copying GIF link"
    linkProc.running = true
  }

  Component.onCompleted: stateDirectoryProc.running = true

  ListModel { id: resultModel }

  Timer {
    id: searchDebounce
    interval: 220
    repeat: false
    onTriggered: root.startSearch(root.requestSerial, root.query)
  }

  Timer {
    id: dismissTimer
    interval: 420
    repeat: false
    onTriggered: root.dismiss()
  }

  Process {
    id: stateDirectoryProc
    command: ["mkdir", "-p", "-m", "700", root.stateDirectory]
    onExited: function(exitCode) {
      root.stateDirectoryReady = exitCode === 0
      if (root.stateDirectoryReady) {
        stateFile.reload()
        if (root.stateSavePending) root.saveState()
      } else if (root.opened) {
        root.statusError = true
        root.statusMessage = "Could not open Loopbox state storage. Favourites will not persist."
      }
    }
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: {
      root.state = LoopboxModel.parseState(text())
      if (root.opened && root.viewMode === "favorites") root.loadFavorites()
    }
    onLoadFailed: root.state = LoopboxModel.defaultState()
    onFileChanged: reload()
  }

  Process {
    id: searchProc
    property int activeSerial: 0
    property int queuedSerial: 0
    property string queuedQuery: ""
    property bool expectedStop: false

    stdout: StdioCollector { id: searchStdout; waitForEnd: true }
    stderr: StdioCollector { id: searchStderr; waitForEnd: true }

    onExited: function(exitCode, exitStatus) {
      var finishedSerial = activeSerial
      var nextSerial = queuedSerial
      var nextQuery = queuedQuery
      activeSerial = 0
      queuedSerial = 0
      queuedQuery = ""

      if (nextSerial > 0 && nextSerial === root.requestSerial && root.opened && root.viewMode !== "favorites") {
        Qt.callLater(function() { root.startSearch(nextSerial, nextQuery) })
        return
      }

      if (expectedStop || finishedSerial !== root.requestSerial || !root.opened || root.viewMode === "favorites") return
      root.loading = false

      if (exitCode !== 0 || exitStatus !== 0) {
        root.statusError = true
        root.statusMessage = root.providerFailure(searchStderr.text)
        return
      }

      try {
        var rows = Klipy.parseResponse(searchStdout.text)
        root.replaceResults(rows)
        root.statusError = false
        if (resultModel.count === 0) {
          root.statusMessage = root.query ? "No GIFs found. Try another search." : "No trending GIFs are available. Press Ctrl+R to retry."
        } else if (root.query) {
          root.statusMessage = resultModel.count + (resultModel.count === 1 ? " result for " : " results for ") + root.query
        } else {
          root.statusMessage = "Trending GIFs"
        }
      } catch (error) {
        root.statusError = true
        root.statusMessage = "The GIF provider returned an invalid response. Press Ctrl+R to retry."
      }
    }
  }

  Process {
    id: copyProc
    property var pendingResult: null
    stderr: StdioCollector { id: copyStderr; waitForEnd: true }
    onExited: function(exitCode, exitStatus) {
      root.copying = false
      if (!root.opened) return
      if (exitCode !== 0 || exitStatus !== 0) {
        var detail = String(copyStderr.text || "").trim()
        root.statusError = true
        root.statusMessage = detail || "Could not copy the GIF. Check your connection and try again."
        return
      }
      root.state = LoopboxModel.addRecent(root.state, pendingResult)
      root.saveState()
      root.statusError = false
      root.statusMessage = "GIF copied to the clipboard"
      dismissTimer.restart()
    }
  }

  Process {
    id: linkProc
    stderr: StdioCollector { id: linkStderr; waitForEnd: true }
    onExited: function(exitCode, exitStatus) {
      root.copying = false
      if (!root.opened) return
      if (exitCode !== 0 || exitStatus !== 0) {
        root.statusError = true
        root.statusMessage = "Could not copy the GIF link. Check that wl-copy is installed and try again."
        return
      }
      root.statusError = false
      root.statusMessage = "GIF link copied to the clipboard"
      dismissTimer.restart()
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "loopbox"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      anchors.centerIn: parent
      color: root.background
      radius: root.cornerRadius
      borderSpec: root.borderSpec
      padding: root.contentMargin
      scale: root.opened ? 1 : 0.98
      opacity: root.opened ? 1 : 0

      Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
      Behavior on opacity { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        z: 2

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          var control = (event.modifiers & Qt.ControlModifier) !== 0
          var shift = (event.modifiers & Qt.ShiftModifier) !== 0

          if (event.key === Qt.Key_Escape) {
            if (root.query) root.setQuery("")
            else root.dismiss()
            event.accepted = true
          } else if (control && shift && event.key === Qt.Key_F) {
            root.toggleSelectedFavorite()
            event.accepted = true
          } else if (control && !shift && event.key === Qt.Key_1) {
            root.showTrending()
            event.accepted = true
          } else if (control && !shift && event.key === Qt.Key_2) {
            root.showFavorites()
            event.accepted = true
          } else if (control && !shift && event.key === Qt.Key_R) {
            root.retrySearch()
            event.accepted = true
          } else if (Util.editsFilter(event, root.query)) {
            root.setQuery(Util.editedFilter(event, root.query))
            event.accepted = true
          } else if (event.key === Qt.Key_Left) {
            root.navigate("left")
            event.accepted = true
          } else if (event.key === Qt.Key_Right) {
            root.navigate("right")
            event.accepted = true
          } else if (event.key === Qt.Key_Up) {
            root.navigate("up")
            event.accepted = true
          } else if (event.key === Qt.Key_Down) {
            root.navigate("down")
            event.accepted = true
          } else if (event.key === Qt.Key_Home || event.key === Qt.Key_PageUp) {
            root.navigate("home")
            event.accepted = true
          } else if (event.key === Qt.Key_End || event.key === Qt.Key_PageDown) {
            root.navigate("end")
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (shift) root.copyLink(root.selectedIndex)
            else root.copyGif(root.selectedIndex)
            event.accepted = true
          } else if (!control && !(event.modifiers & (Qt.AltModifier | Qt.MetaModifier))
                     && event.text && event.text.length === 1
                     && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
            root.setQuery(root.query + event.text)
            event.accepted = true
          }
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        Item {
          id: header
          width: parent.width
          height: Math.max(Style.space(76), titleText.implicitHeight + searchBox.height + Style.spacing.md)

          Text {
            id: titleText
            anchors.left: parent.left
            anchors.top: parent.top
            text: "Loopbox"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.weight: Font.DemiBold
          }

          Text {
            anchors.right: parent.right
            anchors.top: parent.top
            text: "Ctrl+1  Trending    Ctrl+2  Favourites    Powered by KLIPY"
            color: root.foreground
            opacity: 0.58
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Rectangle {
            id: searchBox
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.max(Style.space(42), searchText.implicitHeight + Style.spacing.lg * 2)
            radius: root.cornerRadius
            color: Style.normalFillFor(root.foreground, Color.accent)
            border.color: root.query ? Color.accent : Style.normalBorderFor(root.foreground, Color.accent)
            border.width: root.query ? Math.max(1, Style.space(1)) : Style.normalBorderWidth

            Text {
              anchors.left: parent.left
              anchors.leftMargin: Style.spacing.xl
              anchors.verticalCenter: parent.verticalCenter
              text: ""
              color: root.query ? Color.accent : root.foreground
              opacity: root.query ? 1 : 0.55
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }

            Text {
              id: searchText
              anchors.left: parent.left
              anchors.leftMargin: Style.space(38)
              anchors.right: parent.right
              anchors.rightMargin: Style.spacing.xl
              anchors.verticalCenter: parent.verticalCenter
              text: root.query || (root.viewMode === "favorites" ? "Start typing to search GIFs" : "Search reaction GIFs")
              color: root.foreground
              opacity: root.query ? 1 : 0.5
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              elide: Text.ElideRight
            }
          }
        }

        Item {
          width: parent.width
          height: parent.height - parent.spacing * 2 - header.height - statusBar.height

          GridView {
            id: resultGrid
            anchors.fill: parent
            model: resultModel
            clip: true
            reuseItems: true
            cacheBuffer: 0
            boundsBehavior: Flickable.StopAtBounds
            cellWidth: width / 4
            cellHeight: height / 2
            interactive: false

            delegate: GifTile {
              width: resultGrid.cellWidth - Style.spacing.sm
              height: resultGrid.cellHeight - Style.spacing.sm
              selected: index === root.selectedIndex
              favourite: {
                var row = root.resultAt(index)
                return row ? LoopboxModel.isFavorite(root.state, row) : false
              }
              foreground: root.foreground
              selectedForeground: root.selectedText
              selectedBackground: root.selectedBackground
              onHovered: function(itemIndex) { root.selectedIndex = itemIndex }
              onActivated: function(itemIndex) {
                root.selectedIndex = itemIndex
                root.copyGif(itemIndex)
              }
              onImageFailed: function() {
                if (!root.statusError && !root.copying)
                  root.statusMessage = "A GIF preview could not load. You can still copy the selected GIF."
              }
            }
          }

          Column {
            anchors.centerIn: parent
            width: parent.width - Style.space(80)
            spacing: Style.spacing.lg
            visible: resultModel.count === 0

            Text {
              id: stateIcon
              width: parent.width
              text: root.loading ? "󰔟" : (root.statusError ? "" : (root.viewMode === "favorites" ? "" : "󰋩"))
              color: root.statusError ? Color.urgent : root.selectedText
              opacity: 0.82
              font.family: root.fontFamily
              font.pixelSize: Style.font.displayLarge
              horizontalAlignment: Text.AlignHCenter

              RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                running: root.loading && resultModel.count === 0
              }
            }

            Text {
              width: parent.width
              text: root.loading
                ? (root.query ? "Searching for GIFs" : "Loading trending GIFs")
                : root.statusMessage
              color: root.statusError ? Color.urgent : root.foreground
              opacity: 0.78
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.Wrap
            }
          }
        }

        StatusBar {
          id: statusBar
          width: parent.width
          message: root.statusMessage
          error: root.statusError
          busy: root.loading || root.copying
          foreground: root.foreground
        }
      }
    }
  }
}
