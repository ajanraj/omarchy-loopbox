#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
gif_tile="$script_dir/../components/GifTile.qml"
loopbox="$script_dir/../Loopbox.qml"
status_bar="$script_dir/../components/StatusBar.qml"
shortcut_setup="$script_dir/../components/ShortcutSetup.qml"
key_hint="$script_dir/../components/KeyHint.qml"
clipboard_helper="$script_dir/../scripts/clipboard-gif"

if ! awk '
    /id: label/ { in_label = 1 }
    in_label && /textFormat:[[:space:]]*Text\.PlainText/ { plain_text = 1 }
    in_label && /^    }/ { exit plain_text ? 0 : 1 }
    END { if (!in_label || !plain_text) exit 1 }
' "$gif_tile"; then
    printf 'FAIL: provider-controlled GIF titles must use Text.PlainText\n' >&2
    exit 1
fi

animated_source=$(awk '
    /AnimatedImage[[:space:]]*\{/ { in_image = 1 }
    in_image && /^[[:space:]]*source:/ { print; exit }
' "$gif_tile")
[[ "$animated_source" == *'tile.localPreviewPath'* ]] || {
    printf 'FAIL: AnimatedImage.source must use only the local preview cache path\n' >&2
    exit 1
}
[[ "$animated_source" != *'previewUrl'* ]] || {
    printf 'FAIL: provider preview URLs must never be assigned to AnimatedImage.source\n' >&2
    exit 1
}
grep -F 'fillMode: Image.PreserveAspectFit' "$gif_tile" >/dev/null || {
    printf 'FAIL: GIF cards must letterbox previews instead of cropping or stretching them\n' >&2
    exit 1
}
grep -F 'anchors.bottom: caption.top' "$gif_tile" >/dev/null || {
    printf 'FAIL: GIF card captions must occupy a separate row below the preview\n' >&2
    exit 1
}

grep -F 'requestSerial === tile.previewSerial' "$gif_tile" >/dev/null || {
    printf 'FAIL: preview completion must be gated by the current request serial\n' >&2
    exit 1
}
grep -F 'expectedUrl === tile.previewUrl' "$gif_tile" >/dev/null || {
    printf 'FAIL: preview completion must be gated by the current delegate URL\n' >&2
    exit 1
}
grep -F 'localPreviewPath = ""' "$gif_tile" >/dev/null || {
    printf 'FAIL: delegate reuse must clear the prior local preview\n' >&2
    exit 1
}
grep -F 'onStarted: launchPending = false' "$gif_tile" >/dev/null || {
    printf 'FAIL: preview launch tracking must observe successful process startup\n' >&2
    exit 1
}
grep -F 'if (!running && launchPending)' "$gif_tile" >/dev/null || {
    printf 'FAIL: a preview helper that fails to start must leave the loading state\n' >&2
    exit 1
}
grep -F 'previewScript: root.previewScript' "$loopbox" >/dev/null || {
    printf 'FAIL: preview delegates must receive the local preview helper\n' >&2
    exit 1
}
grep -F 'source: root.fullPreviewPath' "$loopbox" >/dev/null || {
    printf 'FAIL: full-window previews must decode only a local cache path\n' >&2
    exit 1
}
grep -F 'fullPreviewProc.command = [root.previewScript, result.previewUrl]' "$loopbox" >/dev/null || {
    printf 'FAIL: full-window provider URLs must pass through the hardened preview helper\n' >&2
    exit 1
}
grep -F 'event.key === Qt.Key_Space' "$loopbox" >/dev/null || {
    printf 'FAIL: the selected GIF must expose its full-window Space preview\n' >&2
    exit 1
}
if grep -Eq '^[[:space:]]*(provider|resultId):[[:space:]]*model\.' "$loopbox"; then
    printf 'FAIL: ListModel roles must use required-property injection, not an undefined model object\n' >&2
    exit 1
fi
grep -F 'required property string provider' "$gif_tile" >/dev/null || {
    printf 'FAIL: preview delegates must inject the provider ListModel role\n' >&2
    exit 1
}
grep -F 'required property string resultId' "$gif_tile" >/dev/null || {
    printf 'FAIL: preview delegates must inject the resultId ListModel role\n' >&2
    exit 1
}
grep -F 'readonly property int pageSize: 24' "$loopbox" >/dev/null || {
    printf 'FAIL: provider pagination must retain a bounded page size\n' >&2
    exit 1
}
grep -F 'readonly property int maxResults: 96' "$loopbox" >/dev/null || {
    printf 'FAIL: the long-lived shell must cap retained GIF results\n' >&2
    exit 1
}
grep -F 'interactive: contentHeight > height' "$loopbox" >/dev/null || {
    printf 'FAIL: the GIF grid must allow scrolling when results overflow\n' >&2
    exit 1
}
grep -F 'root.loadNextPage()' "$loopbox" >/dev/null || {
    printf 'FAIL: the GIF grid must request another bounded page near its end\n' >&2
    exit 1
}
grep -F 'scrollGestureEnabled: false' "$gif_tile" >/dev/null || {
    printf 'FAIL: GIF tiles must pass touchpad scrolling through to the grid\n' >&2
    exit 1
}
grep -F 'wheel.accepted = false' "$gif_tile" >/dev/null || {
    printf 'FAIL: GIF tiles must pass mouse-wheel scrolling through to the grid\n' >&2
    exit 1
}
grep -F 'var page = Klipy.parsePage(searchStdout.text)' "$loopbox" >/dev/null || {
    printf 'FAIL: the search process must retain the validated provider cursor\n' >&2
    exit 1
}
grep -F 'id: searchInput' "$loopbox" >/dev/null || {
    printf 'FAIL: the search box must be a real text input\n' >&2
    exit 1
}
grep -F 'searchInput.forceActiveFocus()' "$loopbox" >/dev/null || {
    printf 'FAIL: the search input must receive focus when the picker opens\n' >&2
    exit 1
}
grep -F 'cursorVisible: activeFocus && root.opened && !root.shortcutSetup' "$loopbox" >/dev/null || {
    printf 'FAIL: the focused search input must expose its blinking cursor\n' >&2
    exit 1
}
grep -F 'onTextEdited: root.setQuery(text)' "$loopbox" >/dev/null || {
    printf 'FAIL: native text input edits must drive GIF filtering\n' >&2
    exit 1
}
grep -F 'textFormat: Text.PlainText' "$status_bar" >/dev/null || {
    printf 'FAIL: search status text must render as plain text\n' >&2
    exit 1
}
grep -F 'KeyHint {' "$status_bar" >/dev/null || {
    printf 'FAIL: bottom-bar shortcuts must be presented as distinct key/action groups\n' >&2
    exit 1
}
grep -F '"Launch shortcut"' "$status_bar" >/dev/null || {
    printf 'FAIL: the configured launcher chord must identify the action it opens\n' >&2
    exit 1
}
grep -F 'chord: "Ctrl+1"' "$loopbox" >/dev/null || {
    printf 'FAIL: header navigation must present shortcuts as distinct key/action groups\n' >&2
    exit 1
}
grep -F 'onClicked: root.shortcutRequested()' "$status_bar" >/dev/null || {
    printf 'FAIL: the visible shortcut control must open shortcut settings\n' >&2
    exit 1
}
grep -F 'currentShortcut: root.configuredShortcut' "$loopbox" >/dev/null || {
    printf 'FAIL: shortcut settings must display the active chord\n' >&2
    exit 1
}
grep -F 'function recordShortcut(event)' "$loopbox" >/dev/null || {
    printf 'FAIL: shortcut setup must record the complete key event\n' >&2
    exit 1
}
grep -F 'if (event.modifiers & Qt.MetaModifier) parts.push("SUPER")' "$loopbox" >/dev/null || {
    printf 'FAIL: the shortcut recorder must preserve the user-held modifier set\n' >&2
    exit 1
}
grep -F 'onRecordRequested: root.startShortcutRecording()' "$loopbox" >/dev/null || {
    printf 'FAIL: shortcut settings must expose an explicit recording action\n' >&2
    exit 1
}
grep -F '"Record shortcut"' "$shortcut_setup" >/dev/null || {
    printf 'FAIL: the arbitrary shortcut recorder must be clearly labelled\n' >&2
    exit 1
}
if grep -F 'chooseShortcutLetter' "$loopbox" >/dev/null; then
    printf 'FAIL: shortcut selection must not append one letter to fixed modifiers\n' >&2
    exit 1
fi
grep -F 'onCancelRequested: root.cancelShortcutSetup()' "$loopbox" >/dev/null || {
    printf 'FAIL: rebinding must allow the active shortcut to be kept\n' >&2
    exit 1
}
grep -F 'onLauncherInstallRequested: root.installLauncher()' "$loopbox" >/dev/null || {
    printf 'FAIL: settings must expose the explicit Omarchy-menu install action\n' >&2
    exit 1
}
grep -F 'launcherProc.command = [root.launcherScript, "install"]' "$loopbox" >/dev/null || {
    printf 'FAIL: the Omarchy-menu action must use a fixed launcher-helper command\n' >&2
    exit 1
}
grep -F '"Add to Omarchy menu"' "$shortcut_setup" >/dev/null || {
    printf 'FAIL: the external app-menu write must have a clearly labelled UI action\n' >&2
    exit 1
}
grep -F 'scripts/launcher' "$loopbox" >/dev/null || {
    printf 'FAIL: settings must resolve the packaged launcher helper\n' >&2
    exit 1
}
grep -F 'if (!root.forceShortcutSetup)' "$loopbox" >/dev/null || {
    printf 'FAIL: a forced bar-icon setup request must not skip past shortcut settings\n' >&2
    exit 1
}
grep -F 'setupShortcut\":true' "$script_dir/../BarWidget.qml" >/dev/null || {
    printf 'FAIL: right-clicking the bar icon must request shortcut settings\n' >&2
    exit 1
}
grep -F 'Gdk.FileList.new_from_list' "$clipboard_helper" >/dev/null || {
    printf 'FAIL: GIF copy must advertise the original file to clipboard consumers\n' >&2
    exit 1
}
grep -F 'new_for_bytes("image/gif"' "$clipboard_helper" >/dev/null || {
    printf 'FAIL: GIF copy must also advertise the original image/gif bytes\n' >&2
    exit 1
}

qmllint "$gif_tile"
qmllint "$loopbox" "$shortcut_setup" "$status_bar" "$key_hint"
printf 'PASS: QML provider text and local preview security contracts\n'
