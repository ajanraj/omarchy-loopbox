import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
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
  property bool loadingMore: false
  property string nextPosition: ""
  property bool copying: false
  property int copyingIndex: -1
  property string statusMessage: ""
  property bool statusError: false
  property int requestSerial: 0
  property var state: LoopboxModel.defaultState()
  property bool stateLoadStarted: false
  property bool stateLoadFinished: false
  property bool stateStorageReady: false
  property bool stateSavePending: false
  property bool dismissAfterStateSave: false
  property string stateSaveContext: ""
  property string stateStorageError: ""
  property string persistedStateText: ""
  property string pendingStateText: ""
  property bool shortcutSetup: false
  property int shortcutSerial: 0
  property int shortcutCandidateIndex: 0
  property bool shortcutAvailable: false
  property bool shortcutChecking: false
  property bool shortcutInstalling: false
  property string shortcutConflict: ""
  property string shortcutDefaultConflict: ""
  property string shortcutError: ""
  property string customShortcut: ""
  property bool shortcutInstallPending: false
  property bool forceShortcutSetup: false
  property var shortcutCandidates: [
    "SUPER + CTRL + SHIFT + L",
    "SUPER + CTRL + SHIFT + J",
    "SUPER + CTRL + SHIFT + U",
    "SUPER + CTRL + SHIFT + M",
    "SUPER + CTRL + SHIFT + C"
  ]

  readonly property string pluginDirectory: manifest && manifest.__sourceDir ? String(manifest.__sourceDir) : ""
  readonly property string copyScript: pluginDirectory + "/scripts/copy-gif"
  readonly property string previewScript: pluginDirectory + "/scripts/preview-gif"
  readonly property string shortcutScript: pluginDirectory + "/scripts/shortcut"
  readonly property string stateScript: pluginDirectory ? pluginDirectory + "/scripts/state" : ""
  readonly property string selectedShortcut: customShortcut || shortcutCandidates[shortcutCandidateIndex] || shortcutCandidates[0]
  readonly property int pageSize: 24
  readonly property int maxResults: 96
  readonly property int columnCount: 4

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
    root.statusMessage = "Checking shortcut"
    root.statusError = false
    root.loading = false
    root.loadingMore = false
    root.nextPosition = ""
    resultModel.clear()
    root.requestSerial += 1
    root.forceShortcutSetup = false
    try {
      var payload = payloadJson ? JSON.parse(String(payloadJson)) : {}
      root.forceShortcutSetup = payload && payload.setupShortcut === true
    } catch (error) {}
    root.beginShortcutSetup()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function beginShortcutSetup() {
    root.shortcutSetup = true
    root.shortcutSerial += 1
    root.shortcutCandidateIndex = 0
    root.shortcutAvailable = false
    root.shortcutChecking = false
    root.shortcutInstalling = false
    root.shortcutConflict = ""
    root.shortcutDefaultConflict = ""
    root.shortcutError = ""
    root.customShortcut = ""
    root.shortcutInstallPending = false
    if (!root.pluginDirectory) {
      root.shortcutError = "Loopbox could not locate its shortcut helper. Press Tab to continue without a shortcut."
      return
    }
    root.checkShortcutCandidate(true)
  }

  function checkShortcutCandidate(findAlternative) {
    if (!root.opened || !root.shortcutSetup || shortcutProc.running) return
    root.shortcutAvailable = false
    root.shortcutChecking = true
    root.shortcutConflict = ""
    root.shortcutError = ""
    shortcutProc.serial = root.shortcutSerial
    shortcutProc.findAlternative = Boolean(findAlternative)
    shortcutProc.action = "status"
    shortcutProc.command = root.forceShortcutSetup
      ? [root.shortcutScript, "status", root.selectedShortcut, "--force"]
      : [root.shortcutScript, "status", root.selectedShortcut]
    shortcutProc.running = true
  }

  function chooseShortcut(offset) {
    if (root.shortcutChecking || root.shortcutInstalling || shortcutProc.running) return
    var count = root.shortcutCandidates.length
    root.customShortcut = ""
    root.shortcutCandidateIndex = (root.shortcutCandidateIndex + offset + count) % count
    root.checkShortcutCandidate(false)
  }

  function chooseShortcutLetter(letter) {
    if (root.shortcutChecking || root.shortcutInstalling || shortcutProc.running) return
    var key = String(letter || "").toUpperCase()
    if (!/^[A-Z]$/.test(key)) return
    root.customShortcut = "SUPER + CTRL + SHIFT + " + key
    root.checkShortcutCandidate(false)
  }

  function installSelectedShortcut() {
    if (root.shortcutChecking) {
      if (!root.shortcutDefaultConflict) root.shortcutInstallPending = true
      return
    }
    if (!root.shortcutAvailable || root.shortcutInstalling || shortcutProc.running) return
    root.shortcutInstallPending = false
    root.shortcutInstalling = true
    root.shortcutError = ""
    shortcutProc.serial = root.shortcutSerial
    shortcutProc.findAlternative = false
    shortcutProc.action = "install"
    shortcutProc.command = [root.shortcutScript, "install", root.selectedShortcut]
    shortcutProc.running = true
  }

  function skipShortcutSetup() {
    if (root.shortcutInstalling || shortcutProc.running) return
    root.shortcutChecking = true
    shortcutProc.serial = root.shortcutSerial
    shortcutProc.findAlternative = false
    shortcutProc.action = "skip"
    shortcutProc.command = [root.shortcutScript, "skip"]
    shortcutProc.running = true
  }

  function openPicker(message, error) {
    root.shortcutSerial += 1
    if (shortcutProc.running) shortcutProc.running = false
    root.shortcutSetup = false
    root.shortcutChecking = false
    root.shortcutInstalling = false
    root.statusMessage = root.stateStorageError || message || "Trending GIFs"
    root.statusError = Boolean(error) || Boolean(root.stateStorageError)
    root.requestSerial += 1
    root.startSearch(root.requestSerial, "")
  }

  // Called by the shell host before this unload-on-close plugin is destroyed.
  function close() {
    dismissTimer.stop()
    searchDebounce.stop()
    root.requestSerial += 1
    root.shortcutSerial += 1
    searchProc.queuedSerial = 0
    searchProc.expectedStop = true
    if (searchProc.running) searchProc.running = false
    if (copyProc.running) copyProc.running = false
    if (linkProc.running) linkProc.running = false
    if (shortcutProc.running) shortcutProc.running = false
    root.loading = false
    root.loadingMore = false
    root.nextPosition = ""
    root.copying = false
    root.copyingIndex = -1
    root.shortcutSetup = false
    root.shortcutChecking = false
    root.shortcutInstalling = false
    root.opened = false
  }

  function dismiss() {
    if (root.shortcutInstalling) return
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

  function appendResult(row) {
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

  function replaceResults(rows) {
    resultModel.clear()
    var count = Math.min(root.maxResults, Array.isArray(rows) ? rows.length : 0)
    for (var i = 0; i < count; i++) root.appendResult(rows[i])
    root.selectedIndex = resultModel.count > 0 ? 0 : -1
    Qt.callLater(function() {
      if (resultModel.count > 0) resultGrid.positionViewAtIndex(0, GridView.Contain)
    })
  }

  function appendResults(rows) {
    var incoming = Array.isArray(rows) ? rows : []
    var seen = {}
    for (var i = 0; i < resultModel.count; i++) {
      var existing = resultModel.get(i)
      seen[String(existing.provider || "") + ":" + String(existing.resultId || "")] = true
    }

    var added = 0
    for (var j = 0; j < incoming.length && resultModel.count < root.maxResults; j++) {
      var row = incoming[j]
      var key = String(row.provider || "") + ":" + String(row.id || "")
      if (!row.id || seen[key]) continue
      seen[key] = true
      root.appendResult(row)
      added += 1
    }
    return added
  }

  function resultsStatus() {
    var more = root.nextPosition ? " · scroll for more" : ""
    if (root.query)
      return resultModel.count + (resultModel.count === 1 ? " result for " : " results for ") + root.query + more
    return "Trending GIFs" + more
  }

  function loadFavorites() {
    root.replaceResults(root.state.favorites || [])
    root.loading = false
    root.loadingMore = false
    root.nextPosition = ""
    root.statusError = Boolean(root.stateStorageError)
    root.statusMessage = root.stateStorageError || (resultModel.count > 0
      ? resultModel.count + (resultModel.count === 1 ? " favourite" : " favourites")
      : "No favourites yet. Select a GIF and press Ctrl+Shift+F.")
  }

  function saveState(context, dismissWhenSaved) {
    root.stateSaveContext = String(context || "state")
    root.dismissAfterStateSave = Boolean(dismissWhenSaved)
    root.stateSavePending = true
    root.pendingStateText = LoopboxModel.serializeState(root.state) + "\n"
    if (!root.stateStorageReady || stateProc.running) {
      if (root.stateLoadFinished && !root.stateStorageReady)
        root.reportStateSaveFailure(root.stateStorageError)
      return
    }
    if (root.pendingStateText === root.persistedStateText) {
      Qt.callLater(function() { root.finishStateSave() })
      return
    }
    stateProc.action = "save"
    stateProc.command = [root.stateScript, "save"]
    stateProc.running = true
  }

  function stateSaveBlocksAction() {
    if (!root.stateLoadFinished) {
      root.statusError = false
      root.statusMessage = "Loading Loopbox state"
      return true
    }
    if (!root.stateSavePending) return false
    root.statusError = false
    root.statusMessage = "Finishing the previous state save"
    return true
  }

  function reportStateSaveFailure(detail) {
    var context = root.stateSaveContext || "state"
    var copied = root.dismissAfterStateSave
    root.stateSavePending = false
    root.dismissAfterStateSave = false
    root.stateSaveContext = ""
    root.pendingStateText = ""
    root.stateStorageError = String(detail || "").trim()
      || "Could not save Loopbox " + context + ". Check the Loopbox state directory permissions."
    if (root.opened) {
      root.statusError = true
      root.statusMessage = copied
        ? "Copied, but " + root.stateStorageError.charAt(0).toLowerCase() + root.stateStorageError.slice(1)
        : root.stateStorageError
    }
  }

  function finishStateSave() {
    if (!root.stateSavePending) return
    root.persistedStateText = root.pendingStateText
    root.pendingStateText = ""
    root.stateSavePending = false
    root.stateStorageError = ""
    var shouldDismiss = root.dismissAfterStateSave
    root.dismissAfterStateSave = false
    root.stateSaveContext = ""
    if (shouldDismiss) dismissTimer.restart()
  }

  function startStateLoad() {
    if (root.stateLoadStarted || !root.stateScript || stateProc.running) return
    root.stateLoadStarted = true
    stateProc.action = "load"
    stateProc.command = [root.stateScript, "load"]
    stateProc.running = true
  }

  function selectedIsFavorite() {
    var result = root.resultAt(root.selectedIndex)
    return result ? LoopboxModel.isFavorite(root.state, result) : false
  }

  function toggleSelectedFavorite() {
    var result = root.resultAt(root.selectedIndex)
    if (!result || root.copying) return
    if (root.stateSaveBlocksAction()) return
    var wasFavorite = LoopboxModel.isFavorite(root.state, result)
    root.state = LoopboxModel.toggleFavorite(root.state, result)
    root.saveState("favourites", false)
    root.statusError = false
    root.statusMessage = wasFavorite ? "Removed from favourites" : "Added to favourites"
    if (root.viewMode === "favorites") root.loadFavorites()
  }

  function scheduleSearch() {
    root.requestSerial += 1
    searchDebounce.restart()
  }

  function setQuery(nextQuery) {
    root.query = String(nextQuery || "").slice(0, 120)
    root.viewMode = root.query ? "search" : "trending"
    root.selectedIndex = resultModel.count > 0 ? 0 : -1
    root.nextPosition = ""
    root.loadingMore = false
    root.statusError = false
    root.statusMessage = root.query ? "Searching for " + root.query : "Loading trending GIFs"
    root.scheduleSearch()
  }

  function showTrending() {
    root.query = ""
    root.viewMode = "trending"
    root.nextPosition = ""
    root.loadingMore = false
    root.statusError = false
    root.statusMessage = "Loading trending GIFs"
    root.requestSerial += 1
    searchDebounce.stop()
    root.startSearch(root.requestSerial, "")
  }

  function showFavorites() {
    root.query = ""
    root.viewMode = "favorites"
    root.nextPosition = ""
    root.loadingMore = false
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
    root.nextPosition = ""
    root.loadingMore = false
    root.requestSerial += 1
    searchDebounce.stop()
    root.startSearch(root.requestSerial, root.query)
  }

  function startSearch(serial, searchQuery, cursor, append) {
    if (!root.opened || root.viewMode === "favorites") return
    var appendPage = Boolean(append)
    var position = String(cursor || "")
    if (appendPage && (!position || resultModel.count >= root.maxResults)) return
    if (searchProc.running) {
      searchProc.queuedSerial = serial
      searchProc.queuedQuery = searchQuery
      searchProc.queuedCursor = position
      searchProc.queuedAppend = appendPage
      searchProc.expectedStop = true
      searchProc.running = false
      if (appendPage) root.loadingMore = true
      else root.loading = true
      return
    }

    searchProc.activeSerial = serial
    searchProc.activeCursor = position
    searchProc.activeAppend = appendPage
    searchProc.queuedSerial = 0
    searchProc.queuedQuery = ""
    searchProc.queuedCursor = ""
    searchProc.queuedAppend = false
    searchProc.expectedStop = false
    searchProc.command = Klipy.searchCommand(searchQuery, root.pageSize, position)
    searchProc.running = true
    if (appendPage) root.loadingMore = true
    else root.loading = true
  }

  function loadNextPage() {
    if (!root.opened || root.viewMode === "favorites" || root.loading || root.loadingMore
        || searchProc.running || !root.nextPosition || resultModel.count >= root.maxResults) return
    root.statusError = false
    root.statusMessage = "Loading more GIFs"
    root.startSearch(root.requestSerial, root.query, root.nextPosition, true)
  }

  function providerFailure(message, exitCode) {
    var detail = String(message || "").trim()
    if (Number(exitCode) === 63)
      return "GIF provider returned too much data. Try again later."
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
    root.selectedIndex = LoopboxModel.navigate(root.selectedIndex, direction, resultModel.count, root.columnCount)
    if (root.selectedIndex >= 0)
      resultGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
    if (root.selectedIndex >= resultModel.count - root.columnCount * 2)
      root.loadNextPage()
  }

  function copyGif(index) {
    var result = root.resultAt(index)
    if (!result || root.copying || !result.originalUrl) return
    if (root.stateSaveBlocksAction()) return
    if (!root.pluginDirectory) {
      root.statusError = true
      root.statusMessage = "Loopbox could not locate its GIF copy helper."
      return
    }
    copyProc.pendingResult = result
    copyProc.command = [root.copyScript, result.originalUrl, result.provider, result.id]
    root.copying = true
    root.copyingIndex = index
    root.statusError = false
    root.statusMessage = "Preparing GIF for the clipboard"
    copyProc.running = true
  }

  function copyLink(index) {
    var result = root.resultAt(index)
    if (!result || root.copying) return
    if (root.stateSaveBlocksAction()) return
    var url = result.shareUrl || result.originalUrl
    if (!url) {
      root.statusError = true
      root.statusMessage = "This GIF has no copyable link."
      return
    }
    linkProc.command = ["wl-copy", "--type", "text/plain;charset=utf-8", url]
    linkProc.pendingResult = result
    root.copying = true
    root.copyingIndex = index
    root.statusError = false
    root.statusMessage = "Copying GIF link"
    linkProc.running = true
  }

  Component.onCompleted: root.startStateLoad()
  onStateScriptChanged: root.startStateLoad()

  ListModel { id: resultModel }

  Timer {
    id: searchDebounce
    interval: 220
    repeat: false
    onTriggered: root.startSearch(root.requestSerial, root.query, "", false)
  }

  Timer {
    id: dismissTimer
    interval: 420
    repeat: false
    onTriggered: root.dismiss()
  }

  Process {
    id: stateProc
    property string action: ""

    stdinEnabled: true
    stdout: StdioCollector { id: stateStdout; waitForEnd: true }
    stderr: StdioCollector { id: stateStderr; waitForEnd: true }

    onStarted: {
      if (action === "save") write(root.pendingStateText)
    }

    onExited: function(exitCode, exitStatus) {
      var succeeded = exitCode === 0 && exitStatus === 0
      var detail = String(stateStderr.text || "").trim()

      if (action === "save") {
        if (succeeded)
          root.finishStateSave()
        else
          root.reportStateSaveFailure(detail)
        return
      }

      root.stateLoadFinished = true
      root.stateStorageReady = succeeded
      if (succeeded) {
        root.stateStorageError = ""
        var loadedText = String(stateStdout.text || "")
        root.state = LoopboxModel.parseState(loadedText)
        root.persistedStateText = loadedText
          ? LoopboxModel.serializeState(root.state) + "\n"
          : ""
        if (root.stateSavePending)
          Qt.callLater(function() { root.saveState(root.stateSaveContext, root.dismissAfterStateSave) })
        if (root.opened && root.viewMode === "favorites") root.loadFavorites()
        return
      }

      root.state = LoopboxModel.defaultState()
      root.persistedStateText = ""
      root.stateStorageError = detail || "Could not access Loopbox state storage. Check its permissions and file types."
      if (root.stateSavePending) {
        root.reportStateSaveFailure(root.stateStorageError)
        return
      }
      if (root.opened) {
        root.statusError = true
        root.statusMessage = root.stateStorageError
      }
    }
  }

  Process {
    id: searchProc
    property int activeSerial: 0
    property string activeCursor: ""
    property bool activeAppend: false
    property int queuedSerial: 0
    property string queuedQuery: ""
    property string queuedCursor: ""
    property bool queuedAppend: false
    property bool expectedStop: false

    stdout: StdioCollector { id: searchStdout; waitForEnd: true }
    stderr: StdioCollector { id: searchStderr; waitForEnd: true }

    onExited: function(exitCode, exitStatus) {
      var finishedSerial = activeSerial
      var finishedCursor = activeCursor
      var finishedAppend = activeAppend
      var nextSerial = queuedSerial
      var nextQuery = queuedQuery
      var nextCursor = queuedCursor
      var nextAppend = queuedAppend
      activeSerial = 0
      activeCursor = ""
      activeAppend = false
      queuedSerial = 0
      queuedQuery = ""
      queuedCursor = ""
      queuedAppend = false

      if (nextSerial > 0 && nextSerial === root.requestSerial && root.opened && root.viewMode !== "favorites") {
        Qt.callLater(function() { root.startSearch(nextSerial, nextQuery, nextCursor, nextAppend) })
        return
      }

      if (expectedStop || finishedSerial !== root.requestSerial || !root.opened || root.viewMode === "favorites") return
      if (finishedAppend) root.loadingMore = false
      else root.loading = false

      if (exitCode !== 0 || exitStatus !== 0) {
        root.statusError = true
        root.statusMessage = finishedAppend
          ? "Could not load more GIFs. Scroll to the end to retry."
          : root.providerFailure(searchStderr.text, exitCode)
        return
      }

      try {
        var page = Klipy.parsePage(searchStdout.text)
        var added = 0
        if (finishedAppend)
          added = root.appendResults(page.results)
        else {
          root.replaceResults(page.results)
          added = resultModel.count
        }
        var candidate = String(page.next || "")
        root.nextPosition = resultModel.count < root.maxResults
          && candidate && candidate !== finishedCursor && added > 0 ? candidate : ""
        root.statusError = Boolean(root.stateStorageError)
        if (root.stateStorageError) {
          root.statusMessage = root.stateStorageError
        } else if (resultModel.count === 0) {
          root.statusMessage = root.query ? "No GIFs found. Try another search." : "No trending GIFs are available. Press Ctrl+R to retry."
        } else {
          root.statusMessage = root.resultsStatus()
        }
      } catch (error) {
        root.statusError = true
        root.statusMessage = finishedAppend
          ? "The GIF provider returned an invalid next page. Scroll to the end to retry."
          : "The GIF provider returned an invalid response. Press Ctrl+R to retry."
      }
    }
  }

  Process {
    id: copyProc
    property var pendingResult: null
    stderr: StdioCollector { id: copyStderr; waitForEnd: true }
    onExited: function(exitCode, exitStatus) {
      root.copying = false
      root.copyingIndex = -1
      if (!root.opened) return
      if (exitCode !== 0 || exitStatus !== 0) {
        var detail = String(copyStderr.text || "").trim()
        root.statusError = true
        root.statusMessage = detail || "Could not copy the GIF. Check your connection and try again."
        return
      }
      root.state = LoopboxModel.addRecent(root.state, pendingResult)
      root.statusError = false
      root.statusMessage = "GIF copied to the clipboard"
      root.saveState("recents", true)
    }
  }

  Process {
    id: linkProc
    property var pendingResult: null
    stderr: StdioCollector { id: linkStderr; waitForEnd: true }
    // Dismiss only after the copied link has also reached recents on disk.
    onExited: function(exitCode, exitStatus) {
      root.copying = false
      root.copyingIndex = -1
      if (!root.opened) return
      if (exitCode !== 0 || exitStatus !== 0) {
        root.statusError = true
        root.statusMessage = "Could not copy the GIF link. Check that wl-copy is installed and try again."
        return
      }
      root.state = LoopboxModel.addRecent(root.state, pendingResult)
      root.statusError = false
      root.statusMessage = "GIF link copied to the clipboard"
      root.saveState("recents", true)
    }
  }

  Process {
    id: shortcutProc
    property int serial: 0
    property bool findAlternative: false
    property string action: ""

    stdout: StdioCollector { id: shortcutStdout; waitForEnd: true }
    stderr: StdioCollector { id: shortcutStderr; waitForEnd: true }

    onExited: function(exitCode, exitStatus) {
      if (serial !== root.shortcutSerial || !root.opened || !root.shortcutSetup) return

      root.shortcutChecking = false
      var finishedAction = action
      root.shortcutInstalling = false
      if (exitCode !== 0 || exitStatus !== 0) {
        var detail = String(shortcutStderr.text || "").trim()
        if (finishedAction === "status" || finishedAction === "skip") {
          root.openPicker(detail || "Shortcut setup is unavailable. Open Loopbox from the bar.", true)
          return
        }
        root.shortcutAvailable = false
        root.shortcutError = detail || "Could not inspect Hyprland shortcuts. Press Tab to continue without one."
        return
      }

      var response
      try {
        response = JSON.parse(String(shortcutStdout.text || ""))
      } catch (error) {
        if (finishedAction === "status" || finishedAction === "skip") {
          root.openPicker("Shortcut setup returned an invalid response. Open Loopbox from the bar.", true)
          return
        }
        root.shortcutAvailable = false
        root.shortcutError = "The shortcut helper returned an invalid response. Press Tab to continue without one."
        return
      }

      if (finishedAction === "skip" || response.skipped) {
        root.openPicker("")
        return
      }
      if (finishedAction === "install" && response.installed) {
        root.openPicker("Shortcut ready. Trending GIFs")
        return
      }
      if (response.configured) {
        root.openPicker("")
        return
      }

      root.shortcutAvailable = Boolean(response.available)
      root.shortcutConflict = String(response.conflict || "")
      root.shortcutError = ""

      if (!root.shortcutAvailable && findAlternative) {
        if (root.shortcutCandidateIndex === 0) {
          root.shortcutDefaultConflict = root.shortcutConflict || "another action"
          root.shortcutInstallPending = false
        }
        if (root.shortcutCandidateIndex + 1 < root.shortcutCandidates.length) {
          root.shortcutCandidateIndex += 1
          Qt.callLater(function() { root.checkShortcutCandidate(true) })
        }
      } else if (root.shortcutAvailable && root.shortcutInstallPending) {
        Qt.callLater(function() { root.installSelectedShortcut() })
      }
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
      onClicked: if (!root.shortcutInstalling) root.dismiss()
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

          if (root.shortcutSetup) {
            if (root.shortcutInstalling) {
              event.accepted = true
              return
            }
            if (event.key === Qt.Key_Escape) {
              root.dismiss()
            } else if (event.key === Qt.Key_Left) {
              root.chooseShortcut(-1)
            } else if (event.key === Qt.Key_Right) {
              root.chooseShortcut(1)
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              root.installSelectedShortcut()
            } else if (event.key === Qt.Key_Tab) {
              root.skipShortcutSetup()
            } else if (!control && !shift
                       && !(event.modifiers & (Qt.AltModifier | Qt.MetaModifier))
                       && event.text && /^[a-zA-Z]$/.test(event.text)) {
              root.chooseShortcutLetter(event.text)
            }
            event.accepted = true
            return
          }

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
        visible: !root.shortcutSetup

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
            text: "Type to search    Ctrl+1  Trending    Ctrl+2  Favourites    Powered by KLIPY"
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
              textFormat: Text.PlainText
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
            cacheBuffer: cellHeight
            boundsBehavior: Flickable.StopAtBounds
            cellWidth: width / root.columnCount
            cellHeight: height / 2
            interactive: contentHeight > height
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            onContentYChanged: {
              if (contentHeight > height
                  && contentY + height >= contentHeight - cellHeight * 1.5)
                root.loadNextPage()
            }
            onMovementEnded: {
              if (atYEnd) root.loadNextPage()
            }

            delegate: GifTile {
              width: resultGrid.cellWidth - Style.spacing.sm
              height: resultGrid.cellHeight - Style.spacing.sm
              selected: index === root.selectedIndex
              previewScript: root.previewScript
              busy: root.copying && index === root.copyingIndex
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
              textFormat: Text.PlainText
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
          busy: root.loading || root.loadingMore || root.copying
          foreground: root.foreground
        }
      }

      ShortcutSetup {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        visible: root.shortcutSetup
        foreground: root.foreground
        accent: Color.accent
        selectedBackground: root.selectedBackground
        fontFamily: root.fontFamily
        defaultShortcut: root.shortcutCandidates[0]
        shortcut: root.selectedShortcut
        conflict: root.shortcutConflict
        defaultConflict: root.shortcutDefaultConflict
        errorMessage: root.shortcutError
        available: root.shortcutAvailable
        checking: root.shortcutChecking
        installing: root.shortcutInstalling
        candidateIndex: root.shortcutCandidateIndex
        candidateCount: root.shortcutCandidates.length
        onPreviousRequested: root.chooseShortcut(-1)
        onNextRequested: root.chooseShortcut(1)
        onInstallRequested: root.installSelectedShortcut()
        onSkipRequested: root.skipShortcutSetup()
      }
    }
  }
}
